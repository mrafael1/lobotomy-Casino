# Material study provenance

Used the built-in image generation/editing tool, with
`cabinet_baked.png` from the initial working tree as the sole reference and
`transparent_background: true`. No API or CLI fallback was used.

The unmodified generated study is saved at
`tools/art_sources/machine-material-study.png`. It is not a runtime asset.
The initial reference is archived at
`tools/art_sources/machine-direction-baseline.png`.

`tools/refine_machine_materials.py` samples selected interior planes from the
study into the reference with explicit masks. It writes the 1280×2560 runtime
asset `godot/assets/images/machine_polished/cabinet_material_pass.png` and the
review mask `docs/art-direction/material-transfer-mask.png`. The study's alpha
and geometry are not used; the reference's alpha and unmasked pixels are copied
exactly. Keep these source archives when iterating.

## Exact edit prompt

Edit this existing game cabinet texture as a careful art director's material polish, retaining its EXACT front-facing composition, framing, red silhouette, perspective, every assembly position and dimensions, all holes and recesses. This is a registered Godot 2D game asset, NOT a concept redesign. Output only the same full portrait image, no captions, no comparison. Preserve the black transparent three rectangular reel apertures as transparent. Preserve the background red neon casino architecture and all the CRT glass. Preserve the control shelf well locations and sizes, the three round power socket bores and every mounting screw. Do NOT add controls, lettering, symbols, lights, adornment or objects. Primary edit: change the two pale grey/lilac pitted plates (the three-power-socket rail just below CRT and lower control shelf) to believable warm neutral aged brushed steel: broad quiet satin planes, slim restrained upper-left highlight, dark lower return, localized oxidation only at screw seats and joints. They must be lighter than the red cabinet but not pale concrete. Remove random speckles across their faces. Secondary edit: improve the red enamel cabinet: deeper oxblood front planes, warmer vermilion bevels, narrow localized reflective edge glints; preserve its characteristic red. Remove scattered generic noisy texture and arbitrary long drip streaks from the big lower cabinet front. Replace with very few purposeful chips confined to exposed corners, lower edges and service-panel joints showing dark primer and a tiny metal edge. Keep broad paint planes quiet to read at 400x800 gameplay display. Make the dark backing around the reel windows read as blued steel, shadowed behind the red housing, with soft top shadow and limited edge highlights. Keep inset glass wells dark. Keep all structure, no geometry displacement or new perspective. Style: hand-painted vintage electromechanical casino cabinet with tactile enamel, satin steel and restrained reflected red neon, cohesive and sinister, less detail noise, no photoreal scratch maps or decorative texture. Preserve high resolution.
