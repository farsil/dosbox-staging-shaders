#version 330 core

/*
    zfast_crt - A very simple CRT shader.

    Copyright (C) 2017 Greg Hogan (SoltanGris42)
    edited by metallic 77.

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

    This file ported from Libretro's GLSL shader zfast-composite.glslp
    to DOSBox-compatible format by Tyrells, updated for version 0.83
    by Farsil.

*/

/*

#pragma name        Main_Pass1
#pragma output_size Viewport

#pragma linear_filtering on

#pragma parameter blurx "Convergence X-Axis" 0.35 -1.0 2.0 0.05
#pragma parameter blury "Convergence Y-Axis" -0.15 -1.0 1.0 0.05
#pragma parameter HIGHSCANAMOUNT1 "Scanline Amount (Low)" 0.3 0.0 1.0 0.05
#pragma parameter HIGHSCANAMOUNT2 "Scanline Amount (High)" 0.2 0.0 1.0 0.05
#pragma parameter MASK_DARK "Mask Effect Amount" 0.25 0.0 1.0 0.05
#pragma parameter MASK_FADE "Mask/Scanline Fade" 0.8 0.0 1.0 0.05
#pragma parameter sat "Saturation" 1.0 0.0 3.0 0.05

*/

#if defined(VERTEX)

layout (location = 0) in vec2 a_position;

out vec2 v_texCoord;
out float maskFade;

uniform float MASK_FADE;

void main()
{
    gl_Position = vec4(a_position, 0.0, 1.0);
    v_texCoord = vec2(a_position.x + 1.0, a_position.y + 1.0) / 2.0;
    v_texCoord.xy *= 1.0001;

    maskFade = 0.3333 * MASK_FADE;
}

#elif defined(FRAGMENT)

in vec2 v_texCoord;
in float maskFade;

out vec4 FragColor;

uniform vec2 INPUT_SIZE_0;
uniform sampler2D INPUT_TEXTURE_0;

uniform float blurx;
uniform float blury;
uniform float HIGHSCANAMOUNT1;
uniform float HIGHSCANAMOUNT2;
uniform float MASK_DARK;
uniform float sat;

#define PI 3.14159

void main()
{
    vec2 pos = v_texCoord;

    vec3 sample1 = texture(INPUT_TEXTURE_0, vec2(pos.x + blurx/1000.0, pos.y + blury/1000.0)).rgb;
    vec3 sample2 = texture(INPUT_TEXTURE_0, pos).rgb;
    vec3 sample3 = texture(INPUT_TEXTURE_0, vec2(pos.x - blurx/1000.0, pos.y - blury/1000.0)).rgb;

    vec3 colour = vec3(sample1.r*0.5 + sample2.r*0.5, sample1.g*0.25 + sample2.g*0.5 + sample3.g*0.25, sample2.b*0.5 + sample3.b*0.5);
    float lum = colour.r*0.4 + colour.g*0.4 + colour.b*0.2;

    vec3 lumweight = vec3(0.3, 0.6, 0.1);
    float gray = dot(colour, lumweight);
    vec3 graycolour = vec3(gray);

    //Gamma-like
    colour *= mix(0.4, 1.0, lum);

    float SCANAMOUNT = mix(HIGHSCANAMOUNT1, HIGHSCANAMOUNT2, lum);
    // 0.83 flips the texture Y axis, so measure Y from the far end to keep
    // the original light/dark line order.
    float scanLine = SCANAMOUNT * sin(2.0*PI*(1.0 - pos.y) * INPUT_SIZE_0.y);

    float whichmask = fract(gl_FragCoord.x*-0.4999);
    float mask = 1.0 + float(whichmask < 0.5) * -MASK_DARK;

    //Gamma-like
    colour *= mix(2.0, 1.0, lum);

    colour = vec3(mix(graycolour, colour.rgb, sat));

    colour.rgb *= mix(mask*(1.0-scanLine), 1.0-scanLine, dot(colour.rgb,vec3(maskFade)));
    FragColor.rgba = vec4(colour.rgb, 1.0);
}

#endif
