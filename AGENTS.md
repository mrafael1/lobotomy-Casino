# lobotomy-Casino - Codex Guidelines

You are an expert game developer specializing in Godot Engine 4.x and GDScript 2.0.
Write clean, performant, modern Godot 4 code.

## Branching Workflow

Always create a dedicated branch before making changes. Never push directly to `main`
or the current session's base branch.

### Branch Naming

do not add Claude/codex in front of branch

- Bug fixes: `fix-<short-description>`
- New features: `feat-<short-description>`
- Tweaks / balance / polish: `tweak-<short-description>`

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

- **Campaign neurons (lives)** — a campaign grants 3; each run attempt spends
  one. Exhausting them ends the campaign fatally (Game Over).
- **Run spins / chips** — the serialized run field is still `neurons` for
  save/parity compatibility, but the machine presents it as the CHIPS/SPINS
  counter. A fresh run starts with 15 and the run can hold at most 18;
  each spin spends 1 run spin unless protected. Restores and Wealth continuations
  also stop at 18. The machine prints the current remaining-spin number in the left
  control-shelf well beside SPIN; it updates whenever spins are gained, spent, or
  protected, and the number turns dark red when the 18-spin cap is full.
- **Score** — the run's win total. The Wealth targets advance through **100 → 200 →
  500 → 800 → 1,500 → 2,500 → 3,500 → 5,000**; reaching **5,000 score** triggers
  the Wealth ending. The machine's four-reel wealth odometer
  advances directly with score payouts when their score pop appears; it does not collect
  the separate Lucidity coins from the cash tray. Changed digits roll and carry like
  physical number drums. Its white cases sit behind the rolling digits and the
  CRT surround sits above them. The current Wealth objective sits above the odometer
  in the CRT's right column, with a thin progress bar between them. Reaching an
  intermediate target briefly presents that target in the centre of the machine,
  drains its displayed number to zero while the target payment rolls off the wealth
  readout. During the drain, shortened target values stay anchored to the units slot
  (`_90`, not `90_`), then the remainder is shown and the target is subtracted from
  the run score before handing the run to the between-machine route offer. Target and
  loss breaks use the same route choices; the full Pacte ritual is only available when
  a run starts.
- **Run Lucidity (coins / gold)** — earned alongside score during the run. Every 30 coins
  restores one random spent power (18 with Adrenaline). Gold pays for route cards,
  Augment/Power build cards, Shop investments, and Shop consumables; it also pays for
  live-dealer offer rerolls. On a non-Wealth ending, 10% is kept (20% with Smart Save,
  halved by the spade modifier) and banked into the wallet.
- **Wallet Lucidity (credits)** — the persistent meta currency. Buys Lab upgrades
  and persistent progression between runs.

## Typical Run

