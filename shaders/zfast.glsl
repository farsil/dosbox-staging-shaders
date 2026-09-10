#version 330 core

/*
    zfast_crt_standard - A simple, fast CRT shader.

    Copyright (C) 2017 Greg Hogan (SoltanGris42)

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.


Notes:  This shader does scaling with a weighted linear filter for adjustable
    sharpness on the x and y axes based on the algorithm by Inigo Quilez here:
    http://http://www.iquilezles.org/www/articles/texture/texture.htm
    but modified to be somewhat sharper.  Then a scanline effect that varies
    based on pixel brighness is applied along with a monochrome aperture mask.
    This shader runs at 60fps on the Raspberry Pi 3 hardware at 2mpix/s
    resolutions (1920x1080 or 1600x1200).

    This file ported from Libretro's GLSL shader zfast-crt.glslp
    to DOSBox-compatible format by Tyrells, updated for version 0.83
    by Farsil.

*/

//This can't be an option without slowing the shader down
//Comment this out for a coarser 3 pixel mask...which is currently broken
//on SNES Classic Edition due to Mali 400 gpu precision
#define FINEMASK

//Some drivers don't return black with texture coordinates out of bounds
//SNES Classic is too slow to black these areas out when using fullscreen
//overlays.  But you can uncomment the below to black them out if necessary
//#define BLACK_OUT_BORDER

/*

#pragma name        Main_Pass1
#pragma output_size Viewport

#pragma linear_filtering on

// Parameter lines go here:
#pragma parameter BLURSCALEX "Blur Amount X-Axis" 0.45 0.0 1.0 0.05
#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 5.0 0.0 10.0 0.5
#pragma parameter HILUMSCAN "Scanline Darkness - High" 10.0 0.0 50.0 1.0
#pragma parameter BRIGHTBOOST "Dark Pixel Brightness Boost" 1.25 0.5 1.5 0.05
#pragma parameter MASK_DARK "Mask Effect Amount" 0.25 0.0 1.0 0.05
#pragma parameter MASK_FADE "Mask/Scanline Fade" 0.8 0.0 1.0 0.05

*/

#if defined(VERTEX)

layout (location = 0) in vec2 a_position;

out vec2 v_texCoord;
out float maskFade;
out vec2 invDims;

uniform vec2 INPUT_SIZE_0;

uniform float MASK_FADE;

void main()
{
    gl_Position = vec4(a_position, 0.0, 1.0);
    v_texCoord = vec2(a_position.x + 1.0, a_position.y + 1.0) / 2.0;
    v_texCoord.xy *= 1.0001;

    maskFade = 0.3333*MASK_FADE;
    invDims = 1.0/INPUT_SIZE_0.xy;
}

#elif defined(FRAGMENT)

in vec2 v_texCoord;
in float maskFade;
in vec2 invDims;

out vec4 FragColor;

uniform vec2 INPUT_SIZE_0;
uniform sampler2D INPUT_TEXTURE_0;

uniform float BLURSCALEX;
//uniform float BLURSCALEY;
uniform float LOWLUMSCAN;
uniform float HILUMSCAN;
uniform float BRIGHTBOOST;
uniform float MASK_DARK;
uniform float MASK_FADE;

void main()
{

    //This is just like "Quilez Scaling" but sharper
    vec2 p = v_texCoord * INPUT_SIZE_0;
    vec2 i = floor(p) + 0.50;
    vec2 f = p - i;
    p = (i + 4.0*f*f*f)*invDims;
    p.x = mix( p.x , v_texCoord.x, BLURSCALEX);
    float Y = f.y*f.y;
    float YY = Y*Y;

#if defined(FINEMASK)
    float whichmask = fract(gl_FragCoord.x*-0.4999);
    float mask = 1.0 + float(whichmask < 0.5) * -MASK_DARK;
#else
    float whichmask = fract(gl_FragCoord.x * -0.3333);
    float mask = 1.0 + float(whichmask <= 0.33333) * -MASK_DARK;
#endif
    vec3 colour = texture(INPUT_TEXTURE_0, p).rgb;

    float scanLineWeight = (BRIGHTBOOST - LOWLUMSCAN*(Y - 2.05*YY));
    float scanLineWeightB = 1.0 - HILUMSCAN*(YY-2.8*YY*Y);

#if defined(BLACK_OUT_BORDER)
    colour.rgb*=float(p.x > 0.0)*float(p.y > 0.0); //why doesn't the driver do the right thing?
#endif

    FragColor.rgba = vec4(colour.rgb*mix(scanLineWeight*mask, scanLineWeightB, dot(colour.rgb,vec3(maskFade))), 1.0);
}

#endif
