#version 330 core

// CRT Emulation
// by Mattias
// https://www.shadertoy.com/view/lsB3DV

// This file ported from Libretro's GLSL shader crt-mattias.glslp
// to DOSBox-compatible format by Tyrells, updated for version 0.83
// by Farsil.
//
// DOSBox staging 0.83 exposes no frame counter or time uniform, so this
// shader's animated effects are frozen and SCANSPEED has no effect. Film-grain
// noise was removed.

/*

#pragma name        Main_Pass1
#pragma output_size Viewport

#pragma linear_filtering on

#pragma parameter CURVATURE "Curvature" 0.5 0.0 1.0 0.05
#pragma parameter SCANSPEED "Scanline Crawl Speed" 1.0 0.0 10.0 0.5

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

uniform vec2 OUTPUT_SIZE;
uniform sampler2D INPUT_TEXTURE_0;

uniform float CURVATURE;
uniform float SCANSPEED;

#define iChannel0 INPUT_TEXTURE_0
#define iTime 0.0
#define iResolution OUTPUT_SIZE
#define fragCoord gl_FragCoord.xy

vec3 sample_( sampler2D tex, vec2 tc )
{
    vec3 s = pow(texture(tex,tc).rgb, vec3(2.2));
    return s;
}

vec3 blur(sampler2D tex, vec2 tc, float offs)
{
    vec4 xoffs = offs * vec4(-2.0, -1.0, 1.0, 2.0) / iResolution.x;
    vec4 yoffs = offs * vec4(-2.0, -1.0, 1.0, 2.0) / iResolution.y;

    vec3 color = vec3(0.0, 0.0, 0.0);
    color += sample_(tex,tc + vec2(xoffs.x, yoffs.x)) * 0.00366;
    color += sample_(tex,tc + vec2(xoffs.y, yoffs.x)) * 0.01465;
    color += sample_(tex,tc + vec2(    0.0, yoffs.x)) * 0.02564;
    color += sample_(tex,tc + vec2(xoffs.z, yoffs.x)) * 0.01465;
    color += sample_(tex,tc + vec2(xoffs.w, yoffs.x)) * 0.00366;

    color += sample_(tex,tc + vec2(xoffs.x, yoffs.y)) * 0.01465;
    color += sample_(tex,tc + vec2(xoffs.y, yoffs.y)) * 0.05861;
    color += sample_(tex,tc + vec2(    0.0, yoffs.y)) * 0.09524;
    color += sample_(tex,tc + vec2(xoffs.z, yoffs.y)) * 0.05861;
    color += sample_(tex,tc + vec2(xoffs.w, yoffs.y)) * 0.01465;

    color += sample_(tex,tc + vec2(xoffs.x, 0.0)) * 0.02564;
    color += sample_(tex,tc + vec2(xoffs.y, 0.0)) * 0.09524;
    color += sample_(tex,tc + vec2(    0.0, 0.0)) * 0.15018;
    color += sample_(tex,tc + vec2(xoffs.z, 0.0)) * 0.09524;
    color += sample_(tex,tc + vec2(xoffs.w, 0.0)) * 0.02564;

    color += sample_(tex,tc + vec2(xoffs.x, yoffs.z)) * 0.01465;
    color += sample_(tex,tc + vec2(xoffs.y, yoffs.z)) * 0.05861;
    color += sample_(tex,tc + vec2(    0.0, yoffs.z)) * 0.09524;
    color += sample_(tex,tc + vec2(xoffs.z, yoffs.z)) * 0.05861;
    color += sample_(tex,tc + vec2(xoffs.w, yoffs.z)) * 0.01465;

    color += sample_(tex,tc + vec2(xoffs.x, yoffs.w)) * 0.00366;
    color += sample_(tex,tc + vec2(xoffs.y, yoffs.w)) * 0.01465;
    color += sample_(tex,tc + vec2(    0.0, yoffs.w)) * 0.02564;
    color += sample_(tex,tc + vec2(xoffs.z, yoffs.w)) * 0.01465;
    color += sample_(tex,tc + vec2(xoffs.w, yoffs.w)) * 0.00366;

    return color;
}

vec2 curve(vec2 uv)
{
    uv = (uv - 0.5) * 2.0;
    uv *= 1.1;
    uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0);
    uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0);
    uv  = (uv / 2.0) + 0.5;
    uv =  uv *0.92 + 0.04;
    return uv;
}

void main()
{
    vec2 q = v_texCoord;//fragCoord.xy / iResolution.xy;
    vec2 uv = q;
    uv = mix( uv, curve( uv ), CURVATURE );
    vec3 col;
    float o =2.0*mod(fragCoord.y,2.0)/iResolution.x;

    col.r = 1.0*blur(iChannel0,vec2(uv.x+0.0009,uv.y-0.0009),1.2).x+0.005;
    col.g = 1.0*blur(iChannel0,vec2(uv.x+0.000,uv.y+0.0015),1.2).y+0.005;
    col.b = 1.0*blur(iChannel0,vec2(uv.x-0.0015,uv.y+0.000),1.2).z+0.005;
    col.r += 0.2*blur(iChannel0,vec2(uv.x+0.0009,uv.y-0.0009),2.25).x-0.005;
    col.g += 0.2*blur(iChannel0,vec2(uv.x+0.000,uv.y+0.0015),1.75).y-0.005;
    col.b += 0.2*blur(iChannel0,vec2(uv.x-0.0015,uv.y+0.000),1.25).z-0.005;
    float ghs = 0.05;
    col.r += ghs*(1.0-0.299)*blur(iChannel0,0.75*vec2(0.01, 0.027)+vec2(uv.x+0.001,uv.y-0.001),7.0).x;
    col.g += ghs*(1.0-0.587)*blur(iChannel0,0.75*vec2(-0.022, 0.02)+vec2(uv.x+0.000,uv.y+0.002),5.0).y;
    col.b += ghs*(1.0-0.114)*blur(iChannel0,0.75*vec2(-0.02, -0.0)+vec2(uv.x-0.002,uv.y+0.000),3.0).z;



    col = clamp(col*0.4+0.6*col*col*1.0,0.0,1.0);
    float vig = (0.0 + 1.0*16.0*uv.x*uv.y*(1.0-uv.x)*(1.0-uv.y));
    vig = pow(vig,0.3);
    col *= vec3(vig);

    col *= vec3(0.95,1.05,0.95);
    col = mix( col, col * col, 0.3) * 3.8;

    // 0.83 flips the texture Y axis, so measure Y from the far end to keep
    // the original light/dark line order.
    float scans = clamp( 0.35+0.15*sin(3.5*(iTime * SCANSPEED)+(1.0-uv.y)*iResolution.y*1.5), 0.0, 1.0);

    float s = pow(scans,0.9);
    col = col*vec3( s) ;

    col *= 1.0+0.0015*sin(300.0*iTime);

    col*=1.0-0.15*vec3(clamp((mod(fragCoord.x+o, 2.0)-1.0)*2.0,0.0,1.0));
    col = pow(col, vec3(0.45));

    if (uv.x < 0.0 || uv.x > 1.0)
        col *= 0.0;
    if (uv.y < 0.0 || uv.y > 1.0)
        col *= 0.0;

    FragColor = vec4(col, 1.0);
}

#endif
