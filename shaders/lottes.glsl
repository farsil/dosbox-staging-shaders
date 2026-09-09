#version 330 core

// PUBLIC DOMAIN CRT STYLED SCAN-LINE SHADER
//
//   by Timothy Lottes
//
// This is more along the style of a really good CGA arcade monitor.
// With RGB inputs instead of NTSC.
// The shadow mask example has the mask rotated 90 degrees for less chromatic aberration.
//
// Left it unoptimized to show the theory behind the algorithm.
//
// It is an example what I personally would want as a display option for pixel art games.
// Please take and use, change, or whatever.

// This file ported from Libretro's GLSL shader crt-lottes.glslp
// to DOSBox-compatible format by Tyrells, updated for version 0.83
// by Farsil.
//
// The libretro 'use_srgb_texture' and 'use_srgb_framebuffer' pragmas have been
// dropped; they are rejected by 0.83. In their place, we apply the linear <-> 
// gamma conversion in the shader code.

/*

#pragma name        Main_Pass1
#pragma output_size Viewport

#pragma linear_filtering off

// Parameter lines go here:
#pragma parameter hardScan "hardScan" -8.0 -20.0 0.0 1.0
#pragma parameter hardPix "hardPix" -3.0 -20.0 0.0 1.0
#pragma parameter warpX "warpX" 0.031 0.0 0.125 0.01
#pragma parameter warpY "warpY" 0.041 0.0 0.125 0.01
#pragma parameter maskDark "maskDark" 0.5 0.0 2.0 0.1
#pragma parameter maskLight "maskLight" 1.5 0.0 2.0 0.1
#pragma parameter shadowMask "shadowMask" 3.0 0.0 4.0 1.0
#pragma parameter brightBoost "brightness boost" 1.0 0.0 2.0 0.05
#pragma parameter hardBloomPix "bloom-x soft" -1.5 -2.0 -0.5 0.1
#pragma parameter hardBloomScan "bloom-y soft" -2.0 -4.0 -1.0 0.1
#pragma parameter bloomAmount "bloom ammount" 0.15 0.0 1.0 0.05
#pragma parameter shape "filter kernel shape" 2.0 0.0 10.0 0.05

*/

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
uniform sampler2D INPUT_TEXTURE_0;

uniform float hardScan;
uniform float hardPix;
uniform float warpX;
uniform float warpY;
uniform float maskDark;
uniform float maskLight;
uniform float shadowMask;
uniform float brightBoost;
uniform float hardBloomPix;
uniform float hardBloomScan;
uniform float bloomAmount;
uniform float shape;

//Uncomment to reduce instructions with simpler linearization
//(fixes HD3000 Sandy Bridge IGP)
#define DO_BLOOM

// Nearest emulated sample given floating point position and texel offset.
// Also zero's off screen.
vec3 Fetch(vec2 pos,vec2 off){
    pos=(floor(pos*INPUT_SIZE_0+off)+vec2(0.5,0.5))/INPUT_SIZE_0;
    // sRGB => linear; see the note at the top of the file
    return brightBoost * pow(texture(INPUT_TEXTURE_0,pos.xy).rgb, vec3(2.2));
}

// Distance in emulated pixels to nearest texel.
vec2 Dist(vec2 pos)
{
    pos = pos*INPUT_SIZE_0;

    return -((pos - floor(pos)) - vec2(0.5));
}

// 1D Gaussian.
float Gaus(float pos, float scale)
{
    return exp2(scale*pow(abs(pos), shape));
}

// 3-tap Gaussian filter along horz line.
vec3 Horz3(vec2 pos, float off)
{
    vec3 b    = Fetch(pos, vec2(-1.0, off));
    vec3 c    = Fetch(pos, vec2( 0.0, off));
    vec3 d    = Fetch(pos, vec2( 1.0, off));
    float dst = Dist(pos).x;

    // Convert distance to weight.
    float scale = hardPix;
    float wb = Gaus(dst-1.0,scale);
    float wc = Gaus(dst+0.0,scale);
    float wd = Gaus(dst+1.0,scale);

    // Return filtered sample.
    return (b*wb+c*wc+d*wd)/(wb+wc+wd);
}

// 5-tap Gaussian filter along horz line.
vec3 Horz5(vec2 pos,float off){
    vec3 a = Fetch(pos,vec2(-2.0, off));
    vec3 b = Fetch(pos,vec2(-1.0, off));
    vec3 c = Fetch(pos,vec2( 0.0, off));
    vec3 d = Fetch(pos,vec2( 1.0, off));
    vec3 e = Fetch(pos,vec2( 2.0, off));

    float dst = Dist(pos).x;
    // Convert distance to weight.
    float scale = hardPix;
    float wa = Gaus(dst - 2.0, scale);
    float wb = Gaus(dst - 1.0, scale);
    float wc = Gaus(dst + 0.0, scale);
    float wd = Gaus(dst + 1.0, scale);
    float we = Gaus(dst + 2.0, scale);

    // Return filtered sample.
    return (a*wa+b*wb+c*wc+d*wd+e*we)/(wa+wb+wc+wd+we);
}

