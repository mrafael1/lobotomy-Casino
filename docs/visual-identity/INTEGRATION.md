# Phase-two presentation integration contract

Phase one changes **no gameplay or presentation bindings**. New art is a reviewable proposal alongside the current game. The existing user work in rules/controllers/art generators is preserved. Do not infer that the flattened mockups are ready to replace live cabinet textures.

## Layer architecture

Use the current `Presentation` safe origin and `SceneNav` transition cover. New art lives under `res://assets/art_direction/house_remembers`. Source scene dimensions are 320×640, mapped at **0.5** layout units per pixel. Keep the old manifest active until each migrated scene is visually and functionally verified. The new generator writes only its own asset subtree.

For each migrated scene export separate room, furnishing, interactive object, cast shadow, local light, character, and foreground layers from the same source recipes. Flattened scene PNGs are compositional masters, not opaque overlays to put above controls. Masks must be generated from actual shapes, not guessed old coordinates.

Suggested ownership:

```text
Presentation (existing safe-area / overscan)
  Scene art root (source-to-layout transform only)
    Room / casino floor
    Furniture / cabinet shell
    Independent reel strip / character parts / card illustrations
    Local material lights
  Live controls and localized labels (layout units)
  Existing callout / rescue / dealer / ending stack
  Options / unlock / existing transition owner
```

All decorative layers ignore input. Buttons own complete logical hit areas, including transparent art margins. Keyboard/controller activation, focus indicators and mobile coordinates must work through the same action as pointer release. Drag shadows and touch grab offsets use safe-area-local coordinates; a point grabbed on a card stays under the finger.

## Proposed geometry: re-measure before changing the machine

The proposal's source measurements are deliberately different from the current cabinet. Authoritative current constants in `machine_scene.gd` must be updated together, after splitting the new cabinet. Do not swap a texture against old apertures.

| Element | Source pixels (x, y, w, h) | Layout units |
|---|---|---|
| Account content | 48, 155, 146, 97 | 24, 77.5, 73, 48.5 |
| Dealer glass | 212, 155, 55, 76 | 106, 77.5, 27.5, 38 |
| Reel 1 content | 53, 317, 59, 88 | 26.5, 158.5, 29.5, 44 |
| Reel 2 content | 129, 317, 59, 88 | 64.5, 158.5, 29.5, 44 |
| Reel 3 content | 205, 317, 59, 88 | 102.5, 158.5, 29.5, 44 |
| First power touch | 53, 425, 50, 52 | 26.5, 212.5, 25, 26 |
| Second power touch | 134, 425, 50, 52 | 67, 212.5, 25, 26 |
| Third power touch | 215, 425, 50, 52 | 107.5, 212.5, 25, 26 |
| SPIN touch | 96, 494, 99, 51 | 48, 247, 49.5, 25.5 |
| Spin count field | 39, 502, 43, 30 | 19.5, 251, 21.5, 15 |
| Stash 1 touch | 202, 493, 43, 52 | 101, 246.5, 21.5, 26 |
| Stash 2 touch | 245, 493, 43, 52 | 122.5, 246.5, 21.5, 26 |
| Pacte offer 1 | 24, 365, 78, 122 | 12, 182.5, 39, 61 |
| Pacte offer 2 | 121, 365, 78, 122 | 60.5, 182.5, 39, 61 |
| Pacte offer 3 | 218, 365, 78, 122 | 109, 182.5, 39, 61 |

Five item durations occupy their own 16-source-pixel badge row, with individually drawn cigarette, potion, drink can, serum ampoule and cocktail silhouettes, two-scale digits and separate helpful/costly colours. Extend that silhouette family to the remaining items and bind each actual effect phase. The first three power sockets preserve acquisition order; preserve the current behaviour for any additional owned powers. The lower paper tabs remain inspectable augment indicators.

## Presentation progression, with no new save fields

Derive Mr. Vey's state from the **existing saved `wealthTargetIndex`**, clamped against the current target ladder. Proposed thresholds: indices 0–1 Welcome, 2–3 Doubt, 4–5 Pressure, 6+ Late. Restoring an existing save computes the same state immediately. Changing or continuing a run must use that run's index; do not use wall time, lifetime wallet or a fresh random draw. If the final Wealth continuation reuses an index, retain its late presentation by reading the existing Wealth/continuation state rather than writing an art flag.

