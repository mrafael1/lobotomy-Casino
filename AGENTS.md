# lobotomy-Casino - Codex Guidelines

You are an expert game developer specializing in Godot Engine 4.x and GDScript 2.0.
Write clean, performant, modern Godot 4 code.

## Branching Workflow

Always create a dedicated branch before making changes. Never push directly to `main`
or the current session's base branch.

### Branch Naming

- Bug fixes: `Codex/fix-<short-description>`
- New features: `Codex/feat-<short-description>`
- Tweaks / balance / polish: `Codex/tweak-<short-description>`

### Rules

1. Create the branch at the start of the task. If the task grows, keep adding commits
   to the same branch.
2. Related fixes and tweaks can be batched onto one branch when they address the same
   area.
3. Push the branch and open a PR for review; do not merge to `main`.
4. Start a new branch only once the previous one is merged or explicitly abandoned.

## GitHub Workflow

- Never merge any branch locally or remotely without explicit consent from the owner.
- Never use `git merge` locally to absorb another branch; all merges go through a PR.
- If a branch's changes are already present in another branch due to a local merge,
  flag it clearly instead of silently proceeding.

## Godot Project

- The Godot project lives in `godot/`.
- The game uses a 160x320 virtual canvas.
- Runtime art, fonts, and sounds live under `godot/assets`.
- Exported builds must not depend on root-level assets outside `godot/`.
- Machine geometry constants in `godot/scenes/machine_scene.gd` are measured in
  source pixels. Re-measure them when replacing machine art.

## Game Overview

Lobotomy Casino is a single-player roguelite slot machine with a neon body-horror
presentation on a 160x320 pixel canvas: the player gambles pieces of their own
mind against a machine that fights back.

Resources and currencies:

- **Campaign neurons (lives)** — a campaign grants 10; each run attempt spends
  one. Exhausting them ends the campaign fatally (Game Over).
- **Run spins** — the serialized run field is still `neurons` for save/parity
  compatibility, but the machine presents it as spins. A fresh run starts with 20;
  each spin spends 1 run spin unless protected. Restores cap at 35 (105 after a Wealth
  continuation). The machine prints the current remaining-spin number under the
  neuron tube; it updates whenever spins are gained, spent, or protected and
  keeps counting past the tube art's 17-notch cap.
- **Score** — the run's win total. Reaching **2,000 score** triggers the Wealth
  ending; that is the objective of every run. The machine's four-reel wealth odometer
  advances directly with score payouts when their score pop appears; it does not collect
  the separate Lucidity coins from the cash tray. Changed digits roll and carry like
  physical number drums. Its white cases sit behind the rolling digits and the
  authored Wealth bar frame sits above them. The white box below the odometer shows
  the run's Wealth objective as a single "TARGET: 2000" line.
- **Run Lucidity (coins)** — earned alongside score during the run. Every 50 coins
  restores one random spent power; coins also pay for mid-run dealer offer
  rerolls. On a non-Wealth ending, 10% is kept (20% with Smart Save, halved by the
  spade modifier) and banked into the wallet.
- **Wallet Lucidity (credits)** — the persistent meta currency. Buys Lab upgrades
  and persistent progression between runs.

## Typical Run

