# V1 production plan

## Decision and scope

V1 is the selected visual direction, following the user's approval. The finer **640 x 1280 source grid** maps to the existing **160 x 320 safe area** at 0.25 layout units per source pixel. V2 remains an optional comparison reference and is excluded from the implementation path.

Use the healthy ruby-and-gold machine, bright parchment drums, jade power controls and clear account window as the benchmark. Keep the surrounding casino dark and intimate. The multiplier heats the entire cabinet: **x1 ready, x2 hot, x3 maximum output**. Late-run decay is a later polish pass, separate from frenzy heat. Mr. Vey remains outside the machine; its life comes from responsive hardware, lighting, reels and reward choreography.

This document plans presentation production and integration. The existing mockups establish composition and direction; they still need production polish and separation into usable layers. Gameplay rules, economy, scoring, probabilities, saves and deterministic choices remain authoritative in the current game.

## 1. Produce the machine asset package

Work from `tools/house_identity/console.py`, `heat.py` and `pixels.py`; retain the approved compositional masters for comparison. Fix stray pixels, awkward intersections, repeated highlights, cramped labels and implausible material joins at native source size. Use contact wear selectively and preserve quiet surfaces around gameplay information.

Export reproducible runtime assets beneath `godot/assets/art_direction/house_remembers`, with one shared geometry manifest:

- Room/overscan, cabinet shell, transparent reel apertures, drum backing, reel housing and control shelf.
- All existing reel-symbol states, adjacent symbols, heart tiers, Book, targeting/drag/lock states and Tunnel Vision occlusion. Illustrations must register with the same strip geometry.
- Separate ready, selected, pressed, spent and restored control art; two stash slots; augment indicators; all current active-item silhouettes and durations.
- Account glass, numeral surfaces and masks, leaving all values and localized text live. Static mockup numbers never enter production textures.
- Material masks for enamel, metal, glass, reel lips, control surrounds and floor reflection; lamp cores, vent exhaust, sparks and embers as separate effects.

**Exit condition:** an assembled layered preview matches v1 at the same size, with clean apertures and no baked gameplay values. Review x1/x2/x3, a win and rescue at 160 x 320 layout size and on a 390 x 844 display. Exported bounds and hit regions come from shared geometry rather than separately copied coordinates.

## 2. Integrate the live machine as the first complete scene

Keep `godot/autoload/presentation.gd` responsible for the centered safe area and decorative overscan. Re-measure source-pixel constants in `godot/scenes/machine_scene.gd` against v1 and update every dependent aperture, overlay, targeting coordinate and tutorial anchor together. Use nearest-filtered pixel textures and inspect fractional scaling on the actual presentation system.

Reuse the current `MachineView` and existing component owners instead of creating a second controller. First connect the stable shell, reels, account, powers, SPIN, stash, item row and build inspection. Preserve the wealth readout's real payout events, target drain, leading zeros and numeral ghosts. Preserve acquisition order and all current targeting gestures. A transient account reaction can carry the dealer's existing captions without a portrait, keeping their priority and paused hold time.

Then adapt `godot/scenes/machine/machine_heat.gd` to the new material masks and geometry. Read the displayed frenzy tier and pending-loss state. Apply x2 heat across the cabinet and one short x3 entry surge followed by sustained maximum output. Keep real countdown/restoration indicators independent from decorative chase. Rescue suppresses heat/exhaust while controls stay usable; recovery and confirmation follow existing state changes. Respect effects settings and reduced-motion behavior.

Bind reward choreography to the existing resolved outcome and payout sequence. Score travels to Wealth; separate Lucidity feedback stays at the tray. Preserve base payout before COMBO, real restore-lamp sequencing and the existing handoff gates. Local art timing never awards resources, consumes gameplay RNG or selects a result.