1. On the start menu, optionally choose an unlocked **Augmented Run** modifier.
   This is a pre-launch choice only: it locks when the run starts and cannot be
   selected or changed while a run is active, including when continuing a saved
   run (the selector shows the active run's suit, arrows disabled).
2. Reserve the campaign neuron and enter **Pacte**. Reveal three augment cards
   and three power cards, then select and place one of each. Pacte selections are
   saved mid-visit; the initial ritual is free and its completion enters the machine
   directly.
3. Enter the machine with 15 CHIPS/SPINS and the selected Pacte power. No power is
   granted implicitly; Reroll, Shift, and the other run powers must be selected in
   Pacte. The run begins with no pre-run consumables.
   Worn-paper augment stickers sit on the lower red cabinet beneath the controls;
   holding one opens the active Pacte augment(s)' names and
   descriptions.
4. Spin for pairs, triples, and jackpots. Paying wins step the automatic frenzy
   gauge x1 → x2 → x3; a miss at x2/x3 opens a rescuable diminished (combo-loss)
   state instead of dropping instantly.
5. Use powers and consumables to manipulate revealed reels, protect resources, or
   alter future spins.
6. When an intermediate target is reached, finish its target/remainder presentation
   and receive two deterministic route cards from the dealer: **Shop**, **Augment**,
   **Power**, **Bonus**, or **Sacrifice**. A survivable flatline receives the same
   two-card offer, with at least one free tier-capped build route. Shop, Augment, and
   Power spend run Lucidity before opening their destination; Bonus and Sacrifice
   are free. Augment opens only an augment card pool, and Power opens only a power card
   pool. The player may press **CONTINUE** to refuse both cards for free. The route offer,
   build choice, and bonus claim persist through save/resume; no normal route purchase
   spends spins.
7. Handle automatic dealer interruptions: his 12-step countdown advances by 3/2/1
   for x1/x2/x3 each spin, so lower gauges pull him in faster; Glitch 2 makes every
   spin advance three steps.
8. End the run: reach Wealth, flatline and keep part of the run's Lucidity, or
   exhaust the campaign into Game Over. A target break or survivable loss returns to
   the route choice before the next machine segment.
9. Between runs, spend odds-phase tokens and wallet credits on permanent
   progression, then start the next attempt.

## Game Reference

### Routes and between-machine economy

- After every intermediate Wealth target and every survivable flatline, the dealer stores
  exactly two seed-identified route cards drawn from **Shop**, **Augment**, **Power**,
  **Bonus**, and **Sacrifice**. The pair is deterministic and persisted through
  close/resume; the player may pay the dealer to reshuffle both doors for **5G**, then
  **10G**, then **15G** and so on. The player may refuse both with the free **CONTINUE**
  action. Event routes remain reserved for a later milestone.
- The full Pacte scene is the run-start ritual only: it is free and explicitly grants
  one selected augment and one selected power. End-of-segment Augment and Power routes
  use the shared card metadata and pricing but each asks for only one card, never both.
- The current route fees are **5G for Augment**, **5G for Power**, and **8G for Shop**.
  Bonus spins the Fortune Wheel for **50 run coins**, **x1.25 next-round gains**, a
  **jackpot** (no three-flatline cap, half the next target as starting score, and 100
  run coins), or an **odds table with 8 or 4 tokens**. Sacrifice costs no route entry
  fee and trades one augment, power, 100 run coins, or a campaign neuron (only when at
  least 2 remain) for **+5 run spins next round**, up to three accepted sacrifices per
  run.
  Selecting a paid route charges it immediately; selecting a build card charges its
  card price when confirmed. After a loss, both the Augment and Power build pools are
  capped at tier 0 and free, so deliberately losing cannot buy the strongest cards.
- The route Shop is run-scoped machine investment. It sells odds/reward pushes, pair
  consistency, spin protection/capacity, and the existing consumables. Buying a
  consumable adds one stash copy; using it removes that copy. Shop upgrades do not
  become Lab permanents or campaign Chip Augments; the club modifier marks these
  Shop prices up by 50% like the existing shop economy.
- Sacrifice is one possible free route card: it opens the dedicated resource-trade
  scene; refusing it continues normally without recording a deferred choice.
- The live Dealer remains a tactical interruption with power services, rerolls, and
  run-item offers, but it is no longer an end-of-segment route card. It does not
  duplicate Pacte build identity or the Shop's machine-investment inventory.

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
  active, its authored COMBO x1..x9 indicator stays hidden between payouts and
  belongs on the Wealth bar. The base payout lands first, then the COMBO indicator
  pops and shakes over the Wealth readout while sending out its separate bonus
  amount, before disappearing. TV callouts continue to hide the TV-only target
  readout, active-item icons, and dealer countdown information; the Wealth-bar
  COMBO pop is independent of that TV priority.
- Active multi-spin items show as small 8px duration icons in a row under the
  target bar, filling left to right, each with the number of turns it has left
  beside it. That number is coloured by what the item is doing right now: green
  while it is helping, red while it is costing. Five slots, enough that
  simultaneous items no longer collapse into an overflow badge. Only a full-screen
  callout clears the row; the FREE SPIN banner shares the screen with it.
- An item whose effect runs in phases keeps ONE badge for the whole thing, counting
  the entire effect down while the colour tracks the phase currently running. The
  Red Pill counts 2, 1 turning red (the forced flatline it makes you take) then
  green (the triple it owes you); the Energy Drink counts 3, 2, 1 turning green
  (protected spins) then red at 1 (the compulsory spin it queued). Cocktail,
  Potion and Tobacco are green throughout; Serum's blur tail is red.
- Tapping an item icon pops that item's name and what it is currently doing, over
  the TV, for about a second before it fades on its own. The popup never blocks
  input and draws above the banner, the dealer countdown and the losing-state
  overlays; a callout taking the TV dismisses it.
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
	restore's backwards reel roll plays, SPIN is locked out; SPIN re-enables
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
- **Hallucination** — keeps all three reels visible; a visible pair is scored as its
  corresponding triple, and THAT payout — only that one — is cut to 30%. Natural
  triples the reels made on their own (the syringe triple included), ordinary pairs,
  and Book joker wins all pay in full while it is owned; the cut is charged to the
  promotion, the same way Learning charges its cut to book wins. It does not hide or
  cover the third reel.
- **Tunnel Vision** — hides the third reel and increases rewards by 50%.
- **How to Cheat** — a solo visible symbol counts as a pair; all pair payouts use
  a x0.6 multiplier.
- **Adrenaline** — lowers the power-restore threshold from 30 to 18 Lucidity;
  the three reel lamps advance at 6, 12 and 18 coins.
- **Passive Gain** — adds 10 run Lucidity on every spin, including misses.
- **Reward Amplification** — selecting a Reward+ Pacte card opens a symbol-only
	picker so the boosted symbol is chosen during the ritual; its title and close
	cross are intentionally omitted from the compact overlay, and tapping outside
	the choices cannot dismiss the mandatory picker.
- **COMBO** — successive paying pair/triple/jackpot results form a streak and add
  5%, 10%, 15%, …, 45% of that result's base payout (x1 through x9, capped at
  45%). The base payout is shown first, then the Wealth-bar COMBO xN indicator
  pops, shakes, emits its separate bonus, and disappears. A miss opens the same
  rescuable losing state used by the frenzy gauge; while that warning is pending,
  only the loss art beeps and a corrective power can recover the streak.
  Confirming the loss clears it.
