#version 330 core

/*
    CRT Shader by EasyMode
    License: GPL

    This file ported from Libretro's GLSL shader crt-easymode.glslp
    to DOSBox-compatible format by Tyrells, updated for version 0.83
    by Farsil.

    A flat CRT shader ideally for 1080p or higher displays.

    Recommended Settings:

    Video
    - Aspect Ratio:  4:3
    - Integer Scale: Off

    Shader
    - Filter: Nearest
    - Scale:  Don't Care

    Example RGB Mask Parameter Settings:

    Aperture Grille (Default)
    - Dot Width:  1
    - Dot Height: 1
    - Stagger:    0

    Lottes' Shadow Mask
    - Dot Width:  2
    - Dot Height: 1
    - Stagger:    3
*/

/*

#pragma name        Main_Pass1
#pragma output_size Viewport

#pragma linear_filtering off

// Parameter lines go here:
#pragma parameter SHARPNESS_H "Sharpness Horizontal" 0.5 0.0 1.0 0.05
#pragma parameter SHARPNESS_V "Sharpness Vertical" 1.0 0.0 1.0 0.05
#pragma parameter MASK_STRENGTH "Mask Strength" 0.3 0.0 1.0 0.01
#pragma parameter MASK_DOT_WIDTH "Mask Dot Width" 1.0 1.0 100.0 1.0
#pragma parameter MASK_DOT_HEIGHT "Mask Dot Height" 1.0 1.0 100.0 1.0
#pragma parameter MASK_STAGGER "Mask Stagger" 0.0 0.0 100.0 1.0
#pragma parameter MASK_SIZE "Mask Size" 1.0 1.0 100.0 1.0
#pragma parameter SCANLINE_STRENGTH "Scanline Strength" 1.0 0.0 1.0 0.05
#pragma parameter SCANLINE_BEAM_WIDTH_MIN "Scanline Beam Width Min." 1.5 0.5 5.0 0.5
#pragma parameter SCANLINE_BEAM_WIDTH_MAX "Scanline Beam Width Max." 1.5 0.5 5.0 0.5
#pragma parameter SCANLINE_BRIGHT_MIN "Scanline Brightness Min." 0.35 0.0 1.0 0.05
#pragma parameter SCANLINE_BRIGHT_MAX "Scanline Brightness Max." 0.65 0.0 1.0 0.05
#pragma parameter SCANLINE_CUTOFF "Scanline Cutoff" 400.0 1.0 1000.0 1.0
#pragma parameter GAMMA_INPUT "Gamma Input" 2.0 0.1 5.0 0.1
#pragma parameter GAMMA_OUTPUT "Gamma Output" 1.8 0.1 5.0 0.1
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.0 0.01
#pragma parameter DILATION "Dilation" 1.0 0.0 1.0 1.0

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

uniform float SHARPNESS_H;
uniform float SHARPNESS_V;
uniform float MASK_STRENGTH;
uniform float MASK_DOT_WIDTH;
uniform float MASK_DOT_HEIGHT;
uniform float MASK_STAGGER;
uniform float MASK_SIZE;
uniform float SCANLINE_STRENGTH;
uniform float SCANLINE_BEAM_WIDTH_MIN;
uniform float SCANLINE_BEAM_WIDTH_MAX;
uniform float SCANLINE_BRIGHT_MIN;
uniform float SCANLINE_BRIGHT_MAX;
uniform float SCANLINE_CUTOFF;
uniform float GAMMA_INPUT;
uniform float GAMMA_OUTPUT;
uniform float BRIGHT_BOOST;
uniform float DILATION;

#define FIX(c) max(abs(c), 1e-5)
#define PI 3.141592653589

#define TEX2D(c) dilate(texture(INPUT_TEXTURE_0, c))

// Set to 0 to use linear filter and gain speed
#define ENABLE_LANCZOS 1

vec4 dilate(vec4 col)
{
    vec4 x = mix(vec4(1.0), col, DILATION);

    return col * x;
}

float curve_distance(float x, float sharp)
{

/*
    apply half-circle s-curve to distance for sharper (more pixelated) interpolation
    single line formula for Graph Toy:
    0.5 - sqrt(0.25 - (x - step(0.5, x)) * (x - step(0.5, x))) * sign(0.5 - x)
*/

    float x_step = step(0.5, x);
    float curve = 0.5 - sqrt(0.25 - (x - x_step) * (x - x_step)) * sign(0.5 - x);

    return mix(x, curve, sharp);
}

