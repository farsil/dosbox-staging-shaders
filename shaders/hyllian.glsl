#version 330 core

/*
   Hyllian's CRT Shader

   Copyright (C) 2011-2016 Hyllian - sergiogdb@gmail.com

   Copyright (C) 2020, this file ported from Libretro's GLSL
   shader crt-hyllian.glslp to DOSBox-compatible format by Tyrells,
   updated for version 0.83 by Farsil.

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.

*/

/*

#pragma name        Main_Pass1
#pragma output_size Viewport

#pragma linear_filtering on

#pragma parameter PHOSPHOR "CRT - Phosphor ON/OFF" 1.0 0.0 1.0 1.0
#pragma parameter VSCANLINES "CRT - Scanlines Direction" 0.0 0.0 1.0 1.0
#pragma parameter InputGamma "CRT - Input gamma" 2.4 0.0 5.0 0.1
#pragma parameter OutputGamma "CRT - Output Gamma" 2.2 0.0 5.0 0.1
#pragma parameter SHARPNESS "CRT - Sharpness Hack" 1.0 1.0 5.0 1.0
#pragma parameter COLOR_BOOST "CRT - Color Boost" 1.5 1.0 2.0 0.05
#pragma parameter RED_BOOST "CRT - Red Boost" 1.0 1.0 2.0 0.01
#pragma parameter GREEN_BOOST "CRT - Green Boost" 1.0 1.0 2.0 0.01
#pragma parameter BLUE_BOOST "CRT - Blue Boost" 1.0 1.0 2.0 0.01
#pragma parameter SCANLINES_STRENGTH "CRT - Scanline Strength" 0.72 0.0 1.0 0.02
#pragma parameter BEAM_MIN_WIDTH "CRT - Min Beam Width" 0.86 0.0 1.0 0.02
#pragma parameter BEAM_MAX_WIDTH "CRT - Max Beam Width" 1.0 0.0 1.0 0.02
#pragma parameter CRT_ANTI_RINGING "CRT - Anti-Ringing" 0.8 0.0 1.0 0.1

*/

#define GAMMA_IN(color)     pow(color, vec4(InputGamma, InputGamma, InputGamma, InputGamma))
#define GAMMA_OUT(color)    pow(color, vec4(1.0 / OutputGamma, 1.0 / OutputGamma, 1.0 / OutputGamma, 1.0 / OutputGamma))

// Horizontal cubic filter.

// Some known filters use these values:

//    B = 0.0, C = 0.0  =>  Hermite cubic filter.
//    B = 1.0, C = 0.0  =>  Cubic B-Spline filter.
//    B = 0.0, C = 0.5  =>  Catmull-Rom Spline filter. This is the default used in this shader.
//    B = C = 1.0/3.0   =>  Mitchell-Netravali cubic filter.
//    B = 0.3782, C = 0.3109  =>  Robidoux filter.
//    B = 0.2620, C = 0.3690  =>  Robidoux Sharp filter.
//    B = 0.36, C = 0.28  =>  My best config for ringing elimination in pixel art (Hyllian).

// For more info, see: http://www.imagemagick.org/Usage/img_diagrams/cubic_survey.gif

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

uniform float PHOSPHOR;
uniform float VSCANLINES;
uniform float InputGamma;
uniform float OutputGamma;
uniform float SHARPNESS;
uniform float COLOR_BOOST;
uniform float RED_BOOST;
uniform float GREEN_BOOST;
uniform float BLUE_BOOST;
uniform float SCANLINES_STRENGTH;
uniform float BEAM_MIN_WIDTH;
uniform float BEAM_MAX_WIDTH;
uniform float CRT_ANTI_RINGING;
// END PARAMETERS //

// Change these params to configure the horizontal filter.
const float  B =  0.0;
const float  C =  0.5;

const  mat4 invX = mat4((-B - 6.0*C)/6.0,         (12.0 - 9.0*B - 6.0*C)/6.0,  -(12.0 - 9.0*B - 6.0*C)/6.0,  (B + 6.0*C)/6.0,
                        (3.0*B + 12.0*C)/6.0,     (-18.0 + 12.0*B + 6.0*C)/6.0, (18.0 - 15.0*B - 12.0*C)/6.0,             -C,
                        (-3.0*B - 6.0*C)/6.0,                              0.0,          (3.0*B + 6.0*C)/6.0,            0.0,
                        B/6.0,                              (6.0 - 2.0*B)/6.0,                        B/6.0,             0.0);

