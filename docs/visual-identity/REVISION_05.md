# Machine alternative v2 — clustered pixels

V2 is an additional treatment of the healthy machine. V1 and all accepted casino scenes remain available. Compare them at equal display size in [the review](review.html#machine-v2) or the [comparison board](../../godot/assets/art_direction/house_remembers/machine_v2/comparison.png).

The complete v2 cabinet is constructed directly at **320 × 640 source pixels**, two source pixels per layout unit. Its larger curves use deliberate two-pixel coordinate steps; small lamps, typography and engraving use the same native grid at one-pixel precision. The eye symbol has its own explicit lid runs, iris clusters and highlights. These are integer drawing recipes, with no antialiasing, painted input or pixelation filter. Display enlargements use nearest-neighbour sampling. The 160 × 320 images are review reductions only.

Ruby enamel, gold, luminous parchment reels, jade powers and the primary red SPIN control carry forward. The same cabinet progresses through x1 ready, x2 hot and x3 maximum output. Exhaust, sparks and lamp choreography have five additional reproducible animation atlases: three tier loops, the output ladder and the small-win sequence. A rescue study keeps controls visible while output is suppressed.

Assets live in `godot/assets/art_direction/house_remembers/machine_v2`; atlases and GIFs use the `animation/v2_` prefix. Source construction is in `tools/house_identity/console_v2.py`, sharing the cabinet's geometry through an explicit canvas factory. The original default renderer is unchanged. The manifest records v2 separately, preserving the original scenes' source-size contract.

Review includes equal-size v1/v2 comparison, x1/x2/x3 board, reel close-ups, actual-layout reductions and a 390 × 844 phone study. Art checks enforce fixed palette, binary alpha, image reproducibility, frame timing and stable controls, numbers and reels during each tier loop. This is phase-one artwork; no live bindings or mechanics change. Integrating v2 later requires source-coordinate measurements at its own density and a nearest-filtered art layer. Do not double-apply the existing runtime heat treatment.
