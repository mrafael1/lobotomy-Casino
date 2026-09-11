# Painted route-choice scene

`choice_scene_painted.png` is a full-resolution composed art master generated with the built-in
image-generation tool. It follows the painted Pacte dealer, red enamel, dark
green surfaces, brass and restrained casino lighting.

The 160x320 `choice_scene_native.png` derivative is now the active base layer in
`dealer_choice_scene.gd`. It supplies the lobby, doors and dealer as a single
crisp nearest sampled composition. Runtime route emblems and short names sit in
the doors' painted inset and name plaques; the legacy full-card door sheet is
kept hidden as a state carrier for compatibility. Reroll price, confirmation and
navigation controls remain live nodes above it, preserving input and animation
without covering the hardware. The high-resolution file is retained as the
editable source master; the native derivative is the exported runtime asset.

## Generation prompt

Create one finished portrait 1:2 painted pixel-art scene master for Lobotomy Casino's between-machine CHOICE scene, designed for a 160x320 virtual canvas and rendered at high resolution. Reference 1 is the approved Pacte style and dealer identity: crisp controlled pixel clusters, cadaver-green skeletal gentleman, slick dark hair, hollow eyes, knowing grin, black suit, ivory shirt and burgundy bow tie, worn crimson enamel, dark felt, warm tarnished brass, black-green shadows, restrained cyan/red neon. Reference 2 is ONLY the old scene's composition guide. Preserve that arrangement: exactly TWO large equal closed route doors in the upper half, left native rectangle roughly (10,42,64,105), right (86,42,64,105), separated by a narrow central pillar. Reimagine them as heavy dark-green casino doors in deep worn-red frames with brass hinges and small brass handles, each with an EMPTY dark inset rectangular plaque for a runtime route emblem and an EMPTY narrow ivory/brass plaque below for runtime route name. NO written labels or baked-in route icons. The two doors are the primary readable shapes, symmetric and completely unobstructed. A dim red ceiling strip above, narrow cyan accents, dark casino lobby walls. In lower foreground, the SAME dealer from reference 1 stands centered BEHIND a worn red and brass concierge counter: head near native (80,183), shoulders near y207, bony hands resting on the counter at y239. Do not place dealer over either door. Leave quiet dark room around him for dialogue at right around (104,174,40,25) and a reroll control at left around (6,176,38,40), but do not draw controls or speech bubbles. Counter front occupies y247-304 with handsome dark wood inset panels and red enamel/brass edges, subtle use marks, no busy ornaments. Bottom strip y304-320 remains dark and quiet for runtime CONTINUE action. Single cohesive physical scene, not a UI mockup, no cards, no slot machine centerpiece, no numbers, no text, no watermarks, no annotations. Match the pixel-art craftsmanship and lighting of reference 1 exactly. Clean integrated corners and generous gameplay space.