void main()
{
    vec2 texture_size = vec2(SHARPNESS*INPUT_SIZE_0.x, INPUT_SIZE_0.y);

    vec4 color;
    vec2 dx = mix(vec2(1.0/texture_size.x, 0.0), vec2(0.0, 1.0/texture_size.y), VSCANLINES);
    vec2 dy = mix(vec2(0.0, 1.0/texture_size.y), vec2(1.0/texture_size.x, 0.0), VSCANLINES);

    vec2 pix_coord = v_texCoord*texture_size+vec2(-0.5,0.5);

    vec2 tc = mix((floor(pix_coord) + vec2(0.5, 0.5))/texture_size, (floor(pix_coord) + vec2(1.0, -0.5))/texture_size, VSCANLINES);

    vec2 fp = mix(fract(pix_coord), fract(pix_coord.yx), VSCANLINES);

    vec4 c00 = GAMMA_IN(texture(INPUT_TEXTURE_0, tc     - dx - dy).xyzw);
    vec4 c01 = GAMMA_IN(texture(INPUT_TEXTURE_0, tc          - dy).xyzw);
    vec4 c02 = GAMMA_IN(texture(INPUT_TEXTURE_0, tc     + dx - dy).xyzw);
    vec4 c03 = GAMMA_IN(texture(INPUT_TEXTURE_0, tc + 2.0*dx - dy).xyzw);
    vec4 c10 = GAMMA_IN(texture(INPUT_TEXTURE_0, tc     - dx).xyzw);
    vec4 c11 = GAMMA_IN(texture(INPUT_TEXTURE_0, tc         ).xyzw);
    vec4 c12 = GAMMA_IN(texture(INPUT_TEXTURE_0, tc     + dx).xyzw);
    vec4 c13 = GAMMA_IN(texture(INPUT_TEXTURE_0, tc + 2.0*dx).xyzw);

    //  Get min/max samples
    vec4 min_sample = min(min(c01,c11), min(c02,c12));
    vec4 max_sample = max(max(c01,c11), max(c02,c12));

    mat4 color_matrix0 = mat4(c00, c01, c02, c03);
    mat4 color_matrix1 = mat4(c10, c11, c12, c13);

    vec4 lobes = vec4(fp.x*fp.x*fp.x, fp.x*fp.x, fp.x, 1.0);

    vec4 invX_Px  = invX * lobes;
    vec4 color0   = color_matrix0 * invX_Px;
    vec4 color1   = color_matrix1 * invX_Px;

    // Anti-ringing
    vec4 aux = color0;
    color0 = clamp(color0, min_sample, max_sample);
    color0 = mix(aux, color0, CRT_ANTI_RINGING);
    aux = color1;
    color1 = clamp(color1, min_sample, max_sample);
    color1 = mix(aux, color1, CRT_ANTI_RINGING);

    float pos0 = fp.y;
    float pos1 = 1.0 - fp.y;

    vec4 lum0 = mix(vec4(BEAM_MIN_WIDTH), vec4(BEAM_MAX_WIDTH), color0);
    vec4 lum1 = mix(vec4(BEAM_MIN_WIDTH), vec4(BEAM_MAX_WIDTH), color1);

    vec4 d0 = clamp(pos0/(lum0+0.0000001), 0.0, 1.0);
    vec4 d1 = clamp(pos1/(lum1+0.0000001), 0.0, 1.0);

    d0 = exp(-10.0*SCANLINES_STRENGTH*d0*d0);
    d1 = exp(-10.0*SCANLINES_STRENGTH*d1*d1);

    color = clamp(color0*d0+color1*d1, 0.0, 1.0);

    color *= COLOR_BOOST*vec4(RED_BOOST, GREEN_BOOST, BLUE_BOOST, 1.0);

    float mod_factor = v_texCoord.x * OUTPUT_SIZE.x;

    vec4 dotMaskWeights = mix(
                                 vec4(1.0, 0.7, 1.0, 1.),
                                 vec4(0.7, 1.0, 0.7, 1.),
                                 floor(mod(mod_factor, 2.0))
                                  );

    color.rgba *= mix(vec4(1.0,1.0,1.0,1.0), dotMaskWeights, PHOSPHOR);

    color = GAMMA_OUT(color);

    FragColor = vec4(color.rgb, 1.0);
}

#endif
