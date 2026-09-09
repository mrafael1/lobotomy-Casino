extends Node2D

## Main slot-machine scene (Milestone 2, first increment): the playable run loop —
## start run -> spin -> reel/result reveal -> HUD update -> ending -> bank/restart,
## driven entirely by RunStateStore (which delegates rules to the parity-verified
## core). Built programmatically so every position comes straight from the
## documented source-pixel constants below.
##
## Coordinate space is the 160x320 virtual canvas (project stretch scales it to the
## device). Art is loaded from res://assets so exported builds ship every resource.

const SRC_W := 160.0
const SRC_H := 320.0
const HUD_CORNER_INSET := 9.0 # top-corner buttons are pulled this far off both edges
const MACHINE_ART_TEXTURE_FILTER := CanvasItem.TEXTURE_FILTER_NEAREST
const MACHINE_MATERIALS := preload("res://assets/shaders/machine_materials.gdshader")

# Geometry measured from the authored machine art (source px).
const REEL_CELL_CENTERS := [43.5, 75.5, 107.5]
const REEL_WINDOW := { "top": 170.0, "height": 30.0 }
# Per-reel hole rects (source px) — used to mask the spin blur per reel on stop.
const REEL_HOLES := [
	{ "left": 33.0, "top": 170.0, "width": 21.0, "height": 30.0 },
	{ "left": 65.0, "top": 170.0, "width": 21.0, "height": 30.0 },
	{ "left": 97.0, "top": 170.0, "width": 21.0, "height": 30.0 },
]
const TV_SCREEN := { "left": 24.0, "top": 42.0, "width": 112.0, "height": 66.0 }
# Spins-left tube (off-TV, authored as native full-canvas frames): frame N shows
# N spins remaining — frame 0 = empty/no spins, frame 19 = 19+ spins. The sheet
# grew a chip (19 frames -> 20) and EconomyConst.MAX_NEURONS rose with it, so the
# top of the tube is reachable rather than authored-but-dead.
const HEALTH_BAR_FRAME_COUNT := 20
const HEALTH_BAR_SHEET := "machine_polished/spin_tube.svg"
# Emergency Reserve borrows the bottom chip from frame 1 of the native cartridge.
# Its glow stays registered to the final spin instead of adding another HUD badge.
const HEALTH_BOTTOM_CHIP_RECT := Rect2(7.0, 110.0, 7.0, 2.0)
const HEALTH_BAR_FRAME_W := 160.0 # full-canvas sheet: one frame is the whole canvas
const RESERVE_GLOW_COLOR := Color(0.55, 1.0, 0.85)
const RESERVE_GLOW_MIN_ALPHA := 0.22
const RESERVE_GLOW_MAX_ALPHA := 0.72
const RESERVE_GLOW_PERIOD := 1.1
const MAX_RUN_SPINS := EconomyConst.MAX_NEURONS
const SPINS_LEFT_NORMAL_COLOR := Color(0.8, 0.95, 1.0)
const SPINS_LEFT_MAX_COLOR := Color("#8f0d16")
# Remaining spins sit in the left shelf well beside SPIN.
const SPINS_LEFT_LABEL_RECT := Rect2(26.0, 211.0, 29.0, 19.0)
# Objective readout on the TV (issue #181). Authored full-canvas sheets: the goal
# number (art y91..95), the fill bar under it (y99..103), and a six-frame shimmer at
# y95..97 that loops between them. The goal sheet carries one frame per EconomyConst.WEALTH_TARGETS
# entry, so its frame index is the target index; the bar's twelve frames are the fill
# steps. They replace the TARGET word + red digit labels that used to be drawn into
# the bottom wealth bar.
const TV_STATUS_RIGHT := 109.0
const MULT_STRIP := { "top": 77.0, "height": 12.0 }
const MULT_BADGE_CENTERS := [87.5, 92.5, 97.5]
# Lower shelf: SPIN between the remaining-spin display and the two stash wells.
const SPIN_HIT := { "left": 57.0, "top": 210.0, "width": 46.0, "height": 28.0 }
const SPIN_PRESS_TIME := 0.09
# Centre of the reel window — consumable-use hint popups originate here.
const MACHINE_HINT_CENTER := Vector2(75.5, 185.0)
const SYMBOL_TARGET_H := 32.0 # 32px symbols render 1:1 in the virtual canvas.
# Landed reel strip (uses the reel-strip presentation): a smaller centre symbol with dim
# 0.9x neighbours peeking above/below, clipped by the cabinet hole.

# Swap presentation (issue #181). One cue per idea: the slot frames say where a symbol
# may land, the symbol shake says what can be grabbed, the instruction says what to do,
# and the red cross appears only when the pointer is over a reel that would be refused.
const SWAP_CENTRE_SLOT := 1 # 0 = above, 1 = centre, 2 = below; Swap only ever takes centre
# Swap talks about whole reels, so its cues cover the whole visible reel: the hole plus the
# strip symbols above and below it, not just the centre window.

# Cheat's mini-reel overlay (on the picked reel's hole) is CheatMiniReel's, arrow
# geometry and selection sheet included — they describe the overlay, not the cabinet.
# The arrow bounds are measured off the authored art rather than guessed from the
# hole: the old hole+gap guess sat 3px above the top arrow and 4px above the bottom
# one, which left the lower half of the down arrow dead (issue #181).

# Three 22px power faces on the painted steel rail; 26px independent touch boxes.
# Additional IDs share the first authored position until acquisition-order slotting.
const POWER_HITS := {
	"reroll": { "left": 33.0, "top": 114.0, "width": 26.0, "height": 26.0 },
	"shift": { "left": 64.0, "top": 114.0, "width": 26.0, "height": 26.0 },
	"memory": { "left": 95.0, "top": 114.0, "width": 26.0, "height": 26.0 },
	"rewind": { "left": 33.0, "top": 114.0, "width": 26.0, "height": 26.0 },
	"heart": { "left": 33.0, "top": 114.0, "width": 26.0, "height": 26.0 },
	"cheat": { "left": 33.0, "top": 114.0, "width": 26.0, "height": 26.0 },
	"swap": { "left": 33.0, "top": 114.0, "width": 26.0, "height": 26.0 },
}
const POWER_IDS: Array[String] = ["reroll", "shift", "memory", "rewind", "heart", "cheat", "swap"]
const POWER_ART_LEFT := {
	"reroll": 35.0, "shift": 66.0, "memory": 97.0,
	"rewind": 35.0, "heart": 35.0, "cheat": 35.0, "swap": 35.0,
}
const SPIN_FRAME_COUNT := 4
const SPIN_FRAME_TIME := 0.055
const REROLL_REEL_DURATION := 0.55
const REEL_STOP_SFX_LEAD_TIME := 0.1
# Rewind rolls the previous spin back in: all three reels blur backwards for this
# long while the sequence lock keeps SPIN out of reach.
const REWIND_RESTORE_DURATION := 0.9
const MULTIPLIER_FRAME_COUNT := 6
# Issue #155: authored frenzy-gauge effect sheets (full-canvas x1 strips) and the
# blinking FREE SPINS TV overlay.
const MULT_FX_2_SHEET := "machine_polished/multiplier_2_effect.svg"
const MULT_FX_3_SHEET := "machine_polished/multiplier_3_effect.svg"
const MULT_FX_FIRE_SHEET := "machine_polished/multiplier_3_fire.svg"
const MULT_FX_2_FRAMES := 7
const MULT_FX_3_FRAMES := 9
const MULT_FX_FRAME_TIME := 0.09
# Water's on-use pour: an authored full-canvas sheet (3 x 160x320), played once.
# Water's pour sheet and its z_index are ConsumableFx's — it is one of that layer's
# effects, built on first use.
# Issue #155: the dealer countdown is an authored 13-frame progress bar. Frame 0
# is the empty bar at the start of the active cycle (12 steps normally, 24 for
# Club/Joker); the last frame means the dealer arrives after the current spin. The
# three small sheets are cumulative warning lights: x3 shows overlay 1, x2 shows
# 1+2, and x1 shows 1+2+3.
# Dealer's Tip (issue #132) starts every countdown DEALER_TIP_HEAD_START steps along, and
# this single native full-canvas frame recolours exactly those first steps so the head
# start is visible on the bar instead of only in the arithmetic. Shown while the augment
# is owned: each reset comes back onto the tipped value, so those steps are never unlit.
const DEALER_TIP_STEPS_SHEET := "machine_polished/dealer_tips.svg"
# The bar walks through each authored progress frame when one spin advances it
# by multiple steps; the warning itself beeps through alpha so it does not
# reveal a different countdown position before that spin's result is known.
# The warning speeds up as the dealer closes in: a lone first light beeps lazily, and from
# the second light on the cadence tightens. BEEP_TIME is the pulse itself (the lights sit at
# BEEP_MIN_ALPHA for it); the rest of the period is full alpha.
const DEALER_ICON_ASSET := "machine_polished/dealer-painted.png"
const DEALER_ICON_SIZE := Vector2(30.0, 45.0)
# The bar ends at x101; the compact portrait sits two source pixels beside it,
# fully inside the pink TV border.
const DEALER_ICON_POS := Vector2(34.0, 47.0)
const LOCK_POWER_FRAME_COUNT := 3
const POWER_FRAME_AVAILABLE := 0
const POWER_FRAME_SELECTED := 1
const POWER_FRAME_DISABLED := 2
const POWER_SHEETS := {
	# Native 480x320 pixel-grid sheets: available / selected / disabled.
	# at 1:1, no upscale.
	"reroll": "machine_polished/reroll.svg",
	"shift": "machine_polished/shift.svg",
	"memory": "machine_polished/memory.svg",
	"rewind": "machine_polished/rewind.svg",
	"heart": "machine_polished/heart.svg",
	"cheat": "machine_polished/cheat.svg",
	"swap": "machine_polished/swap.svg",
}
const REEL_SELECT_COLUMNS := 2
const REEL_SELECT_ROWS := 2
const SHIFT_POWER_COLUMNS := 3
const SHIFT_POWER_ROWS := 3
# Per-reel up/down shift-arrow hit rects (source px).
const SHIFT_ARROW_HITS := [
	{ "up": { "left": 33.0, "top": 153.0, "width": 21.0, "height": 15.0 }, "down": { "left": 33.0, "top": 204.0, "width": 21.0, "height": 15.0 } },
	{ "up": { "left": 65.0, "top": 153.0, "width": 21.0, "height": 15.0 }, "down": { "left": 65.0, "top": 204.0, "width": 21.0, "height": 15.0 } },
	{ "up": { "left": 97.0, "top": 153.0, "width": 21.0, "height": 15.0 }, "down": { "left": 97.0, "top": 204.0, "width": 21.0, "height": 15.0 } },
]

# The start menu is the default hub: a finished run and any "leave" returns here
# (issue #22). The in-run dealer is shown inline (no full-scene route), so the full
# dealer scene is only used for the pre-run shop, reached from the menu.
const MENU_SCENE := "res://scenes/start_menu_scene.tscn"
const DEALER_SCENE := "res://scenes/dealer_scene.tscn"
const PACTE_SCENE := "res://scenes/pacte_scene.tscn"
const ROUTE_SCENE := "res://scenes/dealer_choice_scene.tscn"
const IN_RUN_DEALER_OFFER_SCENE := preload("res://scenes/in_run_dealer_offer.tscn")
const OPTIONS_OVERLAY_SCENE := preload("res://scenes/options_overlay.tscn")
const TARGET_REACHED_SCENE := preload("res://scenes/target_reached_overlay.tscn")
const WEALTH_ENDING_SCENE := preload("res://scenes/wealth_ending_overlay.tscn")
const GAME_OVER_ENDING_SCENE := preload("res://scenes/game_over_ending_overlay.tscn")
const ENDING_OVERLAY_Z_INDEX := 150
const WEALTH_TARGET_FX_Z_INDEX := 140
# Flying rewards — the score bursts and the coin/lucidity FX — are the front-most thing
# the machine itself draws: above the augment row and its popup (40/41), which in turn sit
# above the cabinet art, and still under the TV blackout (TvOwnership.BLACKOUT_Z_INDEX,
# 45) so the payout screen buries them.
const REWARD_FX_Z_INDEX := 42
const WHITE_POWDER_DISTORTION_SHADER := preload("res://shaders/white_powder_distortion.gdshader")
const WEALTH_TRANSIENT_FX_GROUP := &"wealth_transient_fx"
const SETTINGS_ASSET := "ui/setting_icon.png"
const SFX_FILES := {
	&"reel_spin": "reel-spinning.mp3",
	&"reel_stop": "reel-stop.mp3",
	&"multiplier_change": "multiplier-change.mp3",
	&"pair_win": "pair-bonus.mp3",
	&"triple_win": "triple-bonus.mp3",
	&"jackpot_win": "jackpot-bonus.mp3",
}
const SFX_POLYPHONY := {
	&"reel_stop": 3,
}

# Debug-grant Shift/Memory + test consumables when a run is started standalone
# (machine opened directly, not via the shop). The shop is the real source now.
const DEBUG_GRANT := false

# Visible (non-book) symbols used for the spin-blur animation.
const VISIBLE_SYMBOLS := ["brain", "eye", "pill", "syringe", "vial", "flatline"]
const HEART_SYMBOL_ASSETS := {
	"heart_x1": "symbols/heart x1.png",
	"heart_x2": "symbols/heart x2.png",
	"heart_x3": "symbols/heart x3.png",
}

# Score-burst (score-burst presentation). Visual only.
# How long the score popup is on screen before spin aftereffects (multiplier/bar
# deltas, jackpot lamp, machine reactions) are allowed to pop (issue #54 scope).
const AFTEREFFECT_POP_DELAY := 0.4
const MULT_COLORS := {
	1: Color(0.094, 0.227, 0.549), # x1 dark blue  (#183A8C)
	2: Color(0.984, 0.749, 0.141), # x2 gold       (#fbbf24)
	3: Color(0.839, 0.157, 0.157), # x3 red        (#D62828)
}
const COCKTAIL_COLOR := Color(0.941, 0.671, 0.988) # #f0abfc
const NEON_CYAN := Color(0.42, 1.0, 0.95)
const NEON_GOLD := Color(1.0, 0.86, 0.36)
const LUCIDITY_COLOR := Color(0.92, 0.86, 0.56)
const COIN_ASSET := "ui/coin.png"
const CREDITS_COIN_SIZE := Vector2(9.0, 9.0)
# Presentation stack: machine art → loss overlays (WinCallouts, 97) → dealer
# offer (100) → dealer-interactive stash (StashTray, 110 while his offer is up
# and 50 otherwise) → HUD/options (BottomHudLayer 120).
const DEALER_OVERLAY_Z_INDEX := 100
# Augmented Run badge (issue #111): active-suit indicator, hold to peek at the
# run's restrictions.
# Left of the wealth bar, on its plate's own line: the plate's art starts at x39 and runs
# y242..278, so a 14px badge at x22 leaves a 3px gap and centres on it. The suit belongs
# beside the number the run is played for, not off in the top strip with the settings.
## The suit's own gold, on the badge and on the bubble it raises.
# Pacte augment badge: a compact blue contour around the active card icon stays
# inside the TV; it is shifted 10px right from the original left-side placement.
# Pressing it opens the current card(s) and effects.
# Held augment sockets occupy the CRT's right column beneath the multiplier.
const AUGMENT_PLATE_SHEET := "machine_polished/augments.svg"
# The sockets draw on top of the cabinet and under the badges that fill them (40).
const AUGMENT_PLATE_Z_INDEX := 39
# Canvas centers of the 40 baked marquee bulbs (scanned from the art's yellow
# clusters): 14 across the top, 14 across the bottom, 6 per side.
const TENSION_DELAY := 0.4   # extra hold on reel 3 when reels 1 & 2 match
# Issue #181: a jackpot is the biggest thing the machine does, so the money landing
# IS the reward — the wealth reels roll deliberately slowly instead of snapping, and
# the tray throws a coin spray up through the cabinet like a casino payout.
const JACKPOT_ODOMETER_ROLL_TIME := 1.60
const JACKPOT_ROLL_TAIL := 0.25 # a beat of stillness after the reels land
const COIN_TRAY := Vector2(80.0, 290.0)
const CASH_COIN_TRAY_OFFSET := Vector2(0.0, 8.0)
# The four-frame pop sheet is full-canvas and authored around the wealth-bar centre.
# The translated pop sheet hands its final frame to the flight above the CRT drums.
const WEALTH_COIN_ORIGIN := Vector2(97.0, 62.0)
# The chip's own size, asset, flight time and pop sheet are CoinFlights' — they
# describe the flight, not where it starts. The jackpot pays in the machine's own
# currency, so its spray is lucidity coins — the same coin the dealer and upgrade
# screens count credits in — not power chips.

# Power restore gauge (issue #76). The native power-bar art is a full-canvas sheet with
# six horizontal frames, gauge empty (0) -> full (5), filling bottom-up. A power coin
# flies from the wealth odometer to the bar every 10 power points and advances one frame;
# at the full frame the gauge resets and a random restorable power comes back — the
# button re-enabling is the feedback, no coin walks back out to it. Each bank coin first
# plays the authored four-frame pop sheet.
# The 6 frames span one restore threshold (coins_per_power_restore), so 5 steps = 50
# coins = 10/step.
const POWER_BAR_SHEET := "machine new view/neon_machine_power_bar.png"
const POWER_BAR_HFRAMES := 6
const POWER_BAR_VFRAMES := 1
const POWER_BAR_FRAMES := 6
const POWER_BAR_CENTER := Vector2(137.0, 84.0) # coin-to-bar landing point (gauge middle)
const POWER_COIN_STAGGER := 0.045              # 45ms between power-coin launches (quick succession)
# With no restorable power the gauge stops one frame short of full so it never fake-fills.
const POWER_BAR_MAX_BEFORE_FULL := POWER_BAR_FRAMES - 2

# The restore charge read out as a light beside the gauge (issue #181). Native
# full-canvas sheet, one frame per banked charge: frame 0 lit, frame 1 dark. With the
# light out the gauge can still bank points but never completes — it holds at 4/5 until
# the next spin puts the light back.
const RESTORE_CAP_SHEET := "machine new view/restore_cap.png"
const RESTORE_CAP_FRAMES := 2

# Augmented spade (issue #111) makes a spent charge take two spins to come back, so the
# two pips under the light are a countdown rather than a state: BOTH DARK while a charge
# is banked (a lit light has nothing to count down to), then one pip per spin waited, the
# second landing on the same spin the light returns. Anchoring them to the player's own
# spend is what makes the wait plannable instead of arbitrary.
# The light itself is authored at x142..152, y58..68 of the full canvas; the pips sit in
# the clear strip directly beneath it.
const RESTORE_SPADE_WAITING_TINT := Color(0.45, 0.62, 1.0)
const RESTORE_CYCLE_PIP_RECTS: Array[Rect2] = [
	Rect2(143.0, 71.0, 3.0, 2.0),
	Rect2(148.0, 71.0, 3.0, 2.0),
]
const RESTORE_CYCLE_PIP_ON := Color(1.0, 0.86, 0.2)
const RESTORE_CYCLE_PIP_OFF := Color(0.24, 0.26, 0.34)

# Power restored (issue #181). The coin that used to fly the gauge -> button carried the
# causality: it SHOWED the light paying for the power. Without it the light just switched
# off and the button quietly re-enabled, two unrelated-looking events. The replacement is
# simultaneity plus a shared colour: on the very frame the power lands, the light's last
# glow blows out and fades from the gauge while the chip flashes the same cyan and pulses.
# No object travels, so it costs ~0.3s instead of a full coin flight.
const RESTORE_FLASH_GLOW_TIME := 0.26   # the spent light's glow fading out of the gauge
const RESTORE_FLASH_PULSE_TIME := 0.09  # one half-pulse on the restored chip
const RESTORE_FLASH_PULSES := 2
# Blown-out cyan: >1 channels overdrive the chip's own art rather than tinting it a new
# colour, so it reads as the same power lighting up, not a different sprite.
const RESTORE_FLASH_CHIP_TINT := Color(2.2, 2.7, 2.6)
const RESTORE_FLASH_GLOW_TINT := Color(2.4, 2.8, 2.8)
const RESTORE_FLASH_NUDGE := 0.45

# Dealer-purchase payoffs that land back here (issue #132). Same overdriven-flash idiom
# as the restore feedback, so a bought chip announces itself in the machine's own voice.
const SCENE_FEEDBACK_TINT := Color(2.0, 2.4, 2.3)
const SCENE_FEEDBACK_FADE := 0.5
const SCENE_FEEDBACK_LABEL_COLOR := Color(0.42, 1.0, 0.95)

# Consumable / in-run item id -> icon (under assets/images/). Placeholder fallback.
const ITEM_ICONS := {
	"cons_focus": "items/focus_serum.png",
	"cons_cigarette": "items/cigarette.png",
	"cons_white_powder": "items/white_powder.png",
	"cons_potion": "items/consumable_placeholder.png",
	"cons_tea": "items/herbal_tea.png",
	"item_energy_drink": "items/energy_drink.png",
	"item_cocktail": "items/cocktail.png",
	"item_water": "items/water.png",
	"item_pill": "items/pill.png",
}

# Active multi-spin boosts shown as little duration icons on the TV screen (issue #76):
# each entry maps a RunStateStore spins-remaining counter to the consumable that set it,
# so the player can see WHICH boost is active and for HOW MANY more spins. Ordered by how
# it stacks top-down in the corner.
# Polarity (issue #113): "negative" marks a pure downside, "mixed" a boost whose
# benefit carries a live cost (Tobacco's hidden reel). Unmarked entries are pure
# upside — the Cocktail joined them when its pair/triple tax was dropped. The badges
# surface this as +/- corner glyphs so polarity never rides on the count colour alone.
# `phases` (issue #185) is what an item does over time, in order. An item whose effect
# changes character partway through is still ONE badge: the count is the whole effect's
# remaining spins, and the COLOUR is whichever phase is running right now — so the Red
# Pill counts 2, 1 while turning from red (the forced flatline it makes you take) to
# green (the triple it owes you), and the Energy Drink counts 3, 2, 1 while turning from
# green (protected spins) to red (the compulsory spin at the end). Without phases the
# entry is single-phase on `counter` alone.
# `title`/`desc` are what the badge says when tapped (issue #185) — the description
# describes the RUNNING effect, which is what the player tapped the icon to find out.
const DURATION_BOOSTS := [
	# The rush is the upside; the compulsory spin it queues is the bill, and the badge
	# turns red for it before it lands rather than after.
	{ "counter": "decaySkips", "id": "item_energy_drink",
		"phases": [
			{ "counter": "decaySkips" },
			{ "counter": "pendingCompulsiveSpinSkips", "negative": true },
			{ "counter": "compulsiveSpinSkips", "negative": true },
		],
		"title": "ENERGY DRINK", "desc": "SPINS COST NO HEALTH.",
		# On a joker run the drink is the compulsion alone: the same badge, but every
		# phase it can reach is the red one.
		"jokerDesc": "THE MACHINE TAKES THE NEXT SPIN." },
	{ "counter": "guaranteeSymbolSpins", "id": "cons_focus", "symbolField": "guaranteeSymbolId",
		"title": "SERUM", "desc": "THIS SYMBOL IS GUARANTEED TO APPEAR." },
	{ "counter": "blurReelsSpins", "id": "cons_focus",
		"negative": true, "suppressWhenZeroCounter": "guaranteeSymbolSpins",
		"title": "SERUM", "desc": "THE ADJACENT SYMBOLS STAY BLURRED." },
	{ "counter": "cocktailBoostSpins", "id": "item_cocktail", # rarity bonus, no cost
		"title": "COCKTAIL", "desc": "EVERY VISIBLE REEL PAYS RARITY POINTS, WIN OR MISS." },
	{ "counter": "pairBoostSpins", "id": "cons_cigarette",   # 3x pairs - hidden reel
		"title": "TOBACCO", "desc": "PAIRS PAY 3X. ONE REEL IS HIDDEN FROM SCORING." },
	{ "counter": "potionSpins", "id": "cons_potion",
		"title": "POTION", "desc": "A RANDOM EFFECT ROLLS EVERY SPIN." },
	# The Red Pill: the forced flatline is the cost, the triple after it is the payoff.
	{ "counter": "forceFlatlineSpins", "id": "item_pill",
		"phases": [
			{ "counter": "forceFlatlineSpins", "negative": true },
			{ "counter": "guaranteedTripleSpins" },
		],
		"title": "RED PILL", "desc": "A FORCED FLATLINE FIRST, THEN A GUARANTEED TRIPLE." },
	# Joker items (issue #111). They ride their own counters, so these entries are simply
	# never active on a run that is not dealing the inverted four.
	{ "counter": "cocktailMalusSpins", "id": "item_cocktail", "negative": true,
		"title": "COCKTAIL", "desc": "EVERY WIN PAYS ITS RARITY POINTS BACK." },
	{ "counter": "jokerFlatlineSpins", "id": "item_pill", "negative": true,
		"title": "RED PILL", "desc": "ONE REEL IS DRAGGED TO FLATLINE." },
]

@export_group("Run Balance")
@export var max_consumable_slots: int = Consumables.MAX_CONSUMABLE_SLOTS
@export var coins_per_power_restore: int = EconomyConst.LUCIDITY_COINS_PER_RESTORE
@export var default_run_power_ids: Array[String] = []

@export_group("Feedback")
## Grow-then-fade duration of the on-use +/- hint (issue #33). The animated
## HintLabel owns the +/- and corrupt colours; this only drives its lifetime.
@export_range(0.0, 5.0, 0.1) var hint_grow_time: float = 1.5
## Per-item +/- hint vocabulary shown when a stash item is used in-run. Mirrors
## the dealer scenes' pools (issue #31) so the same item reads the same way.
# Precise, unambiguous copy (issue #76): each line says exactly what happens, and the
# positive/negative are shown at DIFFERENT times — the upside on use, the downside when
# it activates — so they never blur together. Flavor items (Water/Cocktail/Tea/Potion)
# have no real downside, so their negative is empty and only the upside shows.
@export var use_hints: Dictionary = {
	"cons_cigarette": { "pos": "3X PAIRS", "neg": "1 REEL HIDDEN" },
	"cons_white_powder": { "pos": "COPY A REEL", "neg": "RESULT HIDDEN" },
	"cons_focus": { "pos": "SYMBOL GUARANTEED", "neg": "ADJACENTS HIDDEN" },
	"cons_potion": { "pos": "POWERS RESTORED", "neg": "" },
	"cons_tea": { "pos": "RESTORE POWER", "neg": "" },
	"item_water": { "pos": "+40 SCORE & LUCIDITY", "neg": "" },
	"item_pill": { "pos": "WIN GUARANTEED", "neg": "CLOSE CALL" },
	"item_energy_drink": { "pos": "2 FREE SPINS", "neg": "" },
	"item_cocktail": { "pos": "RARITY BONUS", "neg": "" },
}

## What the same four items say on a joker Augmented run (issue #111), where they are
## dealt in their turned-against-you form. Each is pure downside, so the positive line is
## empty and only the red one shows — the mirror of the flavour items above, whose
## negative is the empty one.
@export var joker_use_hints: Dictionary = {
	"item_water": { "pos": "", "neg": "POWER BAR DRAINED" },
	"item_pill": { "pos": "", "neg": "A REEL FLATLINES" },
	"item_energy_drink": { "pos": "", "neg": "FORCED SPIN" },
	"item_cocktail": { "pos": "", "neg": "WINS PAY RARITY BACK" },
}

## Items whose downside only bites later (issue #76): the use popup shows just the
## upside, and the negative is popped separately when it actually activates — more
## dramatic and clearer than front-loading a warning for something not happening yet.
const DEFERRED_NEGATIVE_ITEMS := [
	"item_energy_drink", "cons_focus", "cons_white_powder", "cons_cigarette",
]

## Of the deferred items, these pop their negative via an explicit hook when it fires
## (Energy Drink at the takeover; Serum/White Powder/Tobacco on the affected spin). Red
## Pill is intentionally absent: its forced flatline already surfaces "CLOSE CALL"
## through the flatline-strike reaction, so a second popup would just double it.
const HOOKED_DEFERRED_NEGATIVES := [
	"item_energy_drink", "cons_focus", "cons_white_powder", "cons_cigarette",
]

## item_id -> true while a hooked item's negative is armed but hasn't fired yet.
var _pending_deferred_neg: Dictionary = {}

@export_group("Sound")
@export var sfx_enabled: bool = true
@export_range(0.0, 1.0, 0.05) var sfx_volume: float = 0.8

# ── machine reactions (issue #35) ────────────────────────────────────────────────
# The GDD "flatline result" is a REEL outcome (3 flatline symbols); the pinned
# "flatline" ENDING (neurons <= 0) keeps its serialized name for parity — only this
# new reel event is called flatline_result. A run ends on neurons <= 0 or on
# fatal_flatline_count flatline results; there is no spin-count cap — you never die
# just for spinning a lot, so vials genuinely extend the run (issue #75).
@export_group("Machine Reactions")
@export var fatal_flatline_count: int = 3
@export_range(0.1, 3.0, 0.1) var reaction_flash_time: float = 0.7
## How long the fatal FLATLINE reaction plays before the ending screen replaces it. Covers
## the whole line-sweep tween (reaction_flash_time x 1.1) plus a moment to read the 3/3.
@export_range(0.0, 4.0, 0.1) var fatal_flatline_reaction_delay: float = 1.3
@export var flatline_result_color: Color = Color(0.93, 0.27, 0.27)
@export_group("Triple Overlays", "triple_")
@export var triple_brain_color: Color = Color(1.0, 0.84, 0.0)    # gold
@export var triple_eye_color: Color = Color(0.66, 0.33, 0.86)    # purple
@export var triple_pill_color: Color = Color(1.0, 0.55, 0.75)    # pink
@export var triple_syringe_color: Color = Color(1.0, 0.9, 0.2)   # yellow
@export var triple_vial_color: Color = Color(0.95, 0.25, 0.25)   # red
@export var triple_brain_free_spins: int = 1
@export var triple_vial_free_spins: int = 3

func _flatline_restriction_limit() -> int:
	return 2147483647 if RunStateStore.flatlineRestrictionRemoved else fatal_flatline_count

func _flatline_restriction_limit_text() -> String:
	return "INF" if RunStateStore.flatlineRestrictionRemoved else str(fatal_flatline_count)

# ── consumable visuals (issue #34) ───────────────────────────────────────────────
# Per-item temporary on-machine effects. All presentation-only: they read store
# state (never write it) and revert when the driving counter hits 0. Effects that
# need authored art (pill heartbeat SFX, serum sniper, white-powder hallucination,
# tea sakura) are NOT here — they wait on assets. 🎨
@export_group("Consumable Visuals")
@export var consumable_fx_enabled: bool = true
@export_subgroup("Close Call", "close_call_")
## Non-fatal flatline strikes briefly zoom the machine like a heartbeat.
@export var close_call_fx_enabled: bool = true
@export_range(1.0, 1.2, 0.005) var close_call_zoom_scale: float = 1.055
@export_range(0.1, 1.0, 0.05) var close_call_zoom_time: float = 0.38
@export_subgroup("Tobacco", "tobacco_")
## Smoke + FULLY opaque cover on the reel(s) hidden from scoring (the last
## pairBoostHiddenReels reels — mirrors evaluate.gd's slice) while Tobacco runs.
## Issue #53: the hidden reel can't be seen at all.
@export var tobacco_fx_enabled: bool = true
@export var tobacco_smoke_color: Color = Color(0.78, 0.78, 0.82, 0.5)
@export var tobacco_cover_color: Color = Color(0.05, 0.04, 0.07, 1.0)
@export_subgroup("Cocktail", "cocktail_")
## Whole-machine decaying shake on use (same position:x wobble as _nudge).
@export var cocktail_fx_enabled: bool = true
@export_range(0.2, 3.0, 0.1) var cocktail_shake_time: float = 0.9
@export_range(0.5, 8.0, 0.5) var cocktail_shake_strength: float = 2.5
@export_subgroup("Energy Drink", "energy_")
## Pulsing burning edges + the spins bar/count fade out while decay is skipped,
## restored the moment the effect ends.
@export var energy_fx_enabled: bool = true
@export var energy_edge_color: Color = Color(1.0, 0.45, 0.1, 0.75)
@export_range(1.0, 8.0, 0.5) var energy_edge_thickness: float = 3.0
@export_range(0.2, 3.0, 0.1) var energy_pulse_time: float = 0.9
@export_range(0.1, 2.0, 0.1) var energy_fade_time: float = 0.45
@export_subgroup("Potion", "potion_")
## While Potion runs the machine hops on every spin and announces the rolled
## random-pool effect (read from RunStateStore.lastPotionEffect).
@export var potion_fx_enabled: bool = true
@export_range(1.0, 12.0, 0.5) var potion_jump_height: float = 4.0
@export_range(0.4, 4.0, 0.1) var potion_popup_time: float = 1.4
@export var potion_popup_color: Color = Color(0.72, 1.0, 0.65)
@export var potion_popup_negative_color: Color = Color(0.94, 0.27, 0.27)
@export_subgroup("Water", "water_")
## Water used to land as a bare number with nothing behind it. It now plays the authored
## three-frame sheet over the machine (issue #185) — a short pour, not a loop: the item
## is instantaneous, so the feedback ends with it rather than lingering as a duration.
@export var water_fx_enabled: bool = true
@export_range(0.04, 0.5, 0.01) var water_frame_time: float = 0.11
@export_subgroup("Tea", "tea_")
## Sakura-petal tranquility layer when Tea is used: a light cross-screen wind.
@export var tea_fx_enabled: bool = true
@export_range(0.5, 4.0, 0.1) var tea_petal_time: float = 2.7
@export_range(4, 64, 1) var tea_petal_count: int = 12
@export var tea_petal_color: Color = Color(1.0, 0.62, 0.82, 0.82)
@export_subgroup("White Powder", "white_powder_")
## Copying a symbol ripples the screen, then cleanly fades out.
@export var white_powder_fx_enabled: bool = true
@export_range(0.1, 2.0, 0.05) var white_powder_distortion_time: float = 0.55
@export_range(0.0, 1.0, 0.01) var white_powder_distortion_strength: float = 0.65
@export_subgroup("Hidden Result", "hidden_")
## White Powder: the spin consumed by hideResultSpins reveals "?" covers instead
## of readable reels, until the next spin re-rolls the machine.
@export var hidden_fx_enabled: bool = true
@export var hidden_cover_color: Color = Color(0.04, 0.03, 0.06, 0.94)
@export var hidden_glyph_color: Color = Color(0.85, 0.8, 1.0)
@export_subgroup("Serum", "serum_")
## Serum (issue #53): frost layer over the reels for the spin after the guarantee —
## symbols stay readable, just harder.
@export var blur_cover_color: Color = Color(0.82, 0.86, 0.95, 0.55)
@export_subgroup("Compulsive", "compulsive_")
## Energy Drink: the machine spins by itself once the no-decay rush ends — heavy
## vibration + red overlay while it takes over.
@export var compulsive_fx_enabled: bool = true
@export var compulsive_overlay_color: Color = Color(0.85, 0.08, 0.08, 0.28)
@export_range(1.0, 12.0, 0.5) var compulsive_shake_strength: float = 5.0
@export_range(0.2, 3.0, 0.1) var compulsive_shake_time: float = 1.2