- **Glitch 2** — the dealer countdown always advances by 3 steps per spin, even
  while the machine is at x2 or x3. Its dealer warning bar always shows all three
  warning overlays. Its Pacte card has no icon and occasionally tears visually.
- **Joker** — after the first 3-flatline strike in the run, the dealer sometimes
  uses a helpful Cheat, Shift, Reroll, or Lock effect. These assists are separate
  from the player's loadout and never consume the player's power chips.
- Power slots preserve acquisition order: the first three owned powers occupy the
	three large round sockets on the metal rail below the CRT, regardless of
	their card IDs.
- Selecting a power for targeting flashes its authored TV callout (with text
  frames ordered Reroll, Shift, Lock, Rewind, Heart, Cheat, Swap (with text
  fallbacks if an authored frame is unavailable) with
  a short beeping pulse; the callout stays up while targeting is armed and hides
  when the target is picked or the selection is cancelled.
- Using a power spends it; the three reel lamps restore one random spent power per 30
  run-Lucidity coins. Score payouts—including Cocktail rarity points—also advance the
  wealth-linked 10-point bank. Each 10-point gauge step launches the four-frame `power
  coin animation` from the cash outlet, then sends the real power coin to the power
  lamps above the reels, filling left to right at 10, 20 and 30. The old side gauge
  is removed. A successful restore flashes all three lamps and clears the fill;
  without an eligible spent power or restore charge, the lamps hold full until
  restoration is possible. The diamond modifier caps power use at two per spin.

### Consumables and run items

- Run consumables held during the run: Tobacco, Serum, White Powder, Potion, Tea;
  the initial Pacte handoff starts with no consumables and the stash limit is 2.
- Dealer-only run items (offered mid-run): Energy Drink,
  Cocktail, Water, Red Pill.
- Items are TAKEN and USED in two different places. The dealer's visit overlay is
  where an offer is selected (tapping an item arms TAKE with it) and taken into the
  run stash; the machine's right-hand control-shelf stash is where a held item is
  spent, by tapping its slot. Taking is not using — an item sits in the stash until the player
  spends it, and the stash holds 2.
- Water grants +40 run Lucidity AND +40 score: drinking it rolls the wealth
  odometer up immediately and its points feed the power gauge like any score. Using
  it plays a short authored three-frame pour over the machine.
- The Cocktail pays rarity points for every VISIBLE reel (flatline 1 … brain/book 6,
  scaled by the frenzy multiplier) and is blind to what the reels did: misses, pairs
  and triples all collect the same total for the same symbols. A reel hidden from
  scoring pays nothing.
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
  automatically. A persistent 30x43 dealer portrait occupies the CRT's left column;
  the twelve approach steps and cumulative warning lights sit beneath it. Short
  reactions type into a framed caption, respond to revealed plays, and yield to
  payout and targeting callouts. Their hold/fade timer pauses while the portrait
  is hidden, leaving the response readable after a callout finishes.
- A visit offers 2 run items (3 with the offer-expand augment) plus one dedicated
  Chip Augment; offers can be rerolled for escalating run Lucidity. Taking or
  refusing the visit both reset the countdown.
- Chip Augments: consumable/chip discounts, permanent symbol-level pushes, +3
  spins per copy, expanded offers, the legendary pair/triple specialist (chosen
  win type pays x1.25), Dealer's Tip and Emergency Reserve.
- Chip Augments are CAMPAIGN state and live on MetaStateStore, not the run: they
  survive new runs, Pactes, flatline continuations and Wealth target round
  breaks, and are cleared only when the campaign itself ends (wealth ending or
  game over). `_clear_campaign_augments()` is the single place that removes them.
- Symbol Level picker: the odds table opens holding one golden token. Tapping a
  row's "+" stages the pick and spends the token on the spot — the wallet drops
  to zero and EVERY "+" closes, the picked symbol's included. Only that symbol's
  "-" stays live, and using it hands the token back and reopens every eligible
  "+". DONE commits the staged pick; with nothing staged the button reads CANCEL.
  One augment level per symbol, ever, up to the level-9 hard cap.
- Dealer's Tip: the dealer countdown never starts empty again. Every reset begins
  2 steps in, so the bar reads 2/12 instead of 0/12 and the dealer comes round
  sooner. The countdown's SCALE is unchanged — `dealer_countdown_cycle_length()`
  (12) drives the bar, `dealer_countdown_reset_value()` (10) is what a resolved
  visit resets to. Applies from the next reset; the running countdown is not
  touched.
- Emergency Reserve: one paid spin back when a paid spin leaves the run with no
  neurons and no free spins. Resource exhaustion only — a flatline strike, a
  combo-loss confirmation, or a spin that already restored spins never spends it,
  because the check runs after the spin's own restores and reads neither. Fires
  once per CAMPAIGN (`MetaStateStore.emergencyReserveUsed`), so it does not
  re-arm on a new run or a target round break.
- Purchase feedback is data-driven: `ChipAugments.FEEDBACK` maps each effect to a
  scene ("dealer" or "machine") and a target. Payoffs that only exist back at the
  machine are queued through `SceneNav.queue_feedback()` and collected once on
  entry. That queue is presentation state and is never saved; a missing visual
  target skips its effect silently and never affects gameplay.
- The dealer scene is used for in-run visits and the post-Wealth odds phase; a
  fresh run no longer opens a pre-run consumable shop.
- Sequencing: the visit waits behind reel/reroll animation, the power-coin
  sequence, and Energy Drink's compulsory spin. It MAY open above a pending
  combo-loss decision (dealer at z100 over the z97 loss art, stash elevated to
  z110 while his offer is up); closing him returns to that pending decision.

### Free spins, losses, and compulsions

- Free spins never cost run spins. The bank caps at 1 (3 when upgraded); a jackpot
  grants 1. The FREE SPIN banner covers banked credits and Energy Drink's
  protected spins. While it is lit it takes only the target GOAL NUMBER, whose band
  its own text occupies; the fill bar keeps running underneath it with its shimmer,
  because progress toward the target is exactly what the free spins are being spent
  on. The dealer interface and the active-item icons stay lit beside it too.
  Switching FREE SPIN on or off refreshes the target text immediately, so the
  banner and target never wait for a later HUD update to exchange visibility.
- Combo loss: a miss at x2/x3 sets a pending defeat. The x2 state shows its
  CRT warning with a beeping pulse; the x3 state shows a steady 9-frame
  diminished warning (never both, and the normal gauge effects are suppressed
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

- **Wealth** — 5,000 score after the authored target ladder. Wealth banking waits for
  the player's choice; the run
  can be continued once past Wealth (higher neuron cap, ends only by flatline).
  All three ending presentations draw above the machine HUD art.
- **Flatline** — 0 run spins with no banked free spins. Keeps 10% of run Lucidity
  (20% with Smart Save, spade halves it) into the wallet.
- Campaign neuron loss plays through the authored three-frame death sheet and keeps
  its final frame over the meter for the rest of the run; successive losses retain
  the first, second, and third overlays before Game Over.
- **Game Over** — a flatline with no campaign neurons left; fatal, no coming
  back.
- Progression persists in MetaStateStore: wallet, Lab permanents, unlock-aware
  Pacte augment/power card IDs (gated — see Pacte card unlocks below), the card
  unlock progress counters, the pending
  card-unlock queue awaiting its popup, selected card
  history, permanent odds upgrades (post-run token phase, max 8 tokens held per
  menu), and ending history. Lab permanents include Shift, Memory, Hydration,
  Reward Amplification, Sedative Protocol, Pattern Fabrication, Euphoria Spiral,
  Passive Cognition, Hallucination, Learning, and Smart Save. Pacte-only augments
  include Tunnel Vision, How to Cheat, Adrenaline, and Passive Gain.
- **Pacte card unlocks** — a new save owns four augments (Reward + I, Smart
  Saving, Passive Gain, Book) and three powers (Reroll, Shift, Lock). Everything
  else is earned, and stays earned across campaigns:
  - Reward + II — reach a run target of 2,000.
  - Reward + III — reach a run target of 4,000.
  - Hallucination — use 10 consumables.
  - Pattern Recognition — land 20 pairs in one run.
  - Tunnel Vision — land the same triple 3 times in one run.
  - Adrenaline — restore power 30 times.
  - Joker — win a joker Augmented Run.
  - Combo — win a run without a single flatline.
  - Glitch — die of flatline.
  - Is It Cheating? — use the Cheat power 10 times.
  - Heart power — win a heart Augmented Run.
  - Cheat power — win a run.
  - Rewind power — recover 20 spent spins.
  - Swap power — turn 10 spins into a win with Shift.
- **Augmented Runs** — post-Wealth difficulty modifiers picked on the start menu,
  one per axis: heart/health (a paid spin costs 2 health, the last chip still
  costs 1), spade/power tempo (a restore charge refills only every other spin),
  diamond/choice (two power uses per spin, and the Augment route deals no
  augment), club/economy (shop prices +50% and a HOUSE ANGER row on every target
  payout — the dealer reroll price is deliberately untouched), joker (all four at
  once). Free, compulsive and Energy-Drink spins are exempt from heart's cost.

### Scenes and lifecycle

- `start_menu_scene` — campaign hub: start/continue, Augmented Run selector,
  first-launch tutorial.
- `pacte_scene` — run-start-only card ritual: deterministic three-card augment and
  power offers, previews, drag-to-emplacement selection, and resumable
  partial choices. Its authored table, deck, dealer, dealer-bubble, and two-frame
  emplacement assets are composed at native resolution in bg -> dealer -> table ->
  overlay order. The one-frame augment and power decks stay visible at their
  authored left/right positions during both draw phases. Each emplacement uses a
  no-DROP-HERE frame and a DROP HERE frame while dragging. The active deck shuffles
  briefly while the three cards remain facedown, and dragging either card type
  shows its authored DROP HERE frame. Both proposition card types use the same
  authored 39x61 front size, including the power card's left edge. A dragged card
  casts a drop shadow (as do
  dragged dealer/stash items everywhere). There is no arrow selector overlay and
  no CANCEL/EXIT text buttons. The card preview is a compact dark information
  bubble with a gold contour, gold title, and light description above the currently
  inspected card. The authored two-frame dealer text supplies the augment/power
  prompt; no separate CHOOSE AN AUGMENT, CHOOSE A POWER, or CHOOSE ONE CARD label
  is drawn. The drag instruction sits below the offer-card row, and card dragging
  maps mobile viewport touches into the native canvas while preserving the point
  grabbed under the finger, and remains bounded to the native 160x320 canvas.
  The full Pacte scene is available only at run start; it is never reopened by a
  target or loss route. End-of-segment Augment and Power choices use separate
  single-deck build scenes and save their selected card before returning to the
  next machine.
- `dealer_choice_scene` — the persisted dealer presentation of exactly two changing
  doors for Shop/Augment/Power/Bonus/Sacrifice. The shop background and counter
  layers are intentionally omitted for now; the scene keeps the dealer, doors, and
  route controls.
  Each door switches its authored
  door asset to match the route card; paying the dealer reshuffles both doors at an
  escalating **5G / 10G / 15G** price. Selecting a door commits the route and there is
  no return to this selection screen. **CONTINUE** refuses both doors for free;
  Sacrifice remains a free card when it is offered. `route_scene` remains only
  as a compatibility shell for older direct scene references.
- `route_scene` — the persisted dealer presentation of exactly two
  Shop/Augment/Power/Bonus/Sacrifice cards, using the authored dealer shop art.
  **CONTINUE** refuses both cards for free; Sacrifice remains a free card when it
  is offered. This legacy scene is retained only for older direct references;
  active route navigation uses `dealer_choice_scene`.
- `route_build_scene` — a single augment or single power selection with run-Gold
  pricing and save/resume support. It reuses the authored Pacte room art, showing
  only the matching deck and emplacement: Augment hides the power side, and Power
  hides the augment side. Its three-card offer is presented in Pacte's authored
  card row; tapping inspects a card, dragging it into the matching slot shows the
  selected card there, and only then does the route commit. Its route door is already
  final, so it has no action that returns to dealer choice. The selectable route cards
  remain separate from Pacte's full ritual UI.
- `route_bonus_scene` — the persisted one-time Fortune Wheel prize claim; odds prizes
  open the existing odds table with their exact token budget.
- `sacrifice_scene` — the persisted one-time-per-route resource trade, capped at three
  accepted sacrifices per run and resumable before the next machine.
- `route_shop_scene` — run-scoped machine investments and single-use consumable shop.
- `route_dealer_scene` — retained as a compatibility shell for older route saves;
  new end-of-segment offers use the live Dealer only through its interruption flow.
- `shop_scene` — wallet/meta progression hub.
- `dealer_scene` — live in-run dealer visits and the post-run odds phase (gateway to the Lab).
- `upgrades_scene` — the Lab: permanent upgrades.
- `machine_scene` — the run itself; also hosts the in-run dealer offer overlay
  and the ending overlays (flatline, game over, wealth).
  Its painted cabinet is imported at 160x320, with worn red enamel, recessed
  metal trim and a matching cadaver-green dealer portrait. Independent worn-metal
  reel frames sit over native 160x320 shaded paper drums; a four-frame native
  motion sheet uses the same warm paper surface. The three transparent apertures
  remain x33/65/97, y169..202, with live scoring windows at y170..199. Landed and
  locked reels use the same drum backing while each other reel keeps spinning.
  Symbols, targeting, and the Tunnel Vision shutter remain independent layers.
  A registration material fits the painting to the existing live reel apertures;
  numbers, symbols, powers, and counters remain separate runtime elements.
  SPIN is a separate ivory/brass button centered at x80 on the lower metal shelf.
  Its touch rect is (57,210,46,28), between the remaining-spin counter on the
  left and two 16px stash slots on the right, clear of the wealth odometer.
  The deeper shelf spans y203..241. Three 22px power faces sit on the upper
  metal rail with 26px touch areas centered at (46,127), (77,127), (108,127).
  The CRT groups the dealer at (36,51), with his approach row at y95..98, above
  the item-duration row. TARGET and its value share a 6px font and y49 baseline.
  A muted olive progress strip sits at y59; warm paper wealth drums at (74,64)
  use native heavy digits, with the multiplier/loss warning lowered to y82. Augment
  stickers are 20px paper squares at (48,260), (74,260), and (100,260), with 14px
  icons and hold-for-details behavior; item durations retain their row at y100.
  Payout and targeting callouts hide the portrait, score, target, and normal multiplier
  until they finish. Cabinet stickers remain visible during CRT callouts.
  FREE SPIN replaces only the target number and title. Target-payout digit snapshots
  launch from the CRT; coin pops and flights launch from the cash outlet at (80,298).
  The power rail and sloped lower shelf are composed into the cabinet material.
  The lower shelf is copied directly from the approved preview by
  `tools/extract_preview_shelf.gd`, reduced once to native resolution. Its original
  plate, corners, wells, wear and red fascia remain intact. The changing count and
  items are cleared; the original SPIN cap is extracted into five separate PNG
  states. Do not replace this artwork with procedural approximations.
  The counter is at (28,210,14,16); 12x14 live items sit at (103,211) and (121,211).
  Counter and stash recesses belong to that surface; stash nodes carry only item
  icons and input, with no tray texture overlay. SPIN retains an independent
  native face and press states over its cabinet recess. Worn, uneven sticker
  edges replace the flat paper squares on the lower panel.
  The spin count and small SPINS legend sit side by side within the left well.
  An amber glass jackpot beacon sits on a metal base above the CRT. Its three
  native frames retain the payout hold, lit state and alternating jackpot flash;
  it stays dark until the winning result is announced.
  SPIN retains the preview's original lettering and a two-pixel depressed face;
  its full touch area remains unchanged. Dark mounting rims seat the power buttons
  into the metal rail. Visual review includes the 5,000 target and five active items.
  Stash artwork is inset to 12x14 inside each 16x18 touch well. Tapping the empty
  margin around a held item uses that item under the same animation and dealer
  locks as tapping its icon; the artwork itself does not intercept input.
  COMBO uses nine native-resolution CRT frames with larger x1..x9 lettering and
  an unscaled bonus amount; its original payout timing remains intact.
  The COMBO panel draws above the odometer's cases, digits and dividers and covers
  the whole multiplier band, while leaving the dealer and item-duration row visible.
  The shelf number is the single remaining-spin display. Spin-gain fly-ins land
  over that number before it increments and pulses. Emergency Reserve adds a soft
  mint contour around the counter while armed, disappearing when spent. The
  tutorial highlights the shelf counter; there is no side spin tube.
  Idle, depressed, disabled, hover and focus assets are independent of the cabinet; keyboard/controller UI activation is supported.
  Pressing SPIN calls `_do_spin()` after release; the existing animation, dealer,
  rewind and loss locks still govern it. Power targeting receives shelf input
  through the button. There is no side lever or coin-insert launch sequence.
  Separate three-state power chips preserve acquisition order and the existing
  ready/selected/spent interactions. Tunnel Vision mounts a slatted shutter over
  the third reel; the shutter lowers over the already-opaque scoring cover and
  disappears when the augment is removed. It does not intercept targeting input.
  Learning mounts a small leather field book on a bolted bracket beside the reels,
  with brass indexing strips outside the live symbol apertures. This independent
  layer appears only while Book is enabled, coexists with the Tunnel Vision shutter,
  and disappears when Learning is removed; it never changes scoring or input.
- `scores_scene` / `settings_scene` / `options_overlay` — meta screens.
- `collection_scene` — the complete Pacte card catalog, in two scrollable
  sections (AUGMENTS, then POWERS) that follow the authored card order, so a card
  never changes position once it is earned. Unlocked cards show their authored
  card front with the card icon centred on it and the card name beneath; locked
  cards keep their slot but show only the shared card back, muted and tear-lined,
  with no readable name or description. Tapping an unlocked card opens its detail
  modal with the full front, icon, name, and effect text; tapping a locked card
  opens the same modal in its minimal LOCKED state, which reveals nothing about
  the card. The unlocked ID lists in MetaStateStore are the single source of truth
  for what is revealed, and all card art/names/descriptions/icons are resolved
  from the shared PacteCards metadata. A locked card's modal shows how the card is
  earned, with progress toward the threshold, and nothing about what it does.
- `unlock_card_popup` — the acknowledgement flow for a newly unlocked card. Every
  progression unlock goes through the single MetaStateStore card-unlock API, which
  refuses unknown cards and already-owned cards, adds the card to the unlocked
  list, and queues it for presentation. The popup dims and blocks the scene it is
  mounted over, flips the enlarged card front into view with its icon under a
  CARD UNLOCKED heading, and shows the card name and description. VIEW COLLECTION
  acknowledges the card and opens Collection with it scrolled into view and
  pulsing; CONTINUE acknowledges it and returns to the scene underneath. Several
  cards unlocking at once are presented one after another, and the queue is
  persisted, so an unlock earned at the end of a session is still celebrated on
  the next launch.
- Run lifecycle: `idle` → `pacte_initial` → `running` → `over` (with
  `lastEnding` set to wealth/flatline/game_over). A target break or survivable flatline
  parks the lightweight route state beside `over`, then returns through route choice to
  `running`. The route state is persisted alongside the existing run phase; it does not
  add a new run phase. A free route refusal and every completed paid route return to
  `running` without consuming another campaign neuron.

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