Run progression and frenzy heat are independent: Vey's accumulated unease follows the index, cabinet heat still follows the **displayed existing x1/x2/x3 tier and pending-loss state**. The paired early/advanced machine illustrations deliberately combine two example conditions; they must not imply that late-run machines are forced to x3.

Blink, breathing, gaze and card handling use local presentation timing. They never consume `LobRNG` or alter offers/results. Resuming a scene may restart an idle blink; it may not restart a saved transaction. Caption hold/fade pauses while covered by a callout, preserving the current response behaviour.

## Required state coverage before a scene is migrated

- Machine: normal spin; free bank/protected spin banner; payout before Combo bonus; right-aligned target drain; insufficient spins and full 18 cap; spent/selected/ready powers; restored power lamps; all five active durations and their phases; item popup; two filled/empty stash slots; warning rescue and confirmation; compulsory/rewind/dealer sequencing; Tunnel shutter and Book attachment; Joker assists; campaign neuron death; all endings above the HUD.
- Pacte/build: both decks, partial saved visit, card hold/drag/drop/return, selected illustration, required Reward symbol picker, power replacement picker, locked/unlocked pool eligibility, tier and price, post-loss free pool, diamond constraint. Full Pacte remains run-start only.
- Routes/shop/dealer: exactly two persisted route IDs; five possible route types; 5/10/15… reroll; unaffordable/selected/commit states; free refusal; live run versus wallet currency; taken versus used items; expanded dealer offers; campaign chip ownership; each shop item's existing price/markup/stock; queued feedback; resume while each overlay owns input.
- Meta: stable Collection slots and locked secrecy; full localized names/effects in inspection; unlock queue persistence/acknowledgement; odds staging/token return/level cap; existing Lab tiers and wallet costs; statistics; replayable tutorial restrictions; language row; settings mute/focus; start versus saved-run suit lock; ending choice before banking.

The mockup sample text and prices are illustrative typesetting. Production effects, probabilities, prices, unlocks and collection secrecy still come from current authoritative data/controllers. In particular, current comments/descriptions contain historical differences from AGENTS.md. Do not edit gameplay to make it match an illustration.

## Motion specifications

| Motion | Intended timing / construction | Integration gate |
|---|---|---|
| Vey gaze / blink | 1000ms neutral, 140ms gaze shift, 650ms hold, 70+70ms lids, 1300ms return. Six authored frames; card slips six source pixels as a secondary action. | Independent presentation clock, no input locks. |
| Dealer progression | Four state frames, identity retained; GIF is a comparison study, not an in-game cyclic transformation. | Snap state on resume; short local reveal only at an existing safe transition. |
| Pattern Recognition | Five authored registration frames, 210ms each. | Preserve five-frame animation on live cards, inspection and collection where currently animated. |
| Is It Cheating | 1000/120/520/120ms false-face slide. | Preserve animated emblem; same card/effect ID. |
| Machine state study | Early, advanced, rescue keyframes at 2000/2000/1600ms. | State reference only; never cycle gameplay warnings because a GIF loops. |
| Deal and settle | Proposed: 180ms glide from shoe, 90ms contact, 350ms stillness; shadow tightens on contact. | Existing selection/phase handoff owns completion. No new drag restriction. |
| Reel/coin/target | Existing timing retained initially; restyle mechanical clacks and phosphor ghosts to new surfaces. | Animation may defer the next permitted sequence exactly as current controller does; cannot award results. |

The first five are delivered as fixed-palette GIFs plus atlases and manifest durations. Deal/settle is an animation direction for phase two, not a delivered prototype. Reduced-motion review switches to static frames; runtime must respect the existing effect preferences.

## Validation and acceptance

Phase one: inspect masters, card sheet, dealer close-up, native layout reductions and 390×844 phone study; validate palette, binary alpha, exact card coverage, atlas dimensions, frame durations, relative gallery resources and deterministic rebuild. Current phase-one validation is recorded in `validation.json`. There are no phase-one edits to existing rules/controllers and no claim that the concept is a running game skin.

Phase two: run editor import, `run_parity_headless.gd`, scene smoke, saved-run resume and tutorial checks. Compare parity outputs before/after. Exercise EN/FR with 5,000 targets, five active items and long card names on multiple viewport shapes. Test fractional scaling for shimmer, real phone touch targets, keyboard focus and safe-area overscan. Check texture memory and export-pack resources. Do not declare a scene integrated until the new art layers, aperture masks, live values and all required state variants pass together.