# ── campaign rebalance (issue #38) ───────────────────────────────────────────────
@export_group("Campaign")
## Score that triggers the wealth ending — the campaign goal. Defaults to the
## parity-locked constant; the pinned vectors always use the default.
@export var campaign_goal_score: int = EconomyConst.WEALTH_SCORE_THRESHOLD
## Game-over flatline copy — byte-for-byte from the GDD.
@export var fatal_flatline_text: String = "this time, it's fatal. No coming back"

var _reel_backing_sprite: Sprite2D = null # the shared reel art all three covers copy
var _swap_shake_cover_state: Array[bool] = [] # cover visibility to restore after a shake
var _overlay: Control = null
var _dealer_overlay: Control = null
var _dealer_offer_popup: Control = null
var _dealer_message_label: Label = null
var _dealer_portrait_sprite: Sprite2D = null
# Tap-an-item-badge description (issue #185). Lifetime is a plain countdown stepped from
# _process rather than a tween, so the tween sweeps that clear the run's transient
# effects can never strand it on screen.
var _options_button: TextureButton = null
var _options_overlay: OptionsOverlay = null
var _score_button: Button = null
var _spin_button: Button = null
var _multiplier_sprite: Sprite2D = null
# Issue #155: authored frenzy-gauge effect sheets (x1 full-canvas strips) looping
# over the badge strip while the gauge holds x2/x3, plus the blinking FREE SPINS
# TV overlay shown while free spins are banked.
var _mult_fx_2: Sprite2D = null
var _mult_fx_3: Sprite2D = null
var _mult_fx_fire: Sprite2D = null
var _mult_fx_time := 0.0
var _dealer_tip_steps: Sprite2D = null # Dealer's Tip head start, drawn on the bar's first steps
var _dealer_icon: MachineDealerPortrait = null
var _gauge_shown := 0 # last displayed gauge value (0 = not shown yet; gates the rise sfx)
var _wealth_target_transition: TargetReachedOverlay = null
var _wealth_target_transition_active := false
## Set once CONTINUE on the target screen starts the hand-off to the between-run flow: the
## machine is on its way out, so nothing new may take the screen here.
var _target_round_handoff := false
var _unlock_popup: UnlockCardPopup = null
var _health_bar_sprite: Sprite2D = null  # spins-left tube: frame = spins remaining
var _reserve_glow_sprite: Sprite2D = null # armed Emergency Reserve, glowing on the last chip
var _reserve_glow_tween: Tween = null
var _spins_left_label: Label = null # numeric spins-left readout under the tube
## The mini-reel's authored sheet, as a view onto CheatMiniReel — the smoke checks
## reach it under this name.
var _cheat_selection_sprite: Sprite2D:
	get: return _cheat.selection_sprite() if _cheat != null else null

## First component split out of this file (see scenes/machine/augment_display.gd).
## It reaches back through a MachineView rather than through this node, so what it
## can touch here is a written-down list instead of all ~210 remaining fields.
var _view: MachineView = null
var _augments: AugmentDisplay = null
var _callouts: WinCallouts = null
var _flatline: FlatlineScreen = null
var _bursts: ScoreBursts = null
var _score_table: ScoreTable = null
var _wealth: WealthReadout = null
var _dealer_bar: DealerBar = null
var _boosts: BoostIndicators = null
var _coins: CoinFlights = null
var _reel_blur: ReelBlur = null
var _reel_symbols: ReelSymbols = null
var _power_callout: PowerCallout = null
var _swap_overlay: SwapTargetOverlay = null
var _swap_shake: SwapShake = null
var _targeting: TargetingLayer = null
var _cheat: CheatMiniReel = null
var _consumable_fx: ConsumableFx = null
var _choices: ChoiceOverlays = null
var _reactions: ReactionFlash = null
var _hints: HintPopups = null
var _stash: StashTray = null
var _tv: TvOwnership = null

## The TV's state moved into TvOwnership, but these three names are the contract the
## smoke checks read it through — kept as views onto the component rather than
## rewritten across three check files, because the checks are what pin the priority
## rules and churning them alongside the code they guard proves less.
var _tv_info_pop_sources: Dictionary:
	get: return _tv.sources() if _tv != null else {}
var _free_spin_overlay_active: bool:
	get: return _tv != null and _tv.banner_active()
var _free_spin_sprite: Sprite2D:
	get: return _tv.banner_sprite() if _tv != null else null
var _tv_blackout_rect: ColorRect:
	get: return _tv.blackout_rect() if _tv != null else null

var _power_buttons := {}      # id -> Button
var _power_sprites := {}      # id -> Sprite2D
var _lock_sprites: Array = []
var _lock_count_labels: Array[Label] = []
var _spin_sheet_sprite: Sprite2D = null
## The armed picker layer, as a view onto TargetingLayer — the smoke checks and the
## lock debug shot reach the node under this name.
var _targeting_layer: Control:
	get: return _targeting.node() if _targeting != null else null
var _targeting_power_id := ""
var _copy_source := -1               # white-powder copy: chosen source reel (-1 = none)
var _cheat_reel := -1
var _swap_source := -1
var _swap_drag_active := false
var _swap_dragging := false
var _swap_drag_button: Button = null
var _swap_drag_ghost: Sprite2D = null
var _swap_drag_press := Vector2.ZERO
var _swap_drag_offset := Vector2.ZERO
var _swap_source_slot := 1 # 0 = above, 1 = centre, 2 = below
var _swap_source_symbol := ""
var _rubble_overlay: ColorRect = null
var _dealer_drag_active := false
var _dealer_drag_node: Control = null
var _dealer_drag_id := ""
var _dealer_drag_kind := ""
var _dealer_drag_home := Vector2.ZERO
var _dealer_drag_moved := false
var _dealer_drag_press := Vector2.ZERO
# Freezes HUD delta visuals (multiplier badge, TV bars, jackpot lamp) between a
# spin/power commit and its score popup, so aftereffects never pop before the
# score does (issue #54 scope).
var _hud_delta_hold := false
var _coin_prev_lucidity := 0 # retained as a consumable-gain marker; no coin flight uses it
var _power_bar_sprite: Sprite2D = null
var _restore_cap_sprite: Sprite2D = null # per-spin restore budget lights beside the gauge
var _restore_cap_glow: Sprite2D = null   # the lit frame, flashed and faded when a charge is spent
var _restore_cycle_pips: Array[ColorRect] = [] # spade only: which half of the restore cycle is next
var _restore_flash_tweens: Array[Tween] = []
var _restore_flash_chip: Sprite2D = null # chip currently pulsing, so it can be reset
var _power_bar_frame := 0    # current gauge frame (0 empty .. POWER_BAR_FRAMES-1 full)
var _power_bar_score := 0        # score banked toward the next restore (0 .. coins_per_power_restore)
var _power_seen_lucidity := 0    # legacy name: total power points the gauge has accounted for
var _power_coins_in_flight := 0   # bank + restore coins currently animating
var _power_batch_running := false # a batch of bank coins is being launched/processed
var _pending_dealer_offer := false # a dealer offer is queued behind the power-coin sequence
var _nudge_tween: Tween = null       # quick machine shake on lucidity/jackpot
var _font: FontFile = null
var _tex_cache := {}
var _sequence_lock_active := false
var _post_spin_sequence_active := false
var _pending_combo_overlay: Control = null
var _pending_combo_power_flow := false
var _sfx_players: Dictionary = {}
var _spin_launch_pending := false

# Reveal animation state
var _spinning_anim := false
var _anim_elapsed := 0.0
var _blur_accum := 0.0
var _spin_frame := 0
var _final_reels: Array = []
var _locked_reels_during_spin := [false, false, false]
var _use_full_spin_sheet := true
var _reel_stop_times := [0.55, 1, 1.4]
var _reel_stop_sfx_played := [false, false, false]
var _reroll_anim_active := false
var _reroll_reel_index := -1
var _reroll_elapsed := 0.0
var _reroll_accum := 0.0
var _rewind_anim_active := false
var _rewind_elapsed := 0.0
var _rewind_accum := 0.0
var _spin_label: Label = null
var _credits_row: HBoxContainer = null
var _credits_label: Label = null
var _credits_coin: TextureRect = null
var _machine_scene_lucidity_before := 0
var _machine_scene_score_before := 0
var _machine_scene_lucidity_snapshot_ready := false
## Guards the CONTINUE/TRY AGAIN routing against a second press while the first
## is still awaiting its animation. Flow, not presentation, so it stays here.
var _flatline_transition_active: bool = false
var _neuron_spend_label: Label = null
## Transient on-use +/- HintLabels (issue #33), as a view onto HintPopups — the
## smoke checks read the layer under this name.
var _hint_layer: Control:
	get: return _hints.layer() if _hints != null else null
# Machine reactions (issue #35): dedupe key so one reel configuration reacts once,
# and a pending eye-triple reveal for the next spin.
var _last_reacted_reels: Array = []
var _last_reacted_spin := -1
var _reveal_reel_next_spin := -1
# Spin-gain fly-ins in flight (issue #66): the spins-left counter is held back by
# this amount until each "+N" popup lands, so the number ticks up in sync.
var _pending_spin_gain := 0
# Consumable visuals (issue #34). The effects themselves are ConsumableFx's; these
# two shake and jump the machine NODE, which is not on that layer.
var _cocktail_shake_tween: Tween = null
var _potion_jump_tween: Tween = null

## Views onto ConsumableFx, under the names the smoke checks read the effects by.
var _fx_layer: Control:
	get: return _consumable_fx.layer() if _consumable_fx != null else null
var _tobacco_covers: Array:
	get: return _consumable_fx.tobacco_covers() if _consumable_fx != null else []
var _tobacco_smoke: Array:
	get: return _consumable_fx.tobacco_smoke() if _consumable_fx != null else []
var _hidden_covers: Array:
	get: return _consumable_fx.hidden_covers() if _consumable_fx != null else []
var _energy_edges: Control:
	get: return _consumable_fx.energy_edges() if _consumable_fx != null else null
var _water_fx_sprite: Sprite2D:
	get: return _consumable_fx.water_sprite() if _consumable_fx != null else null

func _hide_water_animation() -> void:
	_consumable_fx.hide_water()
var _close_call_heartbeat_tween: Tween = null
var _hide_result_active := false           # the displayed result is hidden
## Views onto ChoiceOverlays, under the names the smoke checks read them by.
var _serum_picker: Control:
	get: return _choices.serum_node() if _choices != null else null
var _book_choice_overlay: Control:
	get: return _choices.book_node() if _choices != null else null
var _compulsive_queued := false            # energy-drink auto-spin pending
var _compulsive_overlay: ColorRect = null  # red overlay during the compulsive spin

func _ready() -> void:
	_font = _load_font("font/DTM-Sans.otf")
	# Before any build step: _build_augment_emplacements hands the plate straight to
	# the display, and that runs inside the sprite pass below.
	_view = MachineView.new(self)
	_augments = AugmentDisplay.new(_view)
	_callouts = WinCallouts.new(_view)
	_flatline = FlatlineScreen.new(_view)
	_bursts = ScoreBursts.new(_view, REEL_CELL_CENTERS, REEL_WINDOW["top"], SRC_W)
	_score_table = ScoreTable.new(_view, _triple_effect_text, _info_line_segments)
	_wealth = WealthReadout.new(_view)
	_dealer_bar = DealerBar.new(_view)
	_boosts = BoostIndicators.new(_view, DURATION_BOOSTS, TV_SCREEN,
		_icon_for, _item_info_popup_text)
	_coins = CoinFlights.new(_view, MACHINE_ART_TEXTURE_FILTER)
	_reel_blur = ReelBlur.new(_view, REEL_HOLES, SPIN_FRAME_COUNT)
	_reel_symbols = ReelSymbols.new(_view, REEL_CELL_CENTERS, REEL_WINDOW,
		HEART_SYMBOL_ASSETS, MACHINE_ART_TEXTURE_FILTER)
	_power_callout = PowerCallout.new(_view, SRC_W)
	_swap_overlay = SwapTargetOverlay.new(_view, REEL_HOLES, REEL_WINDOW)
	_swap_shake = SwapShake.new(_view)
	_targeting = TargetingLayer.new(_view, Vector2(SRC_W, SRC_H))
	_cheat = CheatMiniReel.new(_view, _reel_symbols, MACHINE_ART_TEXTURE_FILTER,
		_make_hit_button, _on_cheat_symbol_pick)
	_consumable_fx = ConsumableFx.new(_view, REEL_HOLES, Vector2(SRC_W, SRC_H),
		WHITE_POWDER_DISTORTION_SHADER)
	_choices = ChoiceOverlays.new(_view, Vector2(SRC_W, SRC_H), REEL_CELL_CENTERS,
		REEL_WINDOW)
	_reactions = ReactionFlash.new(_view, Vector2(SRC_W, SRC_H),
		WEALTH_TRANSIENT_FX_GROUP)
	_hints = HintPopups.new(_view, MACHINE_HINT_CENTER)
	_stash = StashTray.new(_view, _on_stash_input)
	# Last in the block: it arbitrates over the components above it, so they have to
	# exist first. An arbiter's contenders are its constructor arguments.
	_tv = TvOwnership.new(_view, TV_SCREEN, WEALTH_TRANSIENT_FX_GROUP,
		_augments, _dealer_bar, _boosts,
		_refresh_dealer_countdown, _refresh_target_readout, _spin_in_flight)
	_apply_balance_exports()
	# Draw order (back -> front): casino backdrop -> reel background -> symbols
	# -> cabinet (with transparent holes that mask symbol overflow) -> HUD ->
	# spin button. The authored node order in the .tscn is what fixes this — these
	# sprites all share z_index 0, so the scene tree IS the layer stack.
	_build_neon_background()
	_reel_backing_sprite = _build_full_canvas_sprite(
		"machine_polished/reel_drums.svg")
	_reel_blur.build_spin_strips("machine_polished/reel_motion.svg")
	_reel_blur.build_covers("machine_polished/reel_drums.svg")
	_reel_symbols.build()
	var cabinet := _build_full_canvas_sprite("machine_polished/cabinet-painted.png")
	cabinet.material = preload("res://assets/shaders/painted_cabinet.tres")
	_build_full_canvas_sprite("machine_polished/reel_housing.svg")
	_build_tv_indicators()
	_build_machine_control_art()
	_build_hud()
	_build_spin_button()
	_build_power_buttons()
	_stash.build(max_consumable_slots)
	_build_sfx_players()
	_build_fx_layer() # before the burst/coin layers so rewards draw above effects
	_bursts.build_layer(REWARD_FX_Z_INDEX)
	_coins.build_layer(REWARD_FX_Z_INDEX)
	_build_options_controls()
	_augments.build_augmented_badge()
	_restore_options_overlay_if_requested()
	_play_pending_scene_feedback()
	RunStateStore.state_changed.connect(_update_hud)
	_enter_run()
	_augments.build_pacte_badges()
	_finish_machine_materials(self)
	_init_burst_tracking()
	# A card unlocked during the run interrupts play until it is acknowledged
	# (issue #52); the popup blocks the machine behind its dimmed background. It
	# waits for a quiet moment first — see _can_present_card_unlock.
	_unlock_popup = UnlockCardPopup.attach_to(self, _can_present_card_unlock)
	# Inert unless the played tutorial is running (issue #105). The autoload is not a
	# @tool script, so it does not exist in an editor preview of this scene.
	if not Engine.is_editor_hint():
		Tutorial.attach(self, "machine")

## Whether a control the tutorial wants to point at is really on screen yet (issue #105).
## The dealer's offer hides the machine's own stash while he is in and it slides out over a
## few frames after an item is taken, so the beat that says "tap the powder" would otherwise
## open pointing at a stash that is not drawn.
func tutorial_ready_for(id: String) -> bool:
	match id:
		"stash":
			if _dealer_offer_popup != null:
				return false
			if _stash.icons().is_empty():
				return false
			var icon: Control = _stash.icons()[0] as Control
			return icon != null and is_instance_valid(icon) and icon.visible
	return true

## A descendant's position in this scene's own space, whatever it is nested under. The
## tutorial overlay is a child of this scene, so this is the space its rects live in — and
## an authored control can sit several nodes deep, where its own position means nothing on
## its own. Subtracting this scene's origin also keeps the answer right mid-shake, since the
## machine tweens its own position for the compulsive/cocktail wobbles.
func _canvas_position_of(node: Control) -> Vector2:
	return node.global_position - global_position

## True while something the tutorial does not script owns the screen (issue #105) — here,
## a card unlocked mid-run, which takes the whole machine until it is acknowledged. See
## dealer_scene.tutorial_blocking_modal.
func tutorial_blocking_modal() -> bool:
	return _unlock_popup != null and is_instance_valid(_unlock_popup) and _unlock_popup.visible

## The controls the tutorial rings and hands through (issue #105). Only this scene knows
## where its own things are, so the director asks rather than reaching in. An id it does
## not know answers with an empty rect, which the overlay reads as "mask everything".
func tutorial_anchor(id: String) -> Rect2:
	match id:
		"spin_button":
			return Rect2(SPIN_HIT["left"], SPIN_HIT["top"],
				SPIN_HIT["width"], SPIN_HIT["height"])
		"health":
			# The highlight encloses the independent cartridge and both steel end caps.
			return Rect2(2.0, 43.0, 18.0, 78.0)
		"wealth":
			return Rect2(72.0, 59.0, 50.0, 18.0)
		"target_bar":
			return Rect2(72.0, 47.0, 50.0, 12.0)
		"dealer_countdown":
			return Rect2(34.0, 47.0, 36.0, 51.0)
		"reels":
			return Rect2(REEL_HOLES[0]["left"], REEL_WINDOW["top"],
				REEL_HOLES[2]["left"] + REEL_HOLES[2]["width"] - REEL_HOLES[0]["left"],
				REEL_WINDOW["height"])
		"stash":
			# The LIVE slot node, not the shared computed layout: this scene's stash slots
			# are authored in the .tscn, so Assets.stash_slot_pos describes where they would
			# have gone rather than where they are — which put the ring in the middle of the
			# stash instead of on the first slot the beat asks the player to tap.
			if not _stash.icons().is_empty():
				var icon: Control = _stash.icons()[0] as Control
				if icon != null and is_instance_valid(icon):
					return Rect2(_canvas_position_of(icon), icon.size).grow(1.0)
			var slot := Assets.stash_slot_pos(0, max_consumable_slots)
			return Rect2(slot - Vector2.ONE,
				Vector2.ONE * (Assets.STASH_ICON_SIZE + 2.0))
		"dealer_offer", "screen":
			# Whatever has taken the whole canvas — the dealer walking in, the payout
			# receipt, the flatline screen. Nothing is masked and nothing is ringed: the
			# screen IS the subject, and its own buttons carry on with the game.
			return Rect2(0.0, 0.0, SRC_W, SRC_H)
	return Rect2()

func _apply_balance_exports() -> void:
	if Engine.is_editor_hint():
		return
	RunStateStore.max_consumable_slots = maxi(1, max_consumable_slots)
	RunStateStore.coins_per_power_restore = maxi(1, coins_per_power_restore)

# Asset loading.

func _load_texture(rel: String, mipmaps := false) -> Texture2D:
	return Assets.texture(rel, mipmaps)

func _load_font(rel: String) -> FontFile:
	return Assets.font(rel)

func _load_sfx(rel: String) -> AudioStream:
	return load("res://assets/sound/%s" % rel) as AudioStream

func _sfx_volume_db() -> float:
	return -80.0 if sfx_volume <= 0.0 else linear_to_db(clampf(sfx_volume, 0.0, 1.0))

func _build_sfx_players() -> void:
	for id: StringName in SFX_FILES:
		var stream := _load_sfx(String(SFX_FILES[id]))
		if stream == null:
			push_warning("Missing SFX: %s" % String(SFX_FILES[id]))
			continue
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%s" % String(id).capitalize().replace("_", "")
		player.stream = stream
		player.max_polyphony = int(SFX_POLYPHONY.get(id, 1))
		player.volume_db = _sfx_volume_db()
		add_child(player)
		_sfx_players[id] = player

func _play_sfx(id: StringName) -> void:
	if not sfx_enabled:
		return
	var player := _sfx_players.get(id, null) as AudioStreamPlayer
	if player == null:
		return
	player.volume_db = _sfx_volume_db()
	if player.max_polyphony <= 1:
		player.stop()
	player.play()

func _stop_sfx(id: StringName) -> void:
	var player := _sfx_players.get(id, null) as AudioStreamPlayer
	if player != null:
		player.stop()

# ── scene construction ────────────────────────────────────────────────────────────

func _authored_sprite(name: String) -> Sprite2D:
	return get_node_or_null(name) as Sprite2D

func _authored_button(name: String) -> Button:
	return get_node_or_null(name) as Button

func _authored_texture_button(name: String) -> TextureButton:
	return get_node_or_null(name) as TextureButton

func _authored_control(name: String) -> Control:
	return get_node_or_null(name) as Control

func _full_canvas_name(rel: String) -> String:
	if rel == "machine_polished/cabinet-painted.png":
		return "Cabinet"
	if rel.ends_with("reel_drums.svg"):
		return "ReelBacking"
	if rel.ends_with("reel_housing.svg"):
		return "ReelHousing"
	if rel.ends_with("final_machine.png") or rel.ends_with("neon_machine.png") \
			or rel.ends_with("machine_neon.png"):
		return "Cabinet"
	return ""

func _full_canvas_sheet_name(rel: String, frame: int) -> String:
	if rel == "machine_polished/reroll.svg":
		return "RerollPower"
	if rel == "machine_polished/shift.svg":
		return "ShiftPower"
	if rel == "machine_polished/memory.svg":
		return "MemoryPower"
	if rel == HEALTH_BAR_SHEET:
		return "HealthBar"
	if rel.ends_with("multiplier.svg"):
		return "Multiplier"
	if rel.ends_with("jackpot_final_machine.png") or rel.ends_with("neon_machine_jackpot.png"):
		return "Jackpot"
	if rel.ends_with("lock_power.png"):
		return "LockPower%d" % frame
	if rel.ends_with("reroll.png") or rel.ends_with("reroll_final_machine.png"):
		return "RerollPower"
	if rel.ends_with("shift.png") or rel.ends_with("shift_final_machine.png"):
		return "ShiftPower"
	if rel.ends_with("lock.png") or rel.ends_with("lock_final_machine.png"):
		return "MemoryPower"
	if rel.get_basename().ends_with("free_spin"):
		return "FreeSpinOverlay"
	if rel.ends_with("win_animation.png"):
		return "WinCallout"
	if rel.ends_with("power_animation.png"):
		return "PowerCallout"
	if rel.ends_with("cheat_selection.png"):
		return "CheatSelection"
	if rel.ends_with("loss_2.svg"):
		return "ComboLoss2"
	if rel.ends_with("loss_3.svg"):
		return "ComboLoss3"
	if rel.get_basename().ends_with("dealer_bar"):
		return "DealerBar"
	if rel.get_basename().ends_with("dealer_bar_overlay_1"):
		return "DealerBarOverlay1"
	if rel.get_basename().ends_with("dealer_bar_overlay_2"):
		return "DealerBarOverlay2"
	if rel.get_basename().ends_with("dealer_bar_overlay_3"):
		return "DealerBarOverlay3"
	return ""

## Which authored node a region crop belongs to. Matched with a small tolerance rather than
## exactly: the reel covers crop a little wider than the hole to take in the whole authored
## patch, and an exact match would miss the scene node and build a loose sprite on top of
## everything instead of slotting in under the symbols.
func _region_sprite_name(rel: String, rect: Dictionary) -> String:
	if rel.ends_with("reel_drums.svg"):
		for i in REEL_HOLES.size():
			if absf(float(rect["left"]) - float(REEL_HOLES[i]["left"])) <= 2.0 \
					and absf(float(rect["top"]) - float(REEL_HOLES[i]["top"])) <= 4.0:
				return "ReelCover%d" % i
	return ""

## A full-canvas sprite covers the whole 160x320 canvas, so its scale is entirely decided by
## how the sheet was exported. That is read from the texture EVERY time, including for
## authored nodes: the scene's 0.125 was written for the old x8 reel sheet and would draw a
## native export at an eighth of its size. NEAREST throughout, so an integer factor stays
## pixel-exact.
func _configure_full_canvas_sprite(spr: Sprite2D, tex: Texture2D, apply_transform := true) -> void:
	spr.texture = tex
	spr.centered = false
	if apply_transform:
		spr.position = Vector2.ZERO
	spr.scale = Vector2(SRC_W / float(tex.get_width()), SRC_H / float(tex.get_height()))
	spr.texture_filter = MACHINE_ART_TEXTURE_FILTER

func _configure_full_canvas_sheet(spr: Sprite2D, tex: Texture2D, hframes: int, frame: int, apply_transform := true) -> void:
	spr.texture = tex
	spr.hframes = hframes
	spr.frame = frame
	spr.centered = false
	var frame_w := float(tex.get_width()) / float(hframes)
	if apply_transform:
		spr.position = Vector2.ZERO
		spr.scale = Vector2(SRC_W / frame_w, SRC_H / float(tex.get_height()))
	spr.texture_filter = MACHINE_ART_TEXTURE_FILTER

# Gaussian blur for the backdrop (5x5 taps spread by blur_size source px): the
# hall reads as out-of-focus scenery so the cabinet pops in front of it.
const NEON_BG_BLUR_SHADER := "
shader_type canvas_item;
uniform float blur_size : hint_range(0.0, 16.0) = 6.0;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur_size;
	vec4 sum = vec4(0.0);
	float wsum = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) / 4.0);
			sum += texture(TEXTURE, UV + vec2(float(x), float(y)) * px) * w;
			wsum += w;
		}
	}
	COLOR = (sum / wsum) * vec4(0.46, 0.43, 0.50, 1.0);
}"

## The shared neon casino backdrop fills the canvas behind the cabinet (blurred,
## so the machine sits in focus inside the same hall as the start menu).
func _build_neon_background() -> void:
	var tex := _load_texture("start_menu/neon_casino_background.png", true)
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.name = "NeonBackground"
	spr.texture = tex
	spr.centered = false
	spr.position = Vector2.ZERO
	spr.scale = Vector2(SRC_W / tex.get_width(), SRC_H / tex.get_height())
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var shader := Shader.new()
	shader.code = NEON_BG_BLUR_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	spr.material = mat
	add_child(spr)
	# The cabinet sprites are authored scene children, so a code-added node lands
	# after (= above) them; force the backdrop to the very back of the tree.
	move_child(spr, 0)

func _build_full_canvas_sprite(rel: String) -> Sprite2D:
	var tex := _load_texture(rel, true)
	if tex == null:
		# Only the cabinet gets a visible fallback so the scene isn't blank.
		if rel.ends_with("/final_machine.png") or rel.ends_with("/neon_machine.png") \
				or rel.ends_with("/machine_neon.png"):
			var fallback := ColorRect.new()
			fallback.color = Color(0.06, 0.05, 0.08)
			fallback.size = Vector2(SRC_W, SRC_H)
			add_child(fallback)
		return null
	var name := _full_canvas_name(rel)
	var spr := _authored_sprite(name) if name != "" else null
	var authored := spr != null
	if spr == null:
		spr = Sprite2D.new()
		if name != "":
			spr.name = name
		add_child(spr)
	_configure_full_canvas_sprite(spr, tex, not authored)
	return spr

## A shared finish for the legacy moving hardware. Power icons and gameplay
## overlays keep their own state colours; authored animation frames stay intact.
func _finish_machine_materials(node: Node) -> void:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null and sprite.texture.resource_path.get_file() in [
				"neon_machine_jackpot.png",
				"neon_machine_power_bar.png", "health_bar.png", "augments.png",
				"wealth_bar.png", "wealth_cases.png", "target_goals.png"]:
			var finish := ShaderMaterial.new()
			finish.shader = MACHINE_MATERIALS
			finish.set_shader_parameter("phosphor_text",
				sprite.texture.resource_path.get_file() == "target_goals.png")
			sprite.material = finish
			if sprite.texture.resource_path.get_file() == "wealth_bar.png":
				sprite.material = preload("res://assets/shaders/painted_odometer.tres")
	for child in node.get_children():
		_finish_machine_materials(child)

func _build_full_canvas_sheet(rel: String, hframes: int, frame: int = 0) -> Sprite2D:
	var tex := _load_texture(rel, true)
	if tex == null:
		return null
	var name := _full_canvas_sheet_name(rel, frame)
	var spr := _authored_sprite(name) if name != "" else null
	var authored := spr != null
	if spr == null:
		spr = Sprite2D.new()
		if name != "":
			spr.name = name
		add_child(spr)
	_configure_full_canvas_sheet(spr, tex, hframes, frame, not authored)
	return spr

func _build_full_canvas_grid_sheet(rel: String, hframes: int, vframes: int, frame: int = 0) -> Sprite2D:
	var tex := _load_texture(rel, true)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.hframes = hframes
	spr.vframes = vframes
	spr.frame = frame
	spr.centered = false
	spr.position = Vector2.ZERO
	var frame_w := float(tex.get_width()) / float(hframes)
	var frame_h := float(tex.get_height()) / float(vframes)
	spr.scale = Vector2(SRC_W / frame_w, SRC_H / frame_h)
	spr.texture_filter = MACHINE_ART_TEXTURE_FILTER
	add_child(spr)
	return spr

func _build_region_sprite(rel: String, rect: Dictionary) -> Sprite2D:
	var tex := _load_texture(rel, true)
	if tex == null:
		return null
	var name := _region_sprite_name(rel, rect)
	var spr := _authored_sprite(name) if name != "" else null
	var authored := spr != null
	if spr == null:
		spr = Sprite2D.new()
		if name != "":
			spr.name = name
		add_child(spr)
	spr.texture = tex
	spr.centered = false
	# How many sheet pixels one source pixel is, measured from the sheet instead of assumed:
	# Native and legacy sheets share this helper; crops follow the actual texture
	# height so switching an asset to native resolution cannot crop beyond its bounds.
	var art_scale := maxf(1.0, float(tex.get_height()) / SRC_H)
	spr.position = Vector2(rect["left"], rect["top"])
	spr.region_enabled = true
	spr.region_rect = Rect2(
		float(rect["left"]) * art_scale,
		float(rect["top"]) * art_scale,
		float(rect["width"]) * art_scale,
		float(rect["height"]) * art_scale
	)
	spr.scale = Vector2(1.0 / art_scale, 1.0 / art_scale)
	spr.texture_filter = MACHINE_ART_TEXTURE_FILTER
	return spr

func _build_control_sheet_on(parent: Control, rel: String, hframes: int, frame: int = 0) -> Sprite2D:
	var tex := _load_texture(rel, true)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.hframes = hframes
	spr.frame = frame
	spr.centered = false
	spr.position = Vector2.ZERO
	var frame_w := float(tex.get_width()) / float(hframes)
	spr.scale = Vector2(SRC_W / frame_w, SRC_H / float(tex.get_height()))
	spr.texture_filter = MACHINE_ART_TEXTURE_FILTER
	parent.add_child(spr)
	return spr

func _build_control_grid_sheet_on(parent: Control, rel: String, hframes: int, vframes: int, frame: int = 0) -> Sprite2D:
	var tex := _load_texture(rel, true)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.hframes = hframes
	spr.vframes = vframes
	spr.frame = frame
	spr.centered = false
	spr.position = Vector2.ZERO
	var frame_w := float(tex.get_width()) / float(hframes)
	var frame_h := float(tex.get_height()) / float(vframes)
	spr.scale = Vector2(SRC_W / frame_w, SRC_H / frame_h)
	spr.texture_filter = MACHINE_ART_TEXTURE_FILTER
	parent.add_child(spr)
	return spr

func _set_sheet_frame(spr: Sprite2D, frame: int) -> void:
	if spr != null:
		spr.frame = frame

func _build_tv_indicators() -> void:
	_wealth.build()
	_refresh_target_readout()
	_health_bar_sprite = _build_full_canvas_sheet(
		HEALTH_BAR_SHEET, HEALTH_BAR_FRAME_COUNT)
	_build_reserve_glow()
	_build_full_canvas_sprite("machine_polished/shelf_labels.svg")
	_build_spins_left_label()
	_boosts.build()
	_build_power_bar()
	_build_restore_cap()
	_build_augment_emplacements()

## Numeric spins-left readout in the left control-shelf well — tracks the same
## _display_spins_left() budget the capped tube frames show.
func _build_spins_left_label() -> void:
	_spins_left_label = Label.new()
	_spins_left_label.name = "SpinsLeftNumber"
	_spins_left_label.position = SPINS_LEFT_LABEL_RECT.position
	_spins_left_label.size = SPINS_LEFT_LABEL_RECT.size
	_spins_left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spins_left_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spins_left_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spins_left_label.add_theme_font_size_override("font_size", 13)
	if _font != null:
		_spins_left_label.add_theme_font_override("font", _font)
	_spins_left_label.add_theme_color_override("font_color", SPINS_LEFT_NORMAL_COLOR)
	_spins_left_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_spins_left_label.add_theme_constant_override("outline_size", 1)
	_spins_left_label.text = ""
	add_child(_spins_left_label)
	var legend := Label.new()
	legend.name = "SpinsLegend"
	legend.text = "SPINS"
	legend.position = Vector2(27, 229)
	legend.size = Vector2(27, 8)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_font_override("font", _font)
	legend.add_theme_font_size_override("font_size", 5)
	legend.add_theme_color_override("font_color", Color("#9baa88"))
	add_child(legend)

## The power-restore gauge (issue #76): a native full-canvas overlay sheet (6x1 = 6 frames).
## It starts from the current power-point total so a resumed run does not replay old score.
## The authored augment sockets on the power bar — the divider after the third power
## emplacement plus one chip bed per held augment. Three frames: frame N shows N+1 sockets,
## so the row only ever offers as many beds as the run has augments to put in them (nothing
## at all with none). Full-canvas art, so placement is baked in; the code picks the frame and
## the layer it draws on: above the cabinet, below the badges themselves.
## The socket plate is built here because the full-canvas sheet helper and the
## layering it sits in belong to the machine; AugmentDisplay only shows and frames
## it, so it is handed over once and owned there from then on.
func _build_augment_emplacements() -> void:
	var plate := _build_full_canvas_sheet(AUGMENT_PLATE_SHEET, AugmentDisplay.AUGMENT_PLATE_FRAMES)
	if plate != null:
		plate.position = Vector2.ZERO
		plate.z_index = AUGMENT_PLATE_Z_INDEX
		plate.visible = false
	_augments.attach_plate(plate)

