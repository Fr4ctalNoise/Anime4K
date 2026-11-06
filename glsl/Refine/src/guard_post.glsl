
//!DESC Anime4K-Refine-Guard-Gradient
//!HOOK MAIN
//!BIND GUARD_ORIG
//!SAVE GUARD_GRAD
//!WIDTH GUARD_ORIG.w
//!HEIGHT GUARD_ORIG.h
//!COMPONENTS 4
//!WHEN guard_strength 0 >
float luma(vec2 off) {
    return dot(GUARD_ORIG_texOff(off).rgb, vec3(0.2126, 0.7152, 0.0722));
}
vec4 hook() {
    float tl = luma(vec2(-1, -1)), t = luma(vec2(0, -1)), tr = luma(vec2(1, -1));
    float l  = luma(vec2(-1,  0)),                         r  = luma(vec2(1,  0));
    float bl = luma(vec2(-1,  1)), b = luma(vec2(0,  1)), br = luma(vec2(1,  1));
    // Sobel, scaled so a step of height h gives a response of about h
    float gx = ((tr + 2.0 * r + br) - (tl + 2.0 * l + bl)) / 4.0;
    float gy = ((bl + 2.0 * b + br) - (tl + 2.0 * t + tr)) / 4.0;
    return vec4(gx, gy, length(vec2(gx, gy)), 0.0);
}

//!DESC Anime4K-Refine-Guard-Mask
//!HOOK MAIN
//!BIND GUARD_GRAD
//!SAVE GUARD_MASK
//!WIDTH GUARD_GRAD.w
//!HEIGHT GUARD_GRAD.h
//!COMPONENTS 4
//!WHEN guard_strength 0 >
vec4 hook() {
    // RMS gradient over a 5x5 Gaussian window, plus the strongest edge nearby
    float energy = 0.0, wsum = 0.0, gmax = 0.0;
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            vec3 g = GUARD_GRAD_texOff(vec2(x, y)).xyz;
            float w = exp(-float(x * x + y * y) / 4.0);
            energy += w * dot(g.xy, g.xy);
            wsum += w;
            gmax = max(gmax, g.z);
        }
    }
    float contrast = sqrt(energy / wsum);

    // Anything with detail is texture (stone, cracks, brushwork), unless a bold
    // edge such as a character outline is nearby, which stays Anime4K.
    float busy = smoothstep(texture_threshold, texture_threshold * 3.0, contrast);
    float line = smoothstep(line_threshold * 0.75, line_threshold, gmax);
    return vec4(busy * (1.0 - line), line, 0.0, 0.0);
}

//!DESC Anime4K-Refine-Guard-Mask-Blur
//!HOOK MAIN
//!BIND GUARD_MASK
//!SAVE GUARD_MASK_SMOOTH
//!WIDTH GUARD_MASK.w
//!HEIGHT GUARD_MASK.h
//!COMPONENTS 4
//!WHEN guard_strength 0 >
vec4 hook() {
    // 5x5 Gaussian so textured regions are covered evenly and transitions are soft
    vec2 m = vec2(0.0);
    float wsum = 0.0;
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            float w = exp(-float(x * x + y * y) / 4.0);
            m += w * GUARD_MASK_texOff(vec2(x, y)).xy;
            wsum += w;
        }
    }
    return vec4(m / wsum, 0.0, 0.0);
}

//!DESC Anime4K-Refine-Guard-Apply
//!HOOK MAIN
//!BIND HOOKED
//!BIND GUARD_ORIG
//!BIND GUARD_MASK_SMOOTH
//!WHEN guard_strength 0 >
#define PI 3.14159265359
float lanczos3(float x) {
    x = abs(x);
    if (x < 1e-5) return 1.0;
    if (x >= 3.0) return 0.0;
    return 3.0 * sin(PI * x) * sin(PI * x / 3.0) / (PI * PI * x * x);
}
vec4 hook() {
    // Original frame scaled to the output size with Lanczos3 plus anti-ringing,
    // close to what mpv shows with no shaders
    vec2 p = HOOKED_pos * GUARD_ORIG_size - 0.5;
    vec2 f = fract(p);
    vec2 base = (floor(p) + 0.5) * GUARD_ORIG_pt;
    vec4 sum = vec4(0.0), lo = vec4(1e9), hi = vec4(-1e9);
    float wsum = 0.0;
    for (int j = -2; j <= 3; j++) {
        float wy = lanczos3(float(j) - f.y);
        for (int i = -2; i <= 3; i++) {
            vec4 c = GUARD_ORIG_tex(base + vec2(i, j) * GUARD_ORIG_pt);
            float w = lanczos3(float(i) - f.x) * wy;
            sum += w * c;
            wsum += w;
            if (i >= 0 && i <= 1 && j >= 0 && j <= 1) { lo = min(lo, c); hi = max(hi, c); }
        }
    }
    vec4 orig = sum / wsum;
    orig = mix(orig, clamp(orig, lo, hi), 0.6);

    vec2 mask = GUARD_MASK_SMOOTH_tex(HOOKED_pos).xy;
    vec4 anime4k = HOOKED_tex(HOOKED_pos);
    vec4 result = mix(anime4k, orig, guard_strength * mask.x);

    if (guard_debug == 1) {
        float y = dot(result.rgb, vec3(0.2126, 0.7152, 0.0722)) * 0.5;
        result.rgb = vec3(y) + vec3(0.6 * mask.x, 0.5 * mask.y, 0.0);
    }
    return result;
}
