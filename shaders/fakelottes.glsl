#version 330 core

/*
 * CRT STYLED SCAN-LINE SHADER
 *
 *  SPDX-License-Identifier: CC-PDDC, Public Domain
 *
 * Contributors:
 *   - 2017, Timothy Lottes: authored
 *           This is more along the style of a really good CGA arcade monitor.
 *           With RGB inputs instead of NTSC.
 *           The shadow mask example has the mask rotated 90 degrees for less chromatic aberration.
 *           Left it unoptimized to show the theory behind the algorithm.
 *           It is an example what I personally would want as a display option for pixel art games.
 *           Please take and use, change, or whatever.
 *           https://github.com/libretro/common-shaders/blob/master/crt/shaders/crt-lottes.cg
 *
 *   - 2018, hunterk: modified
 *           Simple scanlines with curvature and mask effects lifted from crt-lottes
 *           https://github.com/Themaister/slang-shaders/blob/master/crt/shaders/fakelottes.slang
 *
 *   - 2020, Ported from Libretro's GLSL shader crt-lottes.glslp
 *           to DOSBox-compatible format by Tyrells.
 *
 *   - 2026, Updated for version 0.83 by Farsil.
 *
 */

/*

#pragma name        Main_Pass1
#pragma output_size Viewport

#pragma linear_filtering on

///////////////////////  Runtime Parameters  ///////////////////////
#pragma parameter shadowMask "shadowMask" 1.0 0.0 4.0 1.0
#pragma parameter SCANLINE_SINE_COMP_B "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter warpX "warpX" 0.031 0.0 0.125 0.01
#pragma parameter warpY "warpY" 0.041 0.0 0.125 0.01
#pragma parameter maskDark "maskDark" 0.5 0.0 2.0 0.1
#pragma parameter maskLight "maskLight" 1.5 0.0 2.0 0.1
#pragma parameter crt_gamma "CRT Gamma" 2.5 1.0 4.0 0.05
#pragma parameter monitor_gamma "Monitor Gamma" 2.2 1.0 4.0 0.05
#pragma parameter SCANLINE_SINE_COMP_A "Scanline Sine Comp A" 0.0 0.0 0.10 0.01
#pragma parameter SCANLINE_BASE_BRIGHTNESS "Scanline Base Brightness" 0.95 0.0 1.0 0.01

*/

////////////////////////////////////////////////////////////////////
////////////////////////////  SETTINGS  ////////////////////////////
/////  comment these lines to disable effects and gain speed  //////
////////////////////////////////////////////////////////////////////

#define MASK // fancy, expensive phosphor mask effect
// #define CURVATURE // applies barrel distortion to the screen
#define SCANLINES // applies horizontal scanline effect
// #define ROTATE_SCANLINES // for TATE games; also disables the mask effects, which look bad with it
#define EXTRA_MASKS // disable these if you need extra registers freed up

////////////////////////////////////////////////////////////////////
//////////////////////////  END SETTINGS  //////////////////////////
////////////////////////////////////////////////////////////////////

// prevent stupid behavior
#if defined ROTATE_SCANLINES && !defined SCANLINES
#define SCANLINES
#endif

#if defined(VERTEX)

layout (location = 0) in vec2 a_position;

out vec2 v_texCoord;

void main()
{
    gl_Position = vec4(a_position, 0.0, 1.0);
    v_texCoord = vec2(a_position.x + 1.0, a_position.y + 1.0) / 2.0;
}

#elif defined(FRAGMENT)

in vec2 v_texCoord;

out vec4 FragColor;

uniform vec2 INPUT_SIZE_0;
uniform vec2 OUTPUT_SIZE;
uniform sampler2D INPUT_TEXTURE_0;

uniform float SCANLINE_BASE_BRIGHTNESS;
uniform float SCANLINE_SINE_COMP_A;
uniform float SCANLINE_SINE_COMP_B;
uniform float warpX;
uniform float warpY;
uniform float maskDark;
uniform float maskLight;
uniform float shadowMask;
uniform float crt_gamma;
uniform float monitor_gamma;