**Exit condition:** one polished, playable machine with the full state coverage in [the integration contract](INTEGRATION.md#required-state-coverage-before-a-scene-is-migrated). Explicitly exercise rescue with powers/items, dealer over rescue, Energy Drink compulsion, rewind, Heart, Swap, Cheat, free spins, all five active durations, target payout, 18-spin cap, campaign losses and endings above the HUD. Resolve clipping and input regressions before migrating another scene.

## 3. Bring Pacte, cards and Mr. Vey to production quality

Split the accepted Pacte table into room, felt, furniture, dealer body/face/hands, shoe, decks, cast shadows and foreground layers. Keep live card fronts, names, effects, prices and inspection separate. Refine all 21 distinct card illustrations against the machine's material and pixel standard; retain the authored animated emblems in offers, selection, inspection and Collection.

Adapt `pacte_scene.gd` and `route_build_scene.gd` to the new composition while preserving the current selection/save actions. Verify touch grab offsets, drag bounds, placement, full effect readability, partial-visit resume and mandatory symbol/replacement pickers. Full Pacte remains run-start only; later build visits remain single-deck choices with their current eligibility and prices.

Give Vey a reusable presentation component with independent face, eye and hand timing. Welcome/doubt/pressure/late states derive from existing run progression as specified in the integration contract, with no new saved state or random draw. Professionalism remains recognizable through each state. Integrate him at the table and dealer visits, then route and ending contexts.

**Exit condition:** a complete start-run Pacte-to-machine passage, a later single-deck visit and a tactical dealer interruption all match the accepted art direction, including save/resume at each existing transaction boundary.

## 4. Extend the accepted direction across the active game

Use [the verified scene inventory](SCENES.md) to distinguish active screens, overlays and compatibility entry paths. Migrate in these groups, completing each group's interaction states before proceeding:

| Order | Presentations | Required production focus |
|---|---|---|
| 1 | Route choice, Shop, Bonus, Sacrifice | Two persisted offers, live costs/balances, reroll/refusal, selection feedback, inventory/trade eligibility and result ownership. Audit actual Shop navigation before binding art; preserve existing route IDs and transactions. |
| 2 | Start, Collection, House Records, odds progression, Lab | Start/continue and locked suit selection; stable/secret card catalogue; actual saved statistics; token staging/return/cap; existing wallet upgrades and entry paths. Do not invent a new Lab route. |
| 3 | Tutorial, settings, options, inspection, unlock popup | Real tutorial targets at new coordinates, EN/FR copy, focus/mute/settings behavior, complete effect inspection and persisted unlock queue. |
| 4 | Wealth, Flatline, Game Over and transitions | Real settlement values, existing continuation/banking decisions, loss overlays and foreground priority. Apply Vey's progression consistently. |

Do not build new standalone rooms for unused compatibility scenes. Keep old resume references functional through their existing behavior. Complete motion with existing transition owners: cards settle on felt, route bays reveal under the transition cover, purchases mark the docket, and the Fortune Wheel displays its already-resolved outcome.

**Exit condition:** every active presentation has production layers, live text and values, full interaction states and a verified place in start/resume/run/end flow. No scene is counted complete from a flattened illustration alone.

## 5. Verify the complete presentation and finish polish

Capture a baseline before integration, then run relevant editor import and scene smoke checks for each migration. Compare rules parity before/after and run saved-run resume and tutorial checks before the integrated release. Use the commands and required invariants in [AGENTS.md](../../AGENTS.md#verification) and [the integration contract](INTEGRATION.md#validation-and-acceptance).

Review EN/FR, long card names, 5,000 targets, narrow/tall/wide viewports, mouse, keyboard focus and real phone touch. Check safe-area containment, fractional-scale shimmer, effect settings, texture memory and export-pack inclusion. Validate pixel palette/alpha, deterministic asset rebuild and all animation timings throughout asset production. Visual previews support these checks; they do not substitute for runtime interaction review.

Finish with restrained late-run cabinet decay and dealer/casino progression after the healthy machine and its maximum-output state are convincing. Decay must not reduce control readability or introduce mechanics. Keep each implementation increment reviewable on the existing dedicated branch while its PR remains open; never merge without the owner's consent.

## Current implementation status

The first increment now supplies the [v1 layer package](MACHINE_V1_PACKAGE.md): registered cabinet/hardware/effect layers, shared geometry, individual symbols, control states and current inventory/augment indicators. All 23 reference state assemblies are checked against the original recipes, with runtime samples excluded from exported layers. The next increment is stable live-scene binding in stage 2. Production polish, touch review and complete playable-state acceptance remain open until integration.

## First implementation increment

Begin with **stage 1: the v1 machine layer package and shared geometry**, followed by the stable live cabinet in stage 2. This is the smallest useful increment that makes the chosen direction concrete in-game and exposes compositing/input issues before the rest of the casino depends on it.