1. On the start menu, optionally choose an unlocked **Augmented Run** modifier.
   This is a pre-launch choice only: it locks when the run starts and cannot be
   selected or changed while a run is active, including when continuing a saved
   run (the selector shows the active run's suit, arrows disabled).
2. Reserve the campaign neuron and enter **Pacte**. Reveal three augment cards
   and three power cards, then select and place one of each. Pacte selections are
   saved mid-visit; the initial completion enters the machine directly.
3. Enter the machine with the base spins, Reroll hero power, and the selected
   Pacte power. The run begins with no pre-run consumables.
4. Spin for pairs, triples, and jackpots. Paying wins step the automatic frenzy
   gauge x1 → x2 → x3; a miss at x2/x3 opens a rescuable diminished (combo-loss)
   state instead of dropping instantly.
5. Use powers and consumables to manipulate revealed reels, protect resources, or
   alter future spins.
6. When spins cross from above 5 to 5 or fewer, finish the current result and
   resolve any loss warning, then open the one-time threshold Pacte visit. Its
   second augment and power append to the first selection and completion opens
   the dealer scene.
7. Handle automatic dealer interruptions: his 12-step countdown advances by 3/2/1
   for x1/x2/x3 each spin, so lower gauges pull him in faster.
8. End the run: reach Wealth, flatline and keep part of the run's Lucidity, or
   exhaust the campaign into Game Over.
9. Between runs, spend odds-phase tokens and wallet credits on permanent
   progression, then start the next attempt.

## Game Reference

### Reels and scoring

- Visible symbol cycle: brain, eye, pill, syringe, vial, flatline (book sits
  outside the strip and only appears with the Learning upgrade).
- Scoring hierarchy: **jackpot** (brain triple, 200 + 1 free spin) > **triples**
  (eye 50, pill 35, syringe 25, vial/book 15) > **pairs** (brain 20, eye 10,
  pill 7, syringe 5, vial 3, book 5). Flatline pairs/triples pay 0.
- A 3-flatline reveal is a "strike": it charges the next winning pair/triple to
  score double, and stacked strikes can kill the run outright.
- A pair or triple win also flashes its authored PAIR/TRIPLE TV callout, beeping
  (alpha pulse) four times after the win is identified, with a teal "+ score"
  payout line beneath the word showing what that win paid. While a transient TV
  callout is visible, it temporarily hides the FREE SPIN banner and dealer
  countdown information so the pop remains readable; those indicators return
  when the callout ends.
- Scores multiply by the frenzy gauge and Lab lucidity multipliers. Exact tables
  and edge cases live in `godot/rules/` and the parity vectors — this file only
  summarizes intent.

### Powers

- **Reroll** (always owned) — rerolls one revealed reel.
- **Shift** — steps one revealed reel along the symbol cycle.
- **Lock** — locks a reel through upcoming spins.
- **Rewind** — restores the immediately previous spin's reels, neuron/free-spin,
  dealer, and combo state while preserving earned score/Lucidity and recovering
  a deterministic 1–3 spent power chips. It is unavailable without spin history
  or while another sequence is active.
- **Heart** — replaces one, two, or three revealed symbols with hearts for
  +1/+2/+3 run spins, never awards bonus score, and arms one free follow-up
  spin that the player must start with the lever.
- **Cheat** — rubble-flashes the revealed symbols, then replaces one selected
  reel with a symbol chosen from the existing symbol chooser.
- **Move** — rubble-flashes the revealed symbols, then moves a selected symbol to
  any other reel, including an adjacent reel, before rescoring.
- Selecting a power for targeting flashes its authored TV callout (with text
  fallbacks for the four new powers) with
  a short beeping pulse; the callout stays up while targeting is armed and hides
  when the target is picked or the selection is cancelled.
- Using a power spends it; the power gauge restores one random spent power per 50
  run-Lucidity coins. Score payouts—including Cocktail rarity points—also advance the
  wealth-linked 10-point bank. Each 10-point gauge step launches the four-frame `power
  coin animation` from the wealth odometer, then sends the real power coin to the power
  bar. The diamond modifier caps power use at two per spin.

### Consumables and run items

- Run consumables held during the run: Tobacco, Serum, White Powder, Potion, Tea;
  the initial Pacte handoff starts with no consumables and the stash limit is 2.
- Dealer-only run items (offered mid-run): Energy Drink,
  Cocktail, Water, Red Pill.
- Water grants +40 run Lucidity AND +40 score: drinking it rolls the wealth
  odometer up immediately and its points feed the power gauge like any score.
- Several items and Lab upgrades are tagged "corrupt"; corruption use is tracked
  campaign-wide (`corruptionEverUsed`) and gates rules-level exit eligibility.

### Dealer

- The in-run dealer runs on a fixed countdown starting/resetting at 12 (the club
  modifier doubles it to 24). Every spin advances it by 3/2/1 at x1/x2/x3; the
  authored 13-frame bar normalizes either countdown across its full range and
  walks through each intermediate frame toward its final arrival
  frame. Its warning lights use the matching countdown-progress frame, beep with
  an alpha pulse, and appear cumulatively only after the current spin's result
  (x3: overlay 1; x2: overlays 1+2; x1: overlays 1+2+3). They remain visible
  during a losing-state warning: pending x1 and x2 show all three lights, while
  pending x3 shows the preceding x2 stack (overlays 1+2). At 0 he visits
  automatically. The compact dealer portrait sits just inside the TV border
  beside the countdown bar.
- A visit offers 2 run items (3 with the offer-expand augment) plus one dedicated
  Chip Augment; offers can be rerolled for escalating run Lucidity. Taking or
  refusing the visit both reset the countdown.
- Chip Augments: consumable/chip discounts, permanent symbol-level pushes, +3
  spins per copy, expanded offers, and the legendary pair/triple specialist
  (chosen win type pays x1.25).
- The dealer scene is used for in-run visits and the post-Wealth odds phase; a
  fresh run no longer opens a pre-run consumable shop.
- Sequencing: the visit waits behind reel/reroll animation, the power-coin
  sequence, and Energy Drink's compulsory spin. It MAY open above a pending
  combo-loss decision (dealer at z100 over the z97 loss art, stash elevated to
  z110 while his offer is up); closing him returns to that pending decision.

### Free spins, losses, and compulsions

- Free spins never cost run spins. The bank caps at 1 (3 when upgraded); a jackpot
  grants 1. The FREE SPIN banner covers banked credits and Energy Drink's
  protected spins.
- Combo loss: a miss at x2/x3 sets a pending defeat. The x2 state shows its
  authored overlay with a beeping pulse; the x3 state shows a steady 9-frame
  diminished-fire sheet (never both, and the normal gauge effects are suppressed
  while one is up). A power that turns the reveal into a paying pair/triple
  rescues the gauge (one step up); pressing SPIN confirms the loss (one step
  down). Consumables stay usable during the rescue window. Cocktail points awarded
  on a miss still launch any pending wealth-bank power-coin sequence while the
  loss warning is open. A warning left with no
  spins remaining resolves itself so the flatline procs without input.
- Energy Drink: two protected spins (no decay, gauge pinned to x2, no losing
  state can open), then one machine-controlled compulsory spin at x2. The
  compulsory spin discards any leftover warning, survives temporary locks, and
  its result alone decides the next combo-loss state; the dealer stays queued
  until it fully resolves.

### Endings and persistence

- **Wealth** — 2,000 score. Wealth banking waits for the player's choice; the run
  can be continued once past Wealth (higher neuron cap, ends only by flatline).
  All three ending presentations draw above the machine HUD art.
- **Flatline** — 0 run spins with no banked free spins. Keeps 10% of run Lucidity
  (20% with Smart Save, spade halves it) into the wallet.
- **Game Over** — a flatline with no campaign neurons left; fatal, no coming
  back.
- Progression persists in MetaStateStore: wallet, Lab permanents, unlock-aware
  Pacte augment/power card IDs (all supplied cards start unlocked), selected card
  history, permanent odds upgrades (post-run token phase, max 8 tokens held per
  menu), and ending history. Lab permanents include Shift, Memory, Hydration,
  Reward Amplification, Sedative Protocol, Pattern Fabrication, Euphoria Spiral,
  Passive Cognition, Hallucination, Learning, and Smart Save.
- **Augmented Runs** — post-Wealth difficulty modifiers picked on the start menu:
  heart (jackpot pays 100, no free spin), spade (end-of-run Lucidity kept is
  halved), diamond (two power uses per spin), club (dealer wait doubled, spin
  rewards halved), joker (all four at once).

### Scenes and lifecycle

- `start_menu_scene` — campaign hub: start/continue, Augmented Run selector,
  first-launch tutorial.
- `pacte_scene` — reusable initial/threshold card ritual: deterministic three-card
  augment and power offers, previews, drag-to-emplacement selection, and resumable
  partial choices.
- `shop_scene` — wallet/meta progression hub.
- `dealer_scene` — in-run dealer visits and the post-run odds phase (gateway to the Lab).
- `upgrades_scene` — the Lab: permanent upgrades.
- `machine_scene` — the run itself; also hosts the in-run dealer offer overlay
  and the ending overlays (flatline, game over, wealth).
- `scores_scene` / `settings_scene` / `collection_scene` / `options_overlay` —
  meta screens.
- Run lifecycle: `idle` → `pacte_initial` → `running` → `pacte_threshold` →
  `running` → `over` (with `lastEnding` set to wealth/flatline/game_over); a
  Wealth continuation returns `over` → `running`.

## Living Game Documentation

Every change that adds, removes, renames, rebalances, or behaviorally modifies a
player-visible mechanic MUST update the Game Reference above in the same branch
and PR.

- Delete removed mechanics outright — never mark them obsolete.
- Update changed constants, terminology, scene flow, currencies, endings, and
  interactions.
- Pure refactors with no gameplay change need no documentation change.
- This file summarizes intended behavior; the rule data in `godot/rules/` and the
  parity tests remain authoritative for exact tables and edge cases.
- Stale game-reference documentation means the task is incomplete.

## Verification

Before considering work done, run the checks relevant to the change:

```sh
godot --headless --editor --quit --path godot
godot --headless --path godot -s res://test/run_parity_headless.gd
godot --headless --path godot -s res://test/scene_smoke.gd
```

Run parity when touching rules, scoring, economy, saves, upgrades, dealer logic, or
content data. Run scene smoke checks when touching scenes, UI, controller flow, assets,
or save/runtime integration.

## GDScript Rules

- Use Godot 4 syntax only.
- Use `@export`, `@onready`, `await`, `super()`, and modern property setters/getters.
- Use strict static typing for variables, parameters, and return values.
- Use `:=` only when the type is obvious from the right-hand side.
- Cast nodes fetched from the scene tree.
- Use modern callable signal connections, never string-based connections.
- Prefer exported node references or `%UniqueName` over fragile relative node paths.
- Prefer signals/events over `_process` or `_physics_process` unless polling is needed.
- Use `StringName` for input actions, animation names, and dictionary keys where useful.

## Style

- Follow the official GDScript style guide.
- Use `snake_case` for variables and functions.
- Use `PascalCase` for class names and node names.
- Use `CONSTANT_CASE` for constants.
- Add brief docstrings only for complex functions and classes.