func _build_power_bar() -> void:
	var tex := _load_texture(POWER_BAR_SHEET, true)
	if tex == null:
		return
	_power_bar_sprite = _authored_sprite("PowerBar")
	var authored := _power_bar_sprite != null
	if _power_bar_sprite == null:
		_power_bar_sprite = Sprite2D.new()
		_power_bar_sprite.name = "PowerBar"
		add_child(_power_bar_sprite)
	_power_bar_sprite.texture = tex
	_power_bar_sprite.hframes = POWER_BAR_HFRAMES
	_power_bar_sprite.vframes = POWER_BAR_VFRAMES
	_power_bar_sprite.centered = false
	if not authored:
		var frame_w := float(tex.get_width()) / float(POWER_BAR_HFRAMES)
		var frame_h := float(tex.get_height()) / float(POWER_BAR_VFRAMES)
		_power_bar_sprite.position = Vector2.ZERO
		_power_bar_sprite.scale = Vector2(SRC_W / frame_w, SRC_H / frame_h)
	_power_bar_sprite.texture_filter = MACHINE_ART_TEXTURE_FILTER
	# Start empty; the gauge fills only from power points gained after this point (a resumed
	# run does not replay its existing score or Lucidity).
	_power_seen_lucidity = _power_point_total()
	_power_bar_score = 0
	_set_power_bar_frame(0)
	# Any restores earned before this scene existed resolve immediately (visual only —
	# the ability itself was already restored by plan_gain at spin time).
	for power_id in RunStateStore.pendingPowerRestores.duplicate():
		RunStateStore.commit_power_restore(String(power_id))

## A soft pulse on the tube's bottom chip while the Emergency Reserve is armed (issue
## #132). Rather than invent a badge, this re-draws the authored chip pixels themselves —
## a region of frame 1 of the tube sheet, laid exactly over where that chip already sits —
## so the glow can never drift out of register with the art it is highlighting.
func _build_reserve_glow() -> void:
	var tex := _load_texture(HEALTH_BAR_SHEET, true)
	if tex == null:
		return
	_reserve_glow_sprite = Sprite2D.new()
	_reserve_glow_sprite.name = "ReserveGlow"
	_reserve_glow_sprite.texture = tex
	_reserve_glow_sprite.centered = false
	_reserve_glow_sprite.region_enabled = true
	# Frame 1 is "one spin left", so its copy of the chip is the lit one to borrow.
	_reserve_glow_sprite.region_rect = Rect2(
		HEALTH_BAR_FRAME_W + HEALTH_BOTTOM_CHIP_RECT.position.x,
		HEALTH_BOTTOM_CHIP_RECT.position.y,
		HEALTH_BOTTOM_CHIP_RECT.size.x, HEALTH_BOTTOM_CHIP_RECT.size.y)
	_reserve_glow_sprite.position = HEALTH_BOTTOM_CHIP_RECT.position
	_reserve_glow_sprite.texture_filter = MACHINE_ART_TEXTURE_FILTER
	_reserve_glow_sprite.z_index = 3 # over the tube, under the HUD overlays
	_reserve_glow_sprite.visible = false
	add_child(_reserve_glow_sprite)

## Armed → a slow breathing glow; spent or unowned → nothing at all.
func _refresh_reserve_glow() -> void:
	if _reserve_glow_sprite == null:
		return
	var armed := RunStateStore.runPhase == "running" \
		and RunStateStore.emergency_reserve_armed()
	if armed == _reserve_glow_sprite.visible:
		return # already in the right state; never restart the pulse mid-breath
	_reserve_glow_sprite.visible = armed
	if _reserve_glow_tween != null and _reserve_glow_tween.is_valid():
		_reserve_glow_tween.kill()
	_reserve_glow_tween = null
	if not armed:
		return
	_reserve_glow_sprite.modulate = Color(RESERVE_GLOW_COLOR, RESERVE_GLOW_MIN_ALPHA)
	_reserve_glow_tween = create_tween().set_loops()
	_reserve_glow_tween.tween_property(_reserve_glow_sprite, "modulate:a",
		RESERVE_GLOW_MAX_ALPHA, RESERVE_GLOW_PERIOD).set_trans(Tween.TRANS_SINE)
	_reserve_glow_tween.tween_property(_reserve_glow_sprite, "modulate:a",
		RESERVE_GLOW_MIN_ALPHA, RESERVE_GLOW_PERIOD).set_trans(Tween.TRANS_SINE)

## The restore light sitting beside the gauge (issue #181). Full-canvas art, so the
## placement is baked in and the code only picks the frame. The glow copy sits on top on
## the LIT frame and is normally invisible — flashing and fading it is how a spent charge
## reads as discharging into the power, without needing a second authored asset.
func _build_restore_cap() -> void:
	_restore_cap_sprite = _build_full_canvas_sheet(RESTORE_CAP_SHEET, RESTORE_CAP_FRAMES)
	_restore_cap_glow = _build_full_canvas_sheet(RESTORE_CAP_SHEET, RESTORE_CAP_FRAMES, 0)
	if _restore_cap_glow != null:
		_restore_cap_glow.visible = false
		_restore_cap_glow.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_build_restore_cycle_pips()
	_refresh_restore_cap()

## The spade cycle read-out. Built only for a spade/joker run: every other suit refills
## the charge every spin, where a cycle indicator would say nothing.
func _build_restore_cycle_pips() -> void:
	# Free the old nodes before dropping the references: clearing the array alone orphans
	# live children, so a rebuild would stack a fresh set of pips on top of the last one.
	for old: ColorRect in _restore_cycle_pips:
		if is_instance_valid(old):
			old.queue_free()
	_restore_cycle_pips.clear()
	if not RunStateStore.augmented_modifier_active(2):
		return
	for rect: Rect2 in RESTORE_CYCLE_PIP_RECTS.slice(0,
			EconomyConst.SPADE_RESTORE_CYCLE_SPINS):
		var pip := ColorRect.new()
		pip.name = "RestoreCyclePip%d" % _restore_cycle_pips.size()
		pip.position = rect.position
		pip.size = rect.size
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.z_index = 30
		add_child(pip)
		_restore_cycle_pips.append(pip)

## The light is lit while a restore charge is banked, so the player can read what the
## economy still owes them before committing a power rather than discovering it on a gauge
## that refuses to fill. The next spin puts it back.
##
## A charge is DEBITED at spin resolution but the power only comes back when the gauge
## finishes filling, so reading the store's charge count directly would snap the light off
## seconds before the power returned — two halves of one event, too far apart to connect.
## Restores still owed (pendingPowerRestores) therefore count as lit: the light holds until
## the moment its power lands, and both resolve on the same frame.
func _shown_restore_charges() -> int:
	var owed := RunStateStore.pendingPowerRestores.size()
	return clampi(RunStateStore.restore_budget_left() + owed,
		0, EconomyConst.POWER_RESTORE_CHARGE_MAX)

func _refresh_restore_cap() -> void:
	if _restore_cap_sprite == null:
		return
	var spent := EconomyConst.POWER_RESTORE_CHARGE_MAX - _shown_restore_charges()
	_set_sheet_frame(_restore_cap_sprite, clampi(spent, 0, RESTORE_CAP_FRAMES - 1))
	# On a spade run a dark light is a wait, not just an empty budget — tint it so the
	# two read differently at a glance, and let the pips say how much longer.
	var waiting: bool = spent > 0 and RunStateStore.augmented_modifier_active(2)
	_restore_cap_sprite.modulate = RESTORE_SPADE_WAITING_TINT if waiting else Color.WHITE
	_refresh_restore_cycle_pips()

func _refresh_restore_cycle_pips() -> void:
	if _restore_cycle_pips.is_empty():
		return
	# Pips fill left to right as the wait elapses, and are all dark while a charge is
	# banked: restore_cycle_progress() is 0 in exactly that case.
	var lit := RunStateStore.restore_cycle_progress()
	for i in _restore_cycle_pips.size():
		var pip := _restore_cycle_pips[i]
		if not is_instance_valid(pip):
			continue
		pip.color = RESTORE_CYCLE_PIP_ON if i < lit else RESTORE_CYCLE_PIP_OFF

## Pooled duration icons on the TV (issue #76): one slot per possible boost, hidden
## until active. The icon says WHICH boost, a badge on its bottom-right corner says how
## many spins are left. Built once; refreshed each HUD update.
##
## The row moved UNDER the target bar and shrank to 8px (issue #185 follow-up). It used
## to be two 12px slots wedged into the y81..93 band beside the goal number — the only
## gap the other TV art left — which capped the machine at two visible items and folded
## everything past that into a "+N", so a run with four items running showed two of them.
## The strip below the fill bar is the one genuinely wide space on the screen: measured
## clear from y99..107 and x30..121, with nothing else authored into it.
##
## 8px is also a CLEANER downscale than 12 was, not a compromise: the source icons are
## 32x32, so 12px meant a fractional 32/12 = 2.67 nearest-neighbour reduction that
## dropped source pixels unevenly, while 8px is exactly 32/4 — every fourth pixel, all
## the way across. The row is left-aligned to the fill bar above it (x41) so the two
## read as one block.
## The row steps aside for a full-screen callout and only for that, and whether one
## is up is the TV priority stack's question, not the row's — so it is answered here.
func _refresh_boost_indicators() -> void:
	_boosts.refresh(_tv_callout_active())

func _boost_indicators_showing() -> bool:
	return _boosts.showing()

func _hide_item_info_popup() -> void:
	_boosts.hide_popup()

## Name over effect, straight off the badge's DURATION_BOOSTS entry. Serum names the
## symbol it guaranteed, because the badge is showing that symbol rather than the bottle.
##
## Stays on the machine and is handed to the row as a Callable: it reaches the item
## catalogue for a display name and the joker run's reworded blurbs, neither of which
## the row has any business in.
func _item_info_popup_text(boost: Dictionary) -> String:
	var title := String(boost.get("title", ""))
	if title == "":
		title = _item_display_name(String(boost.get("id", "")))
	var desc := String(boost.get("desc", ""))
	# An item the joker run has turned around describes what it is doing NOW (issue #111).
	if RunStateStore.augmented_joker_items_active() and boost.has("jokerDesc"):
		desc = String(boost["jokerDesc"])
	# Translated part by part: the bubble auto-translates the whole string it is handed, and
	# "COCKTAIL\n+1 SPIN ON EVERY WIN" glued together is not a key.
	title = tr(title)
	desc = tr(desc) if desc != "" else desc
	var symbol_field := String(boost.get("symbolField", ""))
	if symbol_field != "":
		var symbol_id := String(RunStateStore.get(symbol_field))
		if symbol_id != "":
			desc = "%s: %s" % [tr(symbol_id.to_upper()), desc]
	if desc == "":
		return title
	return "%s\n%s" % [title, desc]

func _capture_expiring_boost_counters() -> Array[Dictionary]:
	return _boosts.capture_expiring()

func _apply_expiring_boost_linger(counters: Array[Dictionary]) -> void:
	_boosts.apply_linger(counters)

func _clear_boost_zero_linger() -> void:
	if not _boosts.has_linger():
		return
	_boosts.clear_linger()
	_refresh_boost_indicators()
	_refresh_consumable_fx()

# ── tap-an-item-badge description (issue #185) ────────────────────────────────────
# ── the machine's description bubble ─────────────────────────────────────────────────
# One builder behind all three explain-this controls (the Augmented suit badge, the
# augment row on the power bar, the item badges on the TV). The panel HUGS its text
# instead of being a fixed box the words float inside, and callers set it down a few px
# from the icon that raised it — a description has to read as attached to the thing it
# describes, not as a plate that happens to be nearby.
const INFO_BUBBLE_PAD := Vector2(8.0, 6.0)   # px of panel around the text block
const INFO_BUBBLE_LINE_H := 8.0              # floor for one row, however short the font
const INFO_BUBBLE_LINE_SPACING := 3          # pinned on the label so sizing can rely on it
const INFO_BUBBLE_FONT_SIZE := 5
const INFO_BUBBLE_GAP := 3.0                 # px between the icon and its bubble
const INFO_BUBBLE_BG := Color(0.045, 0.035, 0.075, 0.97)

## `max_width` (0 = unbounded) wraps long text rather than letting the bubble run off the
## panel it belongs to. The returned Control carries the finished size, so the caller can
## place it against its own edges.
func _make_info_bubble(node_name: String, source: String, border: Color,
		font_color: Color, max_width := 0.0) -> Control:
	# Translated once, up front, with the label's own auto-translation switched off below.
	# The panel HUGS the text it measures, so measuring English while Godot drew French
	# would size every bubble for the wrong language. Measure what you draw.
	var text := tr(source)
	var font: Font = _font if _font != null else ThemeDB.fallback_font
	var lines := text.split("\n")
	var text_w := 0.0
	for line in lines:
		text_w = maxf(text_w, font.get_string_size(
			line, HORIZONTAL_ALIGNMENT_LEFT, -1, INFO_BUBBLE_FONT_SIZE).x)
	var rows := lines.size()
	if max_width > 0.0 and text_w + INFO_BUBBLE_PAD.x > max_width:
		# Wrapping splits lines the measurement above cannot see, so ask the font to do the
		# wrap and report what it produced. Estimating the rows as ceil(width / limit) both
		# miscounted (word wrapping breaks early, it does not fill every row) and left the
		# panel pinned to the full max_width — which is why a wrapped description used to
		# sit in a box with more slack on one side than the other.
		var inner := max_width - INFO_BUBBLE_PAD.x
		var wrapped := font.get_multiline_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, inner, INFO_BUBBLE_FONT_SIZE)
		text_w = minf(inner, wrapped.x)
		rows = maxi(1, roundi(wrapped.y / maxf(1.0, font.get_height(INFO_BUBBLE_FONT_SIZE))))
	# A row is the font's own line box PLUS the label's line spacing, which is pinned
	# below so the two always agree. Sizing on the nominal 8px instead left the last line
	# of a tall bubble (the joker suit lists seven) hanging out under its own border.
	var line_h := maxf(INFO_BUBBLE_LINE_H,
		font.get_height(INFO_BUBBLE_FONT_SIZE) + INFO_BUBBLE_LINE_SPACING)
	var popup_size := Vector2(text_w + INFO_BUBBLE_PAD.x,
		float(rows) * line_h + INFO_BUBBLE_PAD.y)
	var popup := Control.new()
	popup.name = node_name
	popup.size = popup_size
	# Purely informational, and it sits over live controls — it must never eat a tap.
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = INFO_BUBBLE_BG
	bg_style.border_color = border
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	var bg := Panel.new()
	bg.size = popup_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", bg_style)
	popup.add_child(bg)
	var label := Label.new()
	label.name = "Text"
	# ANCHORED to the panel rather than given a size, and that is not a style choice: a
	# Control clamps an assigned size up to its minimum, and a Label built outside the
	# scene tree measures its minimum with the DEFAULT 16px theme font (theme overrides
	# only reach the metric cache once the node is in a tree). A one-row bubble asked for a
	# 10px-tall label, got a 19px one, and centred its line below its own border. Anchors
	# are recomputed from the parent whenever the metrics settle, so the rect self-corrects
	# the moment the popup is added to the scene.
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	var nudge := Assets.centered_text_nudge(INFO_BUBBLE_FONT_SIZE)
	label.offset_left = INFO_BUBBLE_PAD.x * 0.5
	label.offset_top = INFO_BUBBLE_PAD.y * 0.5 + nudge
	label.offset_right = -INFO_BUBBLE_PAD.x * 0.5
	label.offset_bottom = -INFO_BUBBLE_PAD.y * 0.5 + nudge
	label.text = text
	# Already translated above; translating again would look up a French key.
	label.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
	if max_width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", INFO_BUBBLE_FONT_SIZE)
	label.add_theme_constant_override("line_spacing", INFO_BUBBLE_LINE_SPACING)
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	bg.add_child(label)
	return popup

func _build_machine_control_art() -> void:
	_multiplier_sprite = _build_full_canvas_sheet("machine_polished/multiplier.svg", MULTIPLIER_FRAME_COUNT)
	# Issue #155: gauge effect overlays draw above the badge strip; hidden until
	# the frenzy reaches their state.
	_mult_fx_2 = _build_full_canvas_sheet(MULT_FX_2_SHEET, MULT_FX_2_FRAMES)
	_mult_fx_3 = _build_full_canvas_sheet(MULT_FX_3_SHEET, MULT_FX_3_FRAMES)
	_mult_fx_fire = _build_full_canvas_sheet(MULT_FX_FIRE_SHEET, MULT_FX_3_FRAMES)
	for sprite in [_multiplier_sprite, _mult_fx_2, _mult_fx_3, _mult_fx_fire]:
		if sprite != null:
			sprite.position = Vector2(-9, 30)
	_dealer_bar.build()
	_build_dealer_tip_steps()
	_tv.build_banner()
	# The four callout sheets are built here, at the point in the layer stack they
	# have always occupied: the win sheet keeps the machine's default z_index, so
	# the tree order at this line IS its layer (issue #195, seam 4.2).
	_callouts.build()
	_power_callout.build()
	# Hides itself and sets its own z_index — the sheet is the mini-reel's art.
	_cheat.build_sheet()
	for fx in [_mult_fx_2, _mult_fx_3, _mult_fx_fire]:
		if fx != null:
			(fx as Sprite2D).visible = false
	_bursts.build_jackpot_lamp()
	for i in 3:
		var lock := _build_full_canvas_sheet("machine new view/lock_power.png", LOCK_POWER_FRAME_COUNT, i)
		if lock != null:
			lock.visible = false
		_lock_sprites.append(lock)
		var count := get_node_or_null("LockCount%d" % i) as Label
		var authored_count := count != null
		if count == null:
			count = Label.new()
			count.name = "LockCount%d" % i
			add_child(count)
		if not authored_count:
			count.position = Vector2(REEL_CELL_CENTERS[i] - 6.0, REEL_WINDOW["top"] + REEL_WINDOW["height"] + 1.0)
			count.size = Vector2(12.0, 8.0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 7)
		if _font != null:
			count.add_theme_font_override("font", _font)
		count.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
		count.text = ""
		count.visible = false
		_lock_count_labels.append(count)
	for id in POWER_IDS:
		_power_sprites[id] = _build_full_canvas_sheet(String(POWER_SHEETS[id]), 3, POWER_FRAME_DISABLED)

func _transparent_button_style() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

func _make_hit_button(rect: Dictionary, cb: Callable) -> Button:
	var b := Button.new()
	_configure_hit_button(b, rect, cb)
	return b

func _configure_hit_button(b: Button, rect: Dictionary, cb: Callable, apply_rect := true) -> void:
	b.text = ""
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	if apply_rect:
		b.position = Vector2(rect["left"], rect["top"])
		b.size = Vector2(rect["width"], rect["height"])
	var empty := _transparent_button_style()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, empty)
	if not b.pressed.is_connected(cb):
		b.pressed.connect(cb)

func _make_or_bind_hit_button(name: String, rect: Dictionary, cb: Callable) -> Button:
	var b := _authored_button(name)
	var authored := b != null
	if b == null:
		b = Button.new()
		b.name = name
		add_child(b)
	_configure_hit_button(b, rect, cb, not authored)
	return b

# Per-reel reel-background patches, drawn above the spin-blur sheet and below the
# symbols. Showing one masks the blur in that hole, so a reel goes static the moment
# its symbol lands — independent per-reel stops over the single full-canvas sheet.
func _play_reel_stop_sfx(index: int) -> void:
	if index < 0 or index >= _reel_stop_sfx_played.size():
		return
	if bool(_reel_stop_sfx_played[index]):
		return
	_reel_stop_sfx_played[index] = true
	_play_sfx(&"reel_stop")

# A reel lands: mask its blur, show its final symbol, stop animating that reel.
func _reveal_reel(index: int) -> void:
	var was_visible := _reel_symbols.center(index).visible
	if not was_visible:
		_play_reel_stop_sfx(index)
	_reel_blur.set_spin_visible(index, false)
	_reel_blur.set_cover(index, true)
	_reel_symbols.set_symbol(index, String(_final_reels[index]))
	_reel_symbols.set_visible(index, true)
	_set_hidden_cover(index, _hide_result_active) # White Powder masks the reveal (issue #34)
	_reel_symbols.refresh_adjacent(index)      # Serum hides above/below neighbours

func _build_hud() -> void:
	_build_score_button()
	_build_spin_label()
	_build_hint_layer()
	_build_dealer_icon()

## Issue #155: the compact dealer portrait sits beside the authored countdown bar.
## The countdown is entirely visual now; no numeric badge is layered over the icon.
func _build_dealer_icon() -> void:
	var icon := MachineDealerPortrait.new()
	icon.name = "DealerIcon"
	icon.position = DEALER_ICON_POS
	icon.size = DEALER_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = _load_texture(DEALER_ICON_ASSET, true)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.z_index = 12
	_dealer_icon = icon
	add_child(icon)
	# Built in the HUD pass, long after the component block — so it is handed to the
	# arbiter here rather than passed in at construction.
	_tv.set_dealer_icon(icon)
	icon.build_caption(_font)

## Presentation only: a short response remains after the payout releases the CRT.
func _react_dealer(win_type: String) -> void:
	if _dealer_icon != null:
		_dealer_icon.react(win_type)


## Rides as a CHILD of the bar rather than as a fourth sibling overlay: the bar's own
## visibility is driven from four unrelated places (the callout mute, the losing-state
## re-show, TvOwnership.restore_layers, and the ending's name-based sweep in
## _set_tv_progress_bars_visible), and a sibling would have to be remembered in every one
## of them. As a child it simply never draws when the bar doesn't. Both are native 1:1
## full-canvas art at the origin, so the child needs no transform of its own.
func _build_dealer_tip_steps() -> void:
	if _dealer_bar.bar_sprite() == null:
		return
	var tex := _load_texture(DEALER_TIP_STEPS_SHEET, true)
	if tex == null:
		return
	_dealer_tip_steps = Sprite2D.new()
	_dealer_tip_steps.name = "DealerTipSteps"
	_dealer_tip_steps.texture = tex
	_dealer_tip_steps.centered = false
	_dealer_tip_steps.position = Vector2.ZERO
	_dealer_tip_steps.texture_filter = MACHINE_ART_TEXTURE_FILTER
	_dealer_tip_steps.visible = false
	# Above the bar it recolours, below the warning lights that beep over everything.
	_dealer_bar.bar_sprite().add_child(_dealer_tip_steps)

## Owned → the tipped steps wear their own colour; not owned → the bar is untouched.
func _refresh_dealer_tip_steps() -> void:
	if _dealer_tip_steps == null:
		return
	_dealer_tip_steps.visible = int(RunStateStore.dealer_tip_head_start()) > 0

func _refresh_dealer_countdown() -> void:
	_refresh_dealer_tip_steps()
	if _dealer_bar.bar_sprite() == null:
		return
	var remaining := maxi(0, int(RunStateStore.dealerCountdown))
	# The FULL cycle, not the reset value: Dealer's Tip resets to 10 of 12, and the bar
	# has to show that as 2/12 filled. Measuring against the reset value instead would
	# redraw the same empty bar on a shorter scale and hide the head start entirely.
	var cycle_start := maxi(1, int(RunStateStore.dealer_countdown_cycle_length()))
	var elapsed := clampi(cycle_start - remaining, 0, cycle_start)
	var progress_frame := clampi(roundi(float(elapsed) * float(DealerBar.FRAME_COUNT - 1)
		/ float(cycle_start)), 0, DealerBar.FRAME_COUNT - 1)
	_dealer_bar.seek(progress_frame)
	_dealer_bar.sync_overlay_frames()
	# The warning sheets are cumulative: the x3 warning is overlay 1, x2 adds
	# overlay 2, and x1 adds overlay 3. Each sheet follows the same countdown
	# progress as the bar; its shorter tail clamps to its final authored frame.
	var cap := 2 if RunStateStore.energy_drink_owns_multiplier() else 3
	var effective := clampi(int(RunStateStore.betMultiplier), 1, cap)
	var show_overlay_1 := false
	var show_overlay_2 := false
	var show_overlay_3 := false
	if RunStateStore.glitchDealerStepActive:
		# Glitch 2 keeps the complete warning stack lit at every multiplier. The
		# countdown cadence and normal post-result visibility gate still apply;
		# only the cumulative stack is overridden.
		show_overlay_1 = true
		show_overlay_2 = true
		show_overlay_3 = true
	elif RunStateStore.comboDefeatPending:
		# A losing-state warning uses the dealer-warning state that follows a
		# declined loss: pending x1 stays at x1, pending x2 falls to x1, and
		# pending x3 falls to x2. Therefore x1/x2 keep all three lights and x3
		# keeps lights 1+2.
		var preceding_multiplier := maxi(1,
			clampi(int(RunStateStore.pendingComboMultiplier) - 1, 1, 3))
		show_overlay_1 = preceding_multiplier <= 3
		show_overlay_2 = preceding_multiplier <= 2
		show_overlay_3 = preceding_multiplier <= 1
	else:
		show_overlay_1 = effective <= 3
		show_overlay_2 = effective <= 2
		show_overlay_3 = effective <= 1
	# Warning lights are committed after the reveal/score result. Showing them as
	# soon as the SPIN is pressed would leak the next gauge state into the spin.
	var overlay_ready := not _spinning_anim and not _spin_launch_pending \
		and not RunStateStore.isSpinning and not _hud_delta_hold
	var dealer_info_allowed := not _tv_callout_active() \
		or RunStateStore.comboDefeatPending
	# How many lights the state earned, which is not the same as how many are shown:
	# the count sets the beep tempo (DealerBar.WARNING_FAST_BEEP_LIGHTS), while the
	# spin gates above decide whether they may draw at all yet.
	var wanted := 0
	if show_overlay_1:
		wanted = 1
	if show_overlay_2:
		wanted = 2
	if show_overlay_3:
		wanted = 3
	var allowed := overlay_ready and dealer_info_allowed
	_dealer_bar.set_warning_lights(wanted,
		show_overlay_1 and allowed, show_overlay_2 and allowed, show_overlay_3 and allowed)
	if _tv_callout_active() and not RunStateStore.comboDefeatPending:
		_hide_tv_info_layers()
	elif RunStateStore.comboDefeatPending:
		# The dealer warning remains readable over the losing-state art, even if
		# the result's PAIR/TRIPLE callout is still fading out.
		if _dealer_bar.bar_sprite() != null:
			_dealer_bar.bar_sprite().visible = true
		if _dealer_icon != null:
			_dealer_icon.visible = true

func _build_score_button() -> void:
	_score_button = _authored_button("ScoreButton")
	var authored := _score_button != null
	if _score_button == null:
		_score_button = Button.new()
		_score_button.name = "ScoreButton"
		add_child(_score_button)
	_score_button.text = "TABLES"
	if not authored:
		_score_button.size = Vector2(41.0, 15.0)
		# Pulled off the top-right corner so it isn't glued to the edge.
		_score_button.position = Vector2(SRC_W - _score_button.size.x - HUD_CORNER_INSET, HUD_CORNER_INSET)
	_score_button.flat = false
	_score_button.focus_mode = Control.FOCUS_NONE
	_score_button.add_theme_font_size_override("font_size", 7)
	if _font != null:
		_score_button.add_theme_font_override("font", _font)
	ButtonKit.small_neon_button_style(_score_button, NEON_CYAN, 7, 2.0)
	ButtonKit.start_menu_button_press_feedback(_score_button)
	if not _score_button.pressed.is_connected(_show_score_table):
		_score_button.pressed.connect(_show_score_table)

func _build_options_controls() -> void:
	_options_button = _authored_texture_button("options")
	if _options_button == null:
		_options_button = TextureButton.new()
		_options_button.name = "options"
		_options_button.position = Vector2(HUD_CORNER_INSET, HUD_CORNER_INSET)
		_options_button.size = Vector2(20.0, 18.0)
		add_child(_options_button)
	ButtonKit.skin_icon_button(_options_button, SETTINGS_ASSET, 1)
	if not _options_button.pressed.is_connected(_toggle_options_overlay):
		_options_button.pressed.connect(_toggle_options_overlay)
	_options_overlay = get_node_or_null("OptionsOverlay") as OptionsOverlay
	if _options_overlay == null:
		_options_overlay = OPTIONS_OVERLAY_SCENE.instantiate() as OptionsOverlay
		_options_overlay.name = "OptionsOverlay"
		add_child(_options_overlay)

func _toggle_options_overlay() -> void:
	if _options_overlay == null:
		return
	_options_overlay.toggle_overlay()

func _restore_options_overlay_if_requested() -> void:
	if Engine.is_editor_hint() or _options_overlay == null:
		return
	if SceneNav.consume_restore_options(String(scene_file_path)):
		_options_overlay.call_deferred("show_overlay")

## Collects the notes the dealer left for this scene (issue #132): a chip bought at the
## counter whose payoff lives on the machine — Extra Spins filling the tube, the Tip
## shortening the dealer's walk, the Reserve arming. Purely cosmetic: every target is
## checked and a missing one skips its effect, so feedback can never block a run.
func _play_pending_scene_feedback() -> void:
	if Engine.is_editor_hint():
		return
	for note: Dictionary in SceneNav.take_pending_feedback():
		var fb := ChipAugments.feedback_for(String((note.get("data", {}) as Dictionary).get("augment", "")))
		var label := String(fb.get("label", ""))
		match String(note.get("id", "")):
			"spins":
				_pulse_spins_readout(label)
			"dealer_bar":
				_pulse_dealer_bar(label)

## The spins tube/count flashes and the label pops beside it — what Extra Spins and the
## armed Reserve both pay out in.
func _pulse_spins_readout(label: String) -> void:
	var target: CanvasItem = _spins_left_label
	if target == null or not is_instance_valid(target):
		return
	target.modulate = SCENE_FEEDBACK_TINT
	var tw := create_tween()
	tw.tween_property(target, "modulate", Color.WHITE, SCENE_FEEDBACK_FADE) \
		.set_trans(Tween.TRANS_SINE)
	if label != "":
		_bursts.spawn(label, 0, SCENE_FEEDBACK_LABEL_COLOR, 0)

## The dealer bar flashes on its new head start, so the Tip's 2/12 is seen being bought.
func _pulse_dealer_bar(label: String) -> void:
	_refresh_dealer_countdown() # the head start applies from this reset onward
	var target: CanvasItem = _dealer_bar.bar_sprite()
	if target == null or not is_instance_valid(target):
		return
	target.modulate = SCENE_FEEDBACK_TINT
	var tw := create_tween()
	tw.tween_property(target, "modulate", Color.WHITE, SCENE_FEEDBACK_FADE) \
		.set_trans(Tween.TRANS_SINE)
	if label != "":
		_bursts.spawn(label, 0, SCENE_FEEDBACK_LABEL_COLOR, 2)

func _set_score_button_locked(locked: bool) -> void:
	if _score_button == null:
		return
	_score_button.disabled = locked
	_score_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP

func _set_sequence_lock(locked: bool) -> void:
	_sequence_lock_active = locked
	if locked:
		_clear_targeting()
	_refresh_score_button_lock()
	_refresh_controls()

func _refresh_score_button_lock() -> void:
	# The pending-defeat rescue window keeps TABLES readable: the sequence lock is
	# holding the player, but checking the odds is part of deciding on a rescue.
	var locked := (_sequence_lock_active and not RunStateStore.comboDefeatPending) \
		or _dealer_offer_popup != null
	_set_score_button_locked(locked)

func _build_spin_label() -> void:
	var bottom_hud := get_node_or_null("BottomHudLayer") as Control
	if bottom_hud == null:
		bottom_hud = Control.new()
		bottom_hud.name = "BottomHudLayer"
		bottom_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bottom_hud.size = Vector2(SRC_W, SRC_H)
		bottom_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom_hud.z_index = 120
		add_child(bottom_hud)
	_spin_label = bottom_hud.get_node_or_null("spin_number") as Label
	var legacy_label := get_node_or_null("neuron_number") as Label
	if _spin_label == null and legacy_label != null:
		legacy_label.reparent(bottom_hud)
		legacy_label.name = "spin_number"
		_spin_label = legacy_label
	if _spin_label == null:
		_spin_label = Label.new()
		_spin_label.name = "spin_number"
		bottom_hud.add_child(_spin_label)
		_spin_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_spin_label.offset_left = -46.5
		_spin_label.offset_top = -14.0
		_spin_label.offset_right = 46.5
		_spin_label.offset_bottom = -4.0
	_spin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spin_label.add_theme_font_size_override("font_size", 6)
	if _font != null:
		_spin_label.add_theme_font_override("font", _font)
	_spin_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	_spin_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_spin_label.add_theme_constant_override("outline_size", 1)
	_spin_label.text = ""
	# The campaign neuron meter belongs to the menu and flatline overlay. The
	# machine HUD's empty anchor is explicitly named for the run's spin counter.
	_build_machine_credits_display(bottom_hud)
	_refresh_machine_credits()

func _build_machine_credits_display(bottom_hud: Control) -> void:
	_credits_row = bottom_hud.get_node_or_null("CreditsRow") as HBoxContainer
	if _credits_row == null:
		_credits_row = HBoxContainer.new()
		_credits_row.name = "CreditsRow"
		bottom_hud.add_child(_credits_row)
	_credits_row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_credits_row.offset_left = 7.0
	_credits_row.offset_top = -20.0
	_credits_row.offset_right = 30.0
	_credits_row.offset_bottom = -8.0
	_credits_row.add_theme_constant_override("separation", 2)
	_credits_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_credits_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits_row.z_index = 20

	_credits_label = _credits_row.get_node_or_null("CreditsLabel") as Label
	if _credits_label == null:
		_credits_label = Label.new()
		_credits_label.name = "CreditsLabel"
		_credits_row.add_child(_credits_label)
	_credits_label.add_theme_font_size_override("font_size", 7)
	_credits_label.add_theme_color_override("font_color", LUCIDITY_COLOR)
	_credits_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_credits_label.add_theme_constant_override("outline_size", 1)
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_credits_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_credits_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font != null:
		_credits_label.add_theme_font_override("font", _font)

	_credits_coin = _credits_row.get_node_or_null("Coin") as TextureRect
	if _credits_coin == null:
		_credits_coin = TextureRect.new()
		_credits_coin.name = "Coin"
		_credits_row.add_child(_credits_coin)
	_credits_coin.texture = Assets.texture(COIN_ASSET, true)
	_credits_coin.custom_minimum_size = CREDITS_COIN_SIZE
	_credits_coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_credits_coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_credits_coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_credits_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_credits_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh_machine_credits() -> void:
	if _credits_label != null:
		# The Run Wallet is the balance carried into this machine segment. Score is
		# accumulated on the wealth readout and is handed off only after the segment's
		# deduction/settlement sequence completes.
		var displayed := int(RunStateStore.lucidityCoins)
		if _machine_scene_lucidity_snapshot_ready:
			displayed = _machine_scene_lucidity_before
		_credits_label.text = str(maxi(0, displayed))

