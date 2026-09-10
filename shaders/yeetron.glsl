#version 330 core

// ported from ReShade

// This file ported from Libretro's GLSL shader yeetron.glslp
// to DOSBox-compatible format by Tyrells, updated for version 0.83
// by Farsil.

/*

#pragma name        Main_Pass1
#pragma output_size Viewport

#pragma linear_filtering off

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
uniform vec2 OUTPUT_SIZE;
uniform sampler2D INPUT_TEXTURE_0;

// The vertical warp resolves to exactly floor(pixel) for two of every three
// output rows, so uv lands on a texel boundary. The epsilon is required: uv
// arrives as P/H and floor(uv * H) returns P-1 in 32-bit float for a
// scattering of rows (14 of 401 at H=400), which drops a source line.
vec4 nnTexture(in sampler2D sampler, in vec2 uv)
{
    // The added 1e-4 epsilon prevents sampling at texel boundaries, if uv
    // arrives as P/H, floor(uv * H) returns P-1 in 32-bit float
    vec2 texCoord = floor(uv * INPUT_SIZE_0 + 1e-4) + vec2(0.5);
    vec2 invTexSize = 1.0 / INPUT_SIZE_0;
    return texture(sampler, texCoord * invTexSize);
}

vec4 cmp(vec4 src0, vec4 src1, vec4 src2) {
    return vec4(
        src0.x >= 0.0 ? src1.x : src2.x,
        src0.y >= 0.0 ? src1.y : src2.y,
        src0.z >= 0.0 ? src1.z : src2.z,
        src0.w >= 0.0 ? src1.w : src2.w
    );
}

#define saturate(c) clamp(c, 0.0, 1.0)

void main()
{
    //Declare parameters
    //pixelSize
    vec4 c0 = INPUT_SIZE_0.xyyy;
    //textureSize
    vec4 c1 = vec4(INPUT_SIZE_0, 1.0 / INPUT_SIZE_0);
    //viewSize
    vec4 c2 = vec4(OUTPUT_SIZE, 1.0 / OUTPUT_SIZE);

    //Declare constants
    const vec4 c3 = vec4(1.5, 0.800000012, 1.25, 0.75);
    const vec4 c4 = vec4(6.28318548, -3.14159274, 0.25, -0.25);
    const vec4 c5 = vec4(1., 0.5, 720., 3.);
    const vec4 c6 = vec4(0.166666672, -0.333000004, -0.666000009, 0.899999976);
    const vec4 c7 = vec4(0.899999976, 1.10000002, 0., 0.);
    const vec4 c8 = vec4(-0.5, -0.25, 2., 0.5);

    //Declare registers
    vec4 r0, r1, r2, r3, r4, r5, r6, r7, r8, r9;

    //Code starts here
    vec4 v0 = v_texCoord.xyyy;
    //dcl_2d s0
    r0.x = 1.0 / c0.x;
    r0.y = 1.0 / c0.y;
    r0.xy = (r0 * c1).xy;
    r0.xy = (r0 * v0).xy;
    r0.xy = (r0 * c2).xy;
    r0.zw = fract(r0.xyxy).zw;
    r0.xy = (-r0.zwzw + r0).xy;
    r0.xy = (r0 + c8.wwww).xy;
    r0.x = r0.y * c5.w + r0.x;
    r0.x = r0.x * c6.x;
    r0.x = fract(r0.x);
    r0.xy = (r0.xxxx + c6.yzzw).xy;
    r1.yz = (r0.y >= 0.0 ? c7.xxyw : c7.xyxw).yz;
    r1.x = c6.w;
    r0.xyz = (r0.x >= 0.0 ? r1 : c7.yxxw).xyz;
    r1.xy = (c1 * v0).xy;
    r0.w = r1.y * c8.w + c8.w;
    r0.w = fract(r0.w);
    r0.w = r0.w * c4.x + c4.y;
    r2.y = sin(r0.w);
    r1.zw = (abs(r2).yyyy + c4).zw;
    r1.z = clamp(r1.z, 0.0, 1.0);
    r0.w = r1.w >= 0.0 ? r1.z : c8.w;
    r2 = fract(r1.xyxy);
    r1.xy = (r1 + -r2.zwzw).xy;
    r2 = r2 + c8.xxyy;
    r1.zw = (r1.xyxy + c8.wwww).zw;
    r1.zw = (v0.xyxy * -c1.xyxy + r1).zw;
    r1.w = r1.w + r1.w;
    r1.z = r1.z * c8.w;
    r1.z = -abs(r1).z + c3.x;
    r3.x = max(c3.y, r1.z);
    r4.x = min(r3.x, c3.z);
    r1.zw = (-abs(r1).wwww + c3).zw;
    r1.z = clamp(r1.z, 0.0, 1.0);
    r1.z = r1.w >= 0.0 ? r1.z : c8.w;
    r4.y = r0.w + r1.z;
    r0.w = r0.w * r4.x;
    r1.z = r1.z * r4.x;
    r3.xy = (r4 * c5).xy;
    r1.w = r3.y * r3.x;
    r2.z = cmp(r2, r2.xyxy, c8.yyyy).z;
    r3.xy = max(c8.yyyy, -r2.zwzw).xy;
    r2.xy = (r2 + r3).xy;
    r1.xy = (r2 * c8.zzzz + r1).xy;
    r1.xy = (r1 + c8.wwww).xy;
    r2.x = 1.0 / c1.x;
    r2.y = 1.0 / c1.y;
    r1.xy = (r1 * r2).xy;
    r2 = nnTexture(INPUT_TEXTURE_0, r1.xy);
    r3.x = r0.w * r2.x;
    r3.yz = (r1.xzww * r2).yz;
    FragColor.w = r2.w;
    r0.xyz = (r0 * r3).xyz;
    r1.z = c5.z;
    r0.w = r1.z + -c2.y;
    FragColor.xyz = (r0.w >= 0.0 ? r3 : r0).xyz;
}
#endif