mat4 get_color_matrix(vec2 co, vec2 dx)
{
    return mat4(TEX2D(co - dx), TEX2D(co), TEX2D(co + dx), TEX2D(co + 2.0 * dx));
}

vec3 filter_lanczos(vec4 coeffs, mat4 color_matrix)
{
    vec4 col        = color_matrix * coeffs;
    vec4 sample_min = min(color_matrix[1], color_matrix[2]);
    vec4 sample_max = max(color_matrix[1], color_matrix[2]);

    col = clamp(col, sample_min, sample_max);

    return col.rgb;
}

void main()
{
    vec2 dx     = vec2(1.0 / INPUT_SIZE_0.x, 0.0);
    vec2 dy     = vec2(0.0, 1.0 / INPUT_SIZE_0.y);
    vec2 pix_co = v_texCoord * INPUT_SIZE_0 - vec2(0.5, 0.5);
    vec2 tex_co = (floor(pix_co) + vec2(0.5, 0.5)) / INPUT_SIZE_0;
    vec2 dist   = fract(pix_co);
    float curve_x;
    vec3 col, col2;

#if ENABLE_LANCZOS
    curve_x = curve_distance(dist.x, SHARPNESS_H * SHARPNESS_H);

    vec4 coeffs = PI * vec4(1.0 + curve_x, curve_x, 1.0 - curve_x, 2.0 - curve_x);

    coeffs = FIX(coeffs);
    coeffs = 2.0 * sin(coeffs) * sin(coeffs * 0.5) / (coeffs * coeffs);
    coeffs /= dot(coeffs, vec4(1.0));

    col  = filter_lanczos(coeffs, get_color_matrix(tex_co, dx));
    col2 = filter_lanczos(coeffs, get_color_matrix(tex_co + dy, dx));
#else
    curve_x = curve_distance(dist.x, SHARPNESS_H);

    col  = mix(TEX2D(tex_co).rgb,      TEX2D(tex_co + dx).rgb,      curve_x);
    col2 = mix(TEX2D(tex_co + dy).rgb, TEX2D(tex_co + dx + dy).rgb, curve_x);
#endif

    col = mix(col, col2, curve_distance(dist.y, SHARPNESS_V));
    col = pow(col, vec3(GAMMA_INPUT / (DILATION + 1.0)));

    float luma        = dot(vec3(0.2126, 0.7152, 0.0722), col);
    float bright      = (max(col.r, max(col.g, col.b)) + luma) * 0.5;
    float scan_bright = clamp(bright, SCANLINE_BRIGHT_MIN, SCANLINE_BRIGHT_MAX);
    float scan_beam   = clamp(bright * SCANLINE_BEAM_WIDTH_MAX, SCANLINE_BEAM_WIDTH_MIN, SCANLINE_BEAM_WIDTH_MAX);
    float scan_weight = 1.0 - pow(cos(v_texCoord.y * 2.0 * PI * INPUT_SIZE_0.y) * 0.5 + 0.5, scan_beam) * SCANLINE_STRENGTH;

    float mask   = 1.0 - MASK_STRENGTH;
    vec2 mod_fac = floor(v_texCoord * OUTPUT_SIZE / vec2(MASK_SIZE, MASK_DOT_HEIGHT * MASK_SIZE));
    int dot_no   = int(mod((mod_fac.x + mod(mod_fac.y, 2.0) * MASK_STAGGER) / MASK_DOT_WIDTH, 3.0));
    vec3 mask_weight;

    if      (dot_no == 0) mask_weight = vec3(1.0,  mask, mask);
    else if (dot_no == 1) mask_weight = vec3(mask, 1.0,  mask);
    else                  mask_weight = vec3(mask, mask, 1.0);

    if (INPUT_SIZE_0.y >= SCANLINE_CUTOFF)
        scan_weight = 1.0;

    col2 = col.rgb;
    col *= vec3(scan_weight);
    col  = mix(col, col2, scan_bright);
    col *= mask_weight;
    col  = pow(col, vec3(1.0 / GAMMA_OUTPUT));

    FragColor = vec4(col * BRIGHT_BOOST, 1.0);
}

#endif