## Capture the balance at the start of this machine segment. The HUD stays on this
## snapshot while score and in-segment effects are being resolved.
func _begin_machine_lucidity_segment() -> void:
	_machine_scene_lucidity_before = int(RunStateStore.lucidityCoins)
	_machine_scene_score_before = int(RunStateStore.scoreEarned)
	_machine_scene_lucidity_snapshot_ready = true
	_refresh_machine_credits()

## Replace the live score-derived Lucidity with the net remainder after an
## intermediate target. In-segment purchases/effects are retained as the delta that
## did not come from score; the target's `banked` value is the only score amount
## handed into the next segment.
func _settle_machine_lucidity_after_deductions(completed: Dictionary,
		score_before_settlement: int) -> int:
	if not _machine_scene_lucidity_snapshot_ready:
		return maxi(0, int(RunStateStore.lucidityCoins))
	var score_gain := maxi(0, score_before_settlement - _machine_scene_score_before)
	var non_score_delta := int(RunStateStore.lucidityCoins) \
			- _machine_scene_lucidity_before - score_gain
	var settled_score := maxi(0, int(completed.get("banked", 0)))
	var settled := maxi(0, _machine_scene_lucidity_before \
			+ non_score_delta + settled_score)
	RunStateStore.settle_run_lucidity_after_deductions(settled)
	_machine_scene_lucidity_before = settled
	_machine_scene_score_before = int(RunStateStore.scoreEarned)
	_refresh_machine_credits()
	return settled

## RunStateStore.lucidityCoins is already the net machine balance: its score-derived
## gains and all machine-side deductions (dealer, items, rerolls, and potion effects)
## have been applied. Never substitute the wealth score for this handoff.
func _machine_lucidity_after_deductions() -> int:
	return maxi(0, int(RunStateStore.lucidityCoins))

func _build_hint_layer() -> void:
	_hints.build(get_node_or_null("BottomHudLayer") as Control)

func _build_spin_button() -> void:
	_spin_button = _make_or_bind_hit_button("SpinButton", SPIN_HIT, _do_spin)
	_configure_hit_button(_spin_button, SPIN_HIT, _do_spin)
	_spin_button.flat = false
	_spin_button.focus_mode = Control.FOCUS_ALL
	_spin_button.tooltip_text = "SPIN"
	for state in ["normal", "pressed", "disabled", "hover", "focus"]:
		var style := StyleBoxTexture.new()
		style.texture = load("res://assets/images/machine_polished/spin_%s.svg" % state)
		_spin_button.add_theme_stylebox_override(state, style)

# ── run loop ──────────────────────────────────────────────────────────────────────

# Entered from the shop (which already started the run) or standalone. If no run is
# in progress, begin one from meta so the machine works on its own too.
func _enter_run() -> void:
	if RunStateStore.pacte_active():
		# Direct scene smoke/tools can open the machine while a ritual is saved;
		# complete that saved visit deterministically instead of reserving a second
		# campaign neuron. The menu always routes real players to Pacte first.
		RunStateStore.skip_pacte_with_defaults()
	if RunStateStore.runPhase != "running":
		if not _begin_fresh_run():
			_show_campaign_failed()
			return
	_begin_machine_lucidity_segment()
	_sync_visuals()
	# The "-1 NEURON" popup belongs to the flatline overlay only — it no longer
	# fires during normal machine play (the pending flag is just cleared here).
	MetaStateStore.consume_neuron_spend_feedback()

func _begin_fresh_run() -> bool:
	var permanents: Array = MetaStateStore.ownedPermanents.duplicate()
	var consumables: Dictionary = MetaStateStore.get_pending_consumables().duplicate(true)
	if DEBUG_GRANT:
		for p in ["perm_shift", "perm_memory"]:
			if not permanents.has(p):
				permanents.append(p)
		if consumables.is_empty():
			consumables = { "cons_focus": 1, "item_water": 1 }
	return RunStateStore.start_new_run(permanents, consumables)

func _sync_visuals() -> void:
	_stop_sfx(&"reel_spin")
	_spin_launch_pending = false
	_rewind_anim_active = false
	# A spin whose scene was freed mid-resolution (e.g. opening options and tapping
	# Settings/Scores while the reels are still turning) committed lastResult + run
	# state inside RunStateStore.spin() but never reached _run_post_reveal_sequence,
	# so isSpinning is still true. Resolve it below, after the visual reset (issue #77).
	var resume_interrupted_spin := RunStateStore.isSpinning
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_stash.set_tray_visible(true)
	_set_tv_progress_bars_visible(true)
	_close_pending_combo_defeat()
	_pending_combo_power_flow = false
	_stop_flatline_countdown()
	_close_score_table()
	_clear_targeting()
	_clear_close_call_heartbeat()
	_set_hidden_result_active(false)
	_reel_symbols.set_adjacent_hidden(false)
	_close_serum_picker()
	_close_book_choice_overlay()
	_hide_compulsive_overlay()
	_compulsive_queued = false
	_last_reacted_reels = []
	_last_reacted_spin = -1
	_reveal_reel_next_spin = -1
	_pending_spin_gain = 0
	if RunStateStore.lastResult != null:
		_refresh_reels_from_state()
	else:
		_reel_symbols.set_all_visible(true)
		for i in 3:
			_reel_symbols.set_symbol(i, VISIBLE_SYMBOLS[i])
	# Settled reels show their cover (masks any blur); spin sheet hidden.
	for i in 3:
		_reel_blur.set_cover(i, true)
	_reel_blur.hide_spin_strips()
	if _spin_sheet_sprite != null:
		_spin_sheet_sprite.visible = false

	_update_hud()
	_refresh_lock_art()
	_refresh_jackpot_lamp(false)
	if _dealer_interaction_active():
		# A pending Dealer visit is persisted gameplay state, not a transient HUD
		# effect.  Rebuild it before any resume resolver can advance the machine.
		_restore_dealer_overlay_from_state()
		return
	if resume_interrupted_spin:
		_resolve_interrupted_spin()
	elif RunStateStore.comboDefeatPending:
		_post_spin_sequence_active = true
		_show_pending_combo_defeat()
	else:
		_resolve_exhausted_resume()
		# A score can overshoot the next target before the scene is freed for the
		# dealer/Pacte visit. Re-check on rebuild so the next target cannot be skipped.
		if RunStateStore.runPhase == "running" and not RunStateStore.isSpinning \
				and not RunStateStore.comboDefeatPending:
			call_deferred("_check_ending")

## A save can land after the final neuron cost is committed but before the normal
## post-reveal ending check runs. Reconcile that state when the machine is rebuilt so
## an exhausted running save cannot leave a zero-spin machine with no action.
func _resolve_exhausted_resume() -> void:
	if RunStateStore.runPhase != "running":
		return
	if int(RunStateStore.neurons) > 0 or int(RunStateStore.freeSpinsRemaining) > 0:
		return
	if _check_flatline_instant_death():
		return
	_check_ending()

## Finalizes a spin whose committed result never got resolved because its scene was
## freed before _run_post_reveal_sequence ran (issue #77). Runs the same non-visual
## post-spin resolution — minus the animated score burst — so earned reactions land
## and a terminal result (flatline strike, neuron flatline, wealth goal, spin cap)
## resolves into its ending instead of leaving a playable-but-dead machine that only
## answers spins with null. Mirrors the tail of _run_post_reveal_sequence.
func _resolve_interrupted_spin() -> void:
	RunStateStore.set_spinning(false) # clears isSpinning + applies the locked-reel decrement
	_refresh_lock_art()
	if RunStateStore.lastResult == null:
		_update_hud() # defensive: nothing to resolve, just re-enable controls
		_resolve_exhausted_resume()
		return
	var dealer_help := RunStateStore.maybe_dealer_help()
	if not dealer_help.is_empty():
		_refresh_reels_from_state()
		_refresh_lock_art()
	RunStateStore.check_dealer_trigger()
	var dealer_pending := RunStateStore.dealerIncoming
	_release_hud_delta_hold()
	_refresh_jackpot_lamp()
	_apply_machine_reactions(false) # flatline-result / triple reactions the player earned
	if _check_flatline_instant_death():
		return
	# A spin that beats the target and warns of a loss in the same breath pays first —
	# the warning would otherwise return past the ending check and bury the payout.
	if _proc_wealth_target():
		return
	if RunStateStore.comboDefeatPending:
		if not _discard_moot_combo_defeat():
			_post_spin_sequence_active = true
			_show_pending_combo_defeat()
			if RunStateStore.dealerIncoming:
				_present_dealer_or_defer()
			return
	if _check_ending():
		return
	# Issue #96: resolve a pending compulsion before the dealer pops (see
	# _run_post_reveal_sequence) — the dealer stays queued and presents afterward.
	if RunStateStore.compulsiveSpinSkips > 0:
		_queue_compulsive_spin()
	elif RunStateStore.dealerIncoming:
		_present_dealer_or_defer()
	_update_hud()

func _to_menu(transition_kind: int = SceneNav.TransitionKind.NORMAL) -> void:
	SceneNav.change_to(MENU_SCENE, transition_kind)

func _to_dealer(transition_kind: int = SceneNav.TransitionKind.NORMAL) -> void:
	SceneNav.change_to(DEALER_SCENE, transition_kind)

## The beaten intermediate target now takes over the screen with a focused payout
## overlay (issue #176), styled like the flatline screen but without the trace or
## neuron-loss animations: the target pops in beside the running score, flies onto
## it, and the number counts down by that amount (the money paid to the casino).
## A normal neon CONTINUE button resumes the run through _finish_wealth_target_transition.
func _start_wealth_target_transition(info: Dictionary) -> bool:
	if _wealth_target_transition_active or info.is_empty():
		return false
	_wealth_target_transition_active = true
	_set_sequence_lock(true)
	var score := int(RunStateStore.scoreEarned)
	var target := int(info.get("target", 0))
	var overlay := TARGET_REACHED_SCENE.instantiate() as TargetReachedOverlay
	overlay.name = "WealthTargetTransition"
	overlay.add_to_group(WEALTH_TRANSIENT_FX_GROUP)
	overlay.z_index = WEALTH_TARGET_FX_Z_INDEX
	add_child(overlay)
	_wealth_target_transition = overlay
	# The overlay flies a copy of the machine's own wealth reels, so the roll has to be
	# quiesced first — _drive_roll rewrites the digit transforms every frame.
	var snapshot: WealthOdometer = null
	_wealth.stop_roll()
	if _wealth.odometer() != null:
		snapshot = WealthOdometer.make_snapshot(score)
		snapshot.snapshot_origin = _wealth.odometer().position
	_tv.begin_blackout(TargetReachedOverlay.PHASE_BLACKOUT)
	overlay.digits_lifted.connect(_on_wealth_target_digits_lifted)
	# The final target is not paid out of the score and banks nothing, so it shows no
	# receipt — the Wealth ending takes the whole score from here.
	overlay.present(score, target, snapshot, "CONTINUE",
		bool(info.get("final", false)), _machine_scene_lucidity_before)
	overlay.continue_pressed.connect(_finish_wealth_target_transition)
	return true

## The lifted copy has reached the TV; blank the cabinet's own digits so the number is
## never on screen twice.
func _on_wealth_target_digits_lifted() -> void:
	_wealth.set_digits_hidden(true)

func _end_tv_blackout() -> void:
	_tv.end_blackout()
	# Not TvOwnership's: the digits are the odometer's, and lifting them is a payout
	# beat rather than part of who owns the screen.
	_wealth.set_digits_hidden(false)

func _finish_wealth_target_transition() -> void:
	if not _wealth_target_transition_active:
		return
	# The run is leaving for the between-run flow. A card earned on the same spin must not
	# squeeze in during the hand-off — the store commits below emit state_changed, and the
	# unlock gate would otherwise open for those few frames and beat the scene change. It is
	# presented after the odds table instead, by the dealer (issue #52 / #176).
	_target_round_handoff = true
	var wallet_before_transfer := _machine_scene_lucidity_before
	var score_before_settlement := int(RunStateStore.scoreEarned)
	var completed := RunStateStore.complete_wealth_target()
	if completed.is_empty():
		_stop_wealth_target_transition()
		_wealth_target_transition_active = false
		_set_sequence_lock(false)
		return
	if bool(completed.get("final", false)):
		_wealth_target_transition_active = false
		_stop_wealth_target_transition()
		_post_spin_sequence_active = false
		var final_run := {
			"neurons": RunStateStore.neurons,
			"scoreEarned": RunStateStore.scoreEarned,
			"lucidityCoins": _machine_lucidity_after_deductions(),
		}
		_show_ending("wealth", final_run)
		return
	var wallet_after_deductions := _settle_machine_lucidity_after_deductions(
		completed, score_before_settlement)
	_stop_wealth_target_transition()
	_wealth_target_transition_active = false
	_post_spin_sequence_active = false
	# Every intermediate target now opens the same route offer. Pacte is the
	# run-start ceremony; the between-machine AUGMENT and POWER cards are smaller
	# single-deck investments and never reopen the full Pacte scene.
	_set_sequence_lock(false)
	if RunStateStore.begin_target_round():
		# The route offer is revealed under a solid black handoff while the net wallet
		# remainder keeps counting up. The persistent transition layer carries the row
		# across the scene swap, so the choice screen appears before the count finishes.
		SceneNav.change_to(ROUTE_SCENE, SceneNav.TransitionKind.WALLET, -1,
			wallet_before_transfer, wallet_after_deductions)
		return
	# A failed transition should not strand the run behind a visual lock. The
	# target has already been paid out; the next HUD refresh can retry normally.
	_update_hud()

func _stop_wealth_target_transition() -> void:
	_end_tv_blackout()
	if _wealth_target_transition != null and is_instance_valid(_wealth_target_transition):
		_wealth_target_transition.queue_free()
	_wealth_target_transition = null

func _do_spin(compulsive := false) -> void:
	if _spinning_anim or _spin_launch_pending or _reroll_anim_active or _rewind_anim_active:
		return
	# A pending loss is confirmed by the next manual spin. Powers still have the
	# current reveal's rescue window, but pressing SPIN means the pair/triple
	# was not rescued and the gauge loses one level before the new spin starts.
	if _sequence_lock_active and not RunStateStore.comboDefeatPending:
		return
	if RunStateStore.comboDefeatPending:
		_on_pending_combo_declined()
		if _sequence_lock_active or _post_spin_sequence_active \
				or RunStateStore.runPhase != "running" \
				or RunStateStore.dealerIncoming or RunStateStore.compulsiveSpinSkips > 0:
			return
	if _dealer_offer_popup != null:
		return
	if not compulsive and not RunStateStore._can_act():
		return
	_clear_boost_zero_linger()
	var expiring_boost_counters := _capture_expiring_boost_counters()
	_clear_targeting()
	_callouts.stop_win() # last spin's PAIR/TRIPLE callout must not outlive its win
	_callouts.stop_combo() # finish the previous Win Boost beat before the next reveal
	_close_score_table()
	_copy_source = -1 # abandon any half-armed white-powder copy
	_refresh_jackpot_lamp(false)
	var locked_before := RunStateStore.lockedReels.duplicate()
	# White Powder (issue #34): hideResultSpins is consumed inside spin(), so read it
	# before spinning — this spin's result reveals as "?" covers.
	var hide_this_spin := RunStateStore.hideResultSpins > 0
	# Serum (issue #53): blurReelsSpins is consumed inside spin() too; this spin's
	# result hides the top/bottom adjacent strip symbols.
	var blur_this_spin := RunStateStore.blurReelsSpins > 0
	# Tobacco's hidden reel is likewise active this spin (pairBoostSpins decrements in
	# spin()), so read it now to pop its deferred "1 REEL HIDDEN" when it first bites.
	var tobacco_this_spin := RunStateStore.pairBoostSpins > 0
	var pill_guaranteed_spin := _pill_guaranteed_spin_pending()
	# Hold HUD deltas from the commit until the score popup lands: spin() fires
	# state_changed synchronously, which would otherwise pop the new multiplier /
	# bars / lamp during the SPIN press (issue #54). The SPINS LEFT counter is the
	# exception — it must drop with the neuron cost right now (issue #80). Free
	# spins never show in the counter (the FREE SPIN banner carries them), so a
	# grant made by this spin needs no counter hold.
	_hud_delta_hold = true
	var result: Variant = RunStateStore.spin(compulsive)
	if result == null:
		_hud_delta_hold = false
		return
	# Heart restores run spins inside spin(), but hold that gain visually until the
	# triple reveal so the counter rises with its +1/+2/+3 fly-in.
	if String(result.get("winType", "")) == "heart":
		_pending_spin_gain += clampi(int(result.get("heartCount", 0)), 0, 3)
	_apply_expiring_boost_linger(expiring_boost_counters)
	_update_hud() # SPINS LEFT drops with the spent neuron immediately
	_set_hidden_result_active(consumable_fx_enabled and hidden_fx_enabled and hide_this_spin)
	_reel_symbols.set_adjacent_hidden(consumable_fx_enabled and blur_this_spin)
	# Issue #76: a deferred downside pops the moment it bites — the spin it applies to.
	if hide_this_spin:
		_pop_deferred_negative("cons_white_powder")
	if blur_this_spin:
		_pop_deferred_negative("cons_focus")
	if tobacco_this_spin:
		_pop_deferred_negative("cons_cigarette")
	if pill_guaranteed_spin:
		_show_deferred_positive("item_pill")
	_final_reels = result["reels"]
	# Third-reel tension: if reels 1 & 2 will match, hold reel 3 a little longer.
	var tension := TENSION_DELAY if String(_final_reels[0]) == String(_final_reels[1]) else 0.0
	_reel_stop_times = [0.55, 1, 1.4 + tension]
	if _active_hidden_reel_count() > 0:
		_reel_stop_times[2] = _reel_stop_times[1]
	# Eye triple: the revealed reel was already committed at tap time (issue #53);
	# reels 0/1 also stop early (reel 2 stays last: reveal-complete keys off its time).
	if _reveal_reel_next_spin >= 0 and _reveal_reel_next_spin < 2:
		_reel_stop_times[_reveal_reel_next_spin] = 0.2
	_reveal_reel_next_spin = -1
	# Button depression precedes the existing reel/reward sequence.
	_spin_launch_pending = true
	_spin_button.disabled = true
	_refresh_controls()
	await get_tree().create_timer(SPIN_PRESS_TIME).timeout
	if not is_inside_tree() or not _spin_launch_pending:
		_hud_delta_hold = false
		return
	_spin_launch_pending = false
	_start_reel_spin_animation(locked_before)
	_spinning_anim = true
	_anim_elapsed = 0.0
	_blur_accum = 0.0

func _process(delta: float) -> void:
	if _reroll_anim_active:
		_step_reroll(delta)
	if _rewind_anim_active:
		_step_rewind_restore(delta)
	if _flatline.counting_down():
		_flatline.step(delta)
	_step_multiplier_fx(delta)
	_dealer_bar.step_progress(delta)
	_augments.step_glitch(delta)
	_wealth.step_bar_animation(delta)
	_dealer_bar.step_beep(delta)
	_tv.step_banner_blink(delta)
	_boosts.step_popup(delta)
	_try_start_power_coin_flow()
	if not _spinning_anim:
		return
	_anim_elapsed += delta
	_blur_accum += delta
	if _blur_accum >= SPIN_FRAME_TIME:
		_blur_accum = 0.0
		_spin_frame = (_spin_frame + 1) % SPIN_FRAME_COUNT
		for i in 3:
			if not bool(_locked_reels_during_spin[i]) and _anim_elapsed < float(_reel_stop_times[i]):
				_reel_blur.set_spin_frame(i, _spin_frame)
	for i in 3:
		var stop_sfx_time := maxf(0.0, float(_reel_stop_times[i]) - REEL_STOP_SFX_LEAD_TIME)
		if not bool(_locked_reels_during_spin[i]) and _anim_elapsed >= stop_sfx_time:
			_play_reel_stop_sfx(i)
	for i in 3:
		if not bool(_locked_reels_during_spin[i]) and _anim_elapsed >= float(_reel_stop_times[i]) and not _reel_symbols.center(i).visible:
			_reveal_reel(i)
	if _anim_elapsed >= _reel_stop_times[2]:
		for i in 3:
			_reveal_reel(i)
		_reel_blur.hide_spin_strips()
		if _spin_sheet_sprite != null:
			_spin_sheet_sprite.visible = false
		_spinning_anim = false
		_on_reveal_complete()

func _start_reel_spin_animation(locked_before: Array) -> void:
	_play_sfx(&"reel_spin")
	_locked_reels_during_spin = locked_before.duplicate()
	# Play the authored spin-blur sheet as three clipped reel sprites. Each clip
	# hides the moment that reel's final symbol lands.
	_use_full_spin_sheet = false
	_spin_frame = 0
	if _spin_sheet_sprite != null:
		_spin_sheet_sprite.visible = false
	var visible_count := _visible_reel_count()
	for i in 3:
		if i >= visible_count:
			_locked_reels_during_spin[i] = true
		var locked := bool(_locked_reels_during_spin[i])
		_reel_stop_sfx_played[i] = locked
		_reel_symbols.set_visible(i, locked)
		_reel_blur.set_cover(i, locked)
		_reel_blur.set_spin_frame(i, _spin_frame)
		_reel_blur.set_spin_visible(i, not locked)

func _on_reveal_complete() -> void:
	_stop_sfx(&"reel_spin")
	if _post_spin_sequence_active:
		return
	_post_spin_sequence_active = true
	_run_post_reveal_sequence()

func _run_post_reveal_sequence() -> void:
	RunStateStore.set_spinning(false)
	_set_sequence_lock(true)
	_update_hud()
	_refresh_lock_art()
	# Joker's dealer assist resolves before the reward pop so any rescued pair or
	# triple is scored and reacted to as part of this reveal.
	var dealer_help := RunStateStore.maybe_dealer_help()
	if not dealer_help.is_empty():
		_refresh_reels_from_state()
		_refresh_lock_art()
		_power_callout.show_power(String(dealer_help.get("power", "")))
		await get_tree().create_timer(0.55).timeout
		_power_callout.stop()
		_update_hud()
	var reward_time := _emit_score_burst(null) # normal spin: source reel derived from the result
	# Dealer may appear between spins (logic + offers are vector-pinned in dealer.gd).
	RunStateStore.check_dealer_trigger()
	# Aftereffects (multiplier/bar deltas, jackpot lamp, machine reactions, potion
	# fx) only pop once the score popup has been on screen for a beat (issue #54).
	var pop_lead := minf(AFTEREFFECT_POP_DELAY, reward_time)
	if pop_lead > 0.0:
		await get_tree().create_timer(pop_lead).timeout
	_release_hud_delta_hold()
	_refresh_jackpot_lamp()
	_apply_machine_reactions(false)  # flatline-result / triple reactions (issue #35)
	_play_potion_spin_fx()           # potion hop + rolled-effect popup (issue #34)
	if reward_time > pop_lead:
		await get_tree().create_timer(reward_time - pop_lead).timeout
	# Instant death from stacked flatline results takes precedence (issue #35).
	if _check_flatline_instant_death():
		_post_spin_sequence_active = false
		return
	# Same precedence as the reveal tail: a beaten target is paid before the warning can
	# return past _finish_post_spin_sequence and its ending check.
	if _proc_wealth_target():
		_post_spin_sequence_active = false
		return
	if RunStateStore.comboDefeatPending:
		if not _discard_moot_combo_defeat():
			# The combo pop has already disappeared; keep the loss art visible while the
			# player decides whether to spend a current-reveal power. The ending check waits
			# until that decision lands,
			# but the dealer does NOT wait for the confirming spin — he walks in over
			# the beeping warning and the rescue window resumes when his offer closes.
			_show_pending_combo_defeat()
			if RunStateStore.dealerIncoming:
				_present_dealer_or_defer()
			return
	_finish_post_spin_sequence()

func _finish_post_spin_sequence() -> void:
	if _check_ending():
		_post_spin_sequence_active = false
		# A wealth-target payout owns the screen AND the sequence lock until its CONTINUE
		# resumes the run — _start_wealth_target_transition took that lock a moment ago and
		# releasing it here would undo it. That mattered most on a losing spin whose passive
		# gain beat the target: one SPIN press confirms the combo loss, procs the target,
		# and then — with the lock dropped — started a fresh spin straight under the
		# overlay, so the payout screen never got to be read (issue #176).
		if not _wealth_target_transition_active:
			_set_sequence_lock(false)
		return
	# Issue #96: a pending compulsion must fully resolve BEFORE the dealer pops.
	# The dealer stays queued in the store (dealerIncoming) and presents again on
	# the compulsive spin's own post-reveal. If the dealer took the scene first,
	# the player would be locked out (compulsiveSpinSkips>0 blocks _can_act) while
	# nothing re-queued the compulsive spin after the dealer closed → softlock.
	if RunStateStore.compulsiveSpinSkips > 0:
		_set_sequence_lock(false)
		# Energy Drink: once the no-decay rush ends the machine takes the compulsive
		# spin by itself — heavy vibration + red overlay, no player input needed.
		_queue_compulsive_spin()
	elif RunStateStore.dealerIncoming:
		# The dealer waits behind any active/pending power-coin sequence; the power flow
		# runs even under the sequence lock while a dealer is queued (req 2). Keeping the
		# lock on holds the player until the dealer actually appears.
		_present_dealer_or_defer()
	else:
		_set_sequence_lock(false)
	_post_spin_sequence_active = false

# ── compulsive takeover ──────────────────────────────────────────────────────────

## A non-paying reveal pauses the normal tail of the spin sequence. The authored
## x2/x3 loss overlay replaces the old text headline while Reroll/Shift remain
## usable through their existing buttons.
## Energy Drink's compulsory spin outranks a loss warning: while the forced spin
## is queued, a protected result's pending defeat is moot — the machine spins next
## no matter what, and that forced result becomes the sole authority for the next
## combo-loss state. resolve(false) keeps the drink-owned x2
## (energy_drink_owns_multiplier), so discarding never lowers the multiplier.
func _discard_moot_combo_defeat() -> bool:
	if not RunStateStore.comboDefeatPending:
		return false
	# Out of spins: the confirming spin can never come, so the rescue window is
	# dead — resolve the loss now and let the ending check proc the flatline
	# without the player having to press SPIN.
	var out_of_spins: bool = int(RunStateStore.neurons) < 1 \
		and int(RunStateStore.freeSpinsRemaining) <= 0
	if RunStateStore.compulsiveSpinSkips <= 0 and not out_of_spins:
		return false
	RunStateStore.resolve_pending_combo_defeat(false)
	_close_pending_combo_defeat()
	return true

func _show_pending_combo_defeat() -> void:
	if not RunStateStore.comboDefeatPending or _pending_combo_overlay != null:
		return
	_set_sequence_lock(true)
	_clear_targeting()
	_pending_combo_overlay = Control.new()
	_pending_combo_overlay.name = "PendingComboDefeat"
	_pending_combo_overlay.size = Vector2(SRC_W, SRC_H)
	_pending_combo_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pending_combo_overlay.z_index = 96
	add_child(_pending_combo_overlay)
	_callouts.set_loss_display(int(RunStateStore.pendingComboMultiplier))
	_callouts.start_loss_beep()
	_refresh_controls()

func _on_pending_combo_declined() -> void:
	if not RunStateStore.comboDefeatPending:
		return
	RunStateStore.resolve_pending_combo_defeat(false)
	_close_pending_combo_defeat()
	_finish_post_spin_sequence()
func _close_pending_combo_defeat() -> void:
	_callouts.stop_loss_beep()
	_callouts.set_loss_display(0)
	if _pending_combo_overlay != null:
		_pending_combo_overlay.queue_free()
		_pending_combo_overlay = null
	_refresh_controls()

## A rescue cancels the warning the moment the store clears the pending flag — the
## beep and the losing-state art must not linger through the reward presentation.
func _maybe_cancel_combo_defeat_warning(was_pending: bool) -> void:
	if was_pending and not RunStateStore.comboDefeatPending:
		_close_pending_combo_defeat()

## Who may draw on the TV is TvOwnership's question; these forward to it because the
## smoke checks and MachineView call them under these names. See that class for the
## two-tier model (a callout owns the screen outright, the FREE SPINS banner is a
## weaker owner that leaves the dealer interface lit beside it).
func _begin_tv_info_pop(source: StringName) -> void:
	_tv.begin_pop(source)

func _end_tv_info_pop(source: StringName) -> void:
	_tv.end_pop(source)

func _tv_content_muted() -> bool:
	return _tv.content_muted()

func _tv_callout_active() -> bool:
	return _tv.callout_active()

func _hide_tv_info_layers() -> void:
	_tv.hide_layers()

func _queue_compulsive_spin() -> void:
	if _compulsive_queued or RunStateStore.runPhase != "running":
		return
	_compulsive_queued = true
	_play_compulsive_takeover()

## True while another sequence must finish before the machine can seize the spin.
## The compulsion is persistent pending state: being blocked defers it, never drops it.
func _compulsive_spin_blocked() -> bool:
	return _spinning_anim or _spin_launch_pending or _reroll_anim_active \
		or _post_spin_sequence_active or _dealer_offer_popup != null

func _play_compulsive_takeover() -> void:
	await get_tree().create_timer(0.55).timeout
	# The forced spin must survive temporary locks (Energy-Drink softlock): while a
	# spin animation, post-spin sequence, dealer popup, or combo warning is live,
	# keep the request queued and retry — compulsiveSpinSkips>0 locks the player
	# out, so dropping the request here would strand the run.
	while is_inside_tree() and RunStateStore.runPhase == "running" \
			and RunStateStore.compulsiveSpinSkips > 0 and _compulsive_spin_blocked():
		await get_tree().create_timer(0.2).timeout
	if not is_inside_tree() or RunStateStore.runPhase != "running" \
			or RunStateStore.compulsiveSpinSkips <= 0:
		_compulsive_queued = false
		_hide_compulsive_overlay()
		return
	# Issue #76: FORCED SPIN is Energy Drink's deferred downside — pop it now, as the
	# machine seizes the spin, so it reads as a dramatic takeover rather than a warning
	# buried in the on-use popup several spins ago.
	_pop_deferred_negative("item_energy_drink")
	if compulsive_fx_enabled:
		_show_compulsive_overlay()
		_play_compulsive_shake()
		await get_tree().create_timer(0.5).timeout
	_compulsive_queued = false
	if not is_inside_tree() or RunStateStore.runPhase != "running":
		_hide_compulsive_overlay()
		return
	# A loss warning left over from the last protected spin cannot gate the machine's
	# own spin — discard it now so _do_spin(true) doesn't refuse and requeue forever
	# (the old circular wait).
	if _discard_moot_combo_defeat():
		_set_sequence_lock(false)
	_do_spin(true)
	if not RunStateStore.isSpinning and RunStateStore.compulsiveSpinSkips > 0 \
			and RunStateStore.runPhase == "running":
		# _do_spin refused (a lock or overlay raced in) — the pending forced spin
		# is not consumed; requeue it instead of leaving the machine idle.
		_queue_compulsive_spin()
		return
	if _compulsive_overlay != null:
		var tw := create_tween()
		tw.tween_interval(1.4) # reels settle, then the red haze lifts
		tw.tween_property(_compulsive_overlay, "modulate:a", 0.0, 0.4)
		tw.tween_callback(_hide_compulsive_overlay)

func _show_compulsive_overlay() -> void:
	if _compulsive_overlay == null:
		_compulsive_overlay = ColorRect.new()
		_compulsive_overlay.name = "CompulsiveOverlay"
		_compulsive_overlay.color = compulsive_overlay_color
		_compulsive_overlay.size = Vector2(SRC_W, SRC_H)
		_compulsive_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_compulsive_overlay.z_index = 90
		add_child(_compulsive_overlay)
	_compulsive_overlay.modulate.a = 0.0
	_compulsive_overlay.visible = true
	var tw := create_tween()
	tw.tween_property(_compulsive_overlay, "modulate:a", 1.0, 0.18)

func _hide_compulsive_overlay() -> void:
	if _compulsive_overlay != null and is_instance_valid(_compulsive_overlay):
		_compulsive_overlay.visible = false

## Much harder shake than the on-use cocktail wobble — the machine is in charge.
func _play_compulsive_shake() -> void:
	if _cocktail_shake_tween != null and _cocktail_shake_tween.is_valid():
		_cocktail_shake_tween.kill()
	if _nudge_tween != null and _nudge_tween.is_valid():
		_nudge_tween.kill()
	position.x = 0.0
	_cocktail_shake_tween = create_tween()
	var swings := 14
	var step := compulsive_shake_time / float(swings + 1)
	for s in swings:
		var dir := 1.0 if s % 2 == 0 else -1.0
		_cocktail_shake_tween.tween_property(self, "position:x", compulsive_shake_strength * dir, step)
	_cocktail_shake_tween.tween_property(self, "position:x", 0.0, step)

func _update_hud() -> void:
	if _wealth_ending_is_visible():
		# The wealth overlay owns the final presentation. Store commits can still emit
		# state_changed while it is open, but those refreshes must not redraw the TV bars.
		_set_tv_progress_bars_visible(false)
		return
	_refresh_tv_indicators()
	_refresh_spin_label()
	_refresh_machine_credits()
	_augments.refresh_pacte_badges()
	_refresh_controls()
	_refresh_consumable_fx()
	_maybe_present_card_unlocks()
	_restore_dealer_overlay_from_state()

func _dealer_interaction_active() -> bool:
	return bool(RunStateStore.dealerPending)

func _dealer_overlay_is_live() -> bool:
	return _dealer_offer_popup != null \
		and is_instance_valid(_dealer_offer_popup) \
		and _dealer_offer_popup.is_inside_tree()

## Restore the only presentation that may be reconstructed from run state.  HUD,
## TV and score animations can hide individual layers, but none may clear a live
## dealer interaction or make it rely on a stale Control reference.
func _restore_dealer_overlay_from_state() -> void:
	if not _dealer_interaction_active():
		return
	if _dealer_overlay_is_live():
		_dealer_offer_popup.visible = true
		_dealer_overlay = _dealer_offer_popup
		_set_sequence_lock(true)
		_stash.set_elevated(true)
		_stash.set_icons_visible(true)
		return
	_show_dealer_offers()

