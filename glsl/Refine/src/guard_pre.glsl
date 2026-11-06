//!PARAM guard_strength
//!DESC How strongly textured areas keep their original look (0 = stock Anime4K)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
1.0

//!PARAM texture_threshold
//!DESC Local contrast at which an area starts counting as texture (lower = protect more)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 0.2
0.005

//!PARAM line_threshold
//!DESC Edge strength treated as line art, which keeps Anime4K (higher = only the boldest outlines)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.3

//!PARAM guard_debug
//!DESC 1 = heatmap: red = original texture kept, green = Anime4K line art
//!TYPE int
//!MINIMUM 0
//!MAXIMUM 1
0

//!DESC Anime4K-Refine-Guard-Save
//!HOOK MAIN
//!BIND HOOKED
//!SAVE GUARD_ORIG
//!COMPONENTS 4
//!WHEN guard_strength 0 >
vec4 hook() {
    return HOOKED_tex(HOOKED_pos);
}

