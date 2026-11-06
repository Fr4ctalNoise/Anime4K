# Anime4K Detail Guard

Anime4K draws line art very cleanly, but on some shows it also smooths texture that should stay. Grainy stone turns into soft, smeared patches, cracks become neat inked grooves, and backgrounds end up looking like watercolor. Both Restore and Upscale contribute; on real 1080p sources, Upscale does most of the smoothing.

The Detail Guard wraps the whole Mode A chain (Restore + Upscale). At the output size it picks, per pixel:

| Area | Result |
|---|---|
| Bold line art (character outlines) | Anime4K |
| Flat fills (skin, clothing) | Anime4K |
| Anything with detail (stone, cracks, mortar, brushwork) | The original frame, sharply scaled (Lanczos3 + anti-ringing), close to mpv with no shaders |

## Files

`glsl/Refine/Anime4K_ModeA_<S|M|L|VL|UL>_Guarded.glsl` replace the matching `Restore_CNN_<V>` + `Upscale_CNN_x2_<V>` pair. Each one is both Anime4K shaders, unchanged, with the guard wrapped around them.

They are generated, so don't edit them by hand. Edit `glsl/Refine/src/guard_pre.glsl` / `guard_post.glsl` and rerun:

```
python glsl/Refine/make_guarded.py
```

(Why generated? With `vo=gpu-next`, a texture saved in one shader file can't be read by another, so the guard can't sit in separate before/after files. The generator also prefixes Upscale's internal texture names so they don't collide with Restore's.)

## Install (mpv, vo=gpu-next)

1. Copy the `_Guarded.glsl` file into your mpv `shaders` folder.
2. Replace the Restore + first Upscale pair in your chain with it, e.g. Mode A (HQ):

```
glsl-shaders="~~/shaders/Anime4K_Clamp_Highlights.glsl"
glsl-shaders-append="~~/shaders/Anime4K_ModeA_UL_Guarded.glsl"
glsl-shaders-append="~~/shaders/Anime4K_AutoDownscalePre_x2.glsl"
glsl-shaders-append="~~/shaders/Anime4K_AutoDownscalePre_x4.glsl"
glsl-shaders-append="~~/shaders/Anime4K_Upscale_CNN_x2_UL.glsl"
```

3. Optional `input.conf` hotkeys:

```
CTRL+7 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_ModeA_UL_Guarded.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_UL.glsl"; show-text "Anime4K: Mode A (HQ) + Detail Guard"
CTRL+8 cycle-values glsl-shader-opts "guard_strength=0" "guard_strength=1"; show-text "Detail Guard: ${glsl-shader-opts}"
CTRL+9 cycle-values glsl-shader-opts "guard_debug=1" "guard_debug=0"; show-text "Detail Guard: ${glsl-shader-opts}"
```

- `CTRL+8` toggles the guard off and on for a quick A/B on the same frame.
- `CTRL+9` toggles the debug heatmap, which shows what the guard is doing.

## Tuning (`glsl-shader-opts`)

| Option | Default | Meaning |
|---|---|---|
| `guard_strength` | `1.0` | `0` = stock Anime4K (pixel-identical, guard passes skipped). `0.5` = halfway between Anime4K and the original in textured areas. |
| `texture_threshold` | `0.005` | How faint a texture still counts as texture. Lower = keep more original texture; higher = let Anime4K handle more. |
| `line_threshold` | `0.3` | Edge strength that counts as line art. Lower = more edges (e.g. cracks, background detail) get Anime4K's inked look. |
| `guard_debug` | `0` | `1` = heatmap. Red = original texture; green = Anime4K line art; grey = flat, Anime4K. |

Example: `glsl-shader-opts=guard_strength=0.8,line_threshold=0.25`

Cost: four light passes at source resolution plus one blend pass at output resolution. Measured on a UL chain, about 7% of the chain's GPU time.

Known trade-offs: in textured areas, Restore's cleanup of compression artifacts is lost too, so blocking in dark scenes can show through. The Lanczos3 fallback is close to, but not identical to, mpv's own `ewa_lanczossharp`.