## A card earned mid-spin waits for the reels, the power coins, the payout sequence
## and any ending screen to finish: the unlock popup takes over the whole scene, so
## raising it over a running presentation would cut the spin the player is watching
## short. The wealth ending is the extreme case — its card is celebrated only once
## the player has left that screen (the menu drains the same queue).
func _can_present_card_unlock() -> bool:
	return not _target_round_handoff \
		and not RunStateStore.isSpinning \
		and not _spinning_anim \
		and not _spin_launch_pending \
		and not _reroll_anim_active \
		and not _rewind_anim_active \
		and not _sequence_lock_active \
		and not _post_spin_sequence_active \
		and not _power_sequence_active() \
		and not _wealth_target_transition_active \
		and not RunStateStore.comboDefeatPending \
		and _overlay == null

## Drains anything the gate above held back, once the machine is idle again.
func _maybe_present_card_unlocks() -> void:
	if _unlock_popup == null or not is_instance_valid(_unlock_popup):
		return
	if _unlock_popup.visible:
		return
	_unlock_popup.present_next()

func _wealth_ending_is_visible() -> bool:
	return _overlay != null and _overlay.get_node_or_null("WealthEndingOverlay") != null

## Lets the held HUD deltas (multiplier badge, bars, jackpot lamp) pop, once the
## score popup has had its beat on screen.
func _release_hud_delta_hold() -> void:
	if not _hud_delta_hold:
		return
	_hud_delta_hold = false
	_update_hud()
	_refresh_jackpot_lamp()

# The authored spin_number Label stays as an anchor/editor placeholder and
# renders no text; the live number is the SPINS LEFT readout under the tube.
func _refresh_spin_label() -> void:
	if _spin_label != null:
		_spin_label.text = ""

# "-1 NEURON" popup — flatline/neuron-loss overlay only. Spawns above the overlay's
# neuron meter, timed with its losing pop.
func _show_neuron_spend_feedback(feedback_parent: Control, center: Vector2) -> void:
	if feedback_parent == null:
		return
	if _neuron_spend_label != null and is_instance_valid(_neuron_spend_label):
		_neuron_spend_label.queue_free()
	var label_position := center - Vector2(35.0, 6.0)
	_neuron_spend_label = Label.new()
	_neuron_spend_label.name = "NeuronSpendFeedback"
	_neuron_spend_label.add_to_group(WEALTH_TRANSIENT_FX_GROUP)
	_neuron_spend_label.text = "-1 NEURON"
	_neuron_spend_label.position = label_position
	_neuron_spend_label.size = Vector2(70.0, 12.0)
	_neuron_spend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_neuron_spend_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_neuron_spend_label.z_index = 10
	_neuron_spend_label.add_theme_font_size_override("font_size", 8)
	if _font != null:
		_neuron_spend_label.add_theme_font_override("font", _font)
	_neuron_spend_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.45))
	_neuron_spend_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_neuron_spend_label.add_theme_constant_override("outline_size", 1)
	feedback_parent.add_child(_neuron_spend_label)
	var tw := create_tween()
	tw.tween_interval(NeuronMeter.LOSS_ANIM_DELAY) # rises as the meter pops its frame
	tw.set_parallel(true)
	tw.tween_property(_neuron_spend_label, "position:y", label_position.y - 14.0, 1.0)
	tw.tween_property(_neuron_spend_label, "modulate:a", 0.0, 1.0).set_delay(0.35)
	tw.set_parallel(false)
	tw.tween_callback(Callable(_neuron_spend_label, "queue_free"))

func _refresh_reels_from_state() -> void:
	var lr: Variant = RunStateStore.lastResult
	if lr == null:
		return
	_reel_symbols.set_all_visible(true)
	for i in 3:
		# An armed Heart previews immediately: every strip symbol — centre and
		# adjacent — turns into a heart until the next spin resolves the tier.
		_reel_symbols.set_symbol(i, "heart" if RunStateStore.heartPowerArmed \
			else String(lr["reels"][i]))
	_refresh_lock_art()

func _refresh_lock_art() -> void:
	for i in _lock_sprites.size():
		var lock: Sprite2D = _lock_sprites[i]
		var remaining := int(RunStateStore.lockedReelSpins[i])
		if lock != null:
			lock.visible = remaining > 0
		if i < _lock_count_labels.size():
			var label: Label = _lock_count_labels[i]
			label.visible = remaining > 0
			label.text = str(remaining) if remaining > 0 else ""

func _refresh_tv_indicators() -> void:
	# The FREE SPIN banner lights the TV while the next spin is free (banked free
	# spins or an Energy Drink rush); the spins tube lives off-TV and stays put.
	# It resolves FIRST because it is itself a TV owner (_tv_content_muted): every
	# readout below reads the mute it just set, so the banner never shares the screen
	# with the objective, the dealer countdown or the item icons for a frame.
	_refresh_free_spin_banner()
	_refresh_target_readout()
	# The SPINS LEFT counter reflects the neuron cost the moment the SPIN is pressed,
	# so it always updates — it is NOT held with the reward deltas (issue #80).
	var spins_left := _display_spins_left()
	if _health_bar_sprite != null:
		# A HUD refresh re-derives the tube from state (an ending that wants it
		# hidden skips this refresh entirely, see _update_hud).
		_health_bar_sprite.visible = true
		_set_sheet_frame(_health_bar_sprite,
			clampi(spins_left, 0, HEALTH_BAR_FRAME_COUNT - 1))
	# The numeric readout under the tube follows the same budget (spends, gains,
	# protections all land here via _update_hud), capped at MAX_NEURONS spins.
	if _spins_left_label != null:
		_spins_left_label.visible = true
		_spins_left_label.text = str(spins_left)
		_spins_left_label.add_theme_color_override(
			"font_color",
			SPINS_LEFT_MAX_COLOR if spins_left >= MAX_RUN_SPINS else SPINS_LEFT_NORMAL_COLOR)
	# Issue #155: the dealer bar advances with the inverse multiplier step (not the
	# reward hold), so its progress changes the moment the SPIN is pressed.
	_refresh_dealer_countdown()
	# Active-boost duration icons update with the spin cost, not the reward hold, so the
	# count ticks down the moment the boost is spent on a spin (issue #76).
	_refresh_boost_indicators()
	# COMBO is a transient Wealth-bar pop. Refreshing the HUD must not leave an old
	# stage mounted after its bonus has landed; an active pop protects itself.
	if not _hud_delta_hold:
		_callouts.refresh_combo()
	# The wealth odometer is a score total. Hold it (with the multiplier badge and
	# jackpot lamp) until the score popup lands (issue #54).
	if _hud_delta_hold:
		return
	# COMBO has a second payout beat. Keep the base PAIR/TRIPLE total visible until
	# the Wealth-bar pop's bonus lands, then release the final total.
	if _callouts.pending_score() >= 0:
		return
	if RunStateStore.scoreEarned < _wealth.display_score():
		_set_display_lucidity(RunStateStore.scoreEarned)

## The number of spins the neuron pool affords: ceil(neurons / decay) — the SAME
## budget spin() uses. Banked free spins deliberately do NOT inflate the counter:
## a free spin means the NEXT spin costs nothing (the FREE SPIN banner says so),
## not that the meter gained a spin. Spin restores in flight are held back by
## _pending_spin_gain so the counter ticks up when the "+N" popup lands (issue #66).
func _spin_decay() -> int:
	return maxi(1, Economy.compute_neuron_decay(RunStateStore.ownedUpgrades))

## Spins the current neuron pool affords, matching run_state_store.spin()'s budget.
func _neuron_spins_left() -> int:
	if RunStateStore.neurons <= 0:
		return 0
	return mini(MAX_RUN_SPINS,
		maxi(1, int(ceili(float(RunStateStore.neurons) / float(_spin_decay())))))

func _display_spins_left() -> int:
	return maxi(0, _neuron_spins_left() - _pending_spin_gain)

func _current_display_spins_left() -> int:
	return _display_spins_left()

## The legacy method name is kept because scene smoke hooks call it; its value is
## now the cumulative score shown by the wealth odometer.
func _set_display_lucidity(value: int, animated := true, duration_override := 0.0) -> void:
	_wealth.set_score(value, animated, duration_override)
	# The objective bar reads the shown score, so it moves with the reels rather than
	# waiting for the next HUD refresh (some release paths update the digits alone).
	_refresh_target_readout()

## What the objective bar should fill to. NOT RunStateStore.scoreEarned: while the
## reward deltas are held back (or COMBO's second beat is pending) the win has not
## been revealed yet, and a bar that filled early announced the payout before the
## number did. Only the machine knows about either hold, so the readout is told.
func _refresh_target_readout() -> void:
	var shown := int(RunStateStore.scoreEarned)
	if _hud_delta_hold or _callouts.pending_score() >= 0:
		shown = _wealth.display_score()
	_wealth.refresh_target(shown, _tv_callout_active(), _tv_content_muted())

## Whether the cabinet's lamp should be lit is a question about the last result
## and about whether the HUD is still holding its deltas back — both the
## machine's. The lamp itself is ScoreBursts'; this answers and delegates.
func _refresh_jackpot_lamp(use_result := true) -> void:
	var lit := false
	if use_result and RunStateStore.lastResult != null:
		lit = bool(RunStateStore.lastResult.get("isJackpot", false))
	# While the delta hold is up the lamp waits with the other aftereffects, so it
	# pops with the score popup rather than ahead of it.
	_bursts.refresh_jackpot_lamp(lit, _hud_delta_hold)

# Quick horizontal machine shake — feedback on a Lucidity gain / jackpot.
func _nudge(strength: float) -> void:
	if _nudge_tween != null and _nudge_tween.is_valid():
		_nudge_tween.kill()
	position = Vector2.ZERO
	_nudge_tween = create_tween()
	_nudge_tween.tween_property(self, "position:x", strength, 0.04)
	_nudge_tween.tween_property(self, "position:x", -strength * 0.6, 0.04)
	_nudge_tween.tween_property(self, "position:x", 0.0, 0.05)

# ── score bursts (visual only — score-burst presentation) ──────────────

# Sync the "already announced" markers to the current result so returning from the
# dealer/scores never replays an old burst, and a power then computes its true gain.
func _init_burst_tracking() -> void:
	if RunStateStore.lastResult != null:
		_bursts.remember(int(RunStateStore.spinCount),
			int(RunStateStore.lastResult["scoreEarned"]))
	else:
		_bursts.remember(-1, 0)
	_coin_prev_lucidity = RunStateStore.lucidityCoins
	_set_display_lucidity(RunStateStore.scoreEarned, false)

# Normal-spin source reel: a pair on the first two reels pops on reel 2 (index 1);
# every other win reads from reel 3 (index 2).
func _derive_source_reel(reels: Array) -> int:
	if _active_hidden_reel_count() > 0:
		return 1
	return 1 if (String(reels[0]) == String(reels[1]) and String(reels[1]) != String(reels[2])) else 2

func _active_hidden_reel_count() -> int:
	var lr: Variant = RunStateStore.lastResult
	if lr != null and (lr as Dictionary).has("hiddenReelCount"):
		return clampi(int((lr as Dictionary)["hiddenReelCount"]), 0, 2)
	return 0

func _visible_reel_count() -> int:
	return maxi(1, 3 - _active_hidden_reel_count())

## How many reels a power may touch, counting from reel 0 — blinded reels are always the
## last ones, the same slice the scoring keeps.
##
## A power spent on a blinded reel does nothing the machine will ever read: Tunnel Vision
## and Tobacco cut those reels out of the scoring, so rerolling, shifting, cheating or
## copying into one changes a symbol nobody scores. The reel is also physically covered,
## so the player cannot even see what they changed. Powers are the scarcest resource in a
## run, and the picker used to happily let one be burnt on a dead reel; it now stops
## offering them, and every entry point that takes a reel index refuses one anyway (the
## dealer's help can name a reel without going through a picker).
func _power_reel_count() -> int:
	return maxi(1, 3 - _blind_reel_count())

func _reel_is_dead(reel_index: int) -> bool:
	return reel_index < 0 or reel_index >= _power_reel_count()

# The lone unpaired reel of a pair (-1 if none).
func _solo_reel(reels: Array) -> int:
	var a := String(reels[0]); var b := String(reels[1]); var c := String(reels[2])
	if a == b and b != c: return 2
	if b == c and a != b: return 0
	if a == c and a != b: return 1
	return -1

# source_reel: int for a power override, or null for a normal spin (derive it).
func _emit_score_burst(source_reel) -> float:
	var lr: Variant = RunStateStore.lastResult
	if lr == null:
		return 0.0
	var reward_time := 0.0
	var spin_count := int(RunStateStore.spinCount)
	var is_new_spin := spin_count != _bursts.prev_spin()
	var score := int(lr["scoreEarned"])
	var gain := score if is_new_spin else score - _bursts.prev_score()
	_bursts.remember(spin_count, score)

	var win_type := String(lr["winType"])
	if is_new_spin or gain > 0:
		_react_dealer(win_type)
	var reels: Array = lr["reels"]
	var combo_applied := bool(lr.get("winBoostApplied", false)) \
		and win_type in SpinResult.PAYING_WIN_TYPES
	var combo_bonus := maxi(0, int(lr.get("winBoostBonus", 0))) if combo_applied else 0
	var combo_number := clampi(int(lr.get("winBoostCombo", 1)), 1, WinCallouts.COMBO_EFFECT_FRAMES)
	var combo_percent := clampi(int(lr.get("winBoostPercent", 0)), 0, 45)
	var combo_base_gain := maxi(0, gain - combo_bonus)
	if combo_applied and lr.has("winBoostBaseScore"):
		combo_base_gain = mini(combo_base_gain, maxi(0, int(lr["winBoostBaseScore"])))
	var color: Color = MULT_COLORS[clampi(int(RunStateStore.lastEffectiveBet), 1, 3)]
	_coin_prev_lucidity = int(RunStateStore.lucidityCoins)
	# A previous sequence can be interrupted by a power or a scene transition. Make
	# sure a held final odometer value is not mistaken for this result's base payout.
	_callouts.flush_held_score()
	# Score is the wealth bar's source of truth. The number reels begin their roll with
	# the score popup; no individual Lucidity coins leave the cash tray for this HUD.
	# A jackpot rolls them slowly on purpose (issue #181) — watching the money land is
	# the reward. The catch-up above keeps the default pace: it is a correction, not a
	# payout beat.
	var wealth_score := int(RunStateStore.scoreEarned)
	var roll_override := JACKPOT_ODOMETER_ROLL_TIME if gain > 0 and win_type == "jackpot" else 0.0
	if combo_bonus > 0 and _callouts.combo_sprite() != null:
		_set_display_lucidity(maxi(_wealth.display_score(), wealth_score - combo_bonus), true, roll_override)
	elif wealth_score > _wealth.display_score():
		_set_display_lucidity(wealth_score, true, roll_override)

	# Cocktail miss: one "+rarity" mini-burst from each reel.
	if is_new_spin and win_type == "miss" and bool(lr.get("cocktailApplied", false)):
		for i in _visible_reel_count():
			_bursts.spawn("", _cocktail_reel_bonus(String(reels[i]), float(lr["scoreMultiplier"])), COCKTAIL_COLOR, i)
		_nudge(0.8)
		return maxf(reward_time, ScoreBursts.BURST_TIME)

	# Heart is a guaranteed triple that pays run spins instead of score. Reuse the
	# authored TRIPLE callout/music and the vial-style reaction flash; the landed
	# tier supplies the little +1/+2/+3 spin gain.
	if is_new_spin and win_type == "heart":
		var heart_tier := clampi(int(lr.get("heartTier", lr.get("heartCount", 1))), 1, 3)
		_play_sfx(&"triple_win")
		_callouts.play_win("triple", 0, "+ %d" % heart_tier)
		_play_spin_gain_fx(heart_tier, _reel_window_center(), 0.55, true)
		_spawn_reaction_flash(triple_vial_color, "+%d SPINS" % heart_tier)
		_nudge(1.0)
		return maxf(reward_time, ScoreBursts.BURST_TIME)

	# A rescore that doesn't increase the score must NOT pop (gain <= 0).
	if gain > 0 and win_type != "miss":
		# Jackpot is special (issue #22): a large GOLDEN number rising out of the
		# machine centre — never a reel-anchored pair/triple-style burst.
		if win_type == "jackpot":
			_play_sfx(&"jackpot_win")
			_bursts.spawn_jackpot(combo_base_gain)
			var fountain_time := _spawn_jackpot_coin_fountain()
			_bursts.flash_jackpot_lamp(_refresh_jackpot_lamp)
			_nudge(2.2)
			var jackpot_combo_time: float = _callouts.queue_combo(
				combo_number, combo_bonus, combo_percent) if combo_applied else 0.0
			if combo_bonus > 0 and jackpot_combo_time > 0.0:
				_callouts.hold_score(wealth_score)
			# The lock has to outlast the slow reel roll AND the coin spray, or the next
			# spin can be pulled while the money is still landing (issue #181).
			return maxf(reward_time, maxf(
				maxf(maxf(ScoreBursts.BURST_TIME * 1.25, ScoreBursts.JACKPOT_FLASH_TIME), jackpot_combo_time),
				maxf(JACKPOT_ODOMETER_ROLL_TIME + JACKPOT_ROLL_TAIL, fountain_time)))
		var label := "TRIPLE" if win_type == "triple" else ("PAIR" if win_type == "pair" \
			else ("HEART" if win_type == "heart" else "BONUS"))
		if win_type == "triple":
			_play_sfx(&"triple_win")
		elif win_type == "pair":
			_play_sfx(&"pair_win")
		_callouts.play_win(win_type, combo_base_gain)
		# Issue #76: a flatline strike charged this win — call it out and tint it red so
		# the doubled score reads as the flatline payoff, not a normal pair/triple.
		if is_new_spin and bool(lr.get("flatlineBoostApplied", false)):
			label = "FLATLINE x%d" % EconomyConst.FLATLINE_WIN_BOOST_MULT
			color = flatline_result_color
		var reel := int(source_reel) if source_reel != null else _derive_source_reel(reels)
		if _active_hidden_reel_count() > 0:
			reel = mini(reel, _visible_reel_count() - 1)
		_bursts.spawn(label, combo_base_gain, color, reel)
		_nudge(1.0)
		reward_time = maxf(reward_time, ScoreBursts.BURST_TIME)
		# Cocktail + pair: surface the unpaired reel's rarity gain from its own reel.
		if is_new_spin and bool(lr.get("cocktailApplied", false)) and win_type == "pair":
			var solo := _solo_reel(reels)
			if solo != -1 and solo < _visible_reel_count():
				_bursts.spawn("", _cocktail_reel_bonus(String(reels[solo]), float(lr["scoreMultiplier"])), COCKTAIL_COLOR, solo)
		if combo_applied:
			var combo_time: float = _callouts.queue_combo(combo_number, combo_bonus, combo_percent)
			if combo_bonus > 0 and combo_time > 0.0:
				_callouts.hold_score(wealth_score)
			reward_time = maxf(reward_time, combo_time)
	return reward_time

func _cocktail_reel_bonus(symbol_id: String, score_multiplier: float) -> int:
	var points := int(RunStateStore.COCKTAIL_RARITY_POINTS.get(symbol_id, 0))
	return floori(float(points) * score_multiplier + 0.5)

## Kept as a compatibility hook for consumable callers and older smoke scripts.
## Lucidity no longer animates cash-tray coins into the wealth display; the odometer
## is driven directly by score in _emit_score_burst().
func _spawn_lucidity_coins(_gain: int, _target_lucidity: int) -> float:
	return 0.0

# Power points per gauge frame: one power coin banks this much wealth score (10 for the base
# 50-threshold gauge, 6 with Adrenaline). Cocktail rarity points are part of that score. Lucidity-only bonuses still
# keep the existing restore economy caught up, so the point source is the higher of the two totals.
func _power_bar_step() -> int:
	return maxi(1, int(RunStateStore.effective_coins_per_power_restore() \
		/ (POWER_BAR_FRAMES - 1)))

func _power_point_total() -> int:
	return maxi(0, maxi(int(RunStateStore.scoreEarned), int(RunStateStore.lucidityCoins)))

func _set_power_bar_frame(f: int) -> void:
	_power_bar_frame = clampi(f, 0, POWER_BAR_FRAMES - 1)
	if _power_bar_sprite != null:
		_power_bar_sprite.frame = _power_bar_frame

## Gauge frame for a banked-score value (0 empty .. full).
func _bar_frame_for_score(score: int) -> int:
	return clampi(score / _power_bar_step(), 0, POWER_BAR_FRAMES - 1)

func _power_sequence_active() -> bool:
	return _power_coins_in_flight > 0 or _power_batch_running

func _cash_tray_pos() -> Vector2:
	return COIN_TRAY + CASH_COIN_TRAY_OFFSET # same origin as normal lucidity coins

## Polled every frame. Power coins are held behind the sequence lock (so they don't
## overlap the score burst) EXCEPT while a dealer offer or an already-shown combo-loss
## warning is queued behind them — the score has landed, so the threshold sequence still
## runs to completion (issue #76 follow-up).
func _try_start_power_coin_flow() -> void:
	if _spinning_anim or _spin_launch_pending or _reroll_anim_active:
		return
	if _sequence_lock_active and not _pending_dealer_offer and _pending_combo_overlay == null:
		return
	_advance_power_bar()

## Pure: plan the coins for power points gained since the gauge last caught up. Each coin banks
## Pending restore entries are prefixed so their reset happens before this point fill.
## one step; a full gauge is only completed when a restore is available (else it caps at 4/5 and
## the rest of the gain is discarded — never fake-fills or loops). Returns { steps:
## [{frame, restore}], score: <final banked score>, seen: <power points now> }.
func _compute_power_plan() -> Dictionary:
	var power_points := _power_point_total()
	var gain := power_points - _power_seen_lucidity
	var per := maxi(1, RunStateStore.effective_coins_per_power_restore())
	var step := _power_bar_step()
	var score := _power_bar_score
	var out: Array = []
	# Lucidity.plan_gain (and Potion's direct restore) already removed these powers from
	# abilitiesUsed. Fill the gauge for each of them before planning this gain, and start
	# the point fill from the reset gauge. They must not also count as bar-driven restores.
	var pending_restores := RunStateStore.pendingPowerRestores.size()
	for _restore_index in pending_restores:
		out.append({ "frame": POWER_BAR_FRAMES - 1, "restore": true })
	if pending_restores > 0:
		score = 0
	# Only powers still in abilitiesUsed are available for a later bar-completion restore,
	# and only while a restore charge is banked (issue #181 soft cap). A spent charge
	# reads exactly like an empty pool of powers: the gauge stops at 4/5 rather than
	# completing into a restore it is not allowed to hand out.
	var avail := mini(RunStateStore.abilitiesUsed.size(), RunStateStore.restore_budget_left())
	var g := gain
	while g > 0:
		var to_next := step - (score % step)
		if g < to_next:
			score += g # sub-step remainder banks silently (no coin) — no overshoot/loop
			g = 0
			break
		score += to_next
		g -= to_next
		if score >= per:
			if avail > 0:
				out.append({ "frame": POWER_BAR_FRAMES - 1, "restore": true })
				avail -= 1
				score = 0 # restore resets the gauge; no backlog carries over
			else:
				score = per - step # cap at 4/5
				g = 0 # discard the rest of the gain
				break
		else:
			out.append({ "frame": score / step, "restore": false })
	return { "steps": out, "score": score, "seen": power_points }

func _power_has_pending_work() -> bool:
	return not (_compute_power_plan()["steps"] as Array).is_empty()

func _advance_power_bar() -> void:
	# Flatline / run over: no power-coin visuals at all — snap the gauge and resolve any
	# pending restores silently (the ability was already restored by plan_gain).
	if RunStateStore.runPhase != "running":
		_snap_power_bar()
		_maybe_present_pending_dealer()
		return
	if _power_batch_running or _power_coins_in_flight > 0:
		return # a batch is already flying; it re-advances on completion
	var plan := _compute_power_plan()
	# Commit the logical end state now (so the same gain isn't re-planned); coins animate
	# the frames and restores commit on arrival.
	_power_bar_score = int(plan["score"])
	_power_seen_lucidity = int(plan["seen"])
	var steps: Array = plan["steps"]
	if steps.is_empty():
		# Pending restore steps are part of this plan, so this branch only means
		# that there is no visual work at all.
		_set_power_bar_frame(_bar_frame_for_score(_power_bar_score))
		_maybe_present_pending_dealer()
		return
	_power_batch_running = true
	_launch_power_coin_batch(steps)

## Tea restores an ability instantly (a consumable, not a score event): commit its queued
## restore now and fly a coin from the cash tray straight to the power. No-op if Tea
## restored spins instead of a power (nothing queued).
func _resolve_direct_restore() -> void:
	if RunStateStore.pendingPowerRestores.is_empty():
		return
	var power_id := String(RunStateStore.pendingPowerRestores[0])
	RunStateStore.commit_power_restore(power_id)
	var coin := _coins.make_power_coin(_cash_tray_pos())
	if coin == null:
		_advance_power_bar()
		return
	_power_batch_running = true
	_power_coins_in_flight += 1
	var target := _power_center(power_id)
	var tw := create_tween()
	tw.tween_method(_coins.drive_power_coin.bind(coin, _cash_tray_pos(), target),
		0.0, 1.0, CoinFlights.POWER_FLIGHT_TIME)
	tw.tween_callback(_on_restore_coin_arrived.bind(coin))

func _launch_power_coin_batch(steps: Array) -> void:
	_power_coins_in_flight = 0
	for i in steps.size():
		_launch_power_bank_coin(steps[i], float(i) * POWER_COIN_STAGGER)
	if _power_coins_in_flight == 0: # no coin layer/texture — apply instantly
		_power_batch_running = false
		_advance_power_bar()

## One bank coin: the authored pop sheet plays at the wealth odometer, then the real
## power coin flies from that same point to the gauge. A batch staggers the pop starts so
## several threshold hits read as a quick succession rather than one blended burst.
func _launch_power_bank_coin(stepd: Dictionary, delay: float) -> bool:
	var pop := _coins.make_power_pop()
	var power_tex := _load_texture(CoinFlights.POWER_ASSET, true)
	if pop == null and power_tex == null:
		_apply_power_bank_step(stepd)
		return false
	_power_coins_in_flight += 1
	if pop == null:
		_start_power_bank_coin_flight(stepd, delay)
		return true
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(
			_coins.drive_power_pop.bind(pop), 0.0, 1.0, _coins.power_pop_time())
	tw.tween_callback(_on_power_coin_pop_finished.bind(pop, stepd))
	return true

func _on_power_coin_pop_finished(pop: Sprite2D, stepd: Dictionary) -> void:
	if is_instance_valid(pop):
		pop.queue_free()
	_start_power_bank_coin_flight(stepd, 0.0)

func _start_power_bank_coin_flight(stepd: Dictionary, delay: float) -> void:
	var coin := _coins.make_power_coin(WEALTH_COIN_ORIGIN)
	if coin == null:
		_apply_power_bank_step(stepd)
		_on_power_coin_landed()
		return
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(
			_coins.drive_power_coin.bind(coin, WEALTH_COIN_ORIGIN, POWER_BAR_CENTER),
			0.0, 1.0, CoinFlights.POWER_FLIGHT_TIME)
	tw.tween_callback(_on_power_bank_coin_arrived.bind(coin, stepd))

func _on_power_bank_coin_arrived(coin: Node, stepd: Dictionary) -> void:
	if is_instance_valid(coin):
		coin.queue_free()
	_apply_power_bank_step(stepd)
	_on_power_coin_landed()

func _apply_power_bank_step(stepd: Dictionary) -> void:
	_set_power_bar_frame(int(stepd["frame"]))
	if bool(stepd["restore"]):
		_resolve_bar_restore() # full frame already set; commit the restore, reset to 0

## Gauge just filled with a restore available. Commit the restore NOW (guaranteed once —
## commit is idempotent and the ability was already restored by plan_gain) and reset the
## gauge for the next cycle. The power button re-enabling on the commit is the whole
## feedback: the bank coin that filled the gauge already carried the eye to it, so a
## second coin walking back out to the button only delayed the state it announced.
func _resolve_bar_restore() -> void:
	_set_power_bar_frame(0)
	# Consume a plan_gain restore if one is queued; otherwise the gauge itself brings a
	# spent power back (guaranteed once — both paths remove the id from their source).
	var lit_before := _shown_restore_charges()
	var power_id := ""
	if not RunStateStore.pendingPowerRestores.is_empty():
		power_id = String(RunStateStore.pendingPowerRestores[0])
		RunStateStore.commit_power_restore(power_id)
	else:
		power_id = RunStateStore.bar_restore_power(
			RunStateStore._seed(_power_seen_lucidity * 0x9e3779b9))
	if power_id == "":
		return
	# Only announce a light going out if one actually did — Tea's restores are item
	# effects and cost no charge, so they must not fake a discharge.
	_play_restore_flash(power_id, _shown_restore_charges() < lit_before)

