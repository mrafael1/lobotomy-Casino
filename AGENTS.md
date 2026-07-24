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
- **Run spins / chips** — the serialized run field is still `neurons` for
  save/parity compatibility, but the machine presents it as the CHIPS/SPINS
  counter. A fresh run starts with 15 and the run can hold at most 18;
  each spin spends 1 run spin unless protected. Restores and Wealth continuations
  also stop at 18. The machine prints the current remaining-spin number under the
  neuron tube; it updates whenever spins are gained, spent, or protected, and the
  number turns dark red when the 18-spin cap is full.
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
3. Enter the machine with 15 CHIPS/SPINS and the selected Pacte power. No power is
   granted implicitly; Reroll, Shift, and the other run powers must be selected in
   Pacte. The run begins with no pre-run consumables.
   A compact blue contour around the selected augment icon sits inside the machine
   TV, shifted 10px right from the original placement; tapping it opens the active
   Pacte augment(s)' names and descriptions.
4. Spin for pairs, triples, and jackpots. Paying wins step the automatic frenzy
   gauge x1 → x2 → x3; a miss at x2/x3 opens a rescuable diminished (combo-loss)
   state instead of dropping instantly.
5. Use powers and consumables to manipulate revealed reels, protect resources, or
   alter future spins.
6. When a flatline consumes the reserved campaign neuron and the campaign count
   crosses from 8 to 7 or from 5 to 4, finish the flatline presentation and then
   open that threshold Pacte visit. A live machine's CHIPS/SPINS counter reaching
   5 never opens Pacte. Each threshold visit adds one augment and power to the
   earlier selections; completion opens the live dealer scene with the current
   run's Lucidity balance, normal run-item offers, and a dedicated Chip Augment
   offer.
7. Handle automatic dealer interruptions: his 12-step countdown advances by 3/2/1
   for x1/x2/x3 each spin, so lower gauges pull him in faster; Glitch 2 makes every
   spin advance three steps.
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
  payout line beneath the word showing the base payout. When the COMBO augment is
  active, its authored COMBO x1..x9 indicator stays mounted in the machine TV at
  the current streak. The base payout lands first, then the COMBO indicator shakes
  and sends out its separate bonus amount. Any transient TV callout temporarily
  hides COMBO, the FREE SPIN banner, and dealer countdown information so the pop
  remains readable; those indicators return when the callout ends.
- A Heart triple uses the authored TRIPLE music and the vial-style reaction flash
  even though it pays no score: its tier shows a little "+1", "+2", or "+3"
  fly-in while recovering the matching run spins.
- Scores multiply by the frenzy gauge and Lab lucidity multipliers. Exact tables
  and edge cases live in `godot/rules/` and the parity vectors — this file only
  summarizes intent.

### Powers

- **Reroll** — an optional Pacte power that rerolls one revealed reel.
- **Shift** — steps one revealed reel along the symbol cycle.
- **Lock** — locks a reel through upcoming spins.
- **Rewind** — restores the immediately previous spin's reels, neuron/free-spin,
	dealer, and combo state while preserving earned score/Lucidity and recovering
	a deterministic 1–3 other power chips used during that rewound spin. Powers
	spent before that spin remain spent. Rewind itself is spent and cannot recover
	itself, so one history can never create an infinite rewind loop. It is
	unavailable without spin history or while another sequence is active. While the
	restore's backwards reel roll plays, SPIN is locked out; the lever re-enables
	only once the restored reveal (and any restored warning) has fully landed.
- **Heart** — arms the next spin and immediately turns the whole reel strip —
  centre and adjacent symbols — into hearts as a preview. That spin is free and
  deterministically lands a matching triple of `heart_x1`, `heart_x2`, or
  `heart_x3` with equal 1/3 odds, filling each strip with the matching heart
  tier; it pays +1/+2/+3 run spins only — no score or Lucidity — and advances the
  frenzy gauge one step. Heart can also be armed during a losing-state warning;
  doing so rescues the warning without lowering the gauge. It is spent like the
  other powers and returns only through the normal power-restore rules.
- **Cheat** — shows the same rubble/reward-amplification overlay as the other
  symbol powers, then replaces one selected reel with a symbol chosen from the
  existing symbol chooser. After the reel is picked, its authored
  `cheat_selection` sheet shows the idle, bottom-arrow, and top-arrow states.