// 7-tap Gaussian filter along horz line.
vec3 Horz7(vec2 pos,float off)
{
    vec3 a = Fetch(pos, vec2(-3.0, off));
    vec3 b = Fetch(pos, vec2(-2.0, off));
    vec3 c = Fetch(pos, vec2(-1.0, off));
    vec3 d = Fetch(pos, vec2( 0.0, off));
    vec3 e = Fetch(pos, vec2( 1.0, off));
    vec3 f = Fetch(pos, vec2( 2.0, off));
    vec3 g = Fetch(pos, vec2( 3.0, off));

    float dst = Dist(pos).x;
    // Convert distance to weight.
    float scale = hardBloomPix;
    float wa = Gaus(dst - 3.0, scale);
    float wb = Gaus(dst - 2.0, scale);
    float wc = Gaus(dst - 1.0, scale);
    float wd = Gaus(dst + 0.0, scale);
    float we = Gaus(dst + 1.0, scale);
    float wf = Gaus(dst + 2.0, scale);
    float wg = Gaus(dst + 3.0, scale);

    // Return filtered sample.
    return (a*wa+b*wb+c*wc+d*wd+e*we+f*wf+g*wg)/(wa+wb+wc+wd+we+wf+wg);
}

// Return scanline weight.
float Scan(vec2 pos, float off)
{
    float dst = Dist(pos).y;

    return Gaus(dst + off, hardScan);
}

// Return scanline weight for bloom.
float BloomScan(vec2 pos, float off)
{
    float dst = Dist(pos).y;

    return Gaus(dst + off, hardBloomScan);
}

// Allow nearest three lines to effect pixel.
vec3 Tri(vec2 pos)
{
    vec3 a = Horz3(pos,-1.0);
    vec3 b = Horz5(pos, 0.0);
    vec3 c = Horz3(pos, 1.0);

    float wa = Scan(pos,-1.0);
    float wb = Scan(pos, 0.0);
    float wc = Scan(pos, 1.0);

    return a*wa + b*wb + c*wc;
}

// Small bloom.
vec3 Bloom(vec2 pos)
{
    vec3 a = Horz5(pos,-2.0);
    vec3 b = Horz7(pos,-1.0);
    vec3 c = Horz7(pos, 0.0);
    vec3 d = Horz7(pos, 1.0);
    vec3 e = Horz5(pos, 2.0);

    float wa = BloomScan(pos,-2.0);
    float wb = BloomScan(pos,-1.0);
    float wc = BloomScan(pos, 0.0);
    float wd = BloomScan(pos, 1.0);
    float we = BloomScan(pos, 2.0);

    return a*wa+b*wb+c*wc+d*wd+e*we;
}

// Distortion of scanlines, and end of screen alpha.
vec2 Warp(vec2 pos)
{
    pos  = pos*2.0-1.0;
    pos *= vec2(1.0 + (pos.y*pos.y)*warpX, 1.0 + (pos.x*pos.x)*warpY);

    return pos*0.5 + 0.5;
}

// Shadow mask.
vec3 Mask(vec2 pos)
{
    vec3 mask = vec3(maskDark, maskDark, maskDark);

    // Very compressed TV style shadow mask.
    if (shadowMask == 1.0)
    {
        float line = maskLight;
        float odd = 0.0;

        if (fract(pos.x*0.166666666) < 0.5) odd = 1.0;
        if (fract((pos.y + odd) * 0.5) < 0.5) line = maskDark;

        pos.x = fract(pos.x*0.333333333);

        if      (pos.x < 0.333) mask.r = maskLight;
        else if (pos.x < 0.666) mask.g = maskLight;
        else                    mask.b = maskLight;
        mask*=line;
    }

    // Aperture-grille.
    else if (shadowMask == 2.0)
    {
        pos.x = fract(pos.x*0.333333333);

        if      (pos.x < 0.333) mask.r = maskLight;
        else if (pos.x < 0.666) mask.g = maskLight;
        else                    mask.b = maskLight;
    }

    // Stretched VGA style shadow mask (same as prior shaders).
    else if (shadowMask == 3.0)
    {
        pos.x += pos.y*3.0;
        pos.x  = fract(pos.x*0.166666666);

        if      (pos.x < 0.333) mask.r = maskLight;
        else if (pos.x < 0.666) mask.g = maskLight;
        else                    mask.b = maskLight;
    }

    // VGA style shadow mask.
    else if (shadowMask == 4.0)
    {
        pos.xy  = floor(pos.xy*vec2(1.0, 0.5));
        pos.x  += pos.y*3.0;
        pos.x   = fract(pos.x*0.166666666);

        if      (pos.x < 0.333) mask.r = maskLight;
        else if (pos.x < 0.666) mask.g = maskLight;
        else                    mask.b = maskLight;
    }

    return mask;
}

void main()
{
    vec2 pos = Warp(v_texCoord);
    vec3 outColor = Tri(pos);

#ifdef DO_BLOOM
    //Add Bloom
    outColor.rgb += Bloom(pos)*bloomAmount;
#endif

    if (shadowMask > 0.0)
        outColor.rgb *= Mask(gl_FragCoord.xy * 1.000001);

    // linear => sRGB; see the note at the top of the file
    FragColor = vec4(pow(outColor.rgb, vec3(1.0 / 2.2)), 1.0);
}

#endif