## The restore's whole feedback (issue #181): the spent light blows out and fades from the
## gauge on the same frame the chip flashes back on, both in the machine's cyan. Nothing
## travels between them — the simultaneity IS the causal link the old coin used to draw.
func _play_restore_flash(power_id: String, light_spent: bool) -> void:
	_stop_restore_flash()
	var chip: Sprite2D = _power_sprites.get(power_id) as Sprite2D
	if chip == null and not light_spent:
		return
	# Two independent tweens started on the same frame, rather than one sequenced tween:
	# the glow and the chip MUST begin together — that simultaneity is the whole effect.
	if light_spent and _restore_cap_glow != null:
		# The light is already on its dark frame (the commit above stepped it), so this
		# glow reads as the charge leaving, not as the light still being on.
		_restore_cap_glow.visible = true
		_restore_cap_glow.modulate = RESTORE_FLASH_GLOW_TINT
		var glow_tween := create_tween()
		glow_tween.tween_property(_restore_cap_glow, "modulate",
			Color(1.0, 1.0, 1.0, 0.0), RESTORE_FLASH_GLOW_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		glow_tween.tween_callback(_hide_restore_glow)
		_restore_flash_tweens.append(glow_tween)
	if chip != null:
		_restore_flash_chip = chip
		chip.modulate = RESTORE_FLASH_CHIP_TINT
		# Pulse down/up a couple of times before settling, so the chip reads as powering
		# up rather than simply having been redrawn in a brighter colour.
		var chip_tween := create_tween()
		chip_tween.tween_property(chip, "modulate", Color.WHITE,
			RESTORE_FLASH_PULSE_TIME).set_trans(Tween.TRANS_SINE)
		for _pulse in RESTORE_FLASH_PULSES:
			chip_tween.tween_property(chip, "modulate", RESTORE_FLASH_CHIP_TINT,
				RESTORE_FLASH_PULSE_TIME).set_trans(Tween.TRANS_SINE)
			chip_tween.tween_property(chip, "modulate", Color.WHITE,
				RESTORE_FLASH_PULSE_TIME).set_trans(Tween.TRANS_SINE)
		chip_tween.tween_callback(_finish_restore_chip)
		_restore_flash_tweens.append(chip_tween)
	if light_spent:
		_nudge(RESTORE_FLASH_NUDGE)

func _hide_restore_glow() -> void:
	if _restore_cap_glow != null:
		_restore_cap_glow.visible = false
		_restore_cap_glow.modulate = Color(1.0, 1.0, 1.0, 0.0)

func _finish_restore_chip() -> void:
	if _restore_flash_chip != null and is_instance_valid(_restore_flash_chip):
		_restore_flash_chip.modulate = Color.WHITE
	_restore_flash_chip = null

## Teardown / run reset: never leave a chip stuck overdriven or a glow painted on the gauge.
func _stop_restore_flash() -> void:
	for tween in _restore_flash_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_restore_flash_tweens.clear()
	_hide_restore_glow()
	_finish_restore_chip()

func _on_restore_coin_arrived(coin: Node) -> void:
	if is_instance_valid(coin):
		coin.queue_free()
	_on_power_coin_landed() # no pulse (req 1)

func _on_power_coin_landed() -> void:
	_power_coins_in_flight = maxi(0, _power_coins_in_flight - 1)
	if _power_coins_in_flight == 0:
		_power_batch_running = false
		_advance_power_bar() # more lucidity? else presents any queued dealer offer

## Joker Water: the gauge is emptied and the points that filled it are written off, so the
## next restore starts from scratch. `_power_seen_lucidity` catches up to the run's current
## total in the same breath — otherwise the discarded progress would simply be re-planned
## as a fresh gain on the next spin and the drink would do nothing. Banked score, wealth
## and already-restored powers are untouched: this costs the next restore, not the run.
func _drain_power_bar() -> void:
	_power_bar_score = 0
	_power_seen_lucidity = _power_point_total()
	_set_power_bar_frame(0)

## Resolve the gauge without animation and clear pending restores (visual only). Used on
## the flatline/run-over transition — the gauge itself just holds its current frame.
func _snap_power_bar() -> void:
	_power_seen_lucidity = _power_point_total()
	_set_power_bar_frame(_bar_frame_for_score(_power_bar_score))
	for power_id in RunStateStore.pendingPowerRestores.duplicate():
		RunStateStore.commit_power_restore(String(power_id))

## The cash tray mouth is the machine's geometry, so the fountain is told where to
## spray from rather than reaching for it.
func _spawn_jackpot_coin_fountain() -> float:
	return _coins.spawn_jackpot_fountain(_cash_tray_pos())

func jackpot_coin_fountain_time() -> float:
	return _coins.jackpot_fountain_time()

func _clear_jackpot_coins() -> void:
	_coins.clear_jackpot_coins()

## Centre of the emplacement a power currently occupies. The live button rect is the
## source of truth: powers are re-slotted per loadout and each slot carries its own
## pixel nudge, so the authored hit box only stands in before the buttons exist.
func _power_center(power_id: String) -> Vector2:
	var button: Button = _power_buttons.get(power_id) as Button
	if button != null and is_instance_valid(button) and button.visible:
		return button.position + button.size * 0.5
	var hit: Dictionary = POWER_HITS.get(power_id, POWER_HITS["reroll"])
	return Vector2(float(hit["left"]) + float(hit["width"]) * 0.5, float(hit["top"]) + float(hit["height"]) * 0.5)



# ── frenzy gauge / powers / stash controls ────────────────────────────────────────

## Issue #155: the multiplier strip is a read-only frenzy gauge — wins drive it
## x1 → x2 → x3, a losing spin breaks it, the player never taps it. The badge
## sheet keeps its authored frames: 0/1/2 = x1/x2/x3 lit, 3/5 = the Energy-Drink
## "x2 cap" pair (frame 4, the old machine-forced compulsive x1, is unused now).
func _refresh_multiplier_controls() -> void:
	# The Energy-Drink window owns the gauge through both protected spins and the
	# queued/active compulsory spin, so its engaged x2-cap frame stays visible until
	# the whole effect has resolved.
	if _hud_delta_hold and not RunStateStore.energy_drink_owns_multiplier():
		return # badge keeps its pre-commit frame until the score popup lands
	var cap := 2 if RunStateStore.energy_drink_owns_multiplier() else 3
	var effective := clampi(RunStateStore.betMultiplier, 1, cap)
	var frame := effective - 1
	if cap == 2:
		frame = 5 if effective == 2 else 3
	_set_sheet_frame(_multiplier_sprite, frame)
	_refresh_multiplier_fx(effective)

## Toggles the authored gauge effects: sparks while x2 holds, the glitching "3"
## plus its fire while x3 holds. A rise dings the old multiplier-change sfx.
func _refresh_multiplier_fx(effective: int) -> void:
	if _gauge_shown != 0 and effective > _gauge_shown:
		_play_sfx(&"multiplier_change")
	_gauge_shown = effective
	_apply_multiplier_fx_visibility()

## The losing state owns the gauge presentation while it is up: only its authored
## overlay shows — the normal x2 sparks and the x3 glitch + fire sheets stay
## hidden and come back the moment the loss display closes.
func _apply_multiplier_fx_visibility() -> void:
	var loss_active := _callouts.loss_showing()
	var muted := _tv != null and _tv.callout_active()
	if _multiplier_sprite != null:
		_multiplier_sprite.visible = not muted and not loss_active
	if _mult_fx_2 != null:
		_mult_fx_2.visible = _gauge_shown == 2 and not loss_active and not muted
	if _mult_fx_3 != null:
		_mult_fx_3.visible = _gauge_shown == 3 and not loss_active and not muted
	if _mult_fx_fire != null:
		_mult_fx_fire.visible = _gauge_shown == 3 and not loss_active and not muted

func _step_multiplier_fx(delta: float) -> void:
	var loss_3_active := _callouts.loss_3_showing()
	if (_mult_fx_2 == null or not _mult_fx_2.visible) \
			and (_mult_fx_3 == null or not _mult_fx_3.visible) \
			and not loss_3_active:
		return
	_mult_fx_time += delta
	if _mult_fx_time < MULT_FX_FRAME_TIME:
		return
	_mult_fx_time = fmod(_mult_fx_time, MULT_FX_FRAME_TIME)
	if _mult_fx_2 != null and _mult_fx_2.visible:
		_mult_fx_2.frame = (_mult_fx_2.frame + 1) % MULT_FX_2_FRAMES
	if _mult_fx_3 != null and _mult_fx_3.visible:
		_mult_fx_3.frame = (_mult_fx_3.frame + 1) % MULT_FX_3_FRAMES
	if _mult_fx_fire != null and _mult_fx_fire.visible:
		_mult_fx_fire.frame = (_mult_fx_fire.frame + 1) % MULT_FX_3_FRAMES
	if loss_3_active:
		_callouts.step_loss_3_frame()

## The FREE SPINS banner is a TV owner, so it lives with the arbitration
## (TvOwnership). What the machine still answers is whether a spin is on the way —
## a free-spin grant made by the reveal must not light the banner before the reward
## has landed and spoil the result.
func _spin_in_flight() -> bool:
	return _spinning_anim or _spin_launch_pending or _hud_delta_hold

func _refresh_free_spin_banner() -> void:
	_tv.refresh_banner()

func _set_free_spin_display(active: bool) -> void:
	_tv.set_banner_display(active)

func _build_power_buttons() -> void:
	for id in POWER_IDS:
		var hit: Dictionary = POWER_HITS[id]
		var node_name := "PowerButton%s" % id.capitalize()
		var b := _make_or_bind_hit_button(node_name, {
			"left": hit["left"],
			"top": hit["top"],
			"width": maxf(hit["width"], 11.0),
			"height": hit["height"],
		}, _on_power_pressed.bind(id))
		b.position = Vector2(hit["left"], hit["top"])
		b.size = Vector2(hit["width"], hit["height"])
		_power_buttons[id] = b

# Tap a filled stash slot to use it (drag isn't used here — that's the dealer/overlay
# stash). Gated by the same can-act check the refresh uses, so disabled slots ignore taps.
func _on_stash_input(event: InputEvent, node: Control, slot_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var slots := _stash_slots()
	if slot_index >= slots.size():
		return
	if _dealer_offer_popup != null:
		_begin_dealer_drag(node, String(slots[slot_index]), "stash")
		return
	# The pending-defeat rescue window keeps consumables live (issue #155 follow-up):
	# a corrective item can still cancel the losing state before the confirming spin.
	if (_sequence_lock_active and not RunStateStore.comboDefeatPending) \
			or _spin_launch_pending or not RunStateStore._can_use_consumable() \
			or _reroll_anim_active or _rewind_anim_active:
		return
	_on_stash_pressed(slot_index)

# Hidden while the in-run dealer overlay is up so its stash is the only one on screen
# (no duplicate, issue #26).
# Snapshot of the stash expanded to one entry per copy (matches buildStashSlots).
func _stash_slots() -> Array:
	var slots: Array = []
	var stash: Dictionary = RunStateStore.runConsumables
	for entry in stash:
		var copies := int(stash[entry])
		for _k in copies:
			if slots.size() < max_consumable_slots:
				slots.append(String(entry))
	return slots

func _refresh_controls() -> void:
	_refresh_multiplier_controls()
	_refresh_restore_cap()
	_refresh_reserve_glow()

	var combo_pending := RunStateStore.comboDefeatPending
	var can_confirm_combo_loss := combo_pending and RunStateStore.runPhase == "running" \
		and not RunStateStore.isSpinning and RunStateStore.compulsiveSpinSkips <= 0
	var sequence_allows_power := not _sequence_lock_active or combo_pending
	var can_use := RunStateStore._can_use_ability() and not _spinning_anim and not _spin_launch_pending and not _reroll_anim_active \
		and not _rewind_anim_active and _dealer_offer_popup == null and sequence_allows_power
	if _spin_button != null:
		_spin_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if not _targeting_power_id.is_empty() else Control.MOUSE_FILTER_STOP
		_spin_button.disabled = _dealer_offer_popup != null or not (RunStateStore._can_act() or can_confirm_combo_loss) \
			or _spinning_anim or _spin_launch_pending or _reroll_anim_active or _rewind_anim_active \
			or (_sequence_lock_active and not combo_pending)
	if not _power_buttons.is_empty():
		var used: Array = RunStateStore.abilitiesUsed
		var owned: Array = RunStateStore.power_loadout()
		var visible_power_order := _visible_power_order(owned)
		# A restored power stays in its unavailable state until its restore is committed
		# (commit_power_restore fires the refresh) — when the gauge fills for a bar
		# restore, or when Tea's coin lands on the button for a direct one (issue #54).
		var pending: Array = RunStateStore.pendingPowerRestores
		var rescue_ids := RunStateStore.pending_combo_power_ids()
		for id in POWER_IDS:
			var visible := visible_power_order.has(id)
			var b: Button = _power_buttons[id]
			b.visible = visible
			b.disabled = not visible
			if visible:
				_apply_power_slot(id, visible_power_order.find(id))
				var valid_pending_power: bool = not combo_pending or rescue_ids.has(id)
				b.disabled = not (can_use and valid_pending_power and not used.has(id) \
					and not pending.has(id))
			var frame := POWER_FRAME_DISABLED if b.disabled else POWER_FRAME_AVAILABLE
			if id == _targeting_power_id and not b.disabled:
				frame = POWER_FRAME_SELECTED
			var sprite: Sprite2D = _power_sprites[id]
			if sprite != null:
				sprite.visible = visible
			_set_sheet_frame(sprite, frame)

	var slots := _stash_slots()
	var usable := (RunStateStore._can_use_consumable() and not _spin_launch_pending and not _reroll_anim_active \
			and not _rewind_anim_active and (not _sequence_lock_active or combo_pending)) \
		or _dealer_offer_popup != null
	var stash_icons: Array = _stash.icons()
	for i in stash_icons.size():
		var icon: TextureRect = stash_icons[i]
		if i < slots.size():
			icon.texture = _icon_for(slots[i])
			icon.modulate = Color.WHITE if usable else Color(1.0, 1.0, 1.0, 0.4)
		else:
			icon.texture = null # empty slot draws nothing
			icon.modulate = Color.WHITE

func _power_owned(id: String, owned: Array) -> bool:
	var normalised := PacteCards.normalise_card_id(id)
	return owned.has(normalised)

func _visible_power_order(owned: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_id in owned:
		var id := PacteCards.normalise_card_id(String(raw_id))
		if POWER_IDS.has(id) and not result.has(id):
			result.append(id)
		if result.size() == 3:
			break
	return result

## The first three authored power positions are the machine's visible slots. Power
## sheets beyond those positions are full-canvas art, so offsetting the sprite by
## the source/target slot delta moves the icon without changing its pixel scale.
func _apply_power_slot(power_id: String, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= 3:
		return
	var source: Dictionary = POWER_HITS[power_id]
	var target_id := POWER_IDS[slot_index]
	var target: Dictionary = POWER_HITS[target_id]
	var button: Button = _power_buttons[power_id]
	button.position = Vector2(target["left"], target["top"])
	button.size = Vector2(maxf(float(target["width"]), 11.0), float(target["height"]))
	var sprite: Sprite2D = _power_sprites[power_id]
	if sprite != null:
		# Art to art, not hit box to hit box: the chip lands exactly on the emplacement.
		sprite.position = Vector2(
			float(POWER_ART_LEFT[target_id]) - float(POWER_ART_LEFT[power_id]),
			float(target["top"]) - float(source["top"]))

func _short_name(consumable_id: String) -> String:
	return consumable_id.replace("cons_", "").replace("item_", "").substr(0, 4)

## An item's icon — colour-inverted on a joker Augmented run, where the four in-run items
## are dealt turned against the player (issue #111). The silhouette is the one the player
## already knows; only the colour says it is not the item they think it is.
func _icon_for(id: String) -> Texture2D:
	var tex := _load_texture(ITEM_ICONS.get(id, "items/consumable_placeholder.png"))
	if tex != null and RunStateStore.augmented_joker_items_active() \
			and InRunItems.JOKER_EFFECTS.has(id):
		return Assets.inverted_texture(tex)
	return tex

# ── power targeting ────────────────────────────────────────────────────────────────

func _on_power_pressed(id: String) -> void:
	var combo_pending := RunStateStore.comboDefeatPending
	if (_sequence_lock_active and not combo_pending) or _spin_launch_pending \
			or _spinning_anim or _reroll_anim_active or _rewind_anim_active:
		return
	if combo_pending and not RunStateStore.pending_combo_power_ids().has(id):
		return
	if not RunStateStore._can_use_ability():
		return
	if _targeting.is_open():
		_clear_targeting()
		_refresh_controls()
		return
	if id == "rewind":
		_use_rewind_power()
		return
	if id == "heart":
		_use_heart_power()
		return
	if id == "cheat":
		_arm_cheat_targets()
	elif id == "swap":
		_arm_swap_source()
	elif id == "shift":
		_arm_shift_targets()
	else:
		# reroll / memory pick a single reel.
		_arm_reel_picker(func(reel_index: int) -> void: _apply_reel_power(id, reel_index))
	_targeting_power_id = id
	_power_callout.show_power(id)
	_refresh_controls()

func _use_rewind_power() -> void:
	if _rewind_anim_active:
		return
	var was_pending := RunStateStore.comboDefeatPending
	if not RunStateStore.rewind():
		_refresh_controls()
		return
	_clear_targeting()
	_maybe_cancel_combo_defeat_warning(was_pending)
	_start_rewind_restore()

## Rewind's restore beat: all three reels blur backwards while the previous state
## rolls back in. The whole sequence runs under the sequence lock so SPIN is
## dead until the restored reveal has landed; _finish_rewind_restore always runs
## (the step is driven from _process) and always releases the lock.
func _start_rewind_restore() -> void:
	_rewind_anim_active = true
	# A rewind replaces the interrupted post-spin sequence with the restored state.
	# Clearing this flag prevents stale reward/dealer sequencing from keeping SPIN
	# disabled after the backwards reveal has landed.
	_post_spin_sequence_active = false
	_rewind_elapsed = 0.0
	_rewind_accum = 0.0
	_spin_frame = 0
	_set_sequence_lock(true)
	_callouts.stop_win()
	_callouts.stop_combo()
	_play_sfx(&"reel_spin")
	for i in 3:
		_reel_stop_sfx_played[i] = false
		_reel_symbols.set_visible(i, false)
		_reel_blur.set_cover(i, false)
		_reel_blur.set_spin_frame(i, _spin_frame)
		_reel_blur.set_spin_visible(i, true)
	_refresh_controls()

func _step_rewind_restore(delta: float) -> void:
	_rewind_elapsed += delta
	_rewind_accum += delta
	if _rewind_accum >= SPIN_FRAME_TIME:
		_rewind_accum = 0.0
		# The blur runs backwards — the machine is unwinding the previous spin.
		_spin_frame = (_spin_frame - 1 + SPIN_FRAME_COUNT) % SPIN_FRAME_COUNT
		for i in 3:
			_reel_blur.set_spin_frame(i, _spin_frame)
	if _rewind_elapsed >= maxf(0.0, REWIND_RESTORE_DURATION - REEL_STOP_SFX_LEAD_TIME):
		for i in 3:
			_play_reel_stop_sfx(i)
	if _rewind_elapsed >= REWIND_RESTORE_DURATION:
		_finish_rewind_restore()

func _finish_rewind_restore() -> void:
	_stop_sfx(&"reel_spin")
	_rewind_anim_active = false
	_post_spin_sequence_active = false
	for i in 3:
		_reel_blur.set_spin_visible(i, false)
		_reel_blur.set_cover(i, true)
	_refresh_reels_from_state()
	_update_hud()
	_refresh_jackpot_lamp()
	# The restored snapshot may bring a pending combo defeat back with it; the
	# lock hands over to that warning, otherwise spinning re-enables here.
	if RunStateStore.comboDefeatPending:
		_post_spin_sequence_active = true
		_show_pending_combo_defeat()
	else:
		_close_pending_combo_defeat()
		_set_sequence_lock(false)
	_refresh_controls()

func _use_heart_power() -> void:
	var was_pending := RunStateStore.comboDefeatPending
	if not RunStateStore.heart_power():
		_refresh_controls()
		return
	_pending_combo_power_flow = was_pending
	_maybe_cancel_combo_defeat_warning(was_pending)
	_pending_combo_power_flow = false
	if was_pending:
		# The old post-spin sequence was paused behind the loss warning. Heart
		# replaces that warning with a new guaranteed spin, so the next reveal must
		# be allowed to start a fresh post-spin sequence.
		_post_spin_sequence_active = false
	_clear_targeting()
	_refresh_reels_from_state()
	_update_hud()
	# Heart is a preparation action: the next SPIN press renders and resolves the
	# guaranteed heart triple as a free spin.
	if was_pending and RunStateStore.comboDefeatPending:
		_show_pending_combo_defeat()
	else:
		_set_sequence_lock(false)
	_refresh_controls()

func _arm_cheat_targets() -> void:
	# Cheat uses the same rubble/reward-amplification presentation as the other
	# symbol-manipulation powers before the player chooses a reel.
	_flash_power_rubble()
	_arm_reel_picker(func(reel_index: int) -> void: _on_cheat_reel_pick(reel_index))

## Cheat's symbol choice is a mini-reel laid over the picked reel's hole: the
## up/down arrows step the candidate symbol along the pool, tapping the symbol
## itself commits it, tapping anywhere else cancels.
func _on_cheat_reel_pick(reel_index: int) -> void:
	if _reel_is_dead(reel_index):
		return
	_cheat_reel = reel_index
	_clear_targeting()
	_targeting_power_id = "cheat"
	_power_callout.show_power("cheat")
	# What may be chosen is the machine's: the base cycle, plus a Book only once the
	# run has earned one.
	var pool: Array[String] = []
	for symbol in Symbols.BASE_SYMBOL_CYCLE:
		pool.append(String(symbol))
	if Economy.compute_book_weight(RunStateStore.ownedUpgrades) > 0:
		pool.append("book")
	# Start the mini-reel on the symbol currently in the hole.
	var current := ""
	if RunStateStore.lastResult != null:
		var reels: Array = RunStateStore.lastResult["reels"] as Array
		if reel_index >= 0 and reel_index < reels.size():
			current = String(reels[reel_index])
	# STOP, not IGNORE: tapping anywhere off the mini-reel backs out of Cheat, so the
	# layer itself has to receive the miss.
	var layer := _targeting.open("CheatReelOverlay", Control.MOUSE_FILTER_STOP,
		_on_power_picker_input)
	var hole: Dictionary = REEL_HOLES[reel_index]
	_cheat.open(layer, reel_index, Rect2(float(hole["left"]), float(hole["top"]),
		float(hole["width"]), float(hole["height"])), pool, current)

func _set_cheat_selection_state(state: int) -> void:
	_cheat.show_selection(state)

func _on_cheat_symbol_pick(symbol_id: String) -> void:
	var source := _cheat_reel
	var was_pending := RunStateStore.comboDefeatPending
	_clear_targeting()
	if not RunStateStore.cheat_symbol(source, symbol_id):
		_refresh_controls()
		return
	_pending_combo_power_flow = was_pending
	_maybe_cancel_combo_defeat_warning(was_pending)
	_refresh_reels_from_state()
	_update_hud()
	_play_reward_sequence(source, true)
	_cheat_reel = -1

func _arm_swap_source() -> void:
	_clear_targeting()
	_targeting_power_id = "swap"
	_power_callout.show_power("swap")
	var layer := _targeting.open("SwapSymbolDragLayer", Control.MOUSE_FILTER_IGNORE)
	_swap_overlay.forget()
	# A blinded reel is neither grabbable nor droppable: no hint, no drag button, and
	# _swap_target_at() will not return it.
	for i in _power_reel_count():
		_swap_overlay.build_slot_hint(layer, i)
		var hole: Dictionary = REEL_HOLES[i]
		var button := Button.new()
		button.name = "SwapSymbol%d" % i
		button.position = Vector2(float(hole["left"]) - 2.0, float(hole["top"]) - 2.0)
		button.size = Vector2(float(hole["width"]) + 4.0, float(hole["height"]) + 4.0)
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = Control.CURSOR_DRAG
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.gui_input.connect(_on_swap_symbol_gui_input.bind(i, button))
		layer.add_child(button)
	# Issue #181: one cue per idea, and no words. The reel frames breathe (these are the
	# places that take part) and the reels shake (these are the things you can grab); the
	# instruction line the power used to carry is gone.
	_swap_overlay.start_pulse()
	_start_swap_symbol_shake()

## While Swap is armed each REEL shakes as one piece: the reel's own art moves and its
## symbols ride along, stuck to it, rather than the symbols jiggling in a still reel. The
## reels run on staggered phases so they read as three loose reels rather than one juddering
## screen.
## The orbit itself is SwapShake's; what a reel is MADE of stays here, because
## nothing owns "a reel" — it is a blur cover, three symbol sprites from
## ReelSymbols and a slot frame from the swap overlay, and the rule for which reels
## take part is the machine's too.
func _start_swap_symbol_shake() -> void:
	_stop_swap_symbol_shake()
	# The shared backing draws the same three patches the covers do, so a cover moving over it
	# is invisible — nothing appears to shake but the symbols. Hand the reel art to the covers
	# for the duration: backing off, every cover on, and each cover free to move with its reel.
	if _reel_backing_sprite != null:
		_reel_backing_sprite.visible = false
	_swap_shake_cover_state.clear()
	var hints: Array = _swap_overlay.slot_hints()
	# One group per reel, in reel order — the order IS the stagger.
	var groups: Array = []
	# Only the reels Swap can actually take part in move — a blinded reel is not grabbable,
	# so shaking it would advertise a target the drag refuses. Its cover is still switched
	# on, because the shared backing goes off for every reel and the cover is what draws
	# the art in its place; it simply stays still.
	for i in _reel_symbols.count():
		var live: bool = not _reel_is_dead(i)
		var group: Array = []
		# The reel asset first — this is the thing that shakes.
		if i < _reel_blur.cover_count():
			var cover := _reel_blur.cover(i)
			if cover != null:
				_swap_shake_cover_state.append(cover.visible)
				cover.visible = true
				if live:
					group.append(cover)
		if live:
			group.append(_reel_symbols.top(i))
			group.append(_reel_symbols.center(i))
			group.append(_reel_symbols.bottom(i))
			if i < hints.size():
				group.append(hints[i])
		groups.append(group)
	_swap_shake.start(groups)

func _stop_swap_symbol_shake() -> void:
	_swap_shake.stop()
	# Give the reel art back to the shared backing and restore each cover's own state.
	if _swap_shake_cover_state.is_empty():
		return
	if _reel_backing_sprite != null:
		_reel_backing_sprite.visible = true
	for i in mini(_swap_shake_cover_state.size(), _reel_blur.cover_count()):
		var cover := _reel_blur.cover(i)
		if cover != null:
			cover.visible = _swap_shake_cover_state[i]
	_swap_shake_cover_state.clear()

func _on_swap_symbol_gui_input(event: InputEvent, reel_index: int, button: Button) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_swap_drag(reel_index, button, get_global_mouse_position())
	elif event is InputEventScreenTouch and event.index == 0 and event.pressed:
		# gui_input positions arrive local to the reel button; lift them into canvas
		# space so the grabbed symbol tracks the finger (the mouse branch already is).
		_begin_swap_drag(reel_index, button,
			button.get_global_transform() * (event as InputEventScreenTouch).position)

func _input_canvas_position(viewport_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * viewport_position

func _swap_symbol_at(reel_index: int, slot: int) -> String:
	var result: Variant = RunStateStore.lastResult
	if not result is Dictionary:
		return ""
	var reels: Array = result["reels"] as Array
	if reel_index < 0 or reel_index >= reels.size():
		return ""
	var centre := String(reels[reel_index])
	if slot == 1 or _reel_symbols.adjacent_hidden():
		return centre
	var neighbours := _reel_symbols.neighbours_of(centre)
	return String(neighbours["top"] if slot == 0 else neighbours["bottom"])

func _begin_swap_drag(reel_index: int, button: Button, global_position: Vector2) -> void:
	if _swap_drag_active or not _targeting.is_open():
		return
	var result: Variant = RunStateStore.lastResult
	if not result is Dictionary:
		return
	var reels: Array = result["reels"] as Array
	if reel_index < 0 or reel_index >= reels.size():
		return
	# Swap takes whole reels: wherever on the reel the drag starts, what is picked up is the
	# reel itself, represented by the symbol it landed on. The adjacent strip symbols are
	# scenery again, not grabbable.
	var source_slot := SWAP_CENTRE_SLOT
	var source_symbol := _swap_symbol_at(reel_index, source_slot)
	if source_symbol == "":
		return
	_swap_drag_active = true
	_swap_dragging = true
	_swap_source = reel_index
	_swap_source_slot = source_slot
	_swap_source_symbol = source_symbol
	_swap_drag_button = button
	_swap_drag_press = global_position
	var source_position := _swap_symbol_position(reel_index, source_slot)
	_swap_drag_offset = _targeting_local_position(global_position) - source_position
	_swap_drag_ghost = Sprite2D.new()
	_swap_drag_ghost.name = "SwapDraggedSymbol"
	_swap_drag_ghost.centered = true
	_swap_drag_ghost.z_index = 5
	_swap_drag_ghost.modulate = Color(1.0, 1.0, 1.0, 0.92)
	_swap_drag_ghost.position = _targeting_local_position(global_position) - _swap_drag_offset
	_reel_symbols.apply_symbol(_swap_drag_ghost, source_symbol, ReelSymbols.CENTER_H)
	# Drop shadow under the dragged symbol: same texture, black, slightly offset.
	# It is a child of the ghost, so it follows the drag and dies with it.
	var ghost_shadow := Sprite2D.new()
	ghost_shadow.name = "DragShadow"
	ghost_shadow.texture = _swap_drag_ghost.texture
	ghost_shadow.centered = true
	ghost_shadow.position = Vector2(2.0, 3.0)
	ghost_shadow.modulate = Color(0.0, 0.0, 0.0, 0.5)
	ghost_shadow.show_behind_parent = true
	_swap_drag_ghost.add_child(ghost_shadow)
	_swap_overlay.build_destination_cues(_targeting.node(), reel_index)
	_swap_drag_ghost.visible = true
	_targeting.node().add_child(_swap_drag_ghost)
	_swap_drag_button.modulate.a = 0.35

## Builds both destination cues for a Swap drag: a green frame that follows whichever
## legal reel the pointer is over, and a red cross on the source reel. Both start
## silent — the rejection cue is raised only when the player actually offends, rather
## than shouting at them for the whole drag the way it used to (issue #181).
func _update_swap_drag(global_position: Vector2) -> void:
	if not _swap_drag_active or _swap_drag_button == null:
		return
	_swap_dragging = true
	_swap_drag_button.modulate.a = 0.35
	if _swap_drag_ghost != null:
		_swap_drag_ghost.visible = true
		_swap_drag_ghost.position = _targeting_local_position(global_position) - _swap_drag_offset
	_swap_overlay.update_feedback(_swap_target_at(global_position), _swap_source)

func _finish_swap_drag(global_position: Vector2) -> void:
	var source := _swap_source
	var was_dragging := _swap_dragging
	var source_symbol := _swap_source_symbol
	var target := _swap_target_at(global_position)
	_cancel_swap_drag_gesture()
	if not was_dragging or target < 0 or target == source:
		return
	_on_swap_destination_pick(target, source, source_symbol)

func _cancel_swap_drag_gesture() -> void:
	_swap_drag_active = false
	_swap_dragging = false
	if _swap_drag_button != null:
		_swap_drag_button.modulate = Color.WHITE
	_swap_drag_button = null
	if _swap_drag_ghost != null and is_instance_valid(_swap_drag_ghost):
		_swap_drag_ghost.queue_free()
		_swap_drag_ghost = null
	_swap_overlay.free_destination_cues()
	_swap_drag_press = Vector2.ZERO
	_swap_drag_offset = Vector2.ZERO
	_swap_source = -1
	_swap_source_slot = 1
	_swap_source_symbol = ""

## A pointer position in the armed layer's space. The fallback when nothing is
## armed is the machine's OWN local space, which is why this stays here rather
## than in TargetingLayer — that class has no opinion about where a point lives
## when it holds no layer.
func _targeting_local_position(global_position: Vector2) -> Vector2:
	if not _targeting.is_open():
		return to_local(global_position)
	return _targeting.local_position(global_position)

func _swap_symbol_position(reel_index: int, slot: int) -> Vector2:
	if reel_index < 0 or reel_index >= _reel_symbols.count():
		return Vector2.ZERO
	if slot == 0:
		return _reel_symbols.top(reel_index).position
	if slot == 2:
		return _reel_symbols.bottom(reel_index).position
	return _reel_symbols.center(reel_index).position


func _swap_target_at(global_position: Vector2) -> int:
	var local_position := to_local(global_position)
	for i in mini(REEL_HOLES.size(), _power_reel_count()):
		var hole: Dictionary = REEL_HOLES[i]
		var rect := Rect2(float(hole["left"]), float(hole["top"]),
			float(hole["width"]), float(hole["height"])).grow(4.0)
		if rect.has_point(local_position):
			return i
	return -1

func _on_swap_destination_pick(destination: int, source_override: int = -1,
		source_symbol_override: String = "") -> void:
	var source := _swap_source if source_override < 0 else source_override
	if _reel_is_dead(source) or _reel_is_dead(destination):
		return
	# Reel for reel: the store swaps the two reels' own symbols, so no override is passed
	# unless a caller (the dealer's help) explicitly names one.
	var source_symbol := source_symbol_override
	var was_pending := RunStateStore.comboDefeatPending
	_clear_targeting()
	if not RunStateStore.swap_symbol(source, destination, source_symbol):
		_refresh_controls()
		return
	_pending_combo_power_flow = was_pending
	_maybe_cancel_combo_defeat_warning(was_pending)
	_refresh_reels_from_state()
	_update_hud()
	_play_reward_sequence(destination, true)
	_swap_source = -1

func _on_power_picker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_cancel_power_picker()

func _cancel_power_picker() -> void:
	_cheat_reel = -1
	_swap_source = -1
	_swap_source_slot = 1
	_swap_source_symbol = ""
	_clear_targeting()
	_refresh_controls()

func _flash_power_rubble() -> void:
	if _rubble_overlay != null and is_instance_valid(_rubble_overlay):
		_rubble_overlay.queue_free()
	_rubble_overlay = ColorRect.new()
	_rubble_overlay.name = "PowerRubbleAnimation"
	_rubble_overlay.position = Vector2(31.0, 167.0)
	_rubble_overlay.size = Vector2(88.0, 36.0)
	_rubble_overlay.color = Color(0.42, 0.34, 0.24, 0.72)
	_rubble_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rubble_overlay.z_index = 94
	add_child(_rubble_overlay)
	var tw := create_tween()
	tw.tween_property(_rubble_overlay, "modulate:a", 0.0, 0.18)
	tw.finished.connect(_rubble_overlay.queue_free)

# Builds a per-reel picker overlay; each reel button calls cb(reel_index). Blinded reels
# get no button — see _power_reel_count().
func _arm_reel_picker(cb: Callable) -> void:
	_clear_targeting()
	# IGNORE: only its buttons capture clicks.
	var layer := _targeting.open("ReelPickerOverlay", Control.MOUSE_FILTER_IGNORE)
	var selection := _build_control_grid_sheet_on(layer, "machine new view/reel_selection.png", REEL_SELECT_COLUMNS, REEL_SELECT_ROWS)
	var cy := REEL_WINDOW["top"]
	for i in _power_reel_count():
		var reel := i
		var b := _make_hit_button({
			"left": REEL_CELL_CENTERS[reel] - 12.0,
			"top": cy - 8.0,
			"width": 24.0,
			"height": REEL_WINDOW["height"] + 16.0,
		}, func() -> void: cb.call(reel))
		if selection != null:
			b.button_down.connect(_set_sheet_frame.bind(selection, reel + 1))
		layer.add_child(b)

func _arm_shift_targets() -> void:
	_clear_targeting()
	var layer := _targeting.open("ShiftArrowOverlay", Control.MOUSE_FILTER_IGNORE)
	var arrows := _build_control_grid_sheet_on(layer, "machine new view/shift_power.png", SHIFT_POWER_COLUMNS, SHIFT_POWER_ROWS)
	for i in _power_reel_count():   # no arrows on a blinded reel
		for dir_key in ["up", "down"]:
			var hit: Dictionary = SHIFT_ARROW_HITS[i][dir_key]
			var direction := 1 if dir_key == "up" else -1
			var b := _make_hit_button(hit, _apply_shift.bind(i, direction))
			if arrows != null:
				var frame := 1 + i * 2 + (1 if dir_key == "up" else 0)
				b.button_down.connect(_set_sheet_frame.bind(arrows, frame))
			layer.add_child(b)

func _apply_reel_power(power_id: String, reel_index: int) -> void:
	if _reel_is_dead(reel_index):
		return
	var combo_pending := RunStateStore.comboDefeatPending
	if (_sequence_lock_active and not combo_pending) or _spin_launch_pending:
		return
	if combo_pending and power_id not in ["reroll", "shift", "memory"]:
		return
	if not RunStateStore._can_use_ability():
		return
	if power_id == "reroll":
		_hud_delta_hold = true # deltas pop with the reroll's score popup (issue #54)
		if RunStateStore.reroll_reel(reel_index):
			_pending_combo_power_flow = combo_pending
			_maybe_cancel_combo_defeat_warning(combo_pending)
			_clear_targeting()
			_start_reroll_animation(reel_index)
			_update_hud()
			return
		_hud_delta_hold = false
		_clear_targeting()
		if combo_pending:
			# A failed rescue does not settle the loss. The numbered warning stays
			# active until the player confirms it with the next spin.
			_refresh_controls()
	elif power_id == "memory":
		RunStateStore.lock_reel(reel_index)
		if combo_pending:
			RunStateStore.resolve_pending_combo_defeat(false)
			_close_pending_combo_defeat()
			_clear_targeting()
			_finish_post_spin_sequence()
			return
	_clear_targeting()
	_refresh_reels_from_state()
	_update_hud()
	_refresh_jackpot_lamp()

func _start_reroll_animation(reel_index: int) -> void:
	_callouts.stop_win() # the rerolled reveal supersedes the previous win callout
	_callouts.stop_combo()
	_reroll_anim_active = true
	_reroll_reel_index = reel_index
	_reroll_elapsed = 0.0
	_reroll_accum = 0.0
	_spin_frame = 0
	_reel_stop_sfx_played[reel_index] = false
	_play_sfx(&"reel_spin")
	for i in 3:
		var active := i == reel_index
		_reel_symbols.set_visible(i, not active)
		_reel_blur.set_cover(i, not active)
		_reel_blur.set_spin_frame(i, _spin_frame)
		_reel_blur.set_spin_visible(i, active)
	if _spin_button != null:
		_spin_button.disabled = true

func _step_reroll(delta: float) -> void:
	_reroll_elapsed += delta
	_reroll_accum += delta
	if _reroll_accum >= SPIN_FRAME_TIME:
		_reroll_accum = 0.0
		_spin_frame = (_spin_frame + 1) % SPIN_FRAME_COUNT
		_reel_blur.set_spin_frame(_reroll_reel_index, _spin_frame)
	if _reroll_elapsed >= maxf(0.0, REROLL_REEL_DURATION - REEL_STOP_SFX_LEAD_TIME):
		_play_reel_stop_sfx(_reroll_reel_index)
	if _reroll_elapsed >= REROLL_REEL_DURATION:
		_stop_sfx(&"reel_spin")
		_play_reel_stop_sfx(_reroll_reel_index)
		_reroll_anim_active = false
		var lr: Variant = RunStateStore.lastResult
		if lr != null:
			_reel_symbols.set_symbol(_reroll_reel_index, String(lr["reels"][_reroll_reel_index]))
		_reel_blur.set_spin_visible(_reroll_reel_index, false)
		_reel_symbols.set_visible(_reroll_reel_index, true)
		_reel_blur.set_cover(_reroll_reel_index, true)
		var rerolled := _reroll_reel_index
		_reroll_reel_index = -1
		if _spin_button != null:
			_spin_button.disabled = false
		_update_hud()
		# Machine reactions (triple/flatline) and the instant-death check now run
		# inside the reward sequence, after the score popup — a reroll-made triple
		# must not pop before its own score burst (issue #54 alignment).
		_play_reward_sequence(rerolled, true) # reroll burst pops from the rerolled reel

func _apply_shift(reel_index: int, direction: int) -> void:
	if _reel_is_dead(reel_index):
		return
	var combo_pending := RunStateStore.comboDefeatPending
	if (_sequence_lock_active and not combo_pending) or _spin_launch_pending:
		return
	if not RunStateStore._can_use_ability():
		return
	_hud_delta_hold = true # deltas pop with the shift's score popup (issue #54)
	var applied := RunStateStore.move_reel(reel_index, direction)
	if not applied:
		_hud_delta_hold = false
		_clear_targeting()
		if combo_pending:
			# A failed rescue does not settle the loss. The numbered warning stays
			# active until the player confirms it with the next spin.
			_refresh_controls()
		return
	_pending_combo_power_flow = combo_pending
	_maybe_cancel_combo_defeat_warning(combo_pending)
	_clear_targeting()
	_refresh_reels_from_state()
	_update_hud()
	# Reactions + instant-death run inside the reward sequence, after the score
	# popup, so a shift-made triple never pops before its burst (issue #54).
	_play_reward_sequence(reel_index, true) # shift burst pops from the shifted reel

## `apply_power_reaction` runs the machine reactions (reroll/shift triples, flatline
## strikes) and the flatline instant-death check AFTER the score popup, mirroring the
## normal spin path so a power-made triple never flashes before its own burst.
func _play_reward_sequence(source_reel: int, apply_power_reaction := false) -> void:
	_set_sequence_lock(true)
	var pending_defeat_power_flow := _pending_combo_power_flow
	var reward_time := _emit_score_burst(source_reel)
	# Same beat as the spin path: held HUD deltas pop after the score popup.
	var pop_lead := minf(AFTEREFFECT_POP_DELAY, reward_time)
	if pop_lead > 0.0:
		await get_tree().create_timer(pop_lead).timeout
	_release_hud_delta_hold()
	_refresh_jackpot_lamp()
	if apply_power_reaction:
		_apply_machine_reactions(true)  # reroll/shift may form a triple (issue #35)
	if reward_time > pop_lead:
		await get_tree().create_timer(reward_time - pop_lead).timeout
	# Instant death from stacked flatline results takes precedence, and only the
	# power paths can add one here — the copy path never reacts.
	if apply_power_reaction and _check_flatline_instant_death():
		if pending_defeat_power_flow:
			_close_pending_combo_defeat()
		_pending_combo_power_flow = false
		_post_spin_sequence_active = false
		return
	if pending_defeat_power_flow:
		_pending_combo_power_flow = false
		if RunStateStore.comboDefeatPending:
			# The power changed the reveal but did not make a paying pair/triple.
			# Re-open the beeping warning so another available power can be tried or
			# the next spin can confirm the loss.
			_show_pending_combo_defeat()
		else:
			_close_pending_combo_defeat()
			_finish_post_spin_sequence()
		return
	# A power that rescored the reveal can beat the target on its own — the payout
	# screen belongs to that moment, not to whatever spin the player takes next.
	if _settle_off_spin_score_change():
		_post_spin_sequence_active = false
		return
	_set_sequence_lock(false)

func _clear_targeting() -> void:
	_swap_overlay.stop_pulse()
	_stop_swap_symbol_shake()
	_cancel_swap_drag_gesture()
	_targeting.close()
	_swap_overlay.forget() # the frames were children of the layer just freed
	_cheat.close() # its preview and buttons were children of the layer just freed
	_targeting_power_id = ""
	_power_callout.stop()

func _score_label(parent: Control, text: String, pos: Vector2, size: int, color: Color,
		width := 0.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	if width > 0.0:
		l.size = Vector2(width, maxf(10.0, float(size + 6)))
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

## Whether the payout table may open at all — a live spin, a queued launch or the
## dealer holding the screen all refuse it — and the toggle, because the HUD button
## that calls this is the same button that closes it. The table itself is
## ScoreTable's; what is allowed to interrupt the run is the machine's.
func _show_score_table() -> void:
	if (_sequence_lock_active and not RunStateStore.comboDefeatPending) or _spin_launch_pending:
		return
	if _dealer_offer_popup != null:
		return
	if _score_table.is_open():
		_close_score_table()
		return
	_clear_targeting()
	_score_table.open()

func _close_score_table() -> void:
	_score_table.close_table()

## Short 3x-bonus blurb per symbol, shown under the TRIPLE value (issue #51).
## Dynamic counts pull from the reaction exports so the copy never drifts.
## Returns DISPLAY text: each line is translated before its counts go in, because the
## finished sentence ("JACKPOT +1 SPIN") is not a key any table can hold. Callers must not
## translate the result again.
func _triple_effect_text(symbol_id: String) -> String:
	match symbol_id:
		"brain":
			return tr("JACKPOT +%d SPIN") % triple_brain_free_spins
		"eye":
			return tr("REVEALS A REEL")
		"pill":
			return tr("ALL POWERS BACK")
		"syringe":
			return tr("LAST ITEM BACK")
		"vial":
			return tr("+%d SPINS") % triple_vial_free_spins
		"flatline":
			return tr("CLOSE CALL %d/%s,\n2X REWARDS NEXT SPIN") % [
				RunStateStore.flatlineResultCount, _flatline_restriction_limit_text()]
	return ""

## Splits an info-blurb line into [text, color] segments. The flatline strike
## count heats up as it nears the fatal third strike: 0 white, 1 orange, 2 red.
func _info_line_segments(symbol_id: String, line: String) -> Array:
	var base := Color(0.9, 0.94, 1.0)
	if symbol_id == "flatline":
		var count_text := "%d/%s" % [RunStateStore.flatlineResultCount,
			_flatline_restriction_limit_text()]
		var idx := line.find(count_text)
		if idx >= 0:
			var count_color := base
			match RunStateStore.flatlineResultCount:
				0: pass
				1: count_color = Color(1.0, 0.62, 0.2)
				_: count_color = flatline_result_color
			return [[line.substr(0, idx), base], [count_text, count_color],
				[line.substr(idx + count_text.length()), base]]
	return [[line, base]]

func _on_stash_pressed(slot_index: int) -> void:
	var slots := _stash_slots()
	if slot_index >= slots.size():
		return
	var id: String = slots[slot_index]
	if id == "cons_white_powder":
		_begin_white_powder()
		return
	if id == "cons_focus":
		_begin_serum() # Serum (issue #53): pick the guaranteed symbol first
		return
	var lucidity_before := int(RunStateStore.lucidityCoins)
	var score_before := int(RunStateStore.scoreEarned)
	var spins_before := _current_display_spins_left()
	var defeat_was_pending := RunStateStore.comboDefeatPending
	if not RunStateStore.use_consumable(id):
		return
	var direct_score_gain: int = maxi(0, int(RunStateStore.scoreEarned) - score_before)
	if direct_score_gain > 0:
		# Direct score events advance the current result in RunStateStore, so keep the
		# rescore baseline aligned before a power can announce a same-spin delta.
		if RunStateStore.lastResult is Dictionary:
			_bursts.remember(_bursts.prev_spin(),
				int((RunStateStore.lastResult as Dictionary).get("scoreEarned", 0)))
		else:
			_bursts.remember(_bursts.prev_spin(), int(RunStateStore.scoreEarned))
	# Energy Drink taken during an x3 defeat clears it in the store — drop the
	# beeping loss overlay and let the normal post-spin tail resume.
	if defeat_was_pending and not RunStateStore.comboDefeatPending:
		_close_pending_combo_defeat()
		_finish_post_spin_sequence()
	_refresh_reels_from_state()
	# Joker Water (issue #111) empties the gauge instead of filling it: the progress
	# banked toward the next power restore is forfeited on the spot.
	if RunStateStore.consume_power_bar_drain():
		_drain_power_bar()
	_update_hud()
	# Water adds score directly (no score popup carries it), so the odometer
	# rolls up right here instead of waiting for a reward sequence.
	if int(RunStateStore.scoreEarned) > _wealth.display_score():
		_set_display_lucidity(int(RunStateStore.scoreEarned))
	_show_consumable_feedback(id)
	_play_use_fx(id)
	_play_consumable_lucidity_feedback(lucidity_before)
	if id == "cons_tea":
		_resolve_direct_restore() # Tea restores its power instantly, not via the gauge
		# Tea (issue #53): restored spins fly from the stash to the spins counter,
		# with a "+N" fly-in that ticks the counter on landing (issue #66).
		var spins_gained := _current_display_spins_left() - spins_before
		if spins_gained > 0:
			_play_tea_flight(slot_index)
			_play_spin_gain_fx(spins_gained,
				Assets.stash_slot_pos(slot_index, max_consumable_slots) - Vector2(0.0, 10.0))
	# Water and friends can beat the target on the spot; the payout screen pops here
	# rather than waiting for a spin the player no longer needs to take.
	if direct_score_gain > 0 and _settle_off_spin_score_change():
		return

func _item_display_name(id: String) -> String:
	var imap := InRunItems.map()
	if imap.has(id):
		return String(imap[id]["name"]).to_upper()
	var cmap := Consumables.map()
	if cmap.has(id):
		return String(cmap[id]["name"]).to_upper()
	return id.to_upper()

## Animated two-line +/- hint on stash use (issue #33). Spawns a self-freeing
## HintLabel; the item name renders purple when the item is flagged corrupted.
func _show_consumable_feedback(id: String) -> HintLabel:
	if id == "item_pill":
		return _show_deferred_negative(id)
	# Deferred-negative items (issue #76) show only the upside now; a hooked item also
	# arms its downside so the activation hook can pop it later. An item with no negative
	# line left to pop (the Energy Drink, off a joker run) is never armed — otherwise its
	# hook would fire an empty popup at the takeover that never comes.
	if id in HOOKED_DEFERRED_NEGATIVES and String(_hint_for(id).get("neg", "")) != "":
		_pending_deferred_neg[id] = true
	return _spawn_hint(id, false, id in DEFERRED_NEGATIVE_ITEMS)

## Pops a hooked item's armed negative when its downside actually fires (issue #76) —
## e.g. FORCED SPIN as the machine seizes the spin, RESULT HIDDEN on the hidden spin.
## No-op if it isn't armed, so an activation condition can't double-fire the popup.
func _pop_deferred_negative(id: String) -> void:
	if not _pending_deferred_neg.get(id, false):
		return
	_pending_deferred_neg.erase(id)
	_show_deferred_negative(id)

## Pops just the negative line for a deferred-negative item (issue #76).
func _show_deferred_negative(id: String) -> HintLabel:
	return _spawn_hint(id, true, false)

## Pops just the positive line for an upside that activates after the item is consumed.
func _show_deferred_positive(id: String) -> HintLabel:
	return _spawn_hint(id, false, true)

func _pill_guaranteed_spin_pending() -> bool:
	return int(RunStateStore.forceFlatlineSpins) <= 0 and int(RunStateStore.guaranteedTripleSpins) > 0

## Builds one HintLabel. `negative_only` shows just the downside; `positive_only` shows
## just the upside. Otherwise both lines show (the classic on-use hint).
func _spawn_hint(id: String, negative_only: bool, positive_only: bool) -> HintLabel:
	# The losing state is represented by the loss art and its beep alone — no text
	# bubble may appear while it is active, including on-use consumable hints.
	if RunStateStore.comboDefeatPending:
		return null
	var hint := _hint_for(id)
	if hint.is_empty():
		return null
	if not _hints.has_layer():
		_build_hint_layer()
	return _hints.spawn(
		"" if negative_only else String(hint["pos"]),
		"" if positive_only else String(hint["neg"]),
		_item_display_name(id), _item_reads_corrupted(id), hint_grow_time)

## The +/- vocabulary for an item, which on a joker run is the inverted one (issue #111).
func _hint_for(id: String) -> Dictionary:
	if RunStateStore.augmented_joker_items_active() and joker_use_hints.has(id):
		return joker_use_hints[id] as Dictionary
	return use_hints.get(id, {}) as Dictionary

## Purple name. The standing rule is the explicit HintLabel list; on a joker run every
## in-run item joins it, because every one of them is now something done TO the player.
func _item_reads_corrupted(id: String) -> bool:
	if RunStateStore.augmented_joker_items_active() and InRunItems.JOKER_EFFECTS.has(id):
		return true
	return HintLabel.item_is_corrupted(id)

func _play_consumable_lucidity_feedback(lucidity_before: int) -> void:
	var target_lucidity := int(RunStateStore.lucidityCoins)
	var lucidity_gain := maxi(0, target_lucidity - lucidity_before)
	if lucidity_gain <= 0:
		return
	_coin_prev_lucidity = target_lucidity
	# Consumable Lucidity is an economy value, not wealth. It updates immediately and
	# never spawns the removed cash-tray-to-wealth coin sequence.

# ── serum symbol picker (issue #53) ──────────────────────────────────────────────
# Using Serum opens a small overlay listing every reel symbol except brain; the
# picked one is guaranteed to appear at least once next spin (the charge is only
# consumed on pick — tapping anywhere else cancels).

func _begin_serum() -> void:
	if _choices.serum_open() \
			or (_sequence_lock_active and not RunStateStore.comboDefeatPending):
		return
	if not RunStateStore._can_use_consumable():
		return
	_build_serum_picker()

## Every reel symbol except brain — Serum guarantees a symbol, and guaranteeing the
## one the machine is named after is not a choice worth offering.
func _build_serum_picker() -> void:
	var pool: Array[String] = []
	for s in Symbols.BASE_SYMBOL_CYCLE:
		if String(s) != "brain":
			pool.append(String(s))
	_choices.open_serum(pool, _on_serum_pick, _close_serum_picker)

func _on_serum_pick(symbol_id: String) -> void:
	_close_serum_picker()
	var lucidity_before := int(RunStateStore.lucidityCoins)
	if not RunStateStore.use_consumable("cons_focus", symbol_id):
		return
	_refresh_reels_from_state()
	_update_hud()
	_show_consumable_feedback("cons_focus")
	_play_use_fx("cons_focus")
	_play_consumable_lucidity_feedback(lucidity_before)

func _close_serum_picker() -> void:
	_choices.close_serum()

# Centre of the spins tube on the canvas (the authored art spans x 3..18,
# y 47..105 in its native full-canvas frame): spin-restore fly-ins land here.
const HEALTH_TUBE_TARGET := Vector2(11.0, 76.0)

## Tea (issue #53): the restored free spins fly from the used stash slot to the
## spins tube, which pulses as the tea lands.
func _play_tea_flight(slot_index: int) -> void:
	if not consumable_fx_enabled:
		return
	var tex := _icon_for("cons_tea")
	if tex == null:
		return
	var icon := TextureRect.new()
	icon.texture = tex
	icon.size = Vector2(12.0, 12.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.z_index = 130
	icon.add_to_group(WEALTH_TRANSIENT_FX_GROUP)
	icon.position = Assets.stash_slot_pos(slot_index, max_consumable_slots)
	add_child(icon)
	var tw := create_tween()
	tw.tween_property(icon, "position", HEALTH_TUBE_TARGET, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(icon.queue_free)
	# The counter pulse + tick now belongs to the "+N" fly-in (issue #66), which
	# travels alongside this icon and lands on the same beat.

## Issue #66: a "+N" popup pops in at `origin` and flies into the spins tube.
## The tube's fill is held back (_pending_spin_gain) while the popup is in
## flight, then ticks up with a flash exactly when it lands — reward visible,
## value in sync, ~0.7s total so gameplay is not delayed.
func _play_spin_gain_fx(amount: int, origin: Vector2, flight_time := 0.55,
		already_held := false) -> void:
	if amount <= 0:
		return
	if not consumable_fx_enabled or _health_bar_sprite == null or not is_inside_tree():
		if already_held:
			_pending_spin_gain = maxi(0, _pending_spin_gain - amount)
		_update_hud()
		return
	if not already_held:
		_pending_spin_gain += amount
	_update_hud()
	var gain := Label.new()
	gain.name = "SpinGainFx"
	gain.text = "+%d" % amount
	gain.position = origin
	gain.z_index = 130
	gain.add_to_group(WEALTH_TRANSIENT_FX_GROUP)
	gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gain.add_theme_font_size_override("font_size", 8)
	if _font != null:
		gain.add_theme_font_override("font", _font)
	gain.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
	gain.add_theme_color_override("font_outline_color", Color.BLACK)
	gain.add_theme_constant_override("outline_size", 1)
	add_child(gain)
	gain.pivot_offset = Vector2(6.0, 5.0)
	gain.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(gain, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(gain, "position", HEALTH_TUBE_TARGET, flight_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_land_spin_gain.bind(amount, gain))

func _land_spin_gain(amount: int, gain: Label) -> void:
	if is_instance_valid(gain):
		gain.queue_free()
	_pending_spin_gain = maxi(0, _pending_spin_gain - amount)
	_update_hud()
	if _health_bar_sprite != null and is_instance_valid(_health_bar_sprite):
		var pulse := create_tween()
		pulse.tween_property(_health_bar_sprite, "modulate",
			Color(1.6, 1.6, 1.6), 0.1)
		pulse.tween_property(_health_bar_sprite, "modulate", Color.WHITE, 0.14)

# White Powder: consume the charge, then pick a source reel and a target reel to
# copy onto. Needs a spin result to copy from.
func _begin_white_powder() -> void:
	if _sequence_lock_active and not RunStateStore.comboDefeatPending:
		return
	if not RunStateStore._can_use_consumable() or RunStateStore.lastResult == null:
		return
	if not RunStateStore.use_consumable("cons_white_powder"):
		return
	# Issue #76: show the upside now (and arm RESULT HIDDEN for the next spin); the copy
	# picker arms right after, so the player sees what the item does as they pick.
	_show_consumable_feedback("cons_white_powder")
	_copy_source = -1
	_arm_reel_picker(func(reel_index: int) -> void: _on_copy_pick(reel_index))

func _on_copy_pick(reel_index: int) -> void:
	if _sequence_lock_active and not RunStateStore.comboDefeatPending:
		return
	if _reel_is_dead(reel_index):
		return
	if _copy_source < 0:
		_copy_source = reel_index # source chosen; re-arm to pick the target
		_arm_reel_picker(func(target_index: int) -> void: _on_copy_pick(target_index))
	else:
		var src := _copy_source
		_copy_source = -1
		var combo_pending := RunStateStore.comboDefeatPending
		_hud_delta_hold = true # deltas pop with the copy's score popup (issue #54)
		if RunStateStore.copy_reel(src, reel_index):
			_pending_combo_power_flow = combo_pending
			_maybe_cancel_combo_defeat_warning(combo_pending)
		_play_white_powder_distortion()
		_clear_targeting()
		_refresh_reels_from_state()
		_update_hud()
		_refresh_jackpot_lamp()
		_play_reward_sequence(reel_index, true) # copy-made triples now trigger normally

# ── consumable visuals (issue #34) ───────────────────────────────────────────────
# Presentation-only per-item effects. Duration effects (tobacco smoke, energy-drink
# edges) derive purely from store counters via _refresh_consumable_fx() so they
# survive scene re-entry and revert the moment the counter hits 0; one-shots
# (cocktail shake, potion hop/popup, hidden-result covers) fire from use/spin hooks.

# The cabinet's transparent reel holes are y169-203 in the art (measured with
# pngjs), 1px taller above and 3px below REEL_HOLES — full-reel covers must span
# the real hole or the symbol strip peeks out underneath.
func _build_fx_layer() -> void:
	_consumable_fx.build({
		"tobacco_cover": tobacco_cover_color,
		"tobacco_smoke": tobacco_smoke_color,
		"energy_edge": energy_edge_color,
		"energy_thickness": energy_edge_thickness,
		"hidden_cover": hidden_cover_color,
		"hidden_glyph": hidden_glyph_color,
	})
	# The blur covers are ReelBlur's but share this layer, so they are built here
	# and to the same full-reel rect the consumable covers use.
	var blur_rects: Array = []
	for i in 3:
		blur_rects.append(_consumable_fx.cover_rect(REEL_HOLES[i]))
	_reel_blur.build_blur_covers(_consumable_fx.layer(), blur_rects, blur_cover_color)

func _refresh_consumable_fx() -> void:
	if _consumable_fx.layer() == null:
		return
	_refresh_tobacco_fx()
	_refresh_energy_fx()

## Tobacco hides the LAST reels from scoring (reels.slice keeps the first ones),
## so smoke exactly those. Hallucination changes scoring/reward scale but leaves
## all three reels visible.
func _refresh_tobacco_fx() -> void:
	var tobacco_active := RunStateStore.pairBoostSpins > 0 \
		or _boosts.lingering("pairBoostSpins")
	var smoking := consumable_fx_enabled and tobacco_fx_enabled and tobacco_active
	_consumable_fx.set_tobacco(_blind_reel_count(), smoking)
	_consumable_fx.set_tunnel_shutter(Economy.has_tunnel_vision(RunStateStore.ownedUpgrades))

## Reels currently out of the scoring, read from live state rather than the last result so a
## run that owns Tunnel Vision is blind from its first frame, before any spin has landed.
## Tobacco keeps its reel covered through the zero-count linger, like its icon.
func _blind_reel_count() -> int:
	var hidden := _active_hidden_reel_count() # whatever the last scored result used
	if Economy.has_tunnel_vision(RunStateStore.ownedUpgrades):
		hidden = maxi(hidden, 1)
	if RunStateStore.pairBoostSpins > 0 or _boosts.lingering("pairBoostSpins"):
		hidden = maxi(hidden, clampi(RunStateStore.pairBoostHiddenReels, 0, 2))
	return clampi(hidden, 0, 2)

func _refresh_energy_fx() -> void:
	var active := consumable_fx_enabled and energy_fx_enabled and RunStateStore.decaySkips > 0
	if not _consumable_fx.set_energy(active, energy_pulse_time):
		return
	# The drink used to fade the spins tube out for its duration. It stays up now — the
	# rush is told by the edges alone, and hiding the tube took away the one readout the
	# player still needs while it runs. Any fade left mid-flight is returned here. The
	# tube is the machine's, which is why this half did not move with the edges.
	var tw := create_tween()
	tw.set_parallel(true)
	for node in _spins_bar_nodes():
		tw.tween_property(node, "modulate:a", 1.0, energy_fade_time)

func _spins_bar_nodes() -> Array:
	var nodes: Array = []
	for n in [_health_bar_sprite]:
		if n != null and is_instance_valid(n):
			nodes.append(n)
	return nodes

## One-shot on-use feedback. Only the Cocktail has one today; duration effects
## light up via _refresh_consumable_fx() on the same state_changed commit.
func _play_use_fx(id: String) -> void:
	if not consumable_fx_enabled:
		return
	if id == "item_cocktail" and cocktail_fx_enabled:
		_play_cocktail_shake()
	elif id == "cons_tea" and tea_fx_enabled:
		_play_tea_sakura_fx()
	elif id == "item_water" and water_fx_enabled \
			and not RunStateStore.augmented_joker_items_active():
		# The pour reads as refreshment. A joker Water drains the gauge, so it gets the
		# drink's absence rather than a celebration of it (issue #111).
		_play_water_animation()

func _play_water_animation() -> void:
	_consumable_fx.pour_water(water_frame_time)

func _play_cocktail_shake() -> void:
	if _cocktail_shake_tween != null and _cocktail_shake_tween.is_valid():
		_cocktail_shake_tween.kill()
	if _nudge_tween != null and _nudge_tween.is_valid():
		_nudge_tween.kill()
	position.x = 0.0
	_cocktail_shake_tween = create_tween()
	var swings := 6
	var step := cocktail_shake_time / float(swings + 1)
	for s in swings:
		var dir := 1.0 if s % 2 == 0 else -1.0
		var decay := 1.0 - float(s) / float(swings)
		_cocktail_shake_tween.tween_property(self, "position:x", cocktail_shake_strength * dir * decay, step)
	_cocktail_shake_tween.tween_property(self, "position:x", 0.0, step)

func _play_potion_spin_fx() -> void:
	if not (consumable_fx_enabled and potion_fx_enabled):
		return
	var pick: Variant = RunStateStore.lastPotionEffect
	if pick == null:
		return
	_play_potion_jump()
	_show_potion_popup(_potion_effect_text(pick), _potion_effect_color(pick))

func _play_potion_jump() -> void:
	if _potion_jump_tween != null and _potion_jump_tween.is_valid():
		_potion_jump_tween.kill()
	position.y = 0.0
	_potion_jump_tween = create_tween()
	_potion_jump_tween.tween_property(self, "position:y", -potion_jump_height, 0.09)
	_potion_jump_tween.tween_property(self, "position:y", 0.0, 0.14) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _play_tea_sakura_fx() -> void:
	_consumable_fx.tea_petals(tea_petal_count, tea_petal_time, tea_petal_color)

func _play_white_powder_distortion() -> void:
	if not (consumable_fx_enabled and white_powder_fx_enabled):
		return
	_consumable_fx.white_powder_ripple(
		white_powder_distortion_strength, white_powder_distortion_time)

func _potion_effect_text(pick: Dictionary) -> String:
	match String(pick.get("kind", "")):
		"lucidity":
			var amt := int(pick["amount"])
			return ("+%d LUCIDITY" % amt) if amt >= 0 else ("%d LUCIDITY" % amt)
		"freeReroll":
			return "FREE REROLL"
		"symbolToBrain":
			return "BRAIN SWAP"
		"restoreSpin":
			return "+%d SPIN" % int(pick.get("count", 1))
		"restorePower":
			return "POWER BACK"
		"adjacentSymbol":
			return "SYMBOL SHIFT"
	return ""

func _potion_effect_color(pick: Dictionary) -> Color:
	if String(pick.get("kind", "")) == "lucidity" and int(pick.get("amount", 0)) < 0:
		return potion_popup_negative_color
	return potion_popup_color

func _show_potion_popup(text: String, color: Color) -> void:
	var fx_layer := _consumable_fx.layer()
	if text.is_empty() or fx_layer == null:
		return
	var label := Label.new()
	label.add_to_group(WEALTH_TRANSIENT_FX_GROUP)
	label.text = text
	# Centred band, sat between the TV and the multiplier strip.
	const POPUP_SIZE := Vector2(100.0, 10.0)
	const POPUP_Y := 112.0
	label.size = POPUP_SIZE
	label.position = Vector2((SRC_W - POPUP_SIZE.x) * 0.5, POPUP_Y)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 8)
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	fx_layer.add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 10.0, potion_popup_time)
	tw.tween_property(label, "modulate:a", 0.0, potion_popup_time)
	tw.set_parallel(false)
	tw.tween_callback(label.queue_free)

func _set_hidden_result_active(active: bool) -> void:
	_hide_result_active = active
	# Covers are (re)shown per reel as each reveal lands; toggling always clears.
	_consumable_fx.hide_hidden_covers()

func _set_hidden_cover(index: int, visible_now: bool) -> void:
	_consumable_fx.set_hidden_cover(index, visible_now)

# Serum downside: after the guaranteed-symbol spins, hide the strip neighbours above
# and below each center symbol so only the actual result remains readable.
# Legacy frost covers stay built but inactive; Serum now hides adjacent strip symbols.
# ── machine reactions (issue #35) ────────────────────────────────────────────────
# All reactions run in this presentation layer AFTER the parity-pinned spin()/power
# results, so they never touch evaluate()/spin() outputs or the pinned vectors.

## Reacts to the just-settled reels. `power_triggered` is true when a power (reroll/
## shift) produced them, so the brains triple still grants a spin even though the
## pinned evaluate only grants free spins on a natural, non-free spin.
func _apply_machine_reactions(power_triggered: bool) -> void:
	var lr: Variant = RunStateStore.lastResult
	if lr == null:
		return
	var reels: Array = lr["reels"]
	if reels.size() < 3:
		return
	# One reaction per distinct reel configuration (a power can make a new one).
	if reels == _last_reacted_reels and RunStateStore.spinCount == _last_reacted_spin:
		return
	_last_reacted_reels = reels.duplicate()
	_last_reacted_spin = RunStateStore.spinCount
	var win_type := String(lr.get("winType", ""))
	# Tobacco (issue #53): while a reel is hidden the spin scores as pair/miss, so a raw
	# 3-of-a-kind must NOT fire its 3x bonus (jackpot spin, powers back, reveal, flatline
	# strike...). Gating on the scored winType blocks exactly those spins.
	if win_type != "triple" and win_type != "jackpot":
		return
	# A power that left an existing win standing untouched has not formed anything new, so
	# its combination must not react a second time either (it did not pay again).
	if bool(lr.get("combinationReplayed", false)):
		return
	if bool(lr.get("bookJoker", false)) and bool(lr.get("bookTripleChoice", false)):
		_show_book_triple_choice(int(lr.get("freeSpinsGranted", 0)), power_triggered)
		return
	var symbol := _triple_reaction_symbol(lr, reels)
	if symbol == "":
		return
	# Every route to a triple ends here — a raw 3-of-a-kind, a book standing in for one, or
	# a visible pair promoted by Hallucination / a hidden reel — so a flatline triple always
	# registers its strike no matter which of them formed it.
	if symbol == "flatline":
		_show_flatline_result_reaction(RunStateStore.register_flatline_result())
	else:
		_apply_symbol_triple(symbol, int(lr.get("freeSpinsGranted", 0)), power_triggered)

## The symbol a scored triple/jackpot resolved to. The score already decided this IS a
## triple, so the shape of the reels is only being read to find out which symbol it paid
## for: the book's resolution when one stood in, otherwise the 3-of-a-kind, otherwise the
## matching pair — on ANY two reels, because Hallucination promotes reels 2+3 and Pattern 23's
## reels 1+3 exactly like reels 1+2 (issue #35 follow-up).
func _triple_reaction_symbol(lr: Dictionary, reels: Array) -> String:
	if bool(lr.get("bookJoker", false)):
		return String(lr.get("resolvedSymbol", ""))
	var a := String(reels[0])
	var b := String(reels[1])
	var c := String(reels[2])
	if a == b and b == c:
		return a
	# A hidden reel is out of the scoring, so only the reels that still count can pair up.
	var visible := maxi(1, 3 - _active_hidden_reel_count())
	if visible < 3:
		for i in visible - 1:
			if String(reels[i]) == String(reels[i + 1]):
				return String(reels[i])
		return ""
	if a == b:
		return a
	if b == c:
		return b
	if a == c:
		return a
	return ""

func _apply_symbol_triple(symbol: String, free_spins_granted: int, _power_triggered: bool) -> void:
	var color := flatline_result_color
	var label := ""
	# Spin restores fly a "+N" into the spins counter (issue #66); the fx uses the
	# visible spins-left delta, so the bar and label land together.
	var spins_before := _current_display_spins_left()
	match symbol:
		"brain":
			# ALWAYS a free spin: on a natural spin the pinned evaluate already granted
			# one (free_spins_granted > 0); only top up when it didn't (power / free spin).
			if free_spins_granted <= 0:
				RunStateStore.grant_free_spins(triple_brain_free_spins)
				_play_spin_gain_fx(_current_display_spins_left() - spins_before,
					_reel_window_center())
			color = triple_brain_color
			label = "FREE"  # 🎨 "FREE" sticker art pending — text placeholder
		"eye":
			# The player picks the reel to reveal (issue follow-up): the reel-selection
			# UI arms and the chosen reel's NEXT spin result pops up when it lands.
			color = triple_eye_color
			label = "PICK A REEL"
			call_deferred("_arm_eye_reveal_picker")
		"pill":
			RunStateStore.restore_all_powers()
			color = triple_pill_color
			label = "POWERS BACK"
		"syringe":
			color = triple_syringe_color
			label = "RECOVERED" if RunStateStore.recover_last_consumable(maxi(1, max_consumable_slots)) else "SYRINGE"
		"vial":
			RunStateStore.restore_spins(triple_vial_free_spins)
			_play_spin_gain_fx(_current_display_spins_left() - spins_before,
				_reel_window_center())
			color = triple_vial_color
			label = "+%d SPINS" % triple_vial_free_spins
	_spawn_reaction_flash(color, label)
	_update_hud()

## "flatline" is in the row with the five symbols but is not a triple — picking it
## registers a flatline result instead, which is why the choice list is the
## machine's and the overlay only draws what it is handed.
const BOOK_TRIPLE_CHOICES := ["brain", "eye", "pill", "syringe", "vial", "flatline"]

func _show_book_triple_choice(free_spins_granted: int, power_triggered: bool) -> void:
	_set_sequence_lock(true)
	_choices.open_book(BOOK_TRIPLE_CHOICES,
		func(symbol_id: String) -> void:
			_on_book_triple_choice(symbol_id, free_spins_granted, power_triggered))

func _on_book_triple_choice(symbol_id: String, free_spins_granted: int, power_triggered: bool) -> void:
	_close_book_choice_overlay()
	_set_sequence_lock(false)
	if symbol_id == "flatline":
		var count := RunStateStore.register_flatline_result()
		_show_flatline_result_reaction(count)
	else:
		_apply_symbol_triple(symbol_id, free_spins_granted, power_triggered)

func _close_book_choice_overlay() -> void:
	_choices.close_book()

func _reel_window_center() -> Vector2:
	return Vector2(SRC_W * 0.5 - 6.0,
		float(REEL_WINDOW["top"]) + float(REEL_WINDOW["height"]) * 0.5)

# ── 3x eye reveal (player-picked reel) ───────────────────────────────────────────
# Reuses the shared reel-selection UI. Tapping a reel reveals its NEXT-spin symbol
# INSTANTLY (issue #53): the store rolls it through the normal weight pipeline and
# commits it, so the next spin's evaluate() honours the revealed promise.

func _arm_eye_reveal_picker() -> void:
	_arm_reel_picker(func(reel_index: int) -> void: _on_eye_reveal_pick(reel_index))

func _on_eye_reveal_pick(reel_index: int) -> void:
	if _reel_is_dead(reel_index):
		return
	_clear_targeting()
	var symbol := RunStateStore.reveal_next_reel_symbol(reel_index)
	if symbol == "":
		return
	_reveal_reel_next_spin = reel_index # that reel also stops early next spin
	_show_eye_reveal_popup(reel_index, symbol)

## Names the revealed symbol over the picked reel. The pointer takes the triple-eye
## colour, which is the machine's palette rather than the overlay's.
func _show_eye_reveal_popup(reel_index: int, symbol_id: String) -> void:
	_choices.show_eye_reveal(reel_index, symbol_id, triple_eye_color,
		WEALTH_TRANSIENT_FX_GROUP)

## Instant death: too many flatline results ends THIS RUN through the normal
## flatline ending (banks lucidity, shows the #38 fatal text, offers CONTINUE
## while campaign neurons remain) — it does not fail the whole campaign.
func _check_flatline_instant_death() -> bool:
	if RunStateStore.flatlineResultCount < _flatline_restriction_limit():
		return false
	var run := {
		"neurons": RunStateStore.neurons,
		"scoreEarned": RunStateStore.scoreEarned,
		"lucidityCoins": _machine_lucidity_after_deductions(),
	}
	# The killing strike gets to play: the FLATLINE line-sweep and its 3/3 count run to the
	# end before the ending screen takes over, instead of being cut off the frame they land.
	# The machine is locked meanwhile so nothing can be pressed during the beat.
	if fatal_flatline_reaction_delay <= 0.0:
		_show_ending("flatline", run)
		return true
	_set_sequence_lock(true)
	_show_fatal_flatline_ending(run)
	return true

func _show_fatal_flatline_ending(run: Dictionary) -> void:
	await get_tree().create_timer(fatal_flatline_reaction_delay).timeout
	if not is_inside_tree() or _overlay != null:
		return
	_show_ending("flatline", run)

func _show_flatline_result_reaction(count: int) -> void:
	var survived := count < _flatline_restriction_limit()
	# Issue #76: a non-fatal strike charges the next winning pair/triple — say so, since
	# the payoff lands on a later spin and would otherwise feel disconnected. A fatal
	# strike ends the run, so there is no next win to charge and no heartbeat to feel.
	var charge := ""
	if survived:
		_play_close_call_heartbeat()
		charge = "NEXT WIN x%d" % EconomyConst.FLATLINE_WIN_BOOST_MULT
	var headline := "CLOSE CALL" if survived else "FLATLINE"
	_reactions.play_flatline(REEL_WINDOW, flatline_result_color,
		"%s  %d/%s" % [headline, count, _flatline_restriction_limit_text()], charge,
		reaction_flash_time)

func _play_close_call_heartbeat() -> void:
	if not (consumable_fx_enabled and close_call_fx_enabled):
		return
	_clear_close_call_heartbeat()
	var center := Vector2(SRC_W * 0.5, SRC_H * 0.5)
	var zoom := maxf(1.0, close_call_zoom_scale)
	var zoom_pos := -center * (zoom - 1.0)
	var half_time := close_call_zoom_time * 0.5
	_close_call_heartbeat_tween = create_tween()
	_close_call_heartbeat_tween.set_parallel(true)
	_close_call_heartbeat_tween.tween_property(self, "scale", Vector2(zoom, zoom), half_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_close_call_heartbeat_tween.tween_property(self, "position", zoom_pos, half_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_close_call_heartbeat_tween.chain()
	_close_call_heartbeat_tween.tween_property(self, "scale", Vector2.ONE, half_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_close_call_heartbeat_tween.tween_property(self, "position", Vector2.ZERO, half_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_close_call_heartbeat_tween.chain().tween_callback(_clear_close_call_heartbeat)

func _clear_close_call_heartbeat() -> void:
	if _close_call_heartbeat_tween != null and _close_call_heartbeat_tween.is_valid():
		_close_call_heartbeat_tween.kill()
	_close_call_heartbeat_tween = null
	scale = Vector2.ONE
	position = Vector2.ZERO

func _spawn_reaction_flash(color: Color, text: String) -> void:
	_reactions.play(color, text, reaction_flash_time)

func _reaction_label(parent: Control, text: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = Vector2(SRC_W, 20.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	parent.add_child(label)
	return label

## Whether an intermediate Wealth target is standing beaten and unpaid. Reaching it
## is a score fact, not a spin outcome: an item or a power that pushes the score over
## the line makes it due exactly like a paying reveal does.
func _wealth_target_due_now() -> bool:
	return campaign_goal_score == EconomyConst.WEALTH_SCORE_THRESHOLD \
		and not RunStateStore.wealthContinued \
		and RunStateStore.current_wealth_target() < EconomyConst.WEALTH_SCORE_THRESHOLD \
		and RunStateStore.wealth_target_due()

## Claims a due target and puts its payout screen up. Called from every path that can
## move the score — the spin tail, a consumable, a power rescore — so the player never
## has to press SPIN again just to be told the target was already beaten.
## Returns true when the transition took the screen.
## A beaten target outranks a pending combo defeat. The rescue window exists to let the
## player buy their way out before the confirming spin, and beating the target IS the way
## out: the round ends on the payout, so the loss resolves into it (the multiplier still
## steps down) rather than holding the screen for a spin nobody has to take.
func _proc_wealth_target() -> bool:
	if _wealth_target_transition_active:
		return false
	if not _wealth_target_due_now():
		return false
	var target_info := RunStateStore.begin_wealth_target()
	if target_info.is_empty():
		return false
	if RunStateStore.comboDefeatPending:
		RunStateStore.resolve_pending_combo_defeat(false)
		_close_pending_combo_defeat()
	return _start_wealth_target_transition(target_info)

## Score gained outside the spin sequence (item / power). Pops the target payout the
## moment it is earned; returns true when something took the screen and the caller
## must not carry on with its own presentation.
func _settle_off_spin_score_change() -> bool:
	if _proc_wealth_target():
		return true
	return _check_ending()

func _check_ending() -> bool:
	# The target is settled even while a loss warning is up (see _proc_wealth_target);
	# only the ending itself waits for the confirming spin.
	if _proc_wealth_target():
		return true
	if RunStateStore.comboDefeatPending:
		return false
	var run := {
		"neurons": RunStateStore.neurons,
		"scoreEarned": RunStateStore.scoreEarned,
		"lucidityCoins": _machine_lucidity_after_deductions(),
	}
	var ending: Variant = Endings.check_ending(run, {}, campaign_goal_score)
	if ending == null:
		return false
	if ending == "wealth" and RunStateStore.wealthContinued:
		# check_ending short-circuits on the score, so a wealth-continued run that
		# runs out of neurons would otherwise never flatline — the spin button dies
		# and nothing re-checks endings, a softlock (issue #62).
		if int(RunStateStore.neurons) > 0:
			return false
		ending = "flatline"
	# Banked free spins are real spins the player can still take at 0 neurons (the
	# spin gate, the wealth CONTINUE check, and the SPINS LEFT counter all count
	# them), so a spin that drains the last neurons while granting spins back must
	# not flatline; the flatline resolves once both pools are empty (issue #75).
	if ending == "flatline" and int(RunStateStore.freeSpinsRemaining) > 0:
		return false
	_show_ending(String(ending), run)
	return true

## Every ending path (flatline, game over, wealth) funnels through _show_ending;
## tear the live-run presentation down synchronously first so no dealer UI, loss
## warning, gauge effect, or transient sequence overlay survives into the
## terminal screens.
func _cleanup_transient_presentation() -> void:
	_stop_wealth_target_transition()
	_wealth_target_transition_active = false
	if _dealer_overlay != null or _dealer_offer_popup != null:
		_close_dealer(false)
	_callouts.stop_loss_beep()
	_callouts.set_loss_display(0)
	if _pending_combo_overlay != null:
		_pending_combo_overlay.queue_free()
		_pending_combo_overlay = null
	_callouts.stop_win()
	_callouts.stop_combo()
	for fx in [_mult_fx_2, _mult_fx_3, _mult_fx_fire]:
		if fx != null:
			(fx as Sprite2D).visible = false
	_hide_compulsive_overlay()
	_clear_targeting()
	_stash.set_elevated(false)

# Fallback ending overlay (used when no authored ending scene answers). Both the copy
# column and the button are centred bands, so each is parametric on its own inset.

func _show_ending(ending: String, run: Dictionary) -> void:
	_cleanup_transient_presentation()
	_stop_flatline_countdown()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	# The ending host is claimed before the state commits below, not after: end_run
	# and mark_ending_reached are what earn this ending's cards, and a live _overlay
	# is what tells the unlock popup to wait rather than beat the ending screen onto
	# the scene. The queue is drained once the player leaves it (issue #52).
	_overlay = Control.new()
	_overlay.position = Vector2.ZERO
	_overlay.size = Vector2(SRC_W, SRC_H)
	_overlay.z_index = ENDING_OVERLAY_Z_INDEX
	add_child(_overlay)
	# A running campaign reserves its neuron until end_run(). Account for that
	# pending spend while resolving the terminal presentation, then commit the
	# resolved ending once so lastEnding and the persisted balance agree.
	var neurons_after_run := int(MetaStateStore.campaignNeuronsLeft) \
		- (1 if (RunStateStore.campaignNeuronPending \
			or RunStateStore.campaignNeuronRunActive) \
			and (ending == "flatline" or ending == "game_over") \
			and not RunStateStore.wealthContinued else 0)
	var resolved_ending := "game_over" if ending == "flatline" \
		and neurons_after_run <= 0 else ending
	# Freeze the values once, before end_run can clear terminal-only balances.  The
	# scene that was responsible for the ending normally supplied these directly
	# from RunStateStore; the fallback keeps a manually resumed/legacy presentation
	# deterministic without ever adding to the machine score.
	var requested_score := maxi(0, int(run.get("scoreEarned", RunStateStore.scoreEarned)))
	var requested_lucidity := maxi(0,
		int(run.get("lucidityCoins", RunStateStore.lucidityCoins)))
	var committed := RunStateStore.end_run(resolved_ending, requested_score,
		requested_lucidity)
	if committed:
		MetaStateStore.mark_ending_reached(resolved_ending)
		# Wealth banking is deferred until the player chooses Start Again so the ending
		# animation can show the full run total before the wallet is updated.  Flatline
		# and game-over bank exactly this same frozen snapshot, once.
		if resolved_ending != "wealth" and RunStateStore.claim_ending_bank():
			MetaStateStore.bank_run({
				"neurons": int(run.get("neurons", RunStateStore.neurons)),
				"scoreEarned": RunStateStore.endingScoreSnapshot,
				"lucidityCoins": RunStateStore.endingLuciditySnapshot,
			}, resolved_ending)
	var frozen_run := run.duplicate(true)
	frozen_run["scoreEarned"] = maxi(0, int(requested_score if \
		RunStateStore.endingScoreSnapshot < 0 else RunStateStore.endingScoreSnapshot))
	frozen_run["lucidityCoins"] = maxi(0, int(requested_lucidity if \
		RunStateStore.endingLuciditySnapshot < 0 else RunStateStore.endingLuciditySnapshot))
	# Wealth banking is deferred until the player chooses Start Again so the ending
	# animation can show the full run total before the wallet is updated.  The
	# presentation is a read-only copy; it never writes scoreEarned or lucidityCoins.

	# The stash tray draws at z 50 and would float over the ending presentation.
	_stash.set_tray_visible(false)
	# Three endings, three authored screens. A generic dim/title/wallet/button
	# fallback used to sit below this and was UNREACHABLE: check_ending only ever
	# yields "wealth" or "flatline", and the neuron check above turns the second into
	# "game_over", so all three returned before reaching it. Worse, half of it was
	# written for a flatline that had already been handled — a fatal-copy title and a
	# countdown branch nothing could run.
	#
	# The default arm replaces it. A fourth ending now fails the smoke suite through
	# the engine-error gate instead of silently drawing a screen nobody has seen.
	match resolved_ending:
		"wealth":
			_build_wealth_screen(frozen_run)
		"game_over":
			_build_game_over_screen(frozen_run)
		"flatline":
			_build_flatline_screen(frozen_run)
		_:
			push_error("machine: no ending screen for '%s'" % resolved_ending)

## Dedicated issue #140 flatline presentation. The visual layer owns the focused
## message, animated trace, and action; MachineScene retains countdown state,
## banking, and the existing dealer/menu transition.
func _build_flatline_screen(run: Dictionary) -> void:
	var fatal_copy := fatal_flatline_text if not _has_campaign_neurons_remaining() else ""
	_flatline.build_screen(run, _flatline_action_text(), fatal_copy, _on_flatline_action_pressed)


## Terminal campaign ending: the machine remains visible, damaged, and un-dimmed.
## The dedicated scene owns the game-over machine art, red title, draining credit
## readout, and broken-neon retry action; the machine keeps the state transition here.
func _build_game_over_screen(run: Dictionary = {}) -> void:
	_clear_wealth_presentation_fx()
	var game_over_screen := GAME_OVER_ENDING_SCENE.instantiate() as GameOverEndingOverlay
	_overlay.add_child(game_over_screen)
	game_over_screen.present(int(run.get("lucidityCoins", 0)))
	# The terminal loss still shows the third campaign neuron being spent. The
	# meter keeps all completed death overlays above the damaged machine art.
	var game_over_meter := NeuronMeter.attach(game_over_screen, Vector2(80.0, 84.0))
	game_over_meter.name = "CampaignNeuronMeter"
	game_over_meter.z_index = 2
	game_over_meter.play_loss_animation()
	game_over_screen.try_again_pressed.connect(_on_game_over_try_again_pressed)

## Dedicated wealth-ending screen: the final score is presented, then Start Again
## banks the run and returns to the menu hub.
func _build_wealth_screen(run: Dictionary) -> void:
	_clear_wealth_presentation_fx()
	var wealth_screen := WEALTH_ENDING_SCENE.instantiate() as WealthEndingOverlay
	_overlay.add_child(wealth_screen)
	wealth_screen.present(int(run["scoreEarned"]), _cash_tray_pos(), _can_resume_after_wealth())
	wealth_screen.continue_pressed.connect(_continue_from_wealth)
	wealth_screen.start_again_pressed.connect(_start_again_from_wealth.bind(run))

## Ending overlays must be the only presentation layer left alive. State commits can
## arrive on the same frame as the wealth transition, so clear the pooled HUD effects
## explicitly instead of relying on the normal refresh path (which is intentionally
## blocked while the wealth screen is visible).
func _clear_wealth_presentation_fx() -> void:
	_set_tv_progress_bars_visible(false)
	_boosts.hide_all()

	_clear_targeting()
	_close_score_table()
	_augments.hide_augmented_popup()
	_augments.hide_pacte_popup()
	_hide_item_info_popup()
	_close_serum_picker()
	_close_book_choice_overlay()
	if _dealer_overlay != null:
		_close_dealer(false)
	_hide_compulsive_overlay()
	_compulsive_queued = false
	_copy_source = -1
	_pending_spin_gain = 0
	_pending_dealer_offer = false
	_power_coins_in_flight = 0
	_power_batch_running = false

	_consumable_fx.reset()
	_reel_blur.clear_blur()
	_hide_result_active = false
	_reel_symbols.set_adjacent_hidden(false)

	if _cocktail_shake_tween != null and _cocktail_shake_tween.is_valid():
		_cocktail_shake_tween.kill()
	_cocktail_shake_tween = null
	if _potion_jump_tween != null and _potion_jump_tween.is_valid():
		_potion_jump_tween.kill()
	_potion_jump_tween = null
	if _nudge_tween != null and _nudge_tween.is_valid():
		_nudge_tween.kill()
		_nudge_tween = null
	_stop_restore_flash() # never leave a chip overdriven or a glow painted on the gauge
	if _reserve_glow_tween != null and _reserve_glow_tween.is_valid():
		_reserve_glow_tween.kill()
	_reserve_glow_tween = null
	if _reserve_glow_sprite != null and is_instance_valid(_reserve_glow_sprite):
		_reserve_glow_sprite.visible = false
	_clear_close_call_heartbeat()
	position = Vector2.ZERO

	_wealth.stop_roll()
	# A teardown mid-payout must not strand a black TV, a muted dealer bar, or blanked
	# wealth digits — the group sweep below only hides nodes, it restores nothing.
	_end_tv_blackout()
	_bursts.reset_jackpot_lamp()
	_clear_jackpot_coins()
	_bursts.hide_pending()
	_coins.hide_pending()
	_hints.hide_pending()
	var fx_layer := _consumable_fx.layer()
	if fx_layer != null:
		# The covers, smoke and edges are run STATE, not flourishes: sweeping them
		# away would leave a smoked reel uncoverable for the rest of the run. The
		# blur covers are ReelBlur's and share the layer for the same reason.
		var persistent_fx: Array[Node] = []
		persistent_fx.append_array(_consumable_fx.persistent_nodes())
		for node: Node in _reel_blur.blur_covers():
			persistent_fx.append(node)
		for child: Node in fx_layer.get_children():
			if not persistent_fx.has(child):
				var item := child as CanvasItem
				if item != null:
					item.visible = false
					item.modulate.a = 0.0
	for node: Node in get_tree().get_nodes_in_group(WEALTH_TRANSIENT_FX_GROUP):
		if is_instance_valid(node):
			var item := node as CanvasItem
			if item != null:
				item.visible = false
				item.modulate.a = 0.0
	if _neuron_spend_label != null and is_instance_valid(_neuron_spend_label):
		_neuron_spend_label.visible = false
		_neuron_spend_label.modulate.a = 0.0
	_neuron_spend_label = null

func _show_campaign_failed() -> void:
	_cleanup_transient_presentation()
	_stop_flatline_countdown()
	if _overlay != null:
		_overlay.queue_free()
	_overlay = Control.new()
	_overlay.position = Vector2.ZERO
	_overlay.size = Vector2(SRC_W, SRC_H)
	_overlay.z_index = ENDING_OVERLAY_Z_INDEX
	add_child(_overlay)
	_stash.set_tray_visible(false)
	_build_game_over_screen()

func _start_fresh_again() -> void:
	MetaStateStore.start_new_campaign()
	RunStateStore.reset_run_state()
	_to_menu(SceneNav.TransitionKind.FLATLINE)

func _flatline_action_text() -> String:
	return "CONTINUE" if _has_campaign_neurons_remaining() else "TRY AGAIN"


func _on_game_over_try_again_pressed() -> void:
	if _flatline_transition_active:
		return
	_flatline_transition_active = true
	_start_fresh_again()

func _on_flatline_action_pressed() -> void:
	if _flatline_transition_active:
		return
	_flatline_transition_active = true
	var flatline_screen := _overlay.get_node_or_null(
		"FlatlineEndingOverlay") as FlatlineEndingOverlay
	if flatline_screen != null:
		if not flatline_screen.first_revival_beep.is_connected(
			_flatline.attach_revival_meter):
			flatline_screen.first_revival_beep.connect(_flatline.attach_revival_meter)
		flatline_screen.play_continue_animation()
		await flatline_screen.continue_animation_finished
	if _overlay == null or not is_instance_valid(_overlay):
		return
	if flatline_screen == null:
		_flatline.attach_meter(Vector2(80.0, 286.0), Vector2(80.0, 270.0))
	await get_tree().create_timer(NeuronMeter.LOSS_ANIM_DELAY + 0.38).timeout
	if _has_campaign_neurons_remaining():
		if not RunStateStore.routeOfferPending:
			RunStateStore.prepare_route_offer("flatline")
		if RunStateStore.routeOfferPending:
			SceneNav.change_to(ROUTE_SCENE, SceneNav.TransitionKind.FLATLINE)
			return
		_to_dealer(SceneNav.TransitionKind.FLATLINE)
	else:
		_to_menu(SceneNav.TransitionKind.FLATLINE)

func _has_campaign_neurons_remaining() -> bool:
	return int(MetaStateStore.campaignNeuronsLeft) > 0

## Tears the ending screen's state down: the drain on the screen itself, and the
## re-entry guard around the button that leaves it. Every path out of an ending
## goes through here, which is why it clears both halves rather than only the one
## it owns.
func _stop_flatline_countdown() -> void:
	_flatline.stop()
	_flatline_transition_active = false

# The stash tray (z 50) would draw over full-screen ending overlays; hide it while
# one is up and restore it when the run visuals resync.
func _set_tv_progress_bars_visible(visible: bool) -> void:
	# An ending is a TV owner too, and the crudest one: it sweeps the persistent
	# layers away by node name rather than holding a source. Telling the arbiter to
	# forget its snapshot is what stops a mute taken BEFORE the ending from handing
	# back what the ending hid.
	if not visible and _tv_content_muted():
		_tv.forget_restore_state()
	for node_name: String in [
		"WealthOdometer", "HealthBar", "DealerBar", "DealerBarOverlay1",
		"DealerBarOverlay2", "DealerBarOverlay3", "DealerIcon"]:
		var node := get_node_or_null(NodePath(node_name)) as CanvasItem
		if node != null:
			node.visible = visible
	# The FREE SPINS banner re-derives from state on the next HUD refresh; a
	if not visible:
		_set_free_spin_display(false)
	elif _tv.callout_active():
		_tv.hide_layers()

func _end_run_lucidity_kept_fraction() -> float:
	# Asks the store rather than reading ownedPermanents directly, so a Pacte-granted
	# SMART SAVING counts here exactly as it does in the bank.
	return MetaStateStore.effective_lucidity_kept_fraction()

# ── Augmented Run badge (issue #111) ─────────────────────────────────────────────────
## A wealth CONTINUE only makes sense if the resumed run can still take a spin:
## neurons (or banked free spins) remain (issue #62). The normal spin pool is capped
## at 18, including after a Wealth continuation.
func _can_resume_after_wealth() -> bool:
	return int(RunStateStore.neurons) >= 1 or int(RunStateStore.freeSpinsRemaining) > 0

func _continue_from_wealth() -> void:
	RunStateStore.continue_run()
	if _can_resume_after_wealth():
		_begin_machine_lucidity_segment()
		_sync_visuals()
		return
	# Defensive: no spin can follow, so end the run through the flatline flow
	# (banks lucidity, offers the campaign continue/menu action) instead of
	# stranding a dead machine (issue #62).
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_show_ending("flatline", {
		"neurons": RunStateStore.neurons,
		"scoreEarned": RunStateStore.scoreEarned,
		"lucidityCoins": _machine_lucidity_after_deductions(),
	})

## Wealth screen Start Again: bank the run and return to the menu hub.
func _start_again_from_wealth(run: Dictionary) -> void:
	if RunStateStore.claim_ending_bank():
		var frozen_run := run.duplicate(true)
		var score_snapshot: int = RunStateStore.endingScoreSnapshot \
			if RunStateStore.endingScoreSnapshot >= 0 else int(run.get("scoreEarned", 0))
		var lucidity_snapshot: int = RunStateStore.endingLuciditySnapshot \
			if RunStateStore.endingLuciditySnapshot >= 0 else int(run.get("lucidityCoins", 0))
		frozen_run["scoreEarned"] = maxi(0, int(score_snapshot))
		frozen_run["lucidityCoins"] = maxi(0, int(lucidity_snapshot))
		MetaStateStore.bank_run(frozen_run, "wealth")
	_to_menu()

# ── dealer flow ────────────────────────────────────────────────────────────────────

## Queue the dealer offer behind the power-coin sequence (req 2): if power coins are
## flying or still owed, defer; the sequence presents it when it finishes. Never cancels.
## Single authority on whether the dealer may take the scene right now. The visit
## stays queued (dealerIncoming + _pending_dealer_offer) until reels, rerolls,
## power coins, and the Energy-Drink forced spin have fully resolved. A pending
## combo-loss decision does NOT block him — he opens above the beeping warning
## and closing his offer returns to the still-pending decision.
func _can_open_dealer_now() -> bool:
	return not _spinning_anim \
		and not _spin_launch_pending \
		and not _reroll_anim_active \
		and not _compulsive_queued \
		and not _power_sequence_active() \
		and not _power_has_pending_work() \
		and RunStateStore.compulsiveSpinSkips <= 0

## A beaten target outranks a queued visit: the round that dealer belonged to is
## over, so he is dropped rather than deferred — the between-run dealer on the other
## side of the payout screen is the next one the player meets.
func _dealer_stands_down_for_target() -> bool:
	return _wealth_target_transition_active or _wealth_target_due_now()

func _present_dealer_or_defer() -> void:
	if not RunStateStore.dealerIncoming:
		return
	if _dealer_stands_down_for_target():
		_pending_dealer_offer = false
		return
	if not _can_open_dealer_now():
		_pending_dealer_offer = true
		return
	_pending_dealer_offer = false
	_show_dealer_incoming()

func _maybe_present_pending_dealer() -> void:
	if _dealer_stands_down_for_target():
		_pending_dealer_offer = false
		return
	if _pending_dealer_offer and RunStateStore.dealerIncoming and _can_open_dealer_now():
		_pending_dealer_offer = false
		_show_dealer_incoming()

func _show_dealer_incoming() -> void:
	# A legacy/resumed incoming marker can survive without its offer array.  Roll a
	# fresh deterministic visit rather than turning the marker into a softlock.
	if RunStateStore.dealerOfferIds == null:
		RunStateStore.dealerIncoming = false
		if RunStateStore.force_dealer_visit():
			_show_dealer_offers()
		return
	_dealer_visit()

func _dealer_visit() -> void:
	RunStateStore.reveal_dealer()
	# Ordinary in-run dealer visits stay inline (issue #22); the full dealer scene
	# is used for tactical interruptions and the post-Wealth odds phase.
	_show_dealer_offers()

func _show_dealer_offers() -> void:
	var offers: Variant = RunStateStore.dealerOfferIds
	# A pending marker without its offer array is an incomplete older snapshot, not
	# a reason to drop the interaction. Re-roll the same kind of visit so the
	# authoritative pending flag still has a usable presentation to restore.
	if RunStateStore.dealerPending and (not (offers is Array) \
			or (offers as Array).is_empty()):
		RunStateStore.dealerPending = false
		RunStateStore.dealerOfferIds = null
		RunStateStore.dealerIncoming = false
		RunStateStore.force_dealer_visit()
		offers = RunStateStore.dealerOfferIds
	# Direct scene/test callers may restore the persisted offer array before the
	# boolean marker.  Materialize the interaction once here; after that point the
	# boolean is authoritative for every HUD refresh and save/resume.
	if offers is Array and not (offers as Array).is_empty() \
		and not RunStateStore.dealerPending:
		RunStateStore.dealerPending = true
		RunStateStore._commit()
	if not _dealer_interaction_active():
		if _dealer_offer_popup != null or _dealer_overlay != null:
			_close_dealer(false)
		return
	if _dealer_overlay_is_live():
		_dealer_offer_popup.visible = true
		_dealer_overlay = _dealer_offer_popup
		_set_sequence_lock(true)
		_stash.set_elevated(true)
		_stash.set_icons_visible(true)
		_refresh_score_button_lock()
		return
	_set_sequence_lock(true)
	_clear_targeting()
	if _dealer_overlay != null and is_instance_valid(_dealer_overlay):
		_dealer_overlay.queue_free()
	_dealer_overlay = null
	_dealer_offer_popup = null
	_dealer_offer_popup = IN_RUN_DEALER_OFFER_SCENE.instantiate()
	_dealer_overlay = _dealer_offer_popup
	# The dealer draws above the loss overlays (97) but under the HUD (120); the
	# machine stash rides above him while his offer is up so it stays draggable.
	_dealer_offer_popup.z_index = DEALER_OVERLAY_Z_INDEX
	add_child(_dealer_offer_popup)
	_stash.set_elevated(true)
	_refresh_score_button_lock()
	_dealer_offer_popup.item_selected.connect(_dealer_take)
	_dealer_offer_popup.item_forced.connect(_dealer_forced_take)
	_dealer_offer_popup.item_discarded.connect(_dealer_discard_stash)
	_dealer_offer_popup.dealer_ignored.connect(_dealer_leave)
	_dealer_offer_popup.offer_finished.connect(_on_dealer_offer_finished)
	_stash.set_icons_visible(true)
	# Joker (issue #111): the visit is a delivery, not an offer — the overlay plays the
	# buy and the use, and the store names the item so both ends force the same one.
	_dealer_offer_popup.start_offer((offers as Array).duplicate(), [],
		RunStateStore.joker_forced_offer_id())
	_refresh_controls()

func _begin_dealer_drag(node: Control, id: String, kind: String) -> void:
	_dealer_drag_active = true
	_dealer_drag_node = node
	_dealer_drag_id = id
	_dealer_drag_kind = kind
	_dealer_drag_home = node.position
	_dealer_drag_moved = false
	_dealer_drag_press = get_global_mouse_position()
	node.z_index = 20
	node.scale = Vector2(1.2, 1.2)
	node.modulate = Color(1.2, 1.2, 1.2)

func _input(event: InputEvent) -> void:
	if SceneNav.is_transition_active():
		return
	# OptionsOverlay is a modal. Parent _input handlers run before Control GUI
	# dispatch, so returning here prevents a click meant for the menu from also
	# starting a power, spin, or drag underneath it.
	if _options_overlay != null and is_instance_valid(_options_overlay) \
			and _options_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_options_overlay.hide_overlay()
			get_viewport().set_input_as_handled()
		return
	# Points table (issue #119): back/cancel closes the overlay from keyboard
	# (Esc) or controller (B) without needing to focus the CLOSE button.
	if _score_table.is_open() and event.is_action_pressed("ui_cancel"):
		_close_score_table()
		get_viewport().set_input_as_handled()
		return
	if _swap_drag_active:
		if event is InputEventMouseMotion:
			_update_swap_drag(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
				and not event.pressed:
			_finish_swap_drag(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenDrag and event.index == 0:
			_update_swap_drag(_input_canvas_position((event as InputEventScreenDrag).position))
			get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenTouch and event.index == 0 and not event.pressed:
			_finish_swap_drag(_input_canvas_position((event as InputEventScreenTouch).position))
			get_viewport().set_input_as_handled()
			return
	if not _dealer_drag_active:
		return
	if event is InputEventMouseMotion:
		var m := get_global_mouse_position()
		if _dealer_drag_node != null:
			_dealer_drag_node.global_position = m - _dealer_drag_node.size * 0.5
		if m.distance_to(_dealer_drag_press) > 4.0:
			if not _dealer_drag_moved:
				DragShadow.add_drag_shadow(_dealer_drag_node)
			_dealer_drag_moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_dealer_drag(get_global_mouse_position())

func _end_dealer_drag(release_pos: Vector2) -> void:
	var id := _dealer_drag_id
	var kind := _dealer_drag_kind
	var node := _dealer_drag_node
	var dropped_on_dealer := release_pos.y < 214.0
	if _dealer_offer_popup != null:
		dropped_on_dealer = _dealer_offer_popup.has_dealer_drop_point(release_pos)
	_dealer_drag_active = false
	_dealer_drag_node = null
	_dealer_drag_id = ""
	_dealer_drag_kind = ""
	if node != null:
		DragShadow.remove_drag_shadow(node)
		node.z_index = 0
		node.position = _dealer_drag_home
		node.scale = Vector2.ONE
		node.modulate = Color.WHITE
	if not _dealer_drag_moved:
		if kind == "offer" and id != "":
			_dealer_take(id)
		return
	if dropped_on_dealer and id != "":
		if kind == "offer":
			_dealer_take(id)
		elif kind == "stash":
			RunStateStore.discard_run_consumable(id)
			_update_hud()

func _dealer_full_stash_feedback() -> void:
	if _dealer_offer_popup != null:
		_dealer_offer_popup.show_full_pockets()
		return
	if _dealer_message_label != null:
		_dealer_message_label.text = "YOUR POCKETS ARE FULL,\nWANNA THROW SOMETHING ?"
		_dealer_message_label.pivot_offset = _dealer_message_label.size * 0.5
		var mt := create_tween()
		mt.tween_property(_dealer_message_label, "scale", Vector2(1.08, 1.08), 0.06)
		mt.tween_property(_dealer_message_label, "scale", Vector2.ONE, 0.1)
	if _dealer_portrait_sprite != null:
		var start_x := _dealer_portrait_sprite.position.x
		var tw := create_tween()
		tw.tween_property(_dealer_portrait_sprite, "position:x", start_x + 3.0, 0.04)
		tw.tween_property(_dealer_portrait_sprite, "position:x", start_x - 3.0, 0.04)
		tw.tween_property(_dealer_portrait_sprite, "position:x", start_x, 0.05)

func _dealer_take(item_id: String) -> void:
	if Consumables.total_copies(RunStateStore.runConsumables) >= Consumables.MAX_CONSUMABLE_SLOTS:
		_dealer_full_stash_feedback()
		return
	RunStateStore.accept_dealer_offer(item_id)
	if _dealer_offer_popup != null:
		_dealer_offer_popup.finish_offer()
	else:
		_close_dealer()

## Joker (issue #111): the visit's item is accepted and used in one go, halfway through the
## overlay's delivery animation. It is taken with one slot of headroom over the normal cap
## and spent immediately, so a full stash cannot swallow the forced item — the player is
## never asked to make room for something they did not ask for. If the item cannot be used
## right now (a compulsory spin is queued), it simply stays in the stash as a normal item.
func _dealer_forced_take(item_id: String) -> void:
	RunStateStore.accept_dealer_offer_with_limit(item_id,
		Consumables.MAX_CONSUMABLE_SLOTS + 1)
	if RunStateStore.use_consumable(item_id):
		if RunStateStore.consume_power_bar_drain():
			_drain_power_bar()
		_show_consumable_feedback(item_id)
		_play_use_fx(item_id)
	_refresh_reels_from_state()
	_update_hud()

func _dealer_discard_stash(item_id: String) -> void:
	RunStateStore.discard_run_consumable(item_id)
	if _dealer_offer_popup == null:
		_show_dealer_offers()
	else:
		_update_hud()

func _dealer_leave() -> void:
	RunStateStore.decline_dealer_offer()
	if _dealer_offer_popup != null:
		_dealer_offer_popup.finish_offer()
	else:
		_close_dealer()

func _on_dealer_offer_finished() -> void:
	_close_dealer()

func _close_dealer(restore_sequence: bool = true) -> void:
	# This entry point is the explicit player-facing dismissal.  Clear the
	# authoritative offer before tearing down the Control; passive HUD refreshes
	# never call _close_dealer and therefore cannot dismiss a Dealer by accident.
	if restore_sequence and _dealer_interaction_active():
		RunStateStore.decline_dealer_offer()
	if _dealer_overlay != null and is_instance_valid(_dealer_overlay):
		_dealer_overlay.queue_free()
	_dealer_overlay = null
	_dealer_offer_popup = null
	_dealer_message_label = null
	_dealer_portrait_sprite = null
	_dealer_drag_active = false
	_dealer_drag_node = null
	_dealer_drag_id = ""
	_dealer_drag_kind = ""
	_stash.set_icons_visible(true) # overlay gone — restore the machine's own stash (issue #26)
	_stash.set_elevated(false)
	if not restore_sequence:
		return
	if _dealer_interaction_active():
		# UI teardown is allowed to be transient, but persisted Dealer state owns
		# the interaction.  Recreate it immediately instead of returning a machine
		# with an active offer and no way to act on it.
		_restore_dealer_overlay_from_state()
		return
	# The dealer can appear over a live losing state: closing him returns to the
	# pending rescue decision instead of unlocking the whole sequence.
	_set_sequence_lock(RunStateStore.comboDefeatPending)
	_update_hud()
	# Issue #96 safety net: never leave the machine idle while a compulsion is
	# pending — the player can't act (compulsiveSpinSkips>0), so the machine must
	# take the forced spin. Normal sequencing already resolves compulsion first,
	# but this catches any path that closes the dealer with a compulsion queued.
	if RunStateStore.compulsiveSpinSkips > 0:
		_queue_compulsive_spin()