- **Swap** — rubble-flashes the revealed symbols; each reel's centre and adjacent
  symbols shake while targeting is armed, and any visible symbol can be picked.
  The selected symbol follows the finger/mouse immediately in a drag animation and
  swaps with the centre symbol on any other reel, including an adjacent reel,
  before rescoring the reveal. Symbol values do not need to be distinct. The
  selected source reel is marked with a red X while dragging because it cannot be
  used as its own destination.
- **Pattern Recognition** — its five authored icon frames animate on the Pacte card.
- **Reward Amplification** — selecting a Reward+ Pacte card opens a symbol-only
	picker so the boosted symbol is chosen during the ritual; its title and close
	cross are intentionally omitted from the compact overlay, and tapping outside
	the choices cannot dismiss the mandatory picker.
- **COMBO** — successive paying pair/triple/jackpot results form a streak and add
  5%, 10%, 15%, …, 45% of that result's base payout (x1 through x9, capped at
  45%). The base payout is shown first, then the persistent COMBO xN indicator
  shakes and emits its separate bonus. A miss opens the same rescuable losing
  state used by the frenzy gauge; while that warning is pending, COMBO beeps and
  a corrective power can recover the streak. Confirming the loss clears it.
- **Glitch 2** — the dealer countdown always advances by 3 steps per spin, even
  while the machine is at x2 or x3. Its dealer warning bar always shows all three
  warning overlays. Its Pacte card has no icon and occasionally tears visually.
- **Joker** — after the first 3-flatline strike in the run, the dealer sometimes
  uses a helpful Cheat, Shift, Reroll, or Lock effect. These assists are separate
  from the player's loadout and never consume the player's power chips.
- Power slots preserve acquisition order: the first three owned powers occupy the
	authored 1/2/3 positions in the machine bar, regardless of their card IDs.
- Selecting a power for targeting flashes its authored TV callout (with text
  frames ordered Reroll, Shift, Lock, Rewind, Heart, Cheat, Swap (with text
  fallbacks if an authored frame is unavailable) with
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
  modifier doubles it to 24). Every spin advances it by 3/2/1 at x1/x2/x3; Glitch
  2 overrides that cadence with 3 steps at every multiplier. The authored 13-frame
  bar normalizes either countdown across its full range and
  walks through each intermediate frame toward its final arrival
  frame. Its warning lights use the matching countdown-progress frame, beep with
  an alpha pulse, and appear cumulatively only after the current spin's result
  (x3: overlay 1; x2: overlays 1+2; x1: overlays 1+2+3). They remain visible
  during a losing-state warning: pending x1 and x2 show all three lights, while
  pending x3 shows the preceding x2 stack (overlays 1+2). With Glitch 2 active,
  all three overlays remain visible at every multiplier. At 0 he visits
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
  multiplier badge stays in its engaged x2-cap state through the protected and
  compulsory window. The compulsory spin discards any leftover warning, survives
  temporary locks, and its result alone decides the next combo-loss state; the
  dealer stays queued until it fully resolves.

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
  partial choices. Its authored table, deck, dealer, dealer-bubble, and two-frame
  emplacement assets are composed at native resolution. The active deck shuffles
  briefly while the three cards remain facedown, and dragging either card type
  shows its authored DROP HERE frame. A dragged card casts a drop shadow (as do
  dragged dealer/stash items everywhere). There is no arrow selector overlay and
  no CANCEL/EXIT text buttons. The card preview is a compact information bubble
  between the dealer prompt and card row; the centered CHOOSE AN AUGMENT/POWER
  prompt sits in the dealer bubble, using blue text for augment selection and red
  text for power selection. Card dragging is bounded to the native 160x320 canvas.
  Once the machine has started, a reopened Pacte presents a clean table: the
  initial visit's cards keep their effects in the run but are not re-shown.
  Completing the mid-run (threshold) visit hands off to the live dealer scene,
  which shows run Lucidity and the Chip Augment offer before returning to the
  machine.
- `shop_scene` — wallet/meta progression hub.
- `dealer_scene` — in-run dealer visits and the post-run odds phase (gateway to the Lab).
- `upgrades_scene` — the Lab: permanent upgrades.
- `machine_scene` — the run itself; also hosts the in-run dealer offer overlay
  and the ending overlays (flatline, game over, wealth).
- `scores_scene` / `settings_scene` / `collection_scene` / `options_overlay` —
  meta screens.
- Run lifecycle: `idle` → `pacte_initial` → `running` → `over` (with
  `lastEnding` set to wealth/flatline/game_over). A flatline that crosses the
  campaign count from 6 to 5 resumes as `pacte_threshold`, then returns through
  `running` to the dealer; a Wealth continuation returns `over` → `running`.

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