vec4 scanline(vec2 coord, vec4 frame)
{
#if defined SCANLINES
    vec2 omega = vec2(3.1415 * OUTPUT_SIZE.x, 2.0 * 3.1415 * INPUT_SIZE_0.y);
    vec2 sine_comp = vec2(SCANLINE_SINE_COMP_A, SCANLINE_SINE_COMP_B);
    vec3 res = frame.xyz;
#ifdef ROTATE_SCANLINES
    sine_comp = sine_comp.yx;
    omega = omega.yx;
#endif
    vec3 scanline = res * (SCANLINE_BASE_BRIGHTNESS + dot(sine_comp * sin(coord * omega), vec2(1.0, 1.0)));

    return vec4(scanline.x, scanline.y, scanline.z, 1.0);
#else
    return frame;
#endif
}

#ifdef CURVATURE
// Distortion of scanlines, and end of screen alpha.
vec2 Warp(vec2 pos)
{
    pos = pos * 2.0 - 1.0;
    pos *= vec2(1.0 + (pos.y * pos.y) * warpX, 1.0 + (pos.x * pos.x) * warpY);

    return pos * 0.5 + 0.5;
}
#endif

#if defined MASK && !defined ROTATE_SCANLINES
// Shadow mask.
vec4 Mask(vec2 pos)
{
    vec3 mask = vec3(maskDark, maskDark, maskDark);

    // Very compressed TV style shadow mask.
    if (shadowMask == 1.0) {
        float line = maskLight;
        float odd = 0.0;

        if (fract(pos.x * 0.166666666) < 0.5)
            odd = 1.0;
        if (fract((pos.y + odd) * 0.5) < 0.5)
            line = maskDark;

        pos.x = fract(pos.x * 0.333333333);

        if (pos.x < 0.333)
            mask.r = maskLight;
        else if (pos.x < 0.666)
            mask.g = maskLight;
        else
            mask.b = maskLight;
        mask *= line;
    }

    // Aperture-grille.
    else if (shadowMask == 2.0) {
        pos.x = fract(pos.x * 0.333333333);

        if (pos.x < 0.333)
            mask.r = maskLight;
        else if (pos.x < 0.666)
            mask.g = maskLight;
        else
            mask.b = maskLight;
    }
#ifdef EXTRA_MASKS
    // These can cause moire with curvature and scanlines
    // so they're an easy target for freeing up registers

    // Stretched VGA style shadow mask (same as prior shaders).
    else if (shadowMask == 3.0) {
        pos.x += pos.y * 3.0;
        pos.x = fract(pos.x * 0.166666666);

        if (pos.x < 0.333)
            mask.r = maskLight;
        else if (pos.x < 0.666)
            mask.g = maskLight;
        else
            mask.b = maskLight;
    }

    // VGA style shadow mask.
    else if (shadowMask == 4.0) {
        pos.xy = floor(pos.xy * vec2(1.0, 0.5));
        pos.x += pos.y * 3.0;
        pos.x = fract(pos.x * 0.166666666);

        if (pos.x < 0.333)
            mask.r = maskLight;
        else if (pos.x < 0.666)
            mask.g = maskLight;
        else
            mask.b = maskLight;
    }
#endif

    else
        mask = vec3(1., 1., 1.);

    return vec4(mask, 1.0);
}
#endif

void main()
{
#ifdef CURVATURE
    vec2 pos = Warp(v_texCoord);
#else
    vec2 pos = v_texCoord;
#endif

#if defined MASK && !defined ROTATE_SCANLINES
    // mask effects look bad unless applied in linear gamma space
    vec4 in_gamma = vec4(monitor_gamma, monitor_gamma, monitor_gamma, 1.0);
    vec4 out_gamma = vec4(1.0 / crt_gamma, 1.0 / crt_gamma, 1.0 / crt_gamma, 1.0);
    vec4 res = pow(texture(INPUT_TEXTURE_0, pos), in_gamma);
#else
    vec4 res = texture(INPUT_TEXTURE_0, pos);
#endif

#if defined MASK && !defined ROTATE_SCANLINES
    // apply the mask; looks bad with vert scanlines so make them mutually exclusive
    res *= Mask(gl_FragCoord.xy * 1.0001);
#endif

#if defined MASK && !defined ROTATE_SCANLINES
    // re-apply the gamma curve for the mask path
    FragColor = pow(scanline(pos, res), out_gamma);
#else
    FragColor = scanline(pos, res);
#endif
}

#endif
