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
const ASSET_SCALE := 8.0 # legacy machine sheets are 8x the 160x320 source
const MACHINE_ART_TEXTURE_FILTER := CanvasItem.TEXTURE_FILTER_NEAREST

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
# N spins remaining — frame 0 = empty/no spins, frame 18 = 18+ spins.
const HEALTH_BAR_FRAME_COUNT := 19
# The tube's bottom chip — the last spin the run has — measured off health_bar.png as the
# pixels that differ between frame 0 (empty) and frame 1 (one spin). An armed Emergency
# Reserve glows exactly that chip: the reserve IS one more spin waiting under the last
# one, so it reads where the player already looks for spins rather than as a new badge.
const HEALTH_BOTTOM_CHIP_RECT := Rect2(4.0, 98.0, 13.0, 7.0)
const HEALTH_BAR_FRAME_W := 160.0 # full-canvas sheet: one frame is the whole canvas
const RESERVE_GLOW_COLOR := Color(0.55, 1.0, 0.85)
const RESERVE_GLOW_MIN_ALPHA := 0.22
const RESERVE_GLOW_MAX_ALPHA := 0.72
const RESERVE_GLOW_PERIOD := 1.1
const MAX_RUN_SPINS := EconomyConst.MAX_NEURONS
const SPINS_LEFT_NORMAL_COLOR := Color(0.8, 0.95, 1.0)
const SPINS_LEFT_MAX_COLOR := Color("#8f0d16")
# Remaining-spin readout, centered in the badge chip under the neuron tube
# (badge pixels span x4..16, y107..119). The rect rides ~6px above the chip
# centre and 1px right of it because DTM-Sans' line metrics drop the glyphs
# below a centered box and its digits carry a lopsided side bearing (verified
# against rendered pixels; same trick as the wealth goal rects).
const SPINS_LEFT_LABEL_RECT := Rect2(1.0, 102.0, 21.0, 11.0)
# Objective readout on the TV (issue #181). Authored full-canvas sheets: the goal
# number (art y91..95), the fill bar under it (y99..103), and a six-frame shimmer at
# y95..97 that loops between them. The goal sheet carries one frame per EconomyConst.WEALTH_TARGETS
# entry, so its frame index is the target index; the bar's twelve frames are the fill
# steps. They replace the TARGET word + red digit labels that used to be drawn into
# the bottom wealth bar.
const TARGET_BAR_SHEET := "machine new view/target_bar.png"
const TARGET_BAR_FRAME_COUNT := 12
const TARGET_GOALS_SHEET := "machine new view/target_goals.png"
const TARGET_GOALS_FRAME_COUNT := 8
const TARGET_BAR_ANIM_SHEET := "machine new view/target_bar_animation.png"
const TARGET_BAR_ANIM_FRAME_COUNT := 6
const TARGET_BAR_ANIM_FRAME_TIME := 0.12
const TARGET_TV_Z_INDEX := 8 # above the cabinet and callout sheets, below the icons
# Coin-insert sheet: a coin drops into the machine when the lever is pulled, before
# the lever animation starts.
const COIN_INSERT_FRAME_COUNT := 4
const COIN_INSERT_FRAME_TIME := 0.055
const TV_STATUS_RIGHT := 109.0
const MULT_STRIP := { "top": 119.0, "height": 16.0 }
const MULT_BADGE_CENTERS := [47.0, 78.0, 106.0]
const LEVER_HIT := { "left": 133.0, "top": 160.0, "width": 20.0, "height": 40.0 }
# Centre of the reel window — consumable-use hint popups originate here.
const MACHINE_HINT_CENTER := Vector2(75.5, 185.0)
const SYMBOL_TARGET_H := 32.0 # 32px symbols render 1:1 in the virtual canvas.
# Landed reel strip (uses the reel-strip presentation): a smaller centre symbol with dim
# 0.9x neighbours peeking above/below, clipped by the cabinet hole.
const STRIP_CENTER_H := 16.0
const STRIP_ADJ_H := 12.0
const STRIP_OFFSET := 14.0 # vertical gap between symbol centres ((center+adj)/2)
const STRIP_ADJ_ALPHA := 0.5

# Swap presentation (issue #181). One cue per idea: the slot frames say where a symbol
# may land, the symbol shake says what can be grabbed, the instruction says what to do,
# and the red cross appears only when the pointer is over a reel that would be refused.
const SWAP_SHAKE_STEP := 0.09
const SWAP_SHAKE_OFFSETS: Array[Vector2] = [
	Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0), Vector2(-1.0, 0.0),
]
const SWAP_SLOT_FRAME_FILL := Color(1.0, 0.82, 0.42, 0.05)
const SWAP_SLOT_FRAME_BORDER := Color(1.0, 0.82, 0.42, 0.55)
const SWAP_SLOT_TICK_SIZE := Vector2(3.0, 1.0)
const SWAP_SLOT_PULSE_TIME := 0.9
const SWAP_SLOT_PULSE_LOW := 0.45
const SWAP_SLOT_PULSE_HIGH := 0.9
const SWAP_VALID_FILL := Color(0.30, 0.90, 0.52, 0.16)
const SWAP_VALID_BORDER := Color(0.45, 1.0, 0.62, 0.9)
const SWAP_INVALID_FILL := Color(0.72, 0.04, 0.10, 0.28)
const SWAP_INVALID_BORDER := Color(1.0, 0.22, 0.28, 0.95)
const SWAP_CROSS_COLOR := Color(1.0, 0.30, 0.34, 0.95)
const SWAP_CROSS_THICKNESS := 1.0
const SWAP_CROSS_ANGLE_DEG := 38.0
const SWAP_CENTRE_SLOT := 1 # 0 = above, 1 = centre, 2 = below; Swap only ever takes centre
# Swap talks about whole reels, so its cues cover the whole visible reel: the hole plus the
# strip symbols above and below it, not just the centre window.
const SWAP_REEL_HALF_HEIGHT := STRIP_OFFSET + STRIP_CENTER_H * 0.5

# Cheat's mini-reel overlay (on the picked reel's hole): up/down arrows step the
# candidate symbol, tapping the symbol commits it.
# The arrows themselves are authored into cheat_selection.png. These are the measured
# pixel bounds of that art relative to the picked reel's hole (x35..52 / y156..165 and
# y207..216 against hole 33,170 21x30), so the invisible hit buttons land ON the arrows —
# the old hole+gap guess sat 3px above the top arrow and 4px above the bottom one, which
# left the lower half of the down arrow dead (issue #181).
const CHEAT_ARROW_SIZE := Vector2(17.0, 9.0)
const CHEAT_ARROW_UP_RISE := 14.0 # arrow top above the hole's top edge
const CHEAT_ARROW_DOWN_DROP := 7.0 # arrow top below the hole's bottom edge
# Grown a little past the art on every side: 9px of height is a small target on a
# 160x320 canvas, and the gaps around the arrows are dead space anyway.
const CHEAT_ARROW_TOUCH_PAD := Vector2(1.5, 2.0)
const CHEAT_SELECTION_SHEET := "machine new view/cheat_selection.png"
const CHEAT_SELECTION_FRAMES := 9

# Machine-mounted power button hit rects (source px). Every chip is painted 11x11 at y225
# in its own sheet (POWER_ART_LEFT below), so each rect is that chip grown 1px sideways and
# a couple of pixels top and bottom. The old rects drifted a pixel either way and reroll's
# extra width ran into shift's box.
const POWER_HITS := {
	"reroll": { "left": 19.0, "top": 223.0, "width": 13.0, "height": 15.0 },
	"shift": { "left": 33.0, "top": 223.0, "width": 13.0, "height": 15.0 },
	"memory": { "left": 47.0, "top": 223.0, "width": 13.0, "height": 15.0 },
	"rewind": { "left": 61.0, "top": 223.0, "width": 13.0, "height": 15.0 },
	"heart": { "left": 75.0, "top": 223.0, "width": 13.0, "height": 15.0 },
	"cheat": { "left": 89.0, "top": 223.0, "width": 13.0, "height": 15.0 },
	"swap": { "left": 103.0, "top": 223.0, "width": 13.0, "height": 15.0 },
}
const POWER_IDS: Array[String] = ["reroll", "shift", "memory", "rewind", "heart", "cheat", "swap"]
# Where each power's chip is actually painted in its own sheet, measured from the art: 11x11
# at y225, on one unbroken 14px pitch that the augment sockets pick up again at 64/78/92
# after the divider. Slotting is done art-to-art rather than hit box to hit box, so a
# re-slotted power lands exactly where the power that owns the emplacement is drawn.
const POWER_ART_LEFT := {
	"reroll": 20.0, "shift": 34.0, "memory": 48.0,
	"rewind": 62.0, "heart": 76.0, "cheat": 90.0, "swap": 104.0,
}
const LEVER_FRAME_COUNT := 6
const LEVER_FRAME_TIME := 0.042
const LEVER_HOLD_TIME := 0.055
const LEVER_RETURN_TIME := 0.07
const LEVER_REEL_START_DELAY := 0.22
const SPIN_FRAME_COUNT := 4
const SPIN_FRAME_TIME := 0.055
const REROLL_REEL_DURATION := 0.55
const REEL_STOP_SFX_LEAD_TIME := 0.1
# Rewind rolls the previous spin back in: all three reels blur backwards for this
# long while the sequence lock keeps the lever out of reach.
const REWIND_RESTORE_DURATION := 0.9
const FLATLINE_HOLD_TIME := 0.7
const FLATLINE_DRAIN_TIME := 1.6
const MULTIPLIER_FRAME_COUNT := 6
# Issue #155: authored frenzy-gauge effect sheets (full-canvas x1 strips) and the
# blinking FREE SPINS TV overlay.
const MULT_FX_2_SHEET := "machine new view/multiplier_2_effect.png"
const MULT_FX_3_SHEET := "machine new view/multiplier_3_effect.png"
const MULT_FX_FIRE_SHEET := "machine new view/multiplier_3_fire.png"
const FREE_SPIN_SHEET := "machine new view/FREE_SPIN.png"
const COMBO_LOSS_2_SHEET := "machine new view/2_losing_animation.png"
const COMBO_LOSS_3_SHEET := "machine new view/3_losing_animation.png"
const MULT_FX_2_FRAMES := 7
const MULT_FX_3_FRAMES := 9
const MULT_FX_FRAME_TIME := 0.09
# The x3 losing state is an authored 9-frame diminished-fire sheet (1440x320)
# stepped at the same cadence as the regular multiplier effects.
const COMBO_LOSS_3_FRAMES := 9
const FREE_SPIN_OVERLAY_BLINK_PERIOD := 0.18
const COMBO_LOSS_BEEP_FADE_TIME := 0.1
const COMBO_LOSS_BEEP_PAUSE := 0.42
# Authored TV callout sheets (full-canvas x1 frames): the win sheet flashes
# PAIR/TRIPLE after a win is identified; the power sheet flashes the seven power
# names in authored order while that power's targeting is armed. Both beep with
# the combo-loss pulse cadence.
const WIN_ANIM_SHEET := "machine new view/win_animation.png"
const WIN_ANIM_FRAMES := 2
const WIN_ANIM_FRAME := { "pair": 0, "triple": 1 }
const COMBO_EFFECT_SHEET := "machine new view/COMBO_effect.png"
const COMBO_EFFECT_FRAMES := 9 # gameplay cap; the authored sheet may expose fewer frames
const COMBO_EFFECT_DELAY := 2.55
const COMBO_EFFECT_TIME := 1.05
const POWER_ANIM_SHEET := "machine new view/power_animation.png"
const POWER_ANIM_FRAMES := 7
const POWER_ANIM_FRAME := {
	"reroll": 0, "shift": 1, "memory": 2,
	"rewind": 3, "heart": 4, "cheat": 5, "swap": 6,
}
const CALLOUT_BEEP_COUNT := 4
# "+ X" payout line under the PAIR/TRIPLE callout (both words centre on x~76 and
# end at y86 in the re-authored art; the TV screen bottom is y108). Child of the
# callout sprite, so it inherits the beep pulse and hides with it.
const WIN_PAYOUT_RECT := Rect2(41.0, 86.0, 70.0, 14.0)
const WIN_PAYOUT_COLOR := Color("#20d6c7")
# The combo sheet already contains COMBO x1..x9 at y63..92. Keep the bonus line
# below that authored title so the two payouts read as separate beats.
const COMBO_PAYOUT_RECT := Rect2(35.0, 94.0, 82.0, 12.0)
const COMBO_PAYOUT_COLOR := Color("#20d6c7")
# Issue #155: the dealer countdown is an authored 13-frame progress bar. Frame 0
# is the empty bar at the start of the active cycle (12 steps normally, 24 for
# Club/Joker); the last frame means the dealer arrives after the current spin. The
# three small sheets are cumulative warning lights: x3 shows overlay 1, x2 shows
# 1+2, and x1 shows 1+2+3.
const DEALER_BAR_SHEET := "machine new view/dealer_bar.png"
const DEALER_BAR_FRAME_COUNT := 13
const DEALER_BAR_OVERLAY_1_SHEET := "machine new view/dealer_bar_overlay_1.png"
const DEALER_BAR_OVERLAY_2_SHEET := "machine new view/dealer_bar_overlay_2.png"
const DEALER_BAR_OVERLAY_3_SHEET := "machine new view/dealer_bar_overlay_3.png"
const DEALER_BAR_OVERLAY_1_FRAMES := 12
const DEALER_BAR_OVERLAY_2_FRAMES := 11
const DEALER_BAR_OVERLAY_3_FRAMES := 10
# The bar walks through each authored progress frame when one spin advances it
# by multiple steps; the warning itself beeps through alpha so it does not
# reveal a different countdown position before that spin's result is known.
const DEALER_BAR_PROGRESS_FRAME_TIME := 0.10
# The warning speeds up as the dealer closes in: a lone first light beeps lazily, and from
# the second light on the cadence tightens. BEEP_TIME is the pulse itself (the lights sit at
# BEEP_MIN_ALPHA for it); the rest of the period is full alpha.
const DEALER_BAR_OVERLAY_BEEP_PERIOD := 0.9
const DEALER_BAR_OVERLAY_SLOW_BEEP_PERIOD := 1.8
const DEALER_BAR_OVERLAY_BEEP_TIME := 0.5
const DEALER_BAR_OVERLAY_BEEP_MIN_ALPHA := 0.18
const DEALER_ICON_ASSET := "ui/dealer_portrait.png"
const DEALER_ICON_SIZE := Vector2(14.0, 21.0)
# The bar ends at x101; the compact portrait sits two source pixels beside it,
# fully inside the pink TV border.
const DEALER_ICON_POS := Vector2(100.0, 59.0)
const LOCK_POWER_FRAME_COUNT := 3
const JACKPOT_FRAME_COUNT := 3
const JACKPOT_FRAME_OFF := 0
const JACKPOT_FRAME_LIT := 1
const JACKPOT_FRAME_ALT := 2
const POWER_FRAME_AVAILABLE := 0
const POWER_FRAME_SELECTED := 1
const POWER_FRAME_DISABLED := 2
const POWER_SHEETS := {
	# Native 480x320 exports: three full-canvas frames (available / selected / disabled)
	# at 1:1, no upscale.
	"reroll": "machine new view/reroll.png",
	"shift": "machine new view/shift.png",
	"memory": "machine new view/lock.png",
	"rewind": "machine new view/rewind_power.png",
	"heart": "machine new view/chip_power.png",
	"cheat": "machine new view/cheat_power.png",
	"swap": "machine new view/move_power.png",
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
const IN_RUN_DEALER_OFFER_SCENE := preload("res://scenes/in_run_dealer_offer.tscn")
const OPTIONS_OVERLAY_SCENE := preload("res://scenes/options_overlay.tscn")
const FLATLINE_ENDING_SCENE := preload("res://scenes/flatline_ending_overlay.tscn")
const TARGET_REACHED_SCENE := preload("res://scenes/target_reached_overlay.tscn")
const WEALTH_ENDING_SCENE := preload("res://scenes/wealth_ending_overlay.tscn")
const GAME_OVER_ENDING_SCENE := preload("res://scenes/game_over_ending_overlay.tscn")
const ENDING_OVERLAY_Z_INDEX := 150
const WEALTH_TARGET_FX_Z_INDEX := 140
# The payout screen shuts the TV down behind itself (issue #181). The rect sits above
# everything the TV draws — boost icons (12), dealer bar (11), augment row (40) — and
# below the targeting layer (97) and the overlay itself.
const TV_BLACKOUT_Z_INDEX := 45
# Flying rewards — the score bursts and the coin/lucidity FX — are the front-most thing
# the machine itself draws: above the augment row and its popup (40/41), which in turn sit
# above the cabinet art, and still under the TV blackout so the payout screen buries them.
const REWARD_FX_Z_INDEX := 42
const TV_BLACKOUT_COLOR := Color(0.004, 0.008, 0.016, 1.0)
const TV_BLACKOUT_ALPHA := 0.94 # not opaque: the CRT keeps a faint presence
const TV_BLACKOUT_SOURCE := &"wealth_target"
const WHITE_POWDER_DISTORTION_SHADER := preload("res://shaders/white_powder_distortion.gdshader")
const WEALTH_TRANSIENT_FX_GROUP := &"wealth_transient_fx"
const SETTINGS_ASSET := "ui/setting_icon.png"
const SFX_FILES := {
	&"lever": "lever.mp3",
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
const BURST_TIME := 1.05
# How long the score popup is on screen before spin aftereffects (multiplier/bar
# deltas, jackpot lamp, machine reactions) are allowed to pop (issue #54 scope).
const AFTEREFFECT_POP_DELAY := 0.4
const BURST_RISE := 28.0
const MULT_COLORS := {
	1: Color(0.094, 0.227, 0.549), # x1 dark blue  (#183A8C)
	2: Color(0.984, 0.749, 0.141), # x2 gold       (#fbbf24)
	3: Color(0.839, 0.157, 0.157), # x3 red        (#D62828)
}
const COCKTAIL_COLOR := Color(0.941, 0.671, 0.988) # #f0abfc
const JACKPOT_GOLD := Color(1.0, 0.84, 0.18) # jackpot burst is ALWAYS golden (issue #22)
const SCORE_TABLE_GAIN_COLOR := Color(0.75, 1.0, 0.8)
const SCORE_TABLE_DIM_COLOR := Color(0.45, 0.48, 0.58)
const SCORE_TABLE_LEVEL_COLOR := Color(1.0, 0.86, 0.2)
const SCORE_TABLE_REWARD_AMP_COLOR := Color(1.0, 0.86, 0.2)
const SCORE_TABLE_MAXED_COLOR := Color(1.0, 0.24, 0.24)
const SCORE_TABLE_BRAIN_COLOR := Color(1.0, 0.33, 0.58)
const NEON_CYAN := Color(0.42, 1.0, 0.95)
const NEON_GOLD := Color(1.0, 0.86, 0.36)
# Presentation stack: machine art → loss overlays (97) → dealer offer (100) →
# dealer-interactive stash (110, only while his offer is up; 50 otherwise) →
# HUD/options (BottomHudLayer 120).
const COMBO_LOSS_OVERLAY_Z_INDEX := 97
const DEALER_OVERLAY_Z_INDEX := 100
const STASH_TRAY_Z_INDEX := 50
const DEALER_STASH_Z_INDEX := 110
# Issue #119: authored points-table art. Both 1280x2240 sheets cover the full
# 160x320 canvas, but the authored scale is NOT square: x8 horizontally and x7
# vertically (1280/160 vs 2240/320). Canvas-space rects are source px / 8 on x
# and source px / 7 on y; the information sheet only holds the per-row "i"
# buttons, cropped from their first pixel cluster.
const SCORE_TABLE_ART := "TABLE/TABLES SCORE.png"
const SCORE_TABLE_INFO_ART := "TABLE/TABLES SCORE_information.png"
const SCORE_TABLE_INFO_SRC := Rect2(1032.0, 408.0, 56.0, 56.0)
const SCORE_TABLE_INFO_X := 129.0
const SCORE_TABLE_INFO_W := 7.0
const SCORE_TABLE_INFO_H := 8.0
const SCORE_TABLE_INFO_ROW_Y := [58.3, 101.7, 145.1, 188.6, 232.0, 276.6]
# Vertical centers of the art's row bands (dark grid lines sit at canvas y 23.4,
# 68.0, 111.4, 154.9, 198.3, 241.7, 286.3), so the values center inside their cells.
const SCORE_TABLE_ROW_CY := [45.5, 89.5, 133.0, 176.5, 220.0, 264.0]
# Issue #153: the draw-chance peek lives on an "i" button under the LVL value
# (it used to sit on the baked symbol box), on the same baseline as the row's
# triple-effect "i" (SCORE_TABLE_INFO_ROW_Y).
# Per-symbol bubble colors — keep in sync with OddsTableOverlay.SYMBOL_PERCENT_COLORS
# (can't reference the class here: pulling odds_table_overlay.gd into this
# script's compile chain breaks headless -s runs, which compile before autoloads).
# Augmented Run badge (issue #111): active-suit indicator, hold to peek at the
# run's restrictions.
const AUGMENTED_BADGE_POS := Vector2(27.0, 6.0) # top strip, right of the options gear
const AUGMENTED_BADGE_SIZE := 14.0
# Pacte augment badge: a compact blue contour around the active card icon stays
# inside the TV; it is shifted 10px right from the original left-side placement.
# Pressing it opens the current card(s) and effects.
# Issue #181: the held augments sit on the power bar, continuing the row after the
# third emplacement — powers at 22/36/50, augments at 64/78/92 on the same baseline
# and the same 14px pitch, so the whole strip reads as one row of chips.
const AUGMENT_PLATE_SHEET := "machine new view/augments.png"
const AUGMENT_PLATE_FRAMES := 3 # frame N = N+1 sockets
# The sockets draw on top of the cabinet and under the badges that fill them (40).
const AUGMENT_PLATE_Z_INDEX := 39
const PACTE_AUGMENT_BADGE_POS := Vector2(64.0, 223.0)
const PACTE_AUGMENT_BADGE_SIZE := Vector2(12.0, 15.0)
const PACTE_AUGMENT_BADGE_PITCH := 14.0
const PACTE_AUGMENT_BADGE_MAX := 3
const PACTE_AUGMENT_ICON_SIZE := 10.0
const PACTE_AUGMENT_CONTOUR_COLOR := Color("#143464")
const SCORE_TABLE_PCT_COLORS := {
	"brain": Color("#e86a73"),
	"eye": Color("#ce3dde"),
	"pill": Color("#e3e6ff"),
	"syringe": Color("#f9a31b"),
	"vial": Color("#b4202a"),
	"flatline": Color("#8f0d16"),
}
const SCORE_TABLE_LVL_CX := 66.0
const SCORE_TABLE_PAIR_CX := 99.0
const SCORE_TABLE_TRIPLE_CX := 131.5
# Canvas centers of the 40 baked marquee bulbs (scanned from the art's yellow
# clusters): 14 across the top, 14 across the bottom, 6 per side.
const SCORE_TABLE_BULBS: Array[Vector2] = [
	Vector2(20.5, 6.5), Vector2(29.5, 6.5), Vector2(38.5, 6.5), Vector2(47.5, 6.5),
	Vector2(57.5, 6.5), Vector2(66.5, 6.5), Vector2(75.5, 6.5), Vector2(84.5, 6.5),
	Vector2(93.5, 6.5), Vector2(102.5, 6.5), Vector2(112.5, 6.5), Vector2(121.5, 6.5),
	Vector2(130.5, 6.5), Vector2(139.5, 6.5),
	Vector2(7.5, 38.5), Vector2(152.5, 38.5), Vector2(7.5, 90.0), Vector2(152.5, 90.0),
	Vector2(7.5, 133.5), Vector2(152.5, 133.5), Vector2(7.5, 177.0), Vector2(152.5, 177.0),
	Vector2(7.5, 220.0), Vector2(152.5, 220.0), Vector2(7.5, 263.5), Vector2(152.5, 263.5),
	Vector2(20.5, 311.5), Vector2(29.5, 311.5), Vector2(38.5, 311.5), Vector2(47.5, 311.5),
	Vector2(57.5, 311.5), Vector2(66.5, 311.5), Vector2(75.5, 311.5), Vector2(84.5, 311.5),
	Vector2(93.5, 311.5), Vector2(102.5, 311.5), Vector2(112.5, 311.5), Vector2(121.5, 311.5),
	Vector2(130.5, 311.5), Vector2(139.5, 311.5),
]
const SCORE_TABLE_BULB_GLOW_SIZE := 13.0
const TENSION_DELAY := 0.4   # extra hold on reel 3 when reels 1 & 2 match
const JACKPOT_FLASH_TIME := 0.9
# Issue #181: a jackpot is the biggest thing the machine does, so the money landing
# IS the reward — the wealth reels roll deliberately slowly instead of snapping, and
# the tray throws a coin spray up through the cabinet like a casino payout.
const JACKPOT_ODOMETER_ROLL_TIME := 1.60
const JACKPOT_ROLL_TAIL := 0.25 # a beat of stillness after the reels land
const JACKPOT_COIN_COUNT := 14
const JACKPOT_COIN_STAGGER := 0.06
const JACKPOT_COIN_FLIGHT := 0.95
const JACKPOT_COIN_GRAVITY := 260.0
const JACKPOT_COIN_RISE := 132.0
const JACKPOT_COIN_RISE_JITTER := 34.0
const JACKPOT_COIN_SPREAD := 46.0
const JACKPOT_COIN_ORIGIN_JITTER := 14.0
const JACKPOT_COIN_SPIN := 2.5
const JACKPOT_COIN_FADE_IN := 0.10
const JACKPOT_COIN_FADE_START := 0.74
const COIN_TRAY := Vector2(80.0, 290.0)
const CASH_COIN_TRAY_OFFSET := Vector2(0.0, 8.0)
# The four-frame pop sheet is full-canvas and authored around the wealth-bar centre.
# Where the coin pop hands the coin over to the flight: the centre of the pop sheet's LAST
# frame (x70..77, y241..249), so the flying coin appears exactly where the animation left it
# instead of teleporting. The art moved up 3px in its latest export and this followed it.
const WEALTH_COIN_ORIGIN := Vector2(74.0, 245.5)
const POWER_COIN_SIZE := 8.0
const POWER_COIN_ASSET := "ui/power_coin.png"
# The jackpot pays in the machine's own currency, so its spray is lucidity coins —
# the same coin the dealer and upgrade screens count credits in — not power chips.
const LUCIDITY_COIN_ASSET := "ui/coin.png"
const POWER_COIN_FLIGHT_TIME := 0.64
const POWER_COIN_POP_SHEET := "machine new view/power coin animation.png"
const POWER_COIN_POP_FRAMES := 4
const POWER_COIN_POP_FRAME_TIME := 0.06

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
const DURATION_BOOSTS := [
	{ "counter": "decaySkips", "id": "item_energy_drink" },   # no-decay rush
	{ "counter": "guaranteeSymbolSpins", "id": "cons_focus", "symbolField": "guaranteeSymbolId" },
	{ "counter": "blurReelsSpins", "id": "cons_focus",
		"negative": true, "suppressWhenZeroCounter": "guaranteeSymbolSpins" },
	{ "counter": "cocktailBoostSpins", "id": "item_cocktail" },                # rarity bonus, no cost
	{ "counter": "pairBoostSpins", "id": "cons_cigarette", "mixed": true },   # 3x pairs - hidden reel
	{ "counter": "potionSpins", "id": "cons_potion" },         # per-spin random effect
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
	"item_energy_drink": { "pos": "2 FREE SPINS", "neg": "FORCED SPIN" },
	"item_cocktail": { "pos": "RARITY BONUS", "neg": "" },
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

var _reel_sprites: Array[Sprite2D] = []        # centre symbol per reel
var _reel_top_sprites: Array[Sprite2D] = []    # dim neighbour above
var _reel_bottom_sprites: Array[Sprite2D] = [] # dim neighbour below
var _reel_covers: Array = []   # per-reel bg patch shown when a reel stops (masks its blur)
var _reel_backing_sprite: Sprite2D = null # the shared reel art all three covers copy
var _swap_shake_cover_state: Array[bool] = [] # cover visibility to restore after a shake
var _overlay: Control = null
var _dealer_overlay: Control = null
var _dealer_offer_popup: Control = null
var _dealer_message_label: Label = null
var _dealer_portrait_sprite: Sprite2D = null
var _score_overlay: Control = null
var _score_info_popup: Control = null
var _score_info_buttons: Array[Button] = []
var _score_pct_buttons: Array[Button] = []
var _augmented_popup: Control = null # issue #111 hold-to-peek restrictions bubble
var _pacte_augment_badges: Array[Dictionary] = []
var _pacte_augment_badge: Button = null # first slot; anchors the popup
var _pacte_augment_badge_icon: TextureRect = null
var _pacte_augment_count: Label = null
var _pacte_augment_popup: Control = null
var _score_bulb_tween: Tween = null
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
var _dealer_bar_sprite: Sprite2D = null
var _dealer_bar_overlay_1: Sprite2D = null
var _dealer_bar_overlay_2: Sprite2D = null
var _dealer_bar_overlay_3: Sprite2D = null
var _dealer_bar_display_frame: int = 0
var _dealer_bar_target_frame: int = 0
var _dealer_bar_progress_time: float = 0.0
var _dealer_bar_frame_initialized := false
var _dealer_warning_wanted := 0    # lights the multiplier has earned (gates the beep)
var _augment_glitch_time := 0.0
var _augment_glitch_rng := RandomNumberGenerator.new()
var _dealer_bar_overlay_beep_time := 0.0
var _dealer_icon: TextureRect = null
var _combo_loss_2_sprite: Sprite2D = null
var _combo_loss_3_sprite: Sprite2D = null
var _gauge_shown := 0 # last displayed gauge value (0 = not shown yet; gates the rise sfx)
var _free_spin_sprite: Sprite2D = null
var _free_spin_blink_time := 0.0
var _free_spin_overlay_active := false
var _wealth_odometer: WealthOdometer = null
var _target_bar_sprite: Sprite2D = null
var _target_goals_sprite: Sprite2D = null
var _target_bar_anim_sprite: Sprite2D = null
var _target_bar_anim_time := 0.0
var _wealth_target_transition: TargetReachedOverlay = null
var _wealth_target_transition_active := false
## Set once CONTINUE on the target screen starts the hand-off to the between-run flow: the
## machine is on its way out, so nothing new may take the screen here.
var _target_round_handoff := false
var _tv_blackout_rect: ColorRect = null
var _tv_blackout_tween: Tween = null
var _unlock_popup: UnlockCardPopup = null
var _health_bar_sprite: Sprite2D = null  # spins-left tube: frame = spins remaining
var _reserve_glow_sprite: Sprite2D = null # armed Emergency Reserve, glowing on the last chip
var _reserve_glow_tween: Tween = null
var _spins_left_label: Label = null # numeric spins-left readout under the tube
var _win_anim_sprite: Sprite2D = null
var _win_anim_tween: Tween = null
var _win_payout_label: Label = null # "+ X" line under the PAIR/TRIPLE callout
var _combo_effect_sprite: Sprite2D = null
var _combo_effect_delay_tween: Tween = null
var _combo_effect_tween: Tween = null
var _combo_payout_tween: Tween = null
var _combo_payout_label: Label = null
var _combo_effect_frame_count := COMBO_EFFECT_FRAMES
var _power_anim_sprite: Sprite2D = null
var _power_anim_tween: Tween = null
var _power_anim_label: Label = null
var _cheat_selection_sprite: Sprite2D = null
var _tv_info_pop_sources: Dictionary = {}
var _tv_info_pop_restore_dealer_bar_visible := false
var _tv_info_pop_restore_dealer_icon_visible := false
var _coin_insert_sprite: Sprite2D = null # coin-drop played when the lever is pulled
var _coin_anim_active := false
var _coin_anim_elapsed := 0.0
var _boost_indicator_slots: Array = [] # pooled { slot, icon, count } for the TV duration icons
var _boost_zero_linger: Dictionary = {} # counter -> snapshot while the just-spent final spin shows "0"
var _jackpot_sprite: Sprite2D = null
var _power_buttons := {}      # id -> Button
var _power_sprites := {}      # id -> Sprite2D
var _lock_sprites: Array = []
var _lock_count_labels: Array[Label] = []
var _stash_icons: Array[TextureRect] = []  # bottom-right tap-to-use stash (issue #26)
var _lever_sprite: Sprite2D = null
var _spin_sheet_sprite: Sprite2D = null
var _spin_reel_sprites: Array[Sprite2D] = []
var _targeting_layer: Control = null # reel/arrow target buttons while a power is armed
var _targeting_power_id := ""
var _copy_source := -1               # white-powder copy: chosen source reel (-1 = none)
var _cheat_reel := -1
var _cheat_symbol_pool: Array[String] = [] # cheat mini-reel: cycle order (+book)
var _cheat_symbol_index := 0
var _cheat_preview_sprite: Sprite2D = null # candidate symbol in the mini-reel
var _swap_source := -1
var _swap_drag_active := false
var _swap_dragging := false
var _swap_drag_button: Button = null
var _swap_drag_ghost: Sprite2D = null
var _swap_drag_press := Vector2.ZERO
var _swap_drag_offset := Vector2.ZERO
var _swap_shake_tween: Tween = null      # the reels shake while Swap is armed
var _swap_shake_nodes: Array[CanvasItem] = [] # symbols + slot frames, grouped by reel
var _swap_shake_base: Array[Vector2] = []
var _swap_shake_reel: Array[int] = []    # which reel each shaken node belongs to
var _swap_slot_hints: Array[Panel] = []
var _swap_slot_pulse_tween: Tween = null
var _swap_invalid_target_overlay: Panel = null
var _swap_valid_target_overlay: Panel = null
var _swap_target_feedback_reel := -1
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
var _burst_layer: Control = null     # score bursts spawn here (drawn on top)
var _coin_layer: Control = null      # power-coin flights and wealth pop FX spawn here
var _burst_prev_score := 0           # last announced result score (for power gain)
# Freezes HUD delta visuals (multiplier badge, TV bars, jackpot lamp) between a
# spin/power commit and its score popup, so aftereffects never pop before the
# score does (issue #54 scope).
var _hud_delta_hold := false
var _burst_prev_spin := -1           # spin the last announcement belonged to
var _coin_prev_lucidity := 0 # retained as a consumable-gain marker; no coin flight uses it
var _combo_score_pending := -1 # final score held until the COMBO bonus beat lands
var _power_bar_sprite: Sprite2D = null
var _restore_cap_sprite: Sprite2D = null # per-spin restore budget lights beside the gauge
var _restore_cap_glow: Sprite2D = null   # the lit frame, flashed and faded when a charge is spent
var _restore_flash_tweens: Array[Tween] = []
var _restore_flash_chip: Sprite2D = null # chip currently pulsing, so it can be reset
var _augment_plate_sprite: Sprite2D = null # authored augment sockets under the badges
var _power_bar_frame := 0    # current gauge frame (0 empty .. POWER_BAR_FRAMES-1 full)
var _power_bar_score := 0        # score banked toward the next restore (0 .. coins_per_power_restore)
var _power_seen_lucidity := 0    # legacy name: total power points the gauge has accounted for
var _display_lucidity := 0 # wealth score shown by the odometer (legacy variable name)
var _power_coins_in_flight := 0   # bank + restore coins currently animating
var _power_batch_running := false # a batch of bank coins is being launched/processed
var _pending_dealer_offer := false # a dealer offer is queued behind the power-coin sequence
var _nudge_tween: Tween = null       # quick machine shake on lucidity/jackpot
var _jackpot_flash_tween: Tween = null
var _jackpot_coin_tween: Tween = null
var _jackpot_coins: Array[Sprite2D] = []
var _jackpot_flashing := false
var _font: FontFile = null
var _tex_cache := {}
var _sequence_lock_active := false
var _post_spin_sequence_active := false
var _pending_combo_overlay: Control = null
var _pending_combo_power_flow := false
var _combo_loss_beep_tween: Tween = null
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
var _lever_anim_active := false
var _lever_anim_elapsed := 0.0
var _reroll_anim_active := false
var _reroll_reel_index := -1
var _reroll_elapsed := 0.0
var _reroll_accum := 0.0
var _rewind_anim_active := false
var _rewind_elapsed := 0.0
var _rewind_accum := 0.0
var _flatline_countdown_active := false
var _flatline_countdown_elapsed := 0.0
var _flatline_total := 0
var _flatline_kept := 0
var _flatline_display := 0
var _flatline_score_label: Label = null
var _flatline_lost_label: Label = null
var _spin_label: Label = null
var _flatline_meter: NeuronMeter = null # neuron meter shown on the flatline overlay
var _flatline_transition_active: bool = false
var _neuron_spend_label: Label = null
var _hint_layer: Control = null  # transient on-use +/- HintLabels (issue #33)
# Machine reactions (issue #35): dedupe key so one reel configuration reacts once,
# and a pending eye-triple reveal for the next spin.
var _last_reacted_reels: Array = []
var _last_reacted_spin := -1
var _reveal_reel_next_spin := -1
# Spin-gain fly-ins in flight (issue #66): the spins-left counter is held back by
# this amount until each "+N" popup lands, so the number ticks up in sync.
var _pending_spin_gain := 0
# Consumable visuals (issue #34).
var _fx_layer: Control = null              # host for all consumable effect nodes
var _tobacco_covers: Array = []            # per-reel dark cover while smoked out
var _tobacco_smoke: Array = []             # per-reel CPUParticles2D smoke
var _energy_edges: Control = null          # burning-edges frame (Energy Drink)
var _energy_pulse_tween: Tween = null
var _energy_fx_active := false
var _cocktail_shake_tween: Tween = null
var _potion_jump_tween: Tween = null
var _close_call_heartbeat_tween: Tween = null
var _white_powder_distortion_tween: Tween = null
var _hidden_covers: Array = []             # per-reel "?" cover (White Powder)
var _hide_result_active := false           # the displayed result is hidden
var _blur_covers: Array = []               # per-reel frost cover (Serum, issue #53)
var _blur_result_active := false           # the displayed result renders blurry
var _adjacent_symbols_hidden_active := false # Serum downside: hide strip neighbours
var _serum_picker: Control = null          # Serum symbol-pick overlay (issue #53)
var _book_choice_overlay: Control = null
var _compulsive_queued := false            # energy-drink auto-spin pending
var _compulsive_overlay: ColorRect = null  # red overlay during the compulsive spin

func _ready() -> void:
	_font = _load_font("font/DTM-Sans.otf")
	_apply_balance_exports()
	# Draw order (back -> front): casino backdrop -> reel background -> symbols
	# -> lever (bolted to the cabinet's flank, so the cabinet occludes its arm)
	# -> cabinet (with transparent holes that mask symbol overflow) -> HUD ->
	# spin button. The authored node order in the .tscn is what fixes this — these
	# sprites all share z_index 0, so the scene tree IS the layer stack.
	_build_neon_background()
	_reel_backing_sprite = _build_full_canvas_sprite(
		"machine new view/reel_final_machine.png")
	_build_reel_animation_art()
	_build_reel_covers()
	_build_reels()
	_build_full_canvas_sprite("machine new view/machine_neon.png")
	_build_tv_indicators()
	_build_machine_control_art()
	_build_hud()
	_build_spin_button()
	_build_power_buttons()
	_build_stash()
	_build_sfx_players()
	_build_fx_layer() # before the burst/coin layers so rewards draw above effects
	_build_burst_layer()
	_build_coin_layer()
	_build_options_controls()
	_build_augmented_badge()
	_restore_options_overlay_if_requested()
	_play_pending_scene_feedback()
	RunStateStore.state_changed.connect(_update_hud)
	_enter_run()
	_augment_glitch_rng.seed = 181_0726
	_build_pacte_augment_badge()
	_init_burst_tracking()
	# A card unlocked during the run interrupts play until it is acknowledged
	# (issue #52); the popup blocks the machine behind its dimmed background. It
	# waits for a quiet moment first — see _can_present_card_unlock.
	_unlock_popup = UnlockCardPopup.attach_to(self, _can_present_card_unlock)

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
	if rel.ends_with("reel_final_machine.png"):
		return "ReelBacking"
	if rel.ends_with("final_machine.png") or rel.ends_with("neon_machine.png") \
			or rel.ends_with("machine_neon.png"):
		return "Cabinet"
	return ""

func _full_canvas_sheet_name(rel: String, frame: int) -> String:
	if rel.ends_with("health_bar.png"):
		return "HealthBar"
	if rel.ends_with("health_animation.png"):
		return "HealthCoin"
	if rel.ends_with("multiplier_final_machine.png"):
		return "Multiplier"
	if rel.ends_with("lever_final_machine.png") or rel.ends_with("neon_machine_lever.png"):
		return "Lever"
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
	if rel.ends_with("FREE_SPIN.png"):
		return "FreeSpinOverlay"
	if rel.ends_with("win_animation.png"):
		return "WinCallout"
	if rel.ends_with("power_animation.png"):
		return "PowerCallout"
	if rel.ends_with("cheat_selection.png"):
		return "CheatSelection"
	if rel.ends_with("2_losing_animation.png"):
		return "ComboLoss2"
	if rel.ends_with("3_losing_animation.png"):
		return "ComboLoss3"
	if rel.ends_with("dealer_bar.png"):
		return "DealerBar"
	if rel.ends_with("dealer_bar_overlay_1.png"):
		return "DealerBarOverlay1"
	if rel.ends_with("dealer_bar_overlay_2.png"):
		return "DealerBarOverlay2"
	if rel.ends_with("dealer_bar_overlay_3.png"):
		return "DealerBarOverlay3"
	return ""

## Which authored node a region crop belongs to. Matched with a small tolerance rather than
## exactly: the reel covers crop a little wider than the hole to take in the whole authored
## patch, and an exact match would miss the scene node and build a loose sprite on top of
## everything instead of slotting in under the symbols.
func _region_sprite_name(rel: String, rect: Dictionary) -> String:
	if rel.ends_with("reel_final_machine.png"):
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
	COLOR = sum / wsum;
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
	# ASSET_SCALE only ever described the legacy x8 exports, and a sheet that goes native
	# (reel_final_machine.png did) would be cropped far outside its own bounds and draw
	# nothing at all.
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

func _build_reel_animation_art() -> void:
	var tex := _load_texture("machine new view/spin_final_machine.png", true)
	if tex == null:
		return
	for i in 3:
		var spr := _authored_sprite("SpinReel%d" % i)
		var authored := spr != null
		if spr == null:
			spr = Sprite2D.new()
			spr.name = "SpinReel%d" % i
			add_child(spr)
		spr.texture = tex
		spr.centered = false
		spr.region_enabled = true
		if not authored:
			spr.position = Vector2(REEL_HOLES[i]["left"], REEL_HOLES[i]["top"])
			spr.scale = Vector2(1.0 / ASSET_SCALE, 1.0 / ASSET_SCALE)
		spr.texture_filter = MACHINE_ART_TEXTURE_FILTER
		spr.visible = false
		_spin_reel_sprites.append(spr)
		_set_spin_reel_frame(i, 0)

func _set_spin_reel_frame(index: int, frame: int) -> void:
	if index < 0 or index >= _spin_reel_sprites.size():
		return
	var spr: Sprite2D = _spin_reel_sprites[index]
	if spr == null or spr.texture == null:
		return
	var tex := spr.texture
	var frame_w := float(tex.get_width()) / float(SPIN_FRAME_COUNT)
	var hole: Dictionary = REEL_HOLES[index]
	spr.region_rect = Rect2(
		frame_w * float(frame) + float(hole["left"]) * ASSET_SCALE,
		float(hole["top"]) * ASSET_SCALE,
		float(hole["width"]) * ASSET_SCALE,
		float(hole["height"]) * ASSET_SCALE
	)

func _set_spin_reel_visible(index: int, visible: bool) -> void:
	if index >= 0 and index < _spin_reel_sprites.size():
		_spin_reel_sprites[index].visible = visible

func _hide_spin_reels() -> void:
	for spr in _spin_reel_sprites:
		spr.visible = false

func _build_tv_indicators() -> void:
	_wealth_odometer = WealthOdometer.new()
	_wealth_odometer.name = "WealthOdometer"
	add_child(_wealth_odometer)
	_build_target_readout()
	_health_bar_sprite = _build_full_canvas_sheet(
		"machine new view/health_bar.png", HEALTH_BAR_FRAME_COUNT)
	_build_reserve_glow()
	_build_spins_left_label()
	_coin_insert_sprite = _build_full_canvas_sheet(
		"machine new view/health_animation.png", COIN_INSERT_FRAME_COUNT)
	if _coin_insert_sprite != null:
		_coin_insert_sprite.visible = false
	_build_boost_indicators()
	_build_power_bar()
	_build_restore_cap()
	_build_augment_emplacements()

## Objective readout on the TV (issue #181): the authored TARGET plate with its fill
## bar, and the goal number below it. Both are full-canvas sheets, so their placement
## is baked into the art — the code only picks frames.
func _build_target_readout() -> void:
	_target_bar_sprite = _build_full_canvas_sheet(TARGET_BAR_SHEET, TARGET_BAR_FRAME_COUNT)
	if _target_bar_sprite != null:
		_target_bar_sprite.z_index = TARGET_TV_Z_INDEX
	_target_goals_sprite = _build_full_canvas_sheet(TARGET_GOALS_SHEET, TARGET_GOALS_FRAME_COUNT)
	if _target_goals_sprite != null:
		_target_goals_sprite.z_index = TARGET_TV_Z_INDEX
	# The shimmer plays underneath the bar, so the authored fill always reads on top
	# of it rather than being animated over.
	_target_bar_anim_sprite = _build_full_canvas_sheet(
		TARGET_BAR_ANIM_SHEET, TARGET_BAR_ANIM_FRAME_COUNT)
	if _target_bar_anim_sprite != null:
		_target_bar_anim_sprite.z_index = TARGET_TV_Z_INDEX - 1
	_refresh_target_readout()


## Two-frame loop over the fill bar. Driven from _process rather than a tween so it
## survives the tween sweeps that clear the run's transient effects.
func _advance_target_bar_animation(delta: float) -> void:
	if _target_bar_anim_sprite == null or not _target_bar_anim_sprite.visible:
		return
	_target_bar_anim_time += delta
	if _target_bar_anim_time < TARGET_BAR_ANIM_FRAME_TIME:
		return
	_target_bar_anim_time = fmod(_target_bar_anim_time, TARGET_BAR_ANIM_FRAME_TIME)
	_set_sheet_frame(_target_bar_anim_sprite,
		(_target_bar_anim_sprite.frame + 1) % TARGET_BAR_ANIM_FRAME_COUNT)

## The goal frames are authored one per WEALTH_TARGETS entry, so the frame index IS the
## target index. The bar fills with progress toward the CURRENT target and therefore
## empties again each time one is paid — complete_wealth_target() subtracts the target
## from the score and advances the index together.
func _refresh_target_readout() -> void:
	if _target_goals_sprite == null and _target_bar_sprite == null:
		return
	# A win callout, a power animation or the lit FREE SPIN banner owns the whole TV while
	# it is up; the objective readout steps aside for all three. The dealer interface is
	# the one persistent readout that stays up under the banner (_tv_callout_active).
	var should_show := not _tv_content_muted()
	if _target_bar_sprite != null:
		_target_bar_sprite.visible = should_show
	if _target_goals_sprite != null:
		_target_goals_sprite.visible = should_show
	if _target_bar_anim_sprite != null:
		_target_bar_anim_sprite.visible = should_show
	if not should_show:
		return
	var index := clampi(int(RunStateStore.wealthTargetIndex), 0, TARGET_GOALS_FRAME_COUNT - 1)
	_set_sheet_frame(_target_goals_sprite, index)
	var target := maxi(1, RunStateStore.current_wealth_target())
	# The bar tracks the score the odometer is SHOWING, not the score the state already
	# holds: while the reward deltas are held back (or COMBO's second beat is pending)
	# the win has not been revealed yet, and a bar that filled early announced the
	# payout before the number did.
	var shown_score := int(RunStateStore.scoreEarned)
	if _hud_delta_hold or _combo_score_pending >= 0:
		shown_score = _display_lucidity
	var progress := clampf(float(shown_score) / float(target), 0.0, 1.0)
	_set_sheet_frame(_target_bar_sprite, clampi(
		floori(progress * float(TARGET_BAR_FRAME_COUNT - 1)), 0, TARGET_BAR_FRAME_COUNT - 1))

## Numeric spins-left readout under the neuron tube — tracks the same
## _display_spins_left() budget the capped tube frames show.
func _build_spins_left_label() -> void:
	_spins_left_label = Label.new()
	_spins_left_label.name = "SpinsLeftNumber"
	_spins_left_label.position = SPINS_LEFT_LABEL_RECT.position
	_spins_left_label.size = SPINS_LEFT_LABEL_RECT.size
	_spins_left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spins_left_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spins_left_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spins_left_label.add_theme_font_size_override("font_size", 7)
	if _font != null:
		_spins_left_label.add_theme_font_override("font", _font)
	_spins_left_label.add_theme_color_override("font_color", SPINS_LEFT_NORMAL_COLOR)
	_spins_left_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_spins_left_label.add_theme_constant_override("outline_size", 1)
	_spins_left_label.text = ""
	add_child(_spins_left_label)

## The power-restore gauge (issue #76): a native full-canvas overlay sheet (6x1 = 6 frames).
## It starts from the current power-point total so a resumed run does not replay old score.
## The authored augment sockets on the power bar — the divider after the third power
## emplacement plus one chip bed per held augment. Three frames: frame N shows N+1 sockets,
## so the row only ever offers as many beds as the run has augments to put in them (nothing
## at all with none). Full-canvas art, so placement is baked in; the code picks the frame and
## the layer it draws on: above the cabinet, below the badges themselves.
func _build_augment_emplacements() -> void:
	_augment_plate_sprite = _build_full_canvas_sheet(AUGMENT_PLATE_SHEET, AUGMENT_PLATE_FRAMES)
	if _augment_plate_sprite != null:
		_augment_plate_sprite.z_index = AUGMENT_PLATE_Z_INDEX
		_augment_plate_sprite.visible = false

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
	var tex := _load_texture("machine new view/health_bar.png", true)
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
	_refresh_restore_cap()

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

## Pooled duration icons inside the TV's top-right (issue #76): one slot per possible
## boost, hidden until active. The icon says WHICH boost, a badge on its bottom-right
## corner says how many spins are left. Active boosts stack HORIZONTALLY, growing left
## from the corner. Anchored to the TV status column so the row clears the red
## bezel. Built once; refreshed each HUD update.
const BOOST_ICON_SIZE := 12.0
const BOOST_ICON_GAP := 3.0
# Issue #181: fixed authored slots for the item icons, filled right to left. Every
# other thing that owns the TV is measured art, and between them the only clean band
# left is y81..93: the dealer bar runs to y77 with its icon to y80, the goal number
# occupies x66..83 at y86..90 and the fill bar starts at y94. That leaves two 12px
# slots to the right of the goal number and clear of all of it; further simultaneous
# boosts fold into a "+N" on the last one. The old layout was a right-aligned row that
# grew leftwards and pushed its sixth icon onto the left bezel, outside the TV, with
# nothing clipping it.
const BOOST_SLOT_POSITIONS: Array[Vector2] = [Vector2(97.0, 81.0), Vector2(84.0, 81.0)]
const BOOST_COUNT_COLOR := Color(1.0, 0.95, 0.7)
const BOOST_NEGATIVE_COUNT_COLOR := Color(0.94, 0.27, 0.27)
# Issue #113: polarity corner glyphs — "+" top-left when the boost helps, "-"
# top-right when it hurts, both on a mixed boost. Sign shape carries the meaning,
# colour (HintLabel's shared green/red) only reinforces it — never colour alone.
const BOOST_MARK_POS_COLOR := Color(0.13, 0.77, 0.37)
const BOOST_MARK_NEG_COLOR := Color(0.94, 0.27, 0.27)
func _build_boost_indicators() -> void:
	_boost_indicator_slots.clear()
	for i in DURATION_BOOSTS.size():
		var slot := Control.new()
		slot.name = "BoostIndicator%d" % i
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.z_index = 12
		slot.visible = false
		add_child(slot)
		# Icon at the slot origin; the whole slot is positioned per-row on refresh.
		var icon := TextureRect.new()
		icon.position = Vector2.ZERO
		icon.size = Vector2(BOOST_ICON_SIZE, BOOST_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		# Count in the icon's bottom-right corner. The DTM font forces a ~23px min box
		# height, so a fixed box would push bottom-aligned text well below the icon; the
		# box is instead sized/placed from the label's real min height on refresh.
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.add_theme_font_size_override("font_size", 7)
		if _font != null:
			count.add_theme_font_override("font", _font)
		count.add_theme_color_override("font_color", BOOST_COUNT_COLOR)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 1)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count)
		# Polarity glyphs (issue #113): "+" pinned top-left, "-" pinned top-right.
		var pos_mark := _make_boost_mark("+", HORIZONTAL_ALIGNMENT_LEFT, BOOST_MARK_POS_COLOR)
		slot.add_child(pos_mark)
		var neg_mark := _make_boost_mark("-", HORIZONTAL_ALIGNMENT_RIGHT, BOOST_MARK_NEG_COLOR)
		slot.add_child(neg_mark)
		_boost_indicator_slots.append({
			"slot": slot, "icon": icon, "count": count,
			"pos_mark": pos_mark, "neg_mark": neg_mark,
		})

func _make_boost_mark(glyph: String, alignment: HorizontalAlignment, color: Color) -> Label:
	var mark := Label.new()
	mark.text = glyph
	mark.horizontal_alignment = alignment
	mark.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	mark.add_theme_font_size_override("font_size", 7)
	if _font != null:
		mark.add_theme_font_override("font", _font)
	mark.add_theme_color_override("font_color", color)
	mark.add_theme_color_override("font_outline_color", Color.BLACK)
	mark.add_theme_constant_override("outline_size", 1)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pinned to the icon's top edge, nudged 3px up so the sign reads as a corner badge
	# instead of covering the art. The box height comes from the font's real min height
	# on refresh — asking for it here, before the node is in the tree, can return zero.
	mark.position = Vector2(0.0, -3.0)
	mark.visible = false
	return mark


## Whether a boost currently owns a slot: either it has spins left, or it just expired
## and is lingering on zero for one refresh.
func _boost_is_active(boost: Dictionary) -> bool:
	var counter := String(boost["counter"])
	var suppress_when_zero_counter := String(boost.get("suppressWhenZeroCounter", ""))
	if suppress_when_zero_counter != "" and _boost_zero_linger.has(suppress_when_zero_counter):
		return false
	return int(RunStateStore.get(counter)) > 0 or _boost_zero_linger.has(counter)

## Shows one icon per active multi-spin boost, stacked down the TV's right edge, each
## with a spins-remaining badge. A boost whose icon is missing is skipped rather than
## shown as a bare number. Unused slots hide (issue #76). There are more boosts than
## slots, so the last visible one carries a "+N" overflow count (issue #181).
func _refresh_boost_indicators() -> void:
	if _boost_indicator_slots.is_empty():
		return
	# The item icons live on the TV, so they step aside for whatever owns it — a
	# PAIR/TRIPLE or power callout, or the lit FREE SPIN banner.
	if _tv_content_muted():
		_hide_boost_indicators()
		return
	var column_capacity := mini(BOOST_SLOT_POSITIONS.size(), _boost_indicator_slots.size())
	var active_total := 0
	for boost in DURATION_BOOSTS:
		if _boost_is_active(boost):
			active_total += 1
	var col := 0
	for boost in DURATION_BOOSTS:
		var counter := String(boost["counter"])
		var remaining := int(RunStateStore.get(counter))
		var show_zero := remaining <= 0 and _boost_zero_linger.has(counter)
		var suppress_when_zero_counter := String(boost.get("suppressWhenZeroCounter", ""))
		if suppress_when_zero_counter != "" and _boost_zero_linger.has(suppress_when_zero_counter):
			continue
		if remaining > 0:
			_boost_zero_linger.erase(counter)
		if (remaining <= 0 and not show_zero) or col >= column_capacity:
			continue
		var tex := _boost_icon_for(boost)
		if tex == null:
			continue
		var s: Dictionary = _boost_indicator_slots[col]
		var slot: Control = s["slot"]
		slot.position = BOOST_SLOT_POSITIONS[col]
		(s["icon"] as TextureRect).texture = tex
		var cn: Label = s["count"]
		cn.text = str(maxi(0, remaining))
		cn.add_theme_color_override(
			"font_color",
			BOOST_NEGATIVE_COUNT_COLOR if bool(boost.get("negative", false)) else BOOST_COUNT_COLOR)
		# Issue #113: polarity is a sign glyph, not just the count colour — "+" for
		# a helping boost, "-" for a hurting one, both when the boost is mixed.
		var is_negative := bool(boost.get("negative", false))
		var is_mixed := bool(boost.get("mixed", false))
		(s["pos_mark"] as Label).visible = not is_negative or is_mixed
		(s["neg_mark"] as Label).visible = is_negative or is_mixed
		# Pin the digit's bottom-right to the icon's bottom-right corner using the label's
		# real (font-driven) min height, so it sits flush in the corner (issue #76 review).
		var mh := cn.get_minimum_size().y
		cn.size = Vector2(BOOST_ICON_SIZE, mh)
		cn.position = Vector2(0.0, BOOST_ICON_SIZE - mh)
		# The polarity glyphs share the count's font metrics, which are only reliable
		# once the label is in the tree — sizing them at build time can yield a zero-high
		# box and clip the sign.
		for mark_key in ["pos_mark", "neg_mark"]:
			var mark: Label = s[mark_key]
			mark.size = Vector2(BOOST_ICON_SIZE, mark.get_minimum_size().y)
		slot.visible = true
		col += 1
	# More boosts than slots: the last one carries how many are not shown, so the player
	# still knows something is running rather than silently losing it.
	if col > 0 and active_total > col:
		var overflow: Label = _boost_indicator_slots[col - 1]["count"]
		overflow.text = "+%d" % (active_total - col + 1)
	_hide_boost_indicators(col)

## Blanks the boost slots from `first` onwards. Dropping the texture matters: a slot
## re-shown before its icon is resolved would otherwise flash the previous boost's art.
func _hide_boost_indicators(first := 0) -> void:
	for i in range(first, _boost_indicator_slots.size()):
		var hidden: Dictionary = _boost_indicator_slots[i]
		(hidden["slot"] as Control).visible = false
		(hidden["icon"] as TextureRect).texture = null

func _capture_expiring_boost_counters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for boost in DURATION_BOOSTS:
		var counter := String(boost["counter"])
		if int(RunStateStore.get(counter)) == 1:
			var snapshot: Dictionary = { "counter": counter }
			var symbol_field := String(boost.get("symbolField", ""))
			if symbol_field != "":
				var symbol_id := String(RunStateStore.get(symbol_field))
				if symbol_id != "":
					snapshot["symbolId"] = symbol_id
			out.append(snapshot)
	return out

func _apply_expiring_boost_linger(counters: Array[Dictionary]) -> void:
	for snapshot in counters:
		var counter := String(snapshot.get("counter", ""))
		if int(RunStateStore.get(counter)) <= 0:
			_boost_zero_linger[counter] = snapshot

func _clear_boost_zero_linger() -> void:
	if _boost_zero_linger.is_empty():
		return
	_boost_zero_linger.clear()
	_refresh_boost_indicators()
	_refresh_consumable_fx()

func _build_machine_control_art() -> void:
	_multiplier_sprite = _build_full_canvas_sheet("machine new view/multiplier_final_machine.png", MULTIPLIER_FRAME_COUNT)
	# Issue #155: gauge effect overlays draw above the badge strip; hidden until
	# the frenzy reaches their state.
	_mult_fx_2 = _build_full_canvas_sheet(MULT_FX_2_SHEET, MULT_FX_2_FRAMES)
	_mult_fx_3 = _build_full_canvas_sheet(MULT_FX_3_SHEET, MULT_FX_3_FRAMES)
	_mult_fx_fire = _build_full_canvas_sheet(MULT_FX_FIRE_SHEET, MULT_FX_3_FRAMES)
	_dealer_bar_sprite = _build_full_canvas_sheet(DEALER_BAR_SHEET, DEALER_BAR_FRAME_COUNT)
	_dealer_bar_overlay_1 = _build_full_canvas_sheet(
		DEALER_BAR_OVERLAY_1_SHEET, DEALER_BAR_OVERLAY_1_FRAMES)
	_dealer_bar_overlay_2 = _build_full_canvas_sheet(
		DEALER_BAR_OVERLAY_2_SHEET, DEALER_BAR_OVERLAY_2_FRAMES)
	_dealer_bar_overlay_3 = _build_full_canvas_sheet(
		DEALER_BAR_OVERLAY_3_SHEET, DEALER_BAR_OVERLAY_3_FRAMES)
	_free_spin_sprite = _build_full_canvas_sheet(FREE_SPIN_SHEET, 1)
	_combo_loss_2_sprite = _build_full_canvas_sheet(COMBO_LOSS_2_SHEET, 1)
	_combo_loss_3_sprite = _build_full_canvas_sheet(COMBO_LOSS_3_SHEET, COMBO_LOSS_3_FRAMES)
	_win_anim_sprite = _build_full_canvas_sheet(WIN_ANIM_SHEET, WIN_ANIM_FRAMES)
	if _win_anim_sprite != null:
		_win_payout_label = Label.new()
		_win_payout_label.name = "WinPayout"
		_win_payout_label.position = WIN_PAYOUT_RECT.position
		_win_payout_label.size = WIN_PAYOUT_RECT.size
		_win_payout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_win_payout_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_win_payout_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_win_payout_label.add_theme_font_size_override("font_size", 11)
		if _font != null:
			_win_payout_label.add_theme_font_override("font", _font)
		_win_payout_label.add_theme_color_override("font_color", WIN_PAYOUT_COLOR)
		_win_payout_label.text = ""
		_win_anim_sprite.add_child(_win_payout_label)
	var combo_texture := _load_texture(COMBO_EFFECT_SHEET, true)
	if combo_texture != null:
		_combo_effect_frame_count = clampi(
			roundi(float(combo_texture.get_width()) / float(SRC_W)), 1, COMBO_EFFECT_FRAMES)
	_combo_effect_sprite = _build_full_canvas_sheet(
		COMBO_EFFECT_SHEET, _combo_effect_frame_count)
	if _combo_effect_sprite != null:
		_combo_effect_sprite.z_index = 9
		_combo_payout_label = Label.new()
		_combo_payout_label.name = "ComboPayout"
		_combo_payout_label.position = COMBO_PAYOUT_RECT.position
		_combo_payout_label.size = COMBO_PAYOUT_RECT.size
		_combo_payout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_combo_payout_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_combo_payout_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_combo_payout_label.add_theme_font_size_override("font_size", 8)
		if _font != null:
			_combo_payout_label.add_theme_font_override("font", _font)
		_combo_payout_label.add_theme_color_override("font_color", COMBO_PAYOUT_COLOR)
		_combo_payout_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_combo_payout_label.add_theme_constant_override("outline_size", 1)
		_combo_payout_label.text = ""
		_combo_payout_label.visible = false
		_combo_effect_sprite.add_child(_combo_payout_label)
	_power_anim_sprite = _build_full_canvas_sheet(POWER_ANIM_SHEET, POWER_ANIM_FRAMES)
	_cheat_selection_sprite = _build_full_canvas_sheet(
		CHEAT_SELECTION_SHEET, CHEAT_SELECTION_FRAMES)
	for fx in [_mult_fx_2, _mult_fx_3, _mult_fx_fire, _free_spin_sprite,
			_combo_loss_2_sprite, _combo_loss_3_sprite,
			_win_anim_sprite, _combo_effect_sprite, _power_anim_sprite, _cheat_selection_sprite]:
		if fx != null:
			(fx as Sprite2D).visible = false
	if _cheat_selection_sprite != null:
		_cheat_selection_sprite.z_index = 98
	for dealer_art in [_dealer_bar_sprite, _dealer_bar_overlay_1,
			_dealer_bar_overlay_2, _dealer_bar_overlay_3]:
		if dealer_art != null:
			(dealer_art as Sprite2D).z_index = 11
	if _dealer_bar_sprite != null:
		_dealer_bar_sprite.visible = true
	for dealer_overlay in [_dealer_bar_overlay_1, _dealer_bar_overlay_2,
			_dealer_bar_overlay_3]:
		if dealer_overlay != null:
			(dealer_overlay as Sprite2D).visible = false
	for loss_sprite in [_combo_loss_2_sprite, _combo_loss_3_sprite]:
		if loss_sprite != null:
			(loss_sprite as Sprite2D).z_index = COMBO_LOSS_OVERLAY_Z_INDEX
	_lever_sprite = _build_full_canvas_sheet("machine new view/neon_machine_lever.png", LEVER_FRAME_COUNT)
	_jackpot_sprite = _build_full_canvas_sheet("machine new view/neon_machine_jackpot.png", JACKPOT_FRAME_COUNT)
	_set_sheet_frame(_jackpot_sprite, JACKPOT_FRAME_OFF)
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
## Per-reel copies of the reel art. The crop is the hole grown a little, because the authored
## patch runs from y169 to y202 — a pixel above the hole and two below — and Swap shakes these
## copies in place of the shared backing, which would otherwise leave those rows behind.
func _build_reel_covers() -> void:
	for i in 3:
		var hole: Dictionary = REEL_HOLES[i]
		var cover := _build_region_sprite("machine new view/reel_final_machine.png", {
			"left": float(hole["left"]) - 1.0,
			"top": float(hole["top"]) - 3.0,
			"width": float(hole["width"]) + 2.0,
			"height": float(hole["height"]) + 6.0,
		})
		if cover != null:
			cover.visible = false
		_reel_covers.append(cover)

func _set_reel_cover(index: int, visible: bool) -> void:
	if index < _reel_covers.size() and _reel_covers[index] != null:
		_reel_covers[index].visible = visible

func _play_reel_stop_sfx(index: int) -> void:
	if index < 0 or index >= _reel_stop_sfx_played.size():
		return
	if bool(_reel_stop_sfx_played[index]):
		return
	_reel_stop_sfx_played[index] = true
	_play_sfx(&"reel_stop")

# A reel lands: mask its blur, show its final symbol, stop animating that reel.
func _reveal_reel(index: int) -> void:
	var was_visible := _reel_sprites[index].visible
	if not was_visible:
		_play_reel_stop_sfx(index)
	_set_spin_reel_visible(index, false)
	_set_reel_cover(index, true)
	_set_reel_symbol(index, String(_final_reels[index]))
	_set_reel_visible(index, true)
	_set_hidden_cover(index, _hide_result_active) # White Powder masks the reveal (issue #34)
	_apply_adjacent_symbol_visibility(index)      # Serum hides above/below neighbours

func _configure_reel_sprite(s: Sprite2D, pos: Vector2, alpha: float, apply_position := true) -> void:
	s.centered = true
	if apply_position:
		s.position = pos
	s.modulate = Color(1, 1, 1, alpha)
	# Symbols are authored large and drawn at 12-16px, so keep their downscale
	# pixel-perfect with the rest of the machine art.
	s.texture_filter = MACHINE_ART_TEXTURE_FILTER

func _new_reel_sprite(name: String, pos: Vector2, alpha: float) -> Sprite2D:
	var s := _authored_sprite(name)
	var authored := s != null
	if s == null:
		s = Sprite2D.new()
		s.name = name
		add_child(s)
	_configure_reel_sprite(s, pos, alpha, not authored)
	return s

func _build_reels() -> void:
	var cy := REEL_WINDOW["top"] + REEL_WINDOW["height"] * 0.5
	for i in 3:
		var cx: float = REEL_CELL_CENTERS[i]
		# Add neighbours first, centre last so it draws on top where they meet.
		_reel_top_sprites.append(_new_reel_sprite("Reel%dTop" % i, Vector2(cx, cy - STRIP_OFFSET), STRIP_ADJ_ALPHA))
		_reel_bottom_sprites.append(_new_reel_sprite("Reel%dBottom" % i, Vector2(cx, cy + STRIP_OFFSET), STRIP_ADJ_ALPHA))
		_reel_sprites.append(_new_reel_sprite("Reel%dCenter" % i, Vector2(cx, cy), 1.0))

func _set_reel_visible(index: int, visible: bool) -> void:
	_reel_sprites[index].visible = visible
	_reel_top_sprites[index].visible = visible and not _adjacent_symbols_hidden_active
	_reel_bottom_sprites[index].visible = visible and not _adjacent_symbols_hidden_active

func _set_all_reels_visible(visible: bool) -> void:
	for i in _reel_sprites.size():
		_set_reel_visible(i, visible)

# Symbol above/below `sym` in the canonical cycle (book sits outside it).
func _reel_neighbours(sym: String) -> Dictionary:
	if sym.begins_with("heart"):
		# A heart strip cycles x1 -> x2 -> x3 around the landed tier, so the
		# display shows exactly three of each heart symbol — never nine of one.
		var tier := clampi(int(sym.trim_prefix("heart_x")), 1, 3) \
			if sym.begins_with("heart_x") else 1
		return {
			"top": "heart_x%d" % (((tier - 2) + 3) % 3 + 1),
			"bottom": "heart_x%d" % (tier % 3 + 1),
		}
	var cyc: Array = Symbols.BASE_SYMBOL_CYCLE
	var n := cyc.size()
	var i := cyc.find(sym)
	if i < 0:
		if sym == "book":
			# Shift treats out-of-cycle symbols as index 0, so book up -> eye and down -> flatline.
			return { "top": cyc[n - 1], "bottom": cyc[1] }
		return { "top": cyc[n - 1], "bottom": cyc[0] }
	return { "top": cyc[(i - 1 + n) % n], "bottom": cyc[(i + 1) % n] }

func _apply_symbol(s: Sprite2D, symbol_id: String, target_h: float) -> void:
	var heart_asset := String(HEART_SYMBOL_ASSETS.get(symbol_id, ""))
	if symbol_id == "heart" and heart_asset == "":
		heart_asset = String(HEART_SYMBOL_ASSETS["heart_x1"])
	if heart_asset != "":
		var heart_tex := _load_texture(heart_asset, true)
		if heart_tex == null:
			return
		s.region_enabled = false
		s.texture = heart_tex
		var heart_scale := minf(1.0, target_h / float(heart_tex.get_height()))
		s.scale = Vector2(heart_scale, heart_scale)
		return
	var tex := _load_texture("symbols/%s.png" % symbol_id, true) # mipmaps for crisp downscale
	if tex == null:
		return
	s.region_enabled = false
	s.texture = tex
	var k := minf(1.0, target_h / float(tex.get_height()))
	s.scale = Vector2(k, k)

func _set_reel_symbol(index: int, symbol_id: String) -> void:
	_apply_symbol(_reel_sprites[index], symbol_id, STRIP_CENTER_H)
	var nb := _reel_neighbours(symbol_id)
	_apply_symbol(_reel_top_sprites[index], String(nb["top"]), STRIP_ADJ_H)
	_apply_symbol(_reel_bottom_sprites[index], String(nb["bottom"]), STRIP_ADJ_H)
	_apply_adjacent_symbol_visibility(index)

func _apply_adjacent_symbol_visibility(index: int) -> void:
	if index < 0 or index >= _reel_sprites.size():
		return
	var visible := bool(_reel_sprites[index].visible) and not _adjacent_symbols_hidden_active
	_reel_top_sprites[index].visible = visible
	_reel_bottom_sprites[index].visible = visible

func _build_hud() -> void:
	_build_score_button()
	_build_spin_label()
	_build_hint_layer()
	_build_dealer_icon()

## Issue #155: the compact dealer portrait sits beside the authored countdown bar.
## The countdown is entirely visual now; no numeric badge is layered over the icon.
func _build_dealer_icon() -> void:
	var icon := TextureRect.new()
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

## The whole warning stack the multiplier has earned is drawn at once. What changes with it
## is the BEEP RATE: one light beeps on the slow period, two or more on the fast one, so the
## machine audibly speeds up as the dealer closes in. `_dealer_warning_wanted` is how many
## lights the state earned.
const DEALER_WARNING_FAST_BEEP_LIGHTS := 2

func _refresh_dealer_countdown() -> void:
	if _dealer_bar_sprite == null:
		return
	var remaining := maxi(0, int(RunStateStore.dealerCountdown))
	# The FULL cycle, not the reset value: Dealer's Tip resets to 10 of 12, and the bar
	# has to show that as 2/12 filled. Measuring against the reset value instead would
	# redraw the same empty bar on a shorter scale and hide the head start entirely.
	var cycle_start := maxi(1, int(RunStateStore.dealer_countdown_cycle_length()))
	var elapsed := clampi(cycle_start - remaining, 0, cycle_start)
	var progress_frame := clampi(roundi(float(elapsed) * float(DEALER_BAR_FRAME_COUNT - 1)
		/ float(cycle_start)), 0, DEALER_BAR_FRAME_COUNT - 1)
	if not _dealer_bar_frame_initialized:
		_dealer_bar_frame_initialized = true
		_dealer_bar_display_frame = progress_frame
		_dealer_bar_target_frame = progress_frame
		_dealer_bar_progress_time = 0.0
		_set_dealer_bar_progress_frame(progress_frame)
	elif progress_frame < _dealer_bar_display_frame:
		# A dealer visit/new run resets the bar. Snap the reset so the next cycle
		# can visibly walk forward from frame 0 again.
		_dealer_bar_display_frame = progress_frame
		_dealer_bar_target_frame = progress_frame
		_dealer_bar_progress_time = 0.0
		_set_dealer_bar_progress_frame(progress_frame)
	else:
		_dealer_bar_target_frame = progress_frame
		if _dealer_bar_display_frame == _dealer_bar_target_frame:
			_dealer_bar_progress_time = 0.0
	_set_dealer_overlay_progress_frame(_dealer_bar_display_frame)
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
	# soon as the lever is pulled would leak the next gauge state into the spin.
	var overlay_ready := not _spinning_anim and not _spin_launch_pending \
		and not RunStateStore.isSpinning and not _hud_delta_hold
	var dealer_info_allowed := not _tv_callout_active() \
		or RunStateStore.comboDefeatPending
	# How many lights the state earned — the beep waits for the second one (see
	# DEALER_WARNING_BEEP_FROM_LIGHTS); the lights themselves all draw immediately.
	_dealer_warning_wanted = 0
	if show_overlay_1:
		_dealer_warning_wanted = 1
	if show_overlay_2:
		_dealer_warning_wanted = 2
	if show_overlay_3:
		_dealer_warning_wanted = 3
	var overlay_states: Array = [
		{ "sprite": _dealer_bar_overlay_1, "visible": show_overlay_1 },
		{ "sprite": _dealer_bar_overlay_2, "visible": show_overlay_2 },
		{ "sprite": _dealer_bar_overlay_3, "visible": show_overlay_3 },
	]
	for state: Dictionary in overlay_states:
		var overlay := state["sprite"] as Sprite2D
		if overlay == null:
			continue
		var should_show := bool(state["visible"])
		var was_visible := overlay.visible
		overlay.visible = should_show and overlay_ready and dealer_info_allowed
		if overlay.visible and not was_visible:
			overlay.modulate.a = 1.0
		elif not overlay.visible:
			overlay.modulate.a = 1.0
	if _tv_callout_active() and not RunStateStore.comboDefeatPending:
		_hide_tv_info_layers()
	elif RunStateStore.comboDefeatPending:
		# The dealer warning remains readable over the losing-state art, even if
		# the result's PAIR/TRIPLE callout is still fading out.
		if _dealer_bar_sprite != null:
			_dealer_bar_sprite.visible = true
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
		_score_button.position = Vector2(160.0 - _score_button.size.x - 9.0, 9.0)
	_score_button.flat = false
	_score_button.focus_mode = Control.FOCUS_NONE
	_score_button.add_theme_font_size_override("font_size", 7)
	if _font != null:
		_score_button.add_theme_font_override("font", _font)
	Assets.small_neon_button_style(_score_button, NEON_CYAN, 7, 2.0)
	Assets.start_menu_button_press_feedback(_score_button)
	if not _score_button.pressed.is_connected(_show_score_table):
		_score_button.pressed.connect(_show_score_table)

func _build_options_controls() -> void:
	_options_button = _authored_texture_button("options")
	if _options_button == null:
		_options_button = TextureButton.new()
		_options_button.name = "options"
		_options_button.position = Vector2(9.0, 9.0)
		_options_button.size = Vector2(20.0, 18.0)
		add_child(_options_button)
	Assets.skin_icon_button(_options_button, SETTINGS_ASSET, 1)
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
		_spawn_burst(label, 0, SCENE_FEEDBACK_LABEL_COLOR, 0)

## The dealer bar flashes on its new head start, so the Tip's 2/12 is seen being bought.
func _pulse_dealer_bar(label: String) -> void:
	_refresh_dealer_countdown() # the head start applies from this reset onward
	var target: CanvasItem = _dealer_bar_sprite
	if target == null or not is_instance_valid(target):
		return
	target.modulate = SCENE_FEEDBACK_TINT
	var tw := create_tween()
	tw.tween_property(target, "modulate", Color.WHITE, SCENE_FEEDBACK_FADE) \
		.set_trans(Tween.TRANS_SINE)
	if label != "":
		_spawn_burst(label, 0, SCENE_FEEDBACK_LABEL_COLOR, 2)

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
		bottom_hud.size = Vector2(160.0, 320.0)
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

func _build_hint_layer() -> void:
	var bottom_hud := get_node_or_null("BottomHudLayer") as Control
	if bottom_hud == null:
		return
	_hint_layer = bottom_hud.get_node_or_null("HintLayer") as Control
	if _hint_layer == null:
		_hint_layer = Control.new()
		_hint_layer.name = "HintLayer"
		bottom_hud.add_child(_hint_layer)
		# Consumable popups originate from the machine centre (the reel window's
		# midpoint), not the HUD anchor.
		_hint_layer.position = MACHINE_HINT_CENTER
		_hint_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint_layer.z_index = 20

func _build_spin_button() -> void:
	_spin_button = _make_or_bind_hit_button("SpinButton", LEVER_HIT, _do_spin)

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
	_set_stash_tray_visible(true)
	_set_tv_progress_bars_visible(true)
	_close_pending_combo_defeat()
	_pending_combo_power_flow = false
	_stop_flatline_countdown()
	_close_score_table()
	_clear_targeting()
	_clear_close_call_heartbeat()
	_set_hidden_result_active(false)
	_set_adjacent_symbols_hidden_active(false)
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
		_set_all_reels_visible(true)
		for i in 3:
			_set_reel_symbol(i, VISIBLE_SYMBOLS[i])
	# Settled reels show their cover (masks any blur); spin sheet hidden.
	for i in 3:
		_set_reel_cover(i, true)
	_hide_spin_reels()
	if _spin_sheet_sprite != null:
		_spin_sheet_sprite.visible = false
	_cancel_coin_insert()
	_update_hud()
	_refresh_lock_art()
	_refresh_jackpot_lamp(false)
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

func _to_menu() -> void:
	SceneNav.change_to(MENU_SCENE)

func _to_dealer() -> void:
	SceneNav.change_to(DEALER_SCENE)

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
	if _wealth_odometer != null:
		_wealth_odometer.stop_roll()
		snapshot = WealthOdometer.make_snapshot(score)
	_begin_tv_blackout(TargetReachedOverlay.PHASE_BLACKOUT)
	overlay.digits_lifted.connect(_on_wealth_target_digits_lifted)
	# The final target is not paid out of the score and banks nothing, so it shows no
	# receipt — the Wealth ending takes the whole score from here.
	overlay.present(score, target, snapshot, "CONTINUE",
		bool(info.get("final", false)))
	overlay.continue_pressed.connect(_finish_wealth_target_transition)
	return true

## The lifted copy has reached the TV; blank the cabinet's own digits so the number is
## never on screen twice.
func _on_wealth_target_digits_lifted() -> void:
	if _wealth_odometer != null:
		_wealth_odometer.set_digits_hidden(true)

## Fades the TV to black behind the payout screen. Reuses the shared content mute for
## the layers that already know how to step aside (dealer bar, combo, free spins) and
## covers everything else — boost icons, augment row, callout sheets — with one rect,
## rather than enumerating a node list that would rot.
func _begin_tv_blackout(fade_time: float) -> void:
	_begin_tv_info_pop(TV_BLACKOUT_SOURCE)
	if _tv_blackout_rect == null or not is_instance_valid(_tv_blackout_rect):
		_tv_blackout_rect = ColorRect.new()
		_tv_blackout_rect.name = "TvBlackout"
		_tv_blackout_rect.position = Vector2(TV_SCREEN["left"], TV_SCREEN["top"])
		_tv_blackout_rect.size = Vector2(TV_SCREEN["width"], TV_SCREEN["height"])
		_tv_blackout_rect.color = TV_BLACKOUT_COLOR
		_tv_blackout_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tv_blackout_rect.z_index = TV_BLACKOUT_Z_INDEX
		_tv_blackout_rect.add_to_group(WEALTH_TRANSIENT_FX_GROUP)
		add_child(_tv_blackout_rect)
	_tv_blackout_rect.visible = true
	_tv_blackout_rect.modulate.a = 0.0
	if _tv_blackout_tween != null and _tv_blackout_tween.is_valid():
		_tv_blackout_tween.kill()
	_tv_blackout_tween = create_tween()
	_tv_blackout_tween.tween_property(_tv_blackout_rect, "modulate:a",
		TV_BLACKOUT_ALPHA, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _end_tv_blackout() -> void:
	if _tv_blackout_tween != null and _tv_blackout_tween.is_valid():
		_tv_blackout_tween.kill()
	_tv_blackout_tween = null
	if _tv_blackout_rect != null and is_instance_valid(_tv_blackout_rect):
		_tv_blackout_rect.visible = false
		_tv_blackout_rect.modulate.a = 0.0
	_end_tv_info_pop(TV_BLACKOUT_SOURCE)
	if _wealth_odometer != null:
		_wealth_odometer.set_digits_hidden(false)

func _finish_wealth_target_transition() -> void:
	if not _wealth_target_transition_active:
		return
	# The run is leaving for the between-run flow. A card earned on the same spin must not
	# squeeze in during the hand-off — the store commits below emit state_changed, and the
	# unlock gate would otherwise open for those few frames and beat the scene change. It is
	# presented after the odds table instead, by the dealer (issue #52 / #176).
	_target_round_handoff = true
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
			"lucidityCoins": RunStateStore.lucidityCoins,
		}
		_show_ending("wealth", final_run)
		return
	var target := int(completed.get("target", 0))
	_stop_wealth_target_transition()
	_wealth_target_transition_active = false
	_post_spin_sequence_active = false
	# 500/1500 route through the threshold Pacte first; that scene then rejoins the
	# shared between-run flow. Every other target enters it directly via
	# begin_target_round -> the one between-run dealer (odds table -> shop), whose
	# START begins a fresh run (issue #176).
	if RunStateStore.arm_pacte_for_wealth_target(target) \
			and RunStateStore.open_threshold_pacte():
		_set_sequence_lock(false)
		SceneNav.change_to(PACTE_SCENE)
		return
	_set_sequence_lock(false)
	if RunStateStore.begin_target_round():
		SceneNav.change_to(DEALER_SCENE)
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
	# current reveal's rescue window, but pulling the lever means the pair/triple
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
	_stop_win_animation() # last spin's PAIR/TRIPLE callout must not outlive its win
	_stop_combo_effect() # finish the previous Win Boost beat before the next reveal
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
	# bars / lamp during the lever pull (issue #54). The SPINS LEFT counter is the
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
	_set_adjacent_symbols_hidden_active(consumable_fx_enabled and blur_this_spin)
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
	# Launch beat: the coin drops into the machine first, THEN the lever pulls,
	# THEN the reels start.
	_start_coin_insert()
	_spin_launch_pending = true
	_spin_button.disabled = true
	_refresh_controls()
	await get_tree().create_timer(
		COIN_INSERT_FRAME_TIME * float(COIN_INSERT_FRAME_COUNT)).timeout
	if not is_inside_tree() or not _spin_launch_pending:
		_hud_delta_hold = false # aborted launch: don't leave the HUD frozen
		return
	_start_lever_pull()
	await get_tree().create_timer(LEVER_REEL_START_DELAY).timeout
	if not is_inside_tree() or not _spin_launch_pending:
		_hud_delta_hold = false # aborted launch: don't leave the HUD frozen
		return
	_spin_launch_pending = false
	_start_reel_spin_animation(locked_before)
	_spinning_anim = true
	_anim_elapsed = 0.0
	_blur_accum = 0.0

func _process(delta: float) -> void:
	if _coin_anim_active:
		_step_coin_insert(delta)
	if _lever_anim_active:
		_step_lever(delta)
	if _reroll_anim_active:
		_step_reroll(delta)
	if _rewind_anim_active:
		_step_rewind_restore(delta)
	if _flatline_countdown_active:
		_step_flatline_countdown(delta)
	_step_multiplier_fx(delta)
	_step_dealer_bar_progress(delta)
	_step_augment_glitch(delta)
	_advance_target_bar_animation(delta)
	_step_dealer_overlay_beep(delta)
	_step_free_spin_blink(delta)
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
				_set_spin_reel_frame(i, _spin_frame)
	for i in 3:
		var stop_sfx_time := maxf(0.0, float(_reel_stop_times[i]) - REEL_STOP_SFX_LEAD_TIME)
		if not bool(_locked_reels_during_spin[i]) and _anim_elapsed >= stop_sfx_time:
			_play_reel_stop_sfx(i)
	for i in 3:
		if not bool(_locked_reels_during_spin[i]) and _anim_elapsed >= float(_reel_stop_times[i]) and not _reel_sprites[i].visible:
			_reveal_reel(i)
	if _anim_elapsed >= _reel_stop_times[2]:
		for i in 3:
			_reveal_reel(i)
		_hide_spin_reels()
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
		_set_reel_visible(i, locked)
		_set_reel_cover(i, locked)
		_set_spin_reel_frame(i, _spin_frame)
		_set_spin_reel_visible(i, not locked)

func _start_coin_insert() -> void:
	if _coin_insert_sprite == null:
		return
	_coin_anim_active = true
	_coin_anim_elapsed = 0.0
	_coin_insert_sprite.visible = true
	_set_sheet_frame(_coin_insert_sprite, 0)

func _step_coin_insert(delta: float) -> void:
	_coin_anim_elapsed += delta
	var frame := int(_coin_anim_elapsed / COIN_INSERT_FRAME_TIME)
	if frame >= COIN_INSERT_FRAME_COUNT:
		_cancel_coin_insert()
		return
	_set_sheet_frame(_coin_insert_sprite, frame)

func _cancel_coin_insert() -> void:
	_coin_anim_active = false
	if _coin_insert_sprite != null:
		_coin_insert_sprite.visible = false

func _start_lever_pull() -> void:
	_play_sfx(&"lever")
	_lever_anim_active = true
	_lever_anim_elapsed = 0.0
	_set_sheet_frame(_lever_sprite, 0)

func _step_lever(delta: float) -> void:
	_lever_anim_elapsed += delta
	var pull_duration := LEVER_FRAME_TIME * float(LEVER_FRAME_COUNT - 1)
	var return_start := pull_duration + LEVER_HOLD_TIME
	var done_at := return_start + LEVER_RETURN_TIME
	var frame := 0
	if _lever_anim_elapsed <= pull_duration:
		frame = clampi(int(round(_lever_anim_elapsed / LEVER_FRAME_TIME)), 0, LEVER_FRAME_COUNT - 1)
	elif _lever_anim_elapsed <= return_start:
		frame = LEVER_FRAME_COUNT - 1
	elif _lever_anim_elapsed <= done_at:
		var t := (_lever_anim_elapsed - return_start) / LEVER_RETURN_TIME
		frame = clampi(int(round(lerpf(float(LEVER_FRAME_COUNT - 1), 0.0, t))), 0, LEVER_FRAME_COUNT - 1)
	else:
		_lever_anim_active = false
		frame = 0
	_set_sheet_frame(_lever_sprite, frame)

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
		_show_power_animation(String(dealer_help.get("power", "")))
		await get_tree().create_timer(0.55).timeout
		_stop_power_animation()
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
	if RunStateStore.comboDefeatPending:
		if not _discard_moot_combo_defeat():
			# Keep the pre-loss combo visible while the player decides whether to spend
			# a current-reveal power. The ending check waits until that decision lands,
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
		# gain beat the target: one lever press confirms the combo loss, procs the target,
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
	# without the player having to touch the lever.
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
	_set_combo_loss_display(int(RunStateStore.pendingComboMultiplier))
	_start_combo_loss_beep()
	_refresh_controls()

func _on_pending_combo_declined() -> void:
	if not RunStateStore.comboDefeatPending:
		return
	RunStateStore.resolve_pending_combo_defeat(false)
	_close_pending_combo_defeat()
	_finish_post_spin_sequence()
func _close_pending_combo_defeat() -> void:
	_stop_combo_loss_beep()
	_set_combo_loss_display(0)
	if _pending_combo_overlay != null:
		_pending_combo_overlay.queue_free()
		_pending_combo_overlay = null
	_refresh_controls()

## A rescue cancels the warning the moment the store clears the pending flag — the
## beep and the losing-state art must not linger through the reward presentation.
func _maybe_cancel_combo_defeat_warning(was_pending: bool) -> void:
	if was_pending and not RunStateStore.comboDefeatPending:
		_close_pending_combo_defeat()

func _set_combo_loss_display(multiplier: int) -> void:
	if _combo_loss_2_sprite != null:
		_combo_loss_2_sprite.visible = multiplier == 2
	if _combo_loss_3_sprite != null:
		_combo_loss_3_sprite.visible = multiplier == 3
		if multiplier == 3:
			_combo_loss_3_sprite.frame = 0
	# The loss overlay replaces the regular gauge effects; closing it (0) brings
	# the sparks / glitch + fire straight back for the surviving multiplier.
	_apply_multiplier_fx_visibility()

func _start_combo_loss_beep() -> void:
	_stop_combo_loss_beep()
	# The COMBO streak is recoverable while the warning is open, so its persistent
	# TV component beeps at every multiplier. The authored x2 loss marker keeps its
	# existing pulse; x3 remains a steady diminished-fire sheet.
	var loss_sprite: Sprite2D = _combo_loss_2_sprite \
		if int(RunStateStore.pendingComboMultiplier) == 2 else null
	var combo_sprite := _combo_effect_sprite if RunStateStore.winBoostEnabled else null
	if loss_sprite == null and combo_sprite == null:
		return
	if loss_sprite != null:
		loss_sprite.modulate = Color.WHITE
	if combo_sprite != null:
		combo_sprite.modulate = Color.WHITE
	_combo_loss_beep_tween = create_tween().set_loops()
	_combo_loss_beep_tween.set_parallel(true)
	if loss_sprite != null:
		_combo_loss_beep_tween.tween_property(loss_sprite, "modulate:a", 0.18,
			COMBO_LOSS_BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if combo_sprite != null:
		_combo_loss_beep_tween.tween_property(combo_sprite, "modulate:a", 0.18,
			COMBO_LOSS_BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_combo_loss_beep_tween.set_parallel(false)
	_combo_loss_beep_tween.set_parallel(true)
	if loss_sprite != null:
		_combo_loss_beep_tween.tween_property(loss_sprite, "modulate:a", 1.0,
			COMBO_LOSS_BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if combo_sprite != null:
		_combo_loss_beep_tween.tween_property(combo_sprite, "modulate:a", 1.0,
			COMBO_LOSS_BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_combo_loss_beep_tween.set_parallel(false)
	_combo_loss_beep_tween.tween_interval(COMBO_LOSS_BEEP_PAUSE)

## Full-screen TV callouts take visual priority over persistent TV information.
## Multiple callouts can overlap (for example a power callout over a win callout),
## so each owner holds a source until its own presentation has finished.
func _begin_tv_info_pop(source: StringName) -> void:
	_capture_tv_restore_state()
	_tv_info_pop_sources[source] = true
	_hide_pacte_augment_popup()
	_refresh_pacte_augment_badge()
	_refresh_target_readout()
	_hide_tv_info_layers()

## Remembers whether the dealer strip was actually on screen before the TV was muted,
## so an ending that hid it wholesale (_set_tv_progress_bars_visible) does not get it
## back when the mute lifts. Only the FIRST owner captures: a later one would snapshot
## the already-hidden state and the strip would never return.
func _capture_tv_restore_state() -> void:
	if _tv_content_muted():
		return
	_tv_info_pop_restore_dealer_bar_visible = _dealer_bar_sprite != null \
		and _dealer_bar_sprite.visible
	_tv_info_pop_restore_dealer_icon_visible = _dealer_icon != null \
		and _dealer_icon.visible

func _end_tv_info_pop(source: StringName) -> void:
	if not _tv_info_pop_sources.has(source):
		return
	_tv_info_pop_sources.erase(source)
	if not _tv_info_pop_sources.is_empty():
		return
	_restore_tv_info_layers()
	_refresh_pacte_augment_badge()
	_refresh_target_readout()

## Anything that takes the TV over. Two kinds of owner: a full-screen callout held
## through _tv_info_pop_sources (PAIR/TRIPLE win, power, target blackout), and the
## blinking FREE SPIN banner, which owns the screen for as long as it is lit. While
## either is up, the boost/item icons and the COMBO stage step aside.
func _tv_content_muted() -> bool:
	return not _tv_info_pop_sources.is_empty() or _free_spin_overlay_active

## A full-screen callout — the only owner that clears the TV outright. The FREE SPIN
## banner is deliberately weaker: it keeps the dealer interface (bar, warning lights,
## icon) lit beside it, because how close the dealer is stays worth reading while the
## free spins are being spent. Everything else on the TV, the objective readout included,
## still steps aside for the banner (issue #181).
func _tv_callout_active() -> bool:
	return not _tv_info_pop_sources.is_empty()

## Re-applies the mute after the set of TV owners changes.
func _apply_tv_content_mute() -> void:
	if _tv_content_muted():
		_hide_tv_info_layers()
	else:
		_restore_tv_info_layers()

func _hide_tv_info_layers() -> void:
	# The FREE SPIN banner is an owner in its own right, so it hides only for a
	# callout — never for its own mute.
	if _free_spin_sprite != null and not _tv_info_pop_sources.is_empty():
		_free_spin_sprite.visible = false
	if _combo_effect_sprite != null:
		_combo_effect_sprite.visible = false
	_hide_boost_indicators()
	# The dealer interface only clears for a callout — under the banner alone it stays
	# readable alongside the objective.
	if not _tv_callout_active():
		return
	for node in [_dealer_bar_sprite, _dealer_bar_overlay_1, _dealer_bar_overlay_2,
			_dealer_bar_overlay_3, _dealer_icon]:
		var info := node as CanvasItem
		if info != null:
			info.visible = false

func _restore_tv_info_layers() -> void:
	_refresh_free_spin_banner()
	if _free_spin_sprite != null:
		_free_spin_sprite.visible = _free_spin_overlay_active \
			and _free_spin_blink_time < FREE_SPIN_OVERLAY_BLINK_PERIOD * 0.72
	# The callout is gone but the banner is lit: the boost icons and the COMBO stage
	# keep waiting it out, while the dealer interface comes back with the objective.
	if _free_spin_overlay_active:
		_hide_boost_indicators()
		if _combo_effect_sprite != null:
			_combo_effect_sprite.visible = false
	else:
		_refresh_boost_indicators()
	_refresh_dealer_countdown()
	if _dealer_bar_sprite != null:
		_dealer_bar_sprite.visible = _tv_info_pop_restore_dealer_bar_visible \
			or RunStateStore.comboDefeatPending
	if _dealer_icon != null:
		_dealer_icon.visible = _tv_info_pop_restore_dealer_icon_visible \
			or RunStateStore.comboDefeatPending
	if not _free_spin_overlay_active:
		_refresh_combo_effect()

## PAIR/TRIPLE TV callout: the matching win_animation frame beeps (alpha pulse,
## combo-loss cadence) CALLOUT_BEEP_COUNT times after the win is identified, then
## hides. The "+ score" payout line rides along as a child of the callout sprite.
func _play_win_animation(win_type: String, score: int, payout_text := "") -> void:
	if _win_anim_sprite == null or not WIN_ANIM_FRAME.has(win_type):
		return
	_stop_win_animation()
	_begin_tv_info_pop(&"win")
	_set_sheet_frame(_win_anim_sprite, int(WIN_ANIM_FRAME[win_type]))
	if _win_payout_label != null:
		_win_payout_label.text = payout_text if payout_text != "" else "+ %d" % score
	_win_anim_sprite.modulate.a = 1.0
	_win_anim_sprite.visible = true
	_win_anim_tween = create_tween().set_loops(CALLOUT_BEEP_COUNT)
	_win_anim_tween.tween_property(_win_anim_sprite, "modulate:a", 0.18,
		COMBO_LOSS_BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_win_anim_tween.tween_property(_win_anim_sprite, "modulate:a", 1.0,
		COMBO_LOSS_BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_win_anim_tween.tween_interval(COMBO_LOSS_BEEP_PAUSE)
	_win_anim_tween.finished.connect(_stop_win_animation)

func _stop_win_animation() -> void:
	if _win_anim_tween != null and _win_anim_tween.is_valid():
		_win_anim_tween.kill()
	_win_anim_tween = null
	if _win_anim_sprite != null:
		_win_anim_sprite.visible = false
		_win_anim_sprite.modulate.a = 1.0
	_end_tv_info_pop(&"win")

## COMBO is a persistent TV component, but a paying PAIR/TRIPLE result gives it
## a second beat: the authored stage shakes and its separate bonus flies out after
## the base payout callout. The component remains at the new stage afterward.
func _queue_combo_effect(combo_number: int, bonus: int, percent: int) -> float:
	if _combo_effect_sprite == null:
		return 0.0
	_stop_combo_effect()
	var frame := clampi(combo_number - 1, 0, maxi(0, _combo_effect_frame_count - 1))
	_combo_effect_delay_tween = create_tween()
	_combo_effect_delay_tween.tween_interval(COMBO_EFFECT_DELAY)
	_combo_effect_delay_tween.tween_callback(
		_show_combo_effect.bind(frame, bonus, percent))
	return COMBO_EFFECT_DELAY + COMBO_EFFECT_TIME

func _show_combo_effect(frame: int, bonus: int, percent: int) -> void:
	_combo_effect_delay_tween = null
	if _combo_effect_sprite == null or not RunStateStore.winBoostEnabled:
		return
	_stop_win_animation()
	_set_sheet_frame(_combo_effect_sprite,
		clampi(frame, 0, maxi(0, _combo_effect_frame_count - 1)))
	if _combo_payout_label != null:
		_combo_payout_label.text = "+ %d (%d%%)" % [maxi(0, bonus), clampi(percent, 0, 45)]
		_combo_payout_label.position = COMBO_PAYOUT_RECT.position
		_combo_payout_label.modulate.a = 1.0
		_combo_payout_label.visible = true
	_combo_effect_sprite.modulate.a = 1.0
	_combo_effect_sprite.visible = not _tv_content_muted()
	if _combo_score_pending >= 0:
		_set_display_lucidity(maxi(_display_lucidity, _combo_score_pending))
		_combo_score_pending = -1
	if _combo_effect_tween != null and _combo_effect_tween.is_valid():
		_combo_effect_tween.kill()
	_combo_effect_tween = create_tween()
	var origin := _combo_effect_sprite.position
	for offset in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(-1.0, 0.0),
			Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(1.0, 0.0)]:
		_combo_effect_tween.tween_property(_combo_effect_sprite, "position",
			origin + offset, 0.06)
	_combo_effect_tween.tween_property(_combo_effect_sprite, "position", origin, 0.06)
	_combo_effect_tween.tween_interval(maxf(0.0, COMBO_EFFECT_TIME - 0.42))
	_combo_effect_tween.finished.connect(_finish_combo_effect)
	if _combo_payout_tween != null and _combo_payout_tween.is_valid():
		_combo_payout_tween.kill()
	if _combo_payout_label != null:
		_combo_payout_tween = create_tween()
		_combo_payout_tween.tween_property(_combo_payout_label, "position:y",
			COMBO_PAYOUT_RECT.position.y - 8.0, 0.72)
		_combo_payout_tween.parallel().tween_property(_combo_payout_label, "modulate:a",
			0.0, 0.72).set_delay(0.18)

func _finish_combo_effect() -> void:
	_combo_effect_tween = null
	if _combo_effect_sprite != null:
		_combo_effect_sprite.position = Vector2.ZERO
		_combo_effect_sprite.modulate.a = 1.0
	if _combo_payout_label != null:
		_combo_payout_label.position = COMBO_PAYOUT_RECT.position
		_combo_payout_label.modulate.a = 1.0
		_combo_payout_label.visible = false
		_combo_payout_label.text = ""
	if _combo_score_pending >= 0:
		_set_display_lucidity(maxi(_display_lucidity, _combo_score_pending))
		_combo_score_pending = -1
	_refresh_combo_effect()

func _stop_combo_effect() -> void:
	if _combo_effect_delay_tween != null and _combo_effect_delay_tween.is_valid():
		_combo_effect_delay_tween.kill()
	_combo_effect_delay_tween = null
	if _combo_effect_tween != null and _combo_effect_tween.is_valid():
		_combo_effect_tween.kill()
		_combo_effect_tween = null
	if _combo_payout_tween != null and _combo_payout_tween.is_valid():
		_combo_payout_tween.kill()
		_combo_payout_tween = null
	if _combo_effect_sprite != null:
		_combo_effect_sprite.position = Vector2.ZERO
		_combo_effect_sprite.modulate.a = 1.0
	if _combo_payout_label != null:
		_combo_payout_label.position = COMBO_PAYOUT_RECT.position
		_combo_payout_label.modulate.a = 1.0
		_combo_payout_label.visible = false
		_combo_payout_label.text = ""
	if _combo_score_pending >= 0:
		_set_display_lucidity(maxi(_display_lucidity, _combo_score_pending))
		_combo_score_pending = -1
	if _combo_effect_sprite != null:
		_combo_effect_sprite.visible = RunStateStore.winBoostEnabled \
			and not _tv_content_muted()
		if _combo_effect_sprite.visible:
			_set_sheet_frame(_combo_effect_sprite,
				_combo_effect_frame(int(RunStateStore.winBoostCombo)))

## Power TV callout: the selected power's power_animation frame beeps a few times
## and then holds while its targeting stays armed (_clear_targeting hides it).
func _show_power_animation(id: String) -> void:
	if _power_anim_sprite == null:
		return
	_stop_power_animation()
	_begin_tv_info_pop(&"power")
	_set_sheet_frame(_power_anim_sprite, int(POWER_ANIM_FRAME.get(id, 0)))
	if not POWER_ANIM_FRAME.has(id):
		if _power_anim_label == null:
			_power_anim_label = Label.new()
			_power_anim_label.name = "PowerCalloutName"
			_power_anim_label.position = Vector2(35.0, 43.0)
			_power_anim_label.size = Vector2(90.0, 18.0)
			_power_anim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_power_anim_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_power_anim_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_power_anim_label.add_theme_font_size_override("font_size", 8)
			_power_anim_label.add_theme_color_override("font_color", NEON_CYAN)
			_power_anim_label.add_theme_color_override("font_outline_color", Color.BLACK)
			_power_anim_label.add_theme_constant_override("outline_size", 1)
			if _font != null:
				_power_anim_label.add_theme_font_override("font", _font)
			_power_anim_sprite.add_child(_power_anim_label)
		_power_anim_label.text = id.to_upper()
		_power_anim_label.visible = true
	elif _power_anim_label != null:
		_power_anim_label.visible = false
	_power_anim_sprite.modulate.a = 1.0
	_power_anim_sprite.visible = true
	_power_anim_tween = create_tween().set_loops(CALLOUT_BEEP_COUNT)
	_power_anim_tween.tween_property(_power_anim_sprite, "modulate:a", 0.18,
		COMBO_LOSS_BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_power_anim_tween.tween_property(_power_anim_sprite, "modulate:a", 1.0,
		COMBO_LOSS_BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_power_anim_tween.tween_interval(COMBO_LOSS_BEEP_PAUSE)

func _stop_power_animation() -> void:
	if _power_anim_tween != null and _power_anim_tween.is_valid():
		_power_anim_tween.kill()
	_power_anim_tween = null
	if _power_anim_sprite != null:
		_power_anim_sprite.visible = false
		_power_anim_sprite.modulate.a = 1.0
	if _power_anim_label != null:
		_power_anim_label.visible = false
	_end_tv_info_pop(&"power")

func _stop_combo_loss_beep() -> void:
	if _combo_loss_beep_tween != null and _combo_loss_beep_tween.is_valid():
		_combo_loss_beep_tween.kill()
	_combo_loss_beep_tween = null
	for sprite in [_combo_loss_2_sprite, _combo_loss_3_sprite]:
		if sprite != null:
			(sprite as Sprite2D).modulate = Color.WHITE
	if _combo_effect_sprite != null:
		_combo_effect_sprite.modulate = Color.WHITE

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
	_refresh_pacte_augment_badge()
	_refresh_controls()
	_refresh_consumable_fx()
	_maybe_present_card_unlocks()

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
	_set_all_reels_visible(true)
	for i in 3:
		# An armed Heart previews immediately: every strip symbol — centre and
		# adjacent — turns into a heart until the next spin resolves the tier.
		_set_reel_symbol(i, "heart" if RunStateStore.heartPowerArmed \
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

func _combo_effect_frame(stage: int) -> int:
	var zero_based := maxi(0, stage - 1) if stage > 0 else 0
	return clampi(zero_based, 0, maxi(0, _combo_effect_frame_count - 1))

## COMBO is part of the normal TV HUD while the augment is owned. Transient
## announcements own the TV priority stack and temporarily hide this sprite;
## the sprite itself is never destroyed, so its stage survives every popup.
func _refresh_combo_effect() -> void:
	if _combo_effect_sprite == null:
		return
	if not RunStateStore.winBoostEnabled:
		_stop_combo_effect()
		_combo_effect_sprite.visible = false
		return
	if _tv_content_muted():
		_combo_effect_sprite.visible = false
		return
	_set_sheet_frame(_combo_effect_sprite, _combo_effect_frame(int(RunStateStore.winBoostCombo)))
	_combo_effect_sprite.visible = true

func _refresh_tv_indicators() -> void:
	# The FREE SPIN banner lights the TV while the next spin is free (banked free
	# spins or an Energy Drink rush); the spins tube lives off-TV and stays put.
	# It resolves FIRST because it is itself a TV owner (_tv_content_muted): every
	# readout below reads the mute it just set, so the banner never shares the screen
	# with the objective, the dealer countdown or the item icons for a frame.
	_refresh_free_spin_banner()
	_refresh_target_readout()
	# The SPINS LEFT counter reflects the neuron cost the moment the lever is pulled,
	# so it always updates — it is NOT held with the reward deltas (issue #80).
	var spins_left := _display_spins_left()
	if _health_bar_sprite != null:
		# A HUD refresh re-derives the tube from state (an ending that wants it
		# hidden skips this refresh entirely, see _update_hud).
		_health_bar_sprite.visible = true
		_set_sheet_frame(_health_bar_sprite,
			clampi(spins_left, 0, HEALTH_BAR_FRAME_COUNT - 1))
	# The numeric readout under the tube follows the same budget (spends, gains,
	# protections all land here via _update_hud), capped at 18 spins.
	if _spins_left_label != null:
		_spins_left_label.visible = true
		_spins_left_label.text = str(spins_left)
		_spins_left_label.add_theme_color_override(
			"font_color",
			SPINS_LEFT_MAX_COLOR if spins_left >= MAX_RUN_SPINS else SPINS_LEFT_NORMAL_COLOR)
	# Issue #155: the dealer bar advances with the inverse multiplier step (not the
	# reward hold), so its progress changes the moment the lever is pulled.
	_refresh_dealer_countdown()
	# Active-boost duration icons update with the spin cost, not the reward hold, so the
	# count ticks down the moment the boost is spent on a spin (issue #76).
	_refresh_boost_indicators()
	# COMBO is a persistent TV component whenever the Pacte augment is active. Its
	# frame follows the recoverable streak, while higher-priority callouts hide it
	# through _begin_tv_info_pop/_restore_tv_info_layers.
	if not _hud_delta_hold:
		_refresh_combo_effect()
	# The wealth odometer is a score total. Hold it (with the multiplier badge and
	# jackpot lamp) until the score popup lands (issue #54).
	if _hud_delta_hold:
		return
	# COMBO has a second payout beat. Keep the base PAIR/TRIPLE total visible until
	# the persistent indicator's bonus lands, then release the final total.
	if _combo_score_pending >= 0:
		return
	if RunStateStore.scoreEarned < _display_lucidity:
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

func _set_display_lucidity(value: int, animated := true, duration_override := 0.0) -> void:
	# The legacy method name is kept because scene smoke hooks call it; its value is
	# now the cumulative score shown by the wealth odometer. `duration_override` lets a
	# payout pace its own roll (the jackpot); 0.0 keeps the delta-derived default.
	_display_lucidity = maxi(0, value)
	if _wealth_odometer != null:
		_wealth_odometer.set_value(_display_lucidity, animated, duration_override)
	# The objective bar reads the shown score, so it moves with the reels rather than
	# waiting for the next HUD refresh (some release paths update the digits alone).
	_refresh_target_readout()

func _refresh_jackpot_lamp(use_result := true) -> void:
	if _jackpot_sprite == null or _jackpot_flashing:
		return # don't fight an active flash
	if _hud_delta_hold:
		return # lamp state pops with the other aftereffects, after the score popup
	var lit := false
	if use_result and RunStateStore.lastResult != null:
		lit = bool(RunStateStore.lastResult.get("isJackpot", false))
	_set_sheet_frame(_jackpot_sprite, JACKPOT_FRAME_LIT if lit else JACKPOT_FRAME_OFF)

func _flash_jackpot_lamp() -> void:
	if _jackpot_sprite == null:
		return
	if _jackpot_flash_tween != null and _jackpot_flash_tween.is_valid():
		_jackpot_flash_tween.kill()
	_jackpot_flashing = true
	_jackpot_flash_tween = create_tween()
	_jackpot_flash_tween.tween_method(_drive_jackpot_flash, 0.0, 1.0, JACKPOT_FLASH_TIME)
	_jackpot_flash_tween.tween_callback(_end_jackpot_flash)

func _end_jackpot_flash() -> void:
	_jackpot_flashing = false
	_refresh_jackpot_lamp()

func _drive_jackpot_flash(t: float) -> void:
	if _jackpot_sprite == null:
		return
	_set_sheet_frame(
		_jackpot_sprite,
		JACKPOT_FRAME_LIT if (int(t * 12.0) % 2 == 0) else JACKPOT_FRAME_ALT)

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

func _build_burst_layer() -> void:
	_burst_layer = _authored_control("BurstLayer")
	if _burst_layer == null:
		_burst_layer = Control.new()
		_burst_layer.name = "BurstLayer"
		add_child(_burst_layer)
	_burst_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_burst_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst_layer.z_index = REWARD_FX_Z_INDEX

func _build_coin_layer() -> void:
	_coin_layer = _authored_control("CoinLayer")
	if _coin_layer == null:
		_coin_layer = Control.new()
		_coin_layer.name = "CoinLayer"
		add_child(_coin_layer)
	_coin_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_layer.z_index = REWARD_FX_Z_INDEX

# Sync the "already announced" markers to the current result so returning from the
# dealer/scores never replays an old burst, and a power then computes its true gain.
func _init_burst_tracking() -> void:
	if RunStateStore.lastResult != null:
		_burst_prev_spin = int(RunStateStore.spinCount)
		_burst_prev_score = int(RunStateStore.lastResult["scoreEarned"])
	else:
		_burst_prev_spin = -1
		_burst_prev_score = 0
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
	var is_new_spin := spin_count != _burst_prev_spin
	var score := int(lr["scoreEarned"])
	var gain := score if is_new_spin else score - _burst_prev_score
	_burst_prev_spin = spin_count
	_burst_prev_score = score

	var win_type := String(lr["winType"])
	var reels: Array = lr["reels"]
	var combo_applied := bool(lr.get("winBoostApplied", false)) \
		and win_type in ["pair", "triple", "jackpot"]
	var combo_bonus := maxi(0, int(lr.get("winBoostBonus", 0))) if combo_applied else 0
	var combo_number := clampi(int(lr.get("winBoostCombo", 1)), 1, COMBO_EFFECT_FRAMES)
	var combo_percent := clampi(int(lr.get("winBoostPercent", 0)), 0, 45)
	var combo_base_gain := maxi(0, gain - combo_bonus)
	if combo_applied and lr.has("winBoostBaseScore"):
		combo_base_gain = mini(combo_base_gain, maxi(0, int(lr["winBoostBaseScore"])))
	var color: Color = MULT_COLORS[clampi(int(RunStateStore.lastEffectiveBet), 1, 3)]
	_coin_prev_lucidity = int(RunStateStore.lucidityCoins)
	# A previous sequence can be interrupted by a power or a scene transition. Make
	# sure a held final odometer value is not mistaken for this result's base payout.
	if _combo_score_pending >= 0:
		_set_display_lucidity(maxi(_display_lucidity, _combo_score_pending))
		_combo_score_pending = -1
	# Score is the wealth bar's source of truth. The number reels begin their roll with
	# the score popup; no individual Lucidity coins leave the cash tray for this HUD.
	# A jackpot rolls them slowly on purpose (issue #181) — watching the money land is
	# the reward. The catch-up above keeps the default pace: it is a correction, not a
	# payout beat.
	var wealth_score := int(RunStateStore.scoreEarned)
	var roll_override := JACKPOT_ODOMETER_ROLL_TIME if gain > 0 and win_type == "jackpot" else 0.0
	if combo_bonus > 0 and _combo_effect_sprite != null:
		_set_display_lucidity(maxi(_display_lucidity, wealth_score - combo_bonus), true, roll_override)
	elif wealth_score > _display_lucidity:
		_set_display_lucidity(wealth_score, true, roll_override)

	# Cocktail miss: one "+rarity" mini-burst from each reel.
	if is_new_spin and win_type == "miss" and bool(lr.get("cocktailApplied", false)):
		for i in _visible_reel_count():
			_spawn_burst("", _cocktail_reel_bonus(String(reels[i]), float(lr["scoreMultiplier"])), COCKTAIL_COLOR, i)
		_nudge(0.8)
		return maxf(reward_time, BURST_TIME)

	# Heart is a guaranteed triple that pays run spins instead of score. Reuse the
	# authored TRIPLE callout/music and the vial-style reaction flash; the landed
	# tier supplies the little +1/+2/+3 spin gain.
	if is_new_spin and win_type == "heart":
		var heart_tier := clampi(int(lr.get("heartTier", lr.get("heartCount", 1))), 1, 3)
		_play_sfx(&"triple_win")
		_play_win_animation("triple", 0, "+ %d" % heart_tier)
		_play_spin_gain_fx(heart_tier, _reel_window_center(), 0.55, true)
		_spawn_reaction_flash(triple_vial_color, "+%d SPINS" % heart_tier)
		_nudge(1.0)
		return maxf(reward_time, BURST_TIME)

	# A rescore that doesn't increase the score must NOT pop (gain <= 0).
	if gain > 0 and win_type != "miss":
		# Jackpot is special (issue #22): a large GOLDEN number rising out of the
		# machine centre — never a reel-anchored pair/triple-style burst.
		if win_type == "jackpot":
			_play_sfx(&"jackpot_win")
			_spawn_jackpot_burst(combo_base_gain)
			var fountain_time := _spawn_jackpot_coin_fountain()
			_flash_jackpot_lamp()
			_nudge(2.2)
			var jackpot_combo_time: float = _queue_combo_effect(
				combo_number, combo_bonus, combo_percent) if combo_applied else 0.0
			if combo_bonus > 0 and jackpot_combo_time > 0.0:
				_combo_score_pending = wealth_score
			# The lock has to outlast the slow reel roll AND the coin spray, or the next
			# spin can be pulled while the money is still landing (issue #181).
			return maxf(reward_time, maxf(
				maxf(maxf(BURST_TIME * 1.25, JACKPOT_FLASH_TIME), jackpot_combo_time),
				maxf(JACKPOT_ODOMETER_ROLL_TIME + JACKPOT_ROLL_TAIL, fountain_time)))
		var label := "TRIPLE" if win_type == "triple" else ("PAIR" if win_type == "pair" \
			else ("HEART" if win_type == "heart" else "BONUS"))
		if win_type == "triple":
			_play_sfx(&"triple_win")
		elif win_type == "pair":
			_play_sfx(&"pair_win")
		_play_win_animation(win_type, combo_base_gain)
		# Issue #76: a flatline strike charged this win — call it out and tint it red so
		# the doubled score reads as the flatline payoff, not a normal pair/triple.
		if is_new_spin and bool(lr.get("flatlineBoostApplied", false)):
			label = "FLATLINE x%d" % EconomyConst.FLATLINE_WIN_BOOST_MULT
			color = flatline_result_color
		var reel := int(source_reel) if source_reel != null else _derive_source_reel(reels)
		if _active_hidden_reel_count() > 0:
			reel = mini(reel, _visible_reel_count() - 1)
		_spawn_burst(label, combo_base_gain, color, reel)
		_nudge(1.0)
		reward_time = maxf(reward_time, BURST_TIME)
		# Cocktail + pair: surface the unpaired reel's rarity gain from its own reel.
		if is_new_spin and bool(lr.get("cocktailApplied", false)) and win_type == "pair":
			var solo := _solo_reel(reels)
			if solo != -1 and solo < _visible_reel_count():
				_spawn_burst("", _cocktail_reel_bonus(String(reels[solo]), float(lr["scoreMultiplier"])), COCKTAIL_COLOR, solo)
		if combo_applied:
			var combo_time: float = _queue_combo_effect(combo_number, combo_bonus, combo_percent)
			if combo_bonus > 0 and combo_time > 0.0:
				_combo_score_pending = wealth_score
			reward_time = maxf(reward_time, combo_time)
	return reward_time

func _cocktail_reel_bonus(symbol_id: String, score_multiplier: float) -> int:
	var points := int(RunStateStore.COCKTAIL_RARITY_POINTS.get(symbol_id, 0))
	return floori(float(points) * score_multiplier + 0.5)

func _burst_text(text: String, size: int, color: Color, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.size = Vector2(width, float(size) + 2.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l

func _spawn_burst(label: String, amount: int, color: Color, reel: int) -> void:
	if _burst_layer == null:
		return
	var cx: float = REEL_CELL_CENTERS[reel]
	var box_w := 64.0 if label != "" else 28.0
	var top := REEL_WINDOW["top"] - 10.0
	var burst := Control.new()
	burst.position = Vector2(cx - box_w * 0.5, top)
	burst.size = Vector2(box_w, 16.0)
	burst.pivot_offset = Vector2(box_w * 0.5, 8.0)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst_layer.add_child(burst)
	var y := 0.0
	if label != "":
		var lab := _burst_text(label, 8, color, box_w)
		lab.position = Vector2(0, y)
		burst.add_child(lab)
		y += 8.0
	var amt := _burst_text("+%d" % amount, 7, color, box_w)
	amt.position = Vector2(0, y)
	burst.add_child(amt)
	var tw := create_tween()
	tw.tween_method(_drive_burst.bind(burst, top), 0.0, 1.0, BURST_TIME)
	tw.tween_callback(burst.queue_free)

# Jackpot burst (issue #22): a large, always-golden number centred on the machine
# (not anchored to a reel) that rises out of the cabinet. Display only.
func _spawn_jackpot_burst(amount: int) -> void:
	if _burst_layer == null:
		return
	var cx := SRC_W * 0.5
	var box_w := 140.0
	var top := REEL_WINDOW["top"] - 18.0
	var burst := Control.new()
	burst.position = Vector2(cx - box_w * 0.5, top)
	burst.size = Vector2(box_w, 30.0)
	burst.pivot_offset = Vector2(box_w * 0.5, 15.0)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst_layer.add_child(burst)
	var lab := _burst_text("JACKPOT", 13, JACKPOT_GOLD, box_w)
	lab.position = Vector2(0.0, 0.0)
	burst.add_child(lab)
	var amt := _burst_text("+%d" % amount, 20, JACKPOT_GOLD, box_w)
	amt.position = Vector2(0.0, 12.0)
	burst.add_child(amt)
	var tw := create_tween()
	tw.tween_method(_drive_burst.bind(burst, top), 0.0, 1.0, BURST_TIME * 1.25)
	tw.tween_callback(burst.queue_free)

func _drive_burst(t: float, burst: Control, base_y: float) -> void:
	if not is_instance_valid(burst):
		return
	burst.position.y = base_y - BURST_RISE * t
	var s: float
	if t < 0.18:
		s = lerpf(0.5, 1.1, t / 0.18)
	else:
		s = lerpf(1.1, 1.0, (t - 0.18) / 0.82)
	burst.scale = Vector2(s, s)
	var o: float
	if t < 0.12:
		o = t / 0.12
	elif t < 0.7:
		o = 1.0
	else:
		o = 1.0 - (t - 0.7) / 0.3
	burst.modulate.a = clampf(o, 0.0, 1.0)

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
	var coin := _make_power_coin(_cash_tray_pos())
	if coin == null:
		_advance_power_bar()
		return
	_power_batch_running = true
	_power_coins_in_flight += 1
	var target := _power_center(power_id)
	var tw := create_tween()
	tw.tween_method(_drive_power_coin.bind(coin, _cash_tray_pos(), target), 0.0, 1.0, POWER_COIN_FLIGHT_TIME)
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
	var pop := _make_power_coin_pop()
	var power_tex := _load_texture("ui/power_coin.png", true)
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
			_drive_power_coin_pop.bind(pop), 0.0, 1.0,
			float(POWER_COIN_POP_FRAMES) * POWER_COIN_POP_FRAME_TIME)
	tw.tween_callback(_on_power_coin_pop_finished.bind(pop, stepd))
	return true

func _on_power_coin_pop_finished(pop: Sprite2D, stepd: Dictionary) -> void:
	if is_instance_valid(pop):
		pop.queue_free()
	_start_power_bank_coin_flight(stepd, 0.0)

func _start_power_bank_coin_flight(stepd: Dictionary, delay: float) -> void:
	var coin := _make_power_coin(WEALTH_COIN_ORIGIN)
	if coin == null:
		_apply_power_bank_step(stepd)
		_on_power_coin_landed()
		return
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(
			_drive_power_coin.bind(coin, WEALTH_COIN_ORIGIN, POWER_BAR_CENTER),
			0.0, 1.0, POWER_COIN_FLIGHT_TIME)
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

func _make_power_coin_pop() -> Sprite2D:
	if _coin_layer == null:
		return null
	var tex := _load_texture(POWER_COIN_POP_SHEET, true)
	if tex == null:
		return null
	var pop := Sprite2D.new()
	pop.texture = tex
	pop.hframes = POWER_COIN_POP_FRAMES
	pop.vframes = 1
	pop.frame = 0
	pop.centered = false
	pop.position = Vector2.ZERO
	pop.texture_filter = MACHINE_ART_TEXTURE_FILTER
	pop.modulate.a = 0.0
	_coin_layer.add_child(pop)
	return pop

func _drive_power_coin_pop(t: float, pop: Sprite2D) -> void:
	if not is_instance_valid(pop):
		return
	var progress := clampf(t, 0.0, 1.0)
	pop.frame = mini(POWER_COIN_POP_FRAMES - 1,
		floori(progress * float(POWER_COIN_POP_FRAMES)))
	if progress < 0.1:
		pop.modulate.a = progress / 0.1
	elif progress < 0.82:
		pop.modulate.a = 1.0
	else:
		pop.modulate.a = 1.0 - ((progress - 0.82) / 0.18)

## Resolve the gauge without animation and clear pending restores (visual only). Used on
## the flatline/run-over transition — the gauge itself just holds its current frame.
func _snap_power_bar() -> void:
	_power_seen_lucidity = _power_point_total()
	_set_power_bar_frame(_bar_frame_for_score(_power_bar_score))
	for power_id in RunStateStore.pendingPowerRestores.duplicate():
		RunStateStore.commit_power_restore(String(power_id))

func _make_power_coin(pos: Vector2) -> Sprite2D:
	return _make_flying_coin(pos, POWER_COIN_ASSET)

## Shared builder for the coins that fly around the cabinet. `asset` picks which
## currency is in flight: the power chip that restores a power, or the lucidity coin
## the machine actually pays out.
func _make_flying_coin(pos: Vector2, asset: String) -> Sprite2D:
	if _coin_layer == null:
		return null
	var tex := _load_texture(asset, true)
	if tex == null:
		return null
	var coin := Sprite2D.new()
	coin.texture = tex
	coin.centered = true
	coin.position = pos
	var power_scale := POWER_COIN_SIZE / float(maxi(1, tex.get_width()))
	coin.scale = Vector2(power_scale, power_scale)
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	coin.modulate.a = 0.0
	_coin_layer.add_child(coin)
	return coin

## Casino-TV payout spray (issue #181): lucidity coins erupt out of the cash tray
## mouth and arc up through the cabinet while the wealth reels roll. Purely decorative
## — no coin corresponds to a Lucidity unit, it just pays in the machine's own
## currency rather than power chips. Returns how long the spray runs so the caller can
## keep the sequence locked until the money has finished landing.
func _spawn_jackpot_coin_fountain() -> float:
	# Back-to-back jackpots (a rescore, a power) must not stack two tweens.
	_clear_jackpot_coins()
	if _coin_layer == null:
		return 0.0
	var tray := _cash_tray_pos()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_jackpot_coin_tween = create_tween()
	_jackpot_coin_tween.set_parallel(true)
	for i in JACKPOT_COIN_COUNT:
		var origin := tray + Vector2(
			rng.randf_range(-JACKPOT_COIN_ORIGIN_JITTER, JACKPOT_COIN_ORIGIN_JITTER), 0.0)
		var coin := _make_flying_coin(origin, LUCIDITY_COIN_ASSET)
		if coin == null:
			break
		_jackpot_coins.append(coin)
		var rise := JACKPOT_COIN_RISE + rng.randf_range(
			-JACKPOT_COIN_RISE_JITTER, JACKPOT_COIN_RISE_JITTER)
		# Launch speed for the wanted apex; the coins fade while still rising, so the
		# spray reads as leaving the cabinet rather than raining back into the tray.
		var velocity := Vector2(
			rng.randf_range(-JACKPOT_COIN_SPREAD, JACKPOT_COIN_SPREAD),
			-sqrt(2.0 * JACKPOT_COIN_GRAVITY * maxf(8.0, rise)))
		var base_scale := POWER_COIN_SIZE / float(maxi(1, coin.texture.get_width()))
		var delay := float(i) * JACKPOT_COIN_STAGGER
		_jackpot_coin_tween.tween_method(
			_drive_jackpot_coin.bind(coin, origin, velocity, base_scale, rng.randf() * TAU),
			0.0, 1.0, JACKPOT_COIN_FLIGHT).set_delay(delay)
		_jackpot_coin_tween.tween_callback(_free_jackpot_coin.bind(coin)) \
			.set_delay(delay + JACKPOT_COIN_FLIGHT)
	return jackpot_coin_fountain_time()


func jackpot_coin_fountain_time() -> float:
	return float(JACKPOT_COIN_COUNT - 1) * JACKPOT_COIN_STAGGER + JACKPOT_COIN_FLIGHT


func _drive_jackpot_coin(t: float, coin: Sprite2D, origin: Vector2, velocity: Vector2,
		base_scale: float, spin_phase: float) -> void:
	if not is_instance_valid(coin):
		return
	var elapsed := t * JACKPOT_COIN_FLIGHT
	coin.position = origin + velocity * elapsed \
		+ Vector2(0.0, 0.5 * JACKPOT_COIN_GRAVITY * elapsed * elapsed)
	# Horizontal squash only: a flat pixel coin reads as tumbling without needing
	# authored spin frames.
	var squash := maxf(0.16, absf(cos(spin_phase + t * TAU * JACKPOT_COIN_SPIN)))
	coin.scale = Vector2(base_scale * squash, base_scale)
	if t < JACKPOT_COIN_FADE_IN:
		coin.modulate.a = t / JACKPOT_COIN_FADE_IN
	elif t > JACKPOT_COIN_FADE_START:
		coin.modulate.a = clampf(
			1.0 - (t - JACKPOT_COIN_FADE_START) / (1.0 - JACKPOT_COIN_FADE_START), 0.0, 1.0)
	else:
		coin.modulate.a = 1.0


func _free_jackpot_coin(coin: Node) -> void:
	if coin != null and is_instance_valid(coin):
		_jackpot_coins.erase(coin)
		coin.queue_free()


## The coin-layer sweep only hides its children, so the spray needs an explicit free or
## it leaks across an ending.
func _clear_jackpot_coins() -> void:
	if _jackpot_coin_tween != null and _jackpot_coin_tween.is_valid():
		_jackpot_coin_tween.kill()
	_jackpot_coin_tween = null
	for coin: Sprite2D in _jackpot_coins:
		if is_instance_valid(coin):
			coin.queue_free()
	_jackpot_coins.clear()


## Centre of the emplacement a power currently occupies. The live button rect is the
## source of truth: powers are re-slotted per loadout and each slot carries its own
## pixel nudge, so the authored hit box only stands in before the buttons exist.
func _power_center(power_id: String) -> Vector2:
	var button: Button = _power_buttons.get(power_id) as Button
	if button != null and is_instance_valid(button) and button.visible:
		return button.position + button.size * 0.5
	var hit: Dictionary = POWER_HITS.get(power_id, POWER_HITS["reroll"])
	return Vector2(float(hit["left"]) + float(hit["width"]) * 0.5, float(hit["top"]) + float(hit["height"]) * 0.5)

func _drive_power_coin(t: float, coin: Sprite2D, from_pos: Vector2, to_pos: Vector2) -> void:
	if not is_instance_valid(coin):
		return
	var lift := Vector2(from_pos.x, from_pos.y - 26.0)
	var p: Vector2
	if t < 0.35:
		p = from_pos.lerp(lift, t / 0.35)
	else:
		p = lift.lerp(to_pos, (t - 0.35) / 0.65)
	coin.position = p
	var base_scale := POWER_COIN_SIZE / float(maxi(1, coin.texture.get_width()))
	var s := lerpf(0.4, 1.15, minf(t / 0.18, 1.0)) if t < 0.18 else lerpf(1.15, 0.9, (t - 0.18) / 0.82)
	coin.scale = Vector2(base_scale * s, base_scale * s)
	if t < 0.12:
		coin.modulate.a = t / 0.12
	elif t < 0.9:
		coin.modulate.a = 1.0
	else:
		coin.modulate.a = 1.0 - ((t - 0.9) / 0.1)


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
	var loss_active := (_combo_loss_2_sprite != null and _combo_loss_2_sprite.visible) \
		or (_combo_loss_3_sprite != null and _combo_loss_3_sprite.visible)
	if _mult_fx_2 != null:
		_mult_fx_2.visible = _gauge_shown == 2 and not loss_active
	if _mult_fx_3 != null:
		_mult_fx_3.visible = _gauge_shown == 3 and not loss_active
	if _mult_fx_fire != null:
		_mult_fx_fire.visible = _gauge_shown == 3 and not loss_active

func _step_multiplier_fx(delta: float) -> void:
	var loss_3_active := _combo_loss_3_sprite != null and _combo_loss_3_sprite.visible
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
		_combo_loss_3_sprite.frame = (_combo_loss_3_sprite.frame + 1) % COMBO_LOSS_3_FRAMES

## Every lit warning beeps; how fast is what changes. A lone first light beeps on the slow
## period, and from the second light on it tightens to the fast one, so the machine audibly
## speeds up as the dealer closes in.
func _dealer_overlay_beep_period() -> float:
	return DEALER_BAR_OVERLAY_BEEP_PERIOD \
		if _dealer_warning_wanted >= DEALER_WARNING_FAST_BEEP_LIGHTS \
		else DEALER_BAR_OVERLAY_SLOW_BEEP_PERIOD

func _step_dealer_overlay_beep(delta: float) -> void:
	var active := false
	for overlay in [_dealer_bar_overlay_1, _dealer_bar_overlay_2,
			_dealer_bar_overlay_3]:
		if overlay != null and (overlay as Sprite2D).visible:
			active = true
			break
	if not active:
		_dealer_bar_overlay_beep_time = 0.0
		for overlay in [_dealer_bar_overlay_1, _dealer_bar_overlay_2,
				_dealer_bar_overlay_3]:
			if overlay != null:
				(overlay as Sprite2D).modulate.a = 1.0
		return
	_dealer_bar_overlay_beep_time = fmod(
		_dealer_bar_overlay_beep_time + delta, _dealer_overlay_beep_period())
	# One state change per beep, not a fade: the lights drop to the dim alpha for BEEP_TIME
	# and snap back for the rest of the period. Interpolating between the two read as a
	# second, breathing animation on top of the blink.
	var alpha := 1.0
	if _dealer_bar_overlay_beep_time < DEALER_BAR_OVERLAY_BEEP_TIME:
		alpha = DEALER_BAR_OVERLAY_BEEP_MIN_ALPHA
	for overlay in [_dealer_bar_overlay_1, _dealer_bar_overlay_2,
			_dealer_bar_overlay_3]:
		if overlay != null and (overlay as Sprite2D).visible:
			(overlay as Sprite2D).modulate.a = alpha

func _step_dealer_bar_progress(delta: float) -> void:
	if not _dealer_bar_frame_initialized or _dealer_bar_sprite == null \
			or _dealer_bar_display_frame == _dealer_bar_target_frame:
		_dealer_bar_progress_time = 0.0
		return
	_dealer_bar_progress_time += maxf(0.0, delta)
	if _dealer_bar_progress_time < DEALER_BAR_PROGRESS_FRAME_TIME:
		return
	_dealer_bar_progress_time -= DEALER_BAR_PROGRESS_FRAME_TIME
	var direction := 1 if _dealer_bar_target_frame > _dealer_bar_display_frame else -1
	_dealer_bar_display_frame += direction
	_set_dealer_bar_progress_frame(_dealer_bar_display_frame)
	if _dealer_bar_display_frame == _dealer_bar_target_frame:
		_dealer_bar_progress_time = 0.0

func _set_dealer_bar_progress_frame(progress_frame: int) -> void:
	var frame := clampi(progress_frame, 0, DEALER_BAR_FRAME_COUNT - 1)
	_set_sheet_frame(_dealer_bar_sprite, frame)
	_set_dealer_overlay_progress_frame(frame)

func _set_dealer_overlay_progress_frame(progress_frame: int) -> void:
	for overlay in [_dealer_bar_overlay_1, _dealer_bar_overlay_2,
			_dealer_bar_overlay_3]:
		if overlay != null:
			(overlay as Sprite2D).frame = clampi(progress_frame, 0, overlay.hframes - 1)

## FREE SPINS TV banner: blinks for as long as the NEXT spin is free (banked
## free spins or an Energy Drink no-decay rush) and holds until the lever is
## pulled — the spin's own state commit consumes the credit and clears it. It is
## a passive indicator: it never blocks input.
func _step_free_spin_blink(delta: float) -> void:
	if _free_spin_sprite == null or not _free_spin_overlay_active:
		return
	if not _tv_info_pop_sources.is_empty():
		_free_spin_sprite.visible = false
		return
	_free_spin_blink_time = fmod(
		_free_spin_blink_time + delta, FREE_SPIN_OVERLAY_BLINK_PERIOD)
	_free_spin_sprite.visible = _free_spin_blink_time < FREE_SPIN_OVERLAY_BLINK_PERIOD * 0.72

func _refresh_free_spin_banner() -> void:
	var active := RunStateStore.runPhase == "running" \
		and (int(RunStateStore.freeSpinsRemaining) > 0 \
			or int(RunStateStore.decaySkips) > 0 or RunStateStore.heartPowerArmed)
	# Never turn the banner ON while a spin is in flight or its reward is still
	# held — a grant made by the spin being revealed must not spoil the result.
	# Turning it OFF mid-spin is fine (pressing spin consumed the last credit).
	if active and not _free_spin_overlay_active \
			and (_spinning_anim or _spin_launch_pending or _hud_delta_hold):
		active = false
	if not _tv_info_pop_sources.is_empty():
		if _free_spin_sprite != null:
			_free_spin_sprite.visible = false
		return
	_set_free_spin_display(active)

func _set_free_spin_display(active: bool) -> void:
	if active == _free_spin_overlay_active:
		return
	if active:
		_capture_tv_restore_state()
	_free_spin_overlay_active = active
	_free_spin_blink_time = 0.0
	if _free_spin_sprite != null:
		_free_spin_sprite.visible = active
	# Lighting the banner takes the TV; letting it go out hands it back. Either way
	# every other readout has to re-evaluate its mute right here.
	_apply_tv_content_mute()

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
		_power_buttons[id] = b

func _build_stash() -> void:
	# Bottom-right corner, shared layout + scale so the stash matches the dealer, shop,
	# and in-run overlay stashes (issue #26). Bare TextureRects (tap to use) keep the
	# icons crisp and the same size as the drag stashes in the other scenes.
	_stash_icons.clear()
	for i in maxi(1, max_consumable_slots):
		var slot := _stash_slot_node(i)
		var icon := _stash_icon_for_slot(slot, i)
		var authored := slot != null
		if icon == null:
			icon = TextureRect.new()
			icon.name = "StashSlot%d" % i
			add_child(icon)
		if not authored:
			icon.position = Assets.stash_slot_pos(i, max_consumable_slots)
			icon.size = Vector2(Assets.STASH_ICON_SIZE, Assets.STASH_ICON_SIZE)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		elif icon.has_meta("_machine_generated_stash_icon"):
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		var cb := _on_stash_input.bind(icon, i)
		if not icon.gui_input.is_connected(cb):
			icon.gui_input.connect(cb)
		_stash_icons.append(icon)

func _stash_slot_node(index: int) -> Control:
	var one_based := index + 1
	for path in [
		"stash/StashSlot%d" % one_based,
		"CoinLayer/stash/StashSlot%d" % one_based,
		"StashSlot%d" % index,
		"StashSlot%d" % one_based,
	]:
		var slot := get_node_or_null(path) as Control
		if slot != null:
			return slot
	return null

func _stash_icon_for_slot(slot: Control, index: int) -> TextureRect:
	if slot == null:
		return null
	if slot is TextureRect:
		return slot as TextureRect
	var icon := slot.get_node_or_null("Icon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.set_meta("_machine_generated_stash_icon", true)
		icon.position = Vector2.ZERO
		icon.size = slot.size
		slot.add_child(icon)
	return icon

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
func _set_stash_visible(v: bool) -> void:
	for icon in _stash_icons:
		icon.visible = v

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
	for i in _stash_icons.size():
		var icon := _stash_icons[i]
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

func _icon_for(id: String) -> Texture2D:
	return _load_texture(ITEM_ICONS.get(id, "items/consumable_placeholder.png"))

func _boost_icon_for(boost: Dictionary) -> Texture2D:
	var counter := String(boost.get("counter", ""))
	if _boost_zero_linger.has(counter):
		var snapshot := _boost_zero_linger[counter] as Dictionary
		var linger_symbol_id := String(snapshot.get("symbolId", ""))
		if linger_symbol_id != "":
			var linger_symbol_tex := _load_texture("symbols/%s.png" % linger_symbol_id, true)
			if linger_symbol_tex != null:
				return linger_symbol_tex
	var symbol_field := String(boost.get("symbolField", ""))
	if symbol_field != "":
		var symbol_id := String(RunStateStore.get(symbol_field))
		if symbol_id != "":
			var symbol_tex := _load_texture("symbols/%s.png" % symbol_id, true)
			if symbol_tex != null:
				return symbol_tex
	return _icon_for(String(boost["id"]))

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
	if _targeting_layer != null:
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
	_show_power_animation(id)
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
## rolls back in. The whole sequence runs under the sequence lock so the lever is
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
	_stop_win_animation()
	_stop_combo_effect()
	_play_sfx(&"reel_spin")
	for i in 3:
		_reel_stop_sfx_played[i] = false
		_set_reel_visible(i, false)
		_set_reel_cover(i, false)
		_set_spin_reel_frame(i, _spin_frame)
		_set_spin_reel_visible(i, true)
	_refresh_controls()

func _step_rewind_restore(delta: float) -> void:
	_rewind_elapsed += delta
	_rewind_accum += delta
	if _rewind_accum >= SPIN_FRAME_TIME:
		_rewind_accum = 0.0
		# The blur runs backwards — the machine is unwinding the previous spin.
		_spin_frame = (_spin_frame - 1 + SPIN_FRAME_COUNT) % SPIN_FRAME_COUNT
		for i in 3:
			_set_spin_reel_frame(i, _spin_frame)
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
		_set_spin_reel_visible(i, false)
		_set_reel_cover(i, true)
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
	# Heart is a preparation action: the next lever pull renders and resolves the
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
	_cheat_reel = reel_index
	_clear_targeting()
	_targeting_power_id = "cheat"
	_show_power_animation("cheat")
	_set_cheat_selection_state(0)
	_cheat_symbol_pool.clear()
	for symbol in Symbols.BASE_SYMBOL_CYCLE:
		_cheat_symbol_pool.append(String(symbol))
	if Economy.compute_book_weight(RunStateStore.ownedUpgrades) > 0:
		_cheat_symbol_pool.append("book")
	# Start the mini-reel on the symbol currently in the hole.
	var current := ""
	if RunStateStore.lastResult != null:
		var reels: Array = RunStateStore.lastResult["reels"] as Array
		if reel_index >= 0 and reel_index < reels.size():
			current = String(reels[reel_index])
	_cheat_symbol_index = maxi(0, _cheat_symbol_pool.find(current))
	_targeting_layer = Control.new()
	_targeting_layer.name = "CheatReelOverlay"
	_targeting_layer.size = Vector2(SRC_W, SRC_H)
	_targeting_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_targeting_layer.z_index = 97
	_targeting_layer.gui_input.connect(_on_power_picker_input)
	add_child(_targeting_layer)
	var hole: Dictionary = REEL_HOLES[reel_index]
	var hole_rect := Rect2(float(hole["left"]), float(hole["top"]),
		float(hole["width"]), float(hole["height"]))
	_cheat_preview_sprite = Sprite2D.new()
	_cheat_preview_sprite.name = "CheatPreviewSymbol"
	_cheat_preview_sprite.centered = true
	_cheat_preview_sprite.position = hole_rect.get_center()
	_cheat_preview_sprite.z_index = 2
	_cheat_preview_sprite.texture_filter = MACHINE_ART_TEXTURE_FILTER
	_targeting_layer.add_child(_cheat_preview_sprite)
	_refresh_cheat_preview(false)
	var confirm := _make_hit_button({
		"left": hole_rect.position.x, "top": hole_rect.position.y,
		"width": hole_rect.size.x, "height": hole_rect.size.y,
	}, func() -> void: _on_cheat_symbol_pick(_cheat_symbol_pool[_cheat_symbol_index]))
	confirm.name = "CheatConfirmButton"
	_targeting_layer.add_child(confirm)
	_build_cheat_arrow(hole_rect, true)
	_build_cheat_arrow(hole_rect, false)

## Transparent up/down hit targets flank the mini-reel; the authored
## cheat_selection sheet supplies their visible arrows and selected-reel frame.
func _build_cheat_arrow(hole_rect: Rect2, up: bool) -> void:
	var cx := hole_rect.get_center().x
	var top := hole_rect.position.y - CHEAT_ARROW_UP_RISE if up \
		else hole_rect.end.y + CHEAT_ARROW_DOWN_DROP
	var b := _make_hit_button({
		"left": cx - CHEAT_ARROW_SIZE.x * 0.5 - CHEAT_ARROW_TOUCH_PAD.x,
		"top": top - CHEAT_ARROW_TOUCH_PAD.y,
		"width": CHEAT_ARROW_SIZE.x + CHEAT_ARROW_TOUCH_PAD.x * 2.0,
		"height": CHEAT_ARROW_SIZE.y + CHEAT_ARROW_TOUCH_PAD.y * 2.0,
	}, func() -> void: _cycle_cheat_symbol(-1 if up else 1))
	b.name = "CheatArrowUp" if up else "CheatArrowDown"
	var selection_state := 2 if up else 1
	b.button_down.connect(_set_cheat_selection_state.bind(selection_state))
	b.button_up.connect(_set_cheat_selection_state.bind(0))
	_targeting_layer.add_child(b)

func _set_cheat_selection_state(state: int) -> void:
	if _cheat_selection_sprite == null or _cheat_reel < 0:
		return
	var frame := clampi(_cheat_reel * 3 + state, 0, CHEAT_SELECTION_FRAMES - 1)
	_set_sheet_frame(_cheat_selection_sprite, frame)
	_cheat_selection_sprite.visible = true

## Steps match the strip: the up arrow rolls toward the symbol shown above the
## hole (cycle -1), the down arrow toward the one below (+1).
func _cycle_cheat_symbol(step: int) -> void:
	if _cheat_symbol_pool.is_empty():
		return
	_cheat_symbol_index = posmod(_cheat_symbol_index + step, _cheat_symbol_pool.size())
	_refresh_cheat_preview(true)

func _refresh_cheat_preview(pop: bool) -> void:
	if _cheat_preview_sprite == null or not is_instance_valid(_cheat_preview_sprite):
		return
	_apply_symbol(_cheat_preview_sprite, _cheat_symbol_pool[_cheat_symbol_index], STRIP_CENTER_H)
	if pop:
		var rest := _cheat_preview_sprite.scale
		_cheat_preview_sprite.scale = rest * 1.25
		var tw := create_tween()
		tw.tween_property(_cheat_preview_sprite, "scale", rest, 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
	_show_power_animation("swap")
	_targeting_layer = Control.new()
	_targeting_layer.name = "SwapSymbolDragLayer"
	_targeting_layer.size = Vector2(SRC_W, SRC_H)
	_targeting_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_targeting_layer.z_index = 97
	add_child(_targeting_layer)
	_swap_slot_hints.clear()
	for i in 3:
		_build_swap_slot_hint(i)
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
		_targeting_layer.add_child(button)
	# Issue #181: one cue per idea, and no words. The reel frames breathe (these are the
	# places that take part) and the reels shake (these are the things you can grab); the
	# instruction line the power used to carry is gone.
	_start_swap_slot_pulse()
	_start_swap_symbol_shake()

## While Swap is armed each REEL shakes as one piece: the reel's own art moves and its
## symbols ride along, stuck to it, rather than the symbols jiggling in a still reel. The
## reels run on staggered phases so they read as three loose reels rather than one juddering
## screen.
func _start_swap_symbol_shake() -> void:
	_stop_swap_symbol_shake()
	_swap_shake_nodes.clear()
	_swap_shake_base.clear()
	_swap_shake_reel.clear()
	# The shared backing draws the same three patches the covers do, so a cover moving over it
	# is invisible — nothing appears to shake but the symbols. Hand the reel art to the covers
	# for the duration: backing off, every cover on, and each cover free to move with its reel.
	if _reel_backing_sprite != null:
		_reel_backing_sprite.visible = false
	_swap_shake_cover_state.clear()
	for i in _reel_sprites.size():
		# The reel asset first — this is the thing that shakes.
		if i < _reel_covers.size():
			var cover := _reel_covers[i] as Sprite2D
			if cover != null:
				_swap_shake_cover_state.append(cover.visible)
				cover.visible = true
				_swap_shake_nodes.append(cover)
				_swap_shake_base.append(cover.position)
				_swap_shake_reel.append(i)
		for sprite in [_reel_top_sprites[i], _reel_sprites[i], _reel_bottom_sprites[i]]:
			var symbol_sprite := sprite as Sprite2D
			if symbol_sprite == null:
				continue
			_swap_shake_nodes.append(symbol_sprite)
			_swap_shake_base.append(symbol_sprite.position)
			_swap_shake_reel.append(i)
		if i < _swap_slot_hints.size():
			var frame := _swap_slot_hints[i] as Control
			if frame != null:
				_swap_shake_nodes.append(frame)
				_swap_shake_base.append(frame.position)
				_swap_shake_reel.append(i)
	# A slow 1px orbit rather than a jitter: the reels should look loose in the cabinet,
	# not broken (issue #181).
	_swap_shake_tween = create_tween().set_loops()
	for step in SWAP_SHAKE_OFFSETS.size():
		_swap_shake_tween.tween_callback(_set_swap_shake_step.bind(step))
		_swap_shake_tween.tween_interval(SWAP_SHAKE_STEP)

## `step` walks the orbit; each reel is offset along it by its own index, which is what
## staggers them.
func _set_swap_shake_step(step: int) -> void:
	var steps := SWAP_SHAKE_OFFSETS.size()
	for i in mini(_swap_shake_nodes.size(), _swap_shake_base.size()):
		var node := _swap_shake_nodes[i] as Node2D
		var offset: Vector2 = SWAP_SHAKE_OFFSETS[posmod(step + _swap_shake_reel[i], steps)]
		if node != null:
			node.position = _swap_shake_base[i] + offset
			continue
		var control := _swap_shake_nodes[i] as Control
		if control != null:
			control.position = _swap_shake_base[i] + offset

func _stop_swap_symbol_shake() -> void:
	if _swap_shake_tween != null and _swap_shake_tween.is_valid():
		_swap_shake_tween.kill()
	_swap_shake_tween = null
	# Give the reel art back to the shared backing and restore each cover's own state.
	if not _swap_shake_cover_state.is_empty():
		if _reel_backing_sprite != null:
			_reel_backing_sprite.visible = true
		for i in mini(_swap_shake_cover_state.size(), _reel_covers.size()):
			var cover := _reel_covers[i] as Sprite2D
			if cover != null:
				cover.visible = _swap_shake_cover_state[i]
		_swap_shake_cover_state.clear()
	if not _swap_shake_base.is_empty():
		for i in mini(_swap_shake_nodes.size(), _swap_shake_base.size()):
			var node := _swap_shake_nodes[i] as Node2D
			if node != null:
				node.position = _swap_shake_base[i]
				continue
			var control := _swap_shake_nodes[i] as Control
			if control != null:
				control.position = _swap_shake_base[i]
		_swap_shake_base.clear()
		_swap_shake_nodes.clear()
		_swap_shake_reel.clear()

## Marks one reel hole as a slot that takes part in the swap: a thin amber frame with
## corner ticks. Replaces the old brown wash and three hand-placed shard rectangles,
## which were programmer art and read as damage rather than as a target (issue #181).
## The node keeps its historical name — the scene smoke looks it up by it.
func _build_swap_slot_hint(reel_index: int) -> void:
	if _targeting_layer == null or reel_index < 0 or reel_index >= REEL_HOLES.size():
		return
	var column := _swap_reel_rect(reel_index)
	var frame := Panel.new()
	frame.name = "SwapRubbleHint%d" % reel_index
	frame.position = column.position
	frame.size = column.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = -1
	var style := StyleBoxFlat.new()
	style.bg_color = SWAP_SLOT_FRAME_FILL
	style.border_color = SWAP_SLOT_FRAME_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(1)
	frame.add_theme_stylebox_override("panel", style)
	_targeting_layer.add_child(frame)
	# Corner ticks: the pixel-art shorthand for "slot" at this size.
	for corner in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)]:
		var tick := ColorRect.new()
		tick.color = SWAP_SLOT_FRAME_BORDER
		tick.size = SWAP_SLOT_TICK_SIZE
		tick.position = Vector2(
			corner.x * (frame.size.x - SWAP_SLOT_TICK_SIZE.x),
			corner.y * (frame.size.y - SWAP_SLOT_TICK_SIZE.y))
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tick)
	_swap_slot_hints.append(frame)


## One shared breath across all three slot frames, replacing the old flash on the whole
## targeting layer so the drag ghost and buttons keep a steady opacity.
func _start_swap_slot_pulse() -> void:
	_stop_swap_slot_pulse()
	if _swap_slot_hints.is_empty():
		return
	_swap_slot_pulse_tween = create_tween().set_loops()
	for target_alpha in [SWAP_SLOT_PULSE_LOW, SWAP_SLOT_PULSE_HIGH]:
		_swap_slot_pulse_tween.set_parallel(true)
		for hint: Panel in _swap_slot_hints:
			_swap_slot_pulse_tween.tween_property(hint, "modulate:a", target_alpha,
				SWAP_SLOT_PULSE_TIME * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_swap_slot_pulse_tween.chain()


## Stops the breathing only. The hint list belongs to the targeting layer that owns the
## frames and is cleared with it — clearing it here made _start_swap_slot_pulse (which stops
## before it starts) find an empty list and return, so the frames never pulsed at all.
func _stop_swap_slot_pulse() -> void:
	if _swap_slot_pulse_tween != null and _swap_slot_pulse_tween.is_valid():
		_swap_slot_pulse_tween.kill()
	_swap_slot_pulse_tween = null


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
	if slot == 1 or _adjacent_symbols_hidden_active:
		return centre
	var neighbours := _reel_neighbours(centre)
	return String(neighbours["top"] if slot == 0 else neighbours["bottom"])

func _begin_swap_drag(reel_index: int, button: Button, global_position: Vector2) -> void:
	if _swap_drag_active or _targeting_layer == null:
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
	_apply_symbol(_swap_drag_ghost, source_symbol, STRIP_CENTER_H)
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
	_build_swap_invalid_target_feedback(reel_index)
	_swap_drag_ghost.visible = true
	_targeting_layer.add_child(_swap_drag_ghost)
	_swap_drag_button.modulate.a = 0.35

## Builds both destination cues for a Swap drag: a green frame that follows whichever
## legal reel the pointer is over, and a red cross on the source reel. Both start
## silent — the rejection cue is raised only when the player actually offends, rather
## than shouting at them for the whole drag the way it used to (issue #181).
func _build_swap_invalid_target_feedback(reel_index: int) -> void:
	if _targeting_layer == null or reel_index < 0 or reel_index >= REEL_HOLES.size():
		return
	if _swap_invalid_target_overlay != null and is_instance_valid(_swap_invalid_target_overlay):
		_swap_invalid_target_overlay.queue_free()
	if _swap_valid_target_overlay != null and is_instance_valid(_swap_valid_target_overlay):
		_swap_valid_target_overlay.queue_free()
	var overlay := _make_swap_target_panel("SwapInvalidTarget", reel_index,
		SWAP_INVALID_FILL, SWAP_INVALID_BORDER)
	# Two rotated 1px bars, not a font glyph: a DTM-Sans "X" crammed into a 17x26 panel
	# was the least legible thing on the machine.
	var span := minf(overlay.size.x, overlay.size.y) - 6.0
	for angle_deg in [SWAP_CROSS_ANGLE_DEG, -SWAP_CROSS_ANGLE_DEG]:
		var bar := ColorRect.new()
		bar.color = SWAP_CROSS_COLOR
		bar.size = Vector2(span, SWAP_CROSS_THICKNESS)
		bar.pivot_offset = bar.size * 0.5
		bar.position = overlay.size * 0.5 - bar.size * 0.5
		bar.rotation = deg_to_rad(angle_deg)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(bar)
	# Visible but fully transparent: _update_swap_target_feedback owns the alpha.
	overlay.modulate.a = 0.0
	_swap_invalid_target_overlay = overlay
	var valid := _make_swap_target_panel("SwapValidTarget", reel_index,
		SWAP_VALID_FILL, SWAP_VALID_BORDER)
	valid.visible = false
	_swap_valid_target_overlay = valid
	_swap_target_feedback_reel = reel_index

## The full reel a Swap cue covers: the hole's column, grown to take in the strip symbols
## above and below, because what the power moves is the reel and not the window.
func _swap_reel_rect(reel_index: int) -> Rect2:
	var hole: Dictionary = REEL_HOLES[reel_index]
	var centre_y: float = float(REEL_WINDOW["top"]) + float(REEL_WINDOW["height"]) * 0.5
	return Rect2(float(hole["left"]), centre_y - SWAP_REEL_HALF_HEIGHT,
		float(hole["width"]), SWAP_REEL_HALF_HEIGHT * 2.0)

func _make_swap_target_panel(node_name: String, reel_index: int, fill: Color,
		border: Color) -> Panel:
	var column := _swap_reel_rect(reel_index)
	var overlay := Panel.new()
	overlay.name = node_name
	overlay.position = column.position + Vector2(2.0, 2.0)
	overlay.size = column.size - Vector2(4.0, 4.0)
	overlay.z_index = 1
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(1)
	overlay.add_theme_stylebox_override("panel", style)
	_targeting_layer.add_child(overlay)
	return overlay

## Exactly one destination cue is live at a time: a green frame on a legal reel, a red
## cross on the source reel the symbol may not go back onto, and nothing at all while
## the pointer is off the reels.
func _update_swap_target_feedback(target_reel: int) -> void:
	_swap_target_feedback_reel = target_reel
	var invalid := target_reel == _swap_source
	if _swap_invalid_target_overlay != null and is_instance_valid(_swap_invalid_target_overlay):
		_swap_invalid_target_overlay.modulate.a = 1.0 if invalid else 0.0
	if _swap_valid_target_overlay == null or not is_instance_valid(_swap_valid_target_overlay):
		return
	var legal := target_reel >= 0 and target_reel < REEL_HOLES.size() and not invalid
	_swap_valid_target_overlay.visible = legal
	if legal:
		# Same rect the panel was built with (_make_swap_target_panel), so the green cue sits
		# on the reel exactly like the red one — following the hole alone left it hanging off
		# the bottom once the cues grew to cover the whole reel.
		_swap_valid_target_overlay.position = _swap_reel_rect(target_reel).position \
			+ Vector2(2.0, 2.0)

func _update_swap_drag(global_position: Vector2) -> void:
	if not _swap_drag_active or _swap_drag_button == null:
		return
	_swap_dragging = true
	_swap_drag_button.modulate.a = 0.35
	if _swap_drag_ghost != null:
		_swap_drag_ghost.visible = true
		_swap_drag_ghost.position = _targeting_local_position(global_position) - _swap_drag_offset
	_update_swap_target_feedback(_swap_target_at(global_position))

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
	if _swap_invalid_target_overlay != null and is_instance_valid(_swap_invalid_target_overlay):
		_swap_invalid_target_overlay.queue_free()
	_swap_invalid_target_overlay = null
	if _swap_valid_target_overlay != null and is_instance_valid(_swap_valid_target_overlay):
		_swap_valid_target_overlay.queue_free()
	_swap_valid_target_overlay = null
	_swap_target_feedback_reel = -1
	_swap_drag_press = Vector2.ZERO
	_swap_drag_offset = Vector2.ZERO
	_swap_source = -1
	_swap_source_slot = 1
	_swap_source_symbol = ""

func _swap_symbol_position(reel_index: int, slot: int) -> Vector2:
	if reel_index < 0 or reel_index >= _reel_sprites.size():
		return Vector2.ZERO
	if slot == 0:
		return _reel_top_sprites[reel_index].position
	if slot == 2:
		return _reel_bottom_sprites[reel_index].position
	return _reel_sprites[reel_index].position

func _targeting_local_position(global_position: Vector2) -> Vector2:
	if _targeting_layer == null:
		return to_local(global_position)
	return _targeting_layer.get_global_transform_with_canvas().affine_inverse() * global_position

func _swap_target_at(global_position: Vector2) -> int:
	var local_position := to_local(global_position)
	for i in REEL_HOLES.size():
		var hole: Dictionary = REEL_HOLES[i]
		var rect := Rect2(float(hole["left"]), float(hole["top"]),
			float(hole["width"]), float(hole["height"])).grow(4.0)
		if rect.has_point(local_position):
			return i
	return -1

func _on_swap_destination_pick(destination: int, source_override: int = -1,
		source_symbol_override: String = "") -> void:
	var source := _swap_source if source_override < 0 else source_override
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

# Builds a per-reel picker overlay; each reel button calls cb(reel_index).
func _arm_reel_picker(cb: Callable) -> void:
	_clear_targeting()
	_targeting_layer = Control.new()
	_targeting_layer.size = Vector2(SRC_W, SRC_H)
	_targeting_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE # only its buttons capture clicks
	_targeting_layer.z_index = 97
	add_child(_targeting_layer)
	var selection := _build_control_grid_sheet_on(_targeting_layer, "machine new view/reel_selection.png", REEL_SELECT_COLUMNS, REEL_SELECT_ROWS)
	var cy := REEL_WINDOW["top"]
	for i in 3:
		var reel := i
		var b := _make_hit_button({
			"left": REEL_CELL_CENTERS[reel] - 12.0,
			"top": cy - 8.0,
			"width": 24.0,
			"height": REEL_WINDOW["height"] + 16.0,
		}, func() -> void: cb.call(reel))
		if selection != null:
			b.button_down.connect(_set_sheet_frame.bind(selection, reel + 1))
		_targeting_layer.add_child(b)

func _arm_shift_targets() -> void:
	_clear_targeting()
	_targeting_layer = Control.new()
	_targeting_layer.size = Vector2(SRC_W, SRC_H)
	_targeting_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE # only its buttons capture clicks
	_targeting_layer.z_index = 97
	add_child(_targeting_layer)
	var arrows := _build_control_grid_sheet_on(_targeting_layer, "machine new view/shift_power.png", SHIFT_POWER_COLUMNS, SHIFT_POWER_ROWS)
	for i in 3:
		for dir_key in ["up", "down"]:
			var hit: Dictionary = SHIFT_ARROW_HITS[i][dir_key]
			var direction := 1 if dir_key == "up" else -1
			var b := _make_hit_button(hit, _apply_shift.bind(i, direction))
			if arrows != null:
				var frame := 1 + i * 2 + (1 if dir_key == "up" else 0)
				b.button_down.connect(_set_sheet_frame.bind(arrows, frame))
			_targeting_layer.add_child(b)

func _apply_reel_power(power_id: String, reel_index: int) -> void:
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
	_stop_win_animation() # the rerolled reveal supersedes the previous win callout
	_stop_combo_effect()
	_reroll_anim_active = true
	_reroll_reel_index = reel_index
	_reroll_elapsed = 0.0
	_reroll_accum = 0.0
	_spin_frame = 0
	_reel_stop_sfx_played[reel_index] = false
	_play_sfx(&"reel_spin")
	for i in 3:
		var active := i == reel_index
		_set_reel_visible(i, not active)
		_set_reel_cover(i, not active)
		_set_spin_reel_frame(i, _spin_frame)
		_set_spin_reel_visible(i, active)
	if _spin_button != null:
		_spin_button.disabled = true

func _step_reroll(delta: float) -> void:
	_reroll_elapsed += delta
	_reroll_accum += delta
	if _reroll_accum >= SPIN_FRAME_TIME:
		_reroll_accum = 0.0
		_spin_frame = (_spin_frame + 1) % SPIN_FRAME_COUNT
		_set_spin_reel_frame(_reroll_reel_index, _spin_frame)
	if _reroll_elapsed >= maxf(0.0, REROLL_REEL_DURATION - REEL_STOP_SFX_LEAD_TIME):
		_play_reel_stop_sfx(_reroll_reel_index)
	if _reroll_elapsed >= REROLL_REEL_DURATION:
		_stop_sfx(&"reel_spin")
		_play_reel_stop_sfx(_reroll_reel_index)
		_reroll_anim_active = false
		var lr: Variant = RunStateStore.lastResult
		if lr != null:
			_set_reel_symbol(_reroll_reel_index, String(lr["reels"][_reroll_reel_index]))
		_set_spin_reel_visible(_reroll_reel_index, false)
		_set_reel_visible(_reroll_reel_index, true)
		_set_reel_cover(_reroll_reel_index, true)
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
	_stop_swap_slot_pulse()
	_stop_swap_symbol_shake()
	_cancel_swap_drag_gesture()
	if _targeting_layer != null:
		_targeting_layer.queue_free()
		_targeting_layer = null
	_swap_slot_hints.clear() # the frames were children of the layer just freed
	_cheat_preview_sprite = null # freed with the targeting layer
	if _cheat_selection_sprite != null:
		_cheat_selection_sprite.visible = false
		_set_sheet_frame(_cheat_selection_sprite, 0)
	_targeting_power_id = ""
	_stop_power_animation()

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

func _show_score_table() -> void:
	if (_sequence_lock_active and not RunStateStore.comboDefeatPending) or _spin_launch_pending:
		return
	if _dealer_offer_popup != null:
		return
	if _score_overlay != null:
		_close_score_table()
		return
	_clear_targeting()
	_score_info_buttons.clear()
	_score_pct_buttons.clear()
	_score_overlay = Control.new()
	_score_overlay.size = Vector2(SRC_W, SRC_H)
	_score_overlay.z_index = 130 # above HUD extras, below the options overlay (140)
	add_child(_score_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.size = Vector2(SRC_W, SRC_H)
	_score_overlay.add_child(dim)

	# Authored full-canvas table art (issue #119): SYMBOL|LVL|PAIR|TRIPLE header,
	# row grid and symbol icons are baked in; only the live values are labels.
	var art := TextureRect.new()
	art.name = "TableArt"
	art.texture = _load_texture(SCORE_TABLE_ART, true)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = Vector2(SRC_W, SRC_H)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_overlay.add_child(art)
	_spawn_score_bulb_glows()

	var reward_amp_symbol := String(MetaStateStore.rewardAmpSymbol)
	var reward_amp_bonus := Economy.compute_symbol_reward_amp_bonus(RunStateStore.ownedUpgrades)
	for i in Symbols.BASE_SYMBOL_CYCLE.size():
		var symbol_id := String(Symbols.BASE_SYMBOL_CYCLE[i])
		var btn_y := float(SCORE_TABLE_INFO_ROW_Y[i])
		var row_cy := float(SCORE_TABLE_ROW_CY[i])

		# Permanent odds level: the same levels bought at the dealer's odds table;
		# dimmed when the symbol was never upgraded.
		var level := RunStateStore.odds_upgrade_level(symbol_id)
		var is_maxed := level >= int(RunStateStore.odds_max_level)
		var level_color := SCORE_TABLE_MAXED_COLOR if is_maxed else (
			SCORE_TABLE_LEVEL_COLOR if level > 0 else SCORE_TABLE_DIM_COLOR)
		_score_label_cell(str(level), SCORE_TABLE_LVL_CX, row_cy, 12, level_color)
		if is_maxed:
			_score_label_cell("(%s)" % _reward_bonus_text(
				float(RunStateStore.odds_max_level_reward_bonus)),
				SCORE_TABLE_LVL_CX, row_cy + 10.0, 4, SCORE_TABLE_MAXED_COLOR)

		var reward_bonus := float(RunStateStore.symbolRewardBonuses.get(symbol_id, 0.0))
		var pair := floori(float(int(Payouts.PAIR_SCORE.get(symbol_id, 0))) * (1.0 + reward_bonus) + 0.5)
		var triple_base := Payouts.JACKPOT_SCORE if symbol_id == "brain" else int(Payouts.TRIPLE_SCORE.get(symbol_id, 0))
		# Augmented heart modifier (issue #111): the table shows the halved jackpot.
		if symbol_id == "brain" and RunStateStore.augmented_modifier_active(1):
			triple_base = Payouts.JACKPOT_SCORE / 2
		var triple := floori(float(triple_base) * (1.0 + reward_bonus) + 0.5)
		var reward_amp_active := reward_amp_bonus > 0.0 and reward_amp_symbol == symbol_id
		var pair_color := SCORE_TABLE_REWARD_AMP_COLOR if reward_amp_active else SCORE_TABLE_GAIN_COLOR
		var triple_color := SCORE_TABLE_REWARD_AMP_COLOR if reward_amp_active else (
			SCORE_TABLE_BRAIN_COLOR if symbol_id == "brain" else SCORE_TABLE_GAIN_COLOR)
		_score_label_cell("+%d" % pair, SCORE_TABLE_PAIR_CX, row_cy, 12, pair_color)
		_score_label_cell("+%d" % triple, SCORE_TABLE_TRIPLE_CX, row_cy, 12, triple_color)
		if is_maxed:
			_score_label_right(_score_overlay, _reward_bonus_text(
				float(RunStateStore.odds_max_level_reward_bonus)),
				SCORE_TABLE_INFO_X - 2.0, btn_y, 4, SCORE_TABLE_MAXED_COLOR)

		# Hold-to-peek info button (issue #119): the triple's special effect only
		# shows while the button is held (button_down/button_up also fire from
		# ui_accept, so keyboard/controller holds work the same as pointer holds).
		_score_info_buttons.append(_build_score_info_button(symbol_id, btn_y))
		# Hold-to-peek draw chance on the "i" under the LVL value (issue #153),
		# sharing the triple info button's row baseline.
		_score_pct_buttons.append(_build_score_pct_button(symbol_id, btn_y))

	# BACK close button: a wide rounded rectangle centered in the bottom
	# red band with the text in its middle. The text lives on a child
	# Label: Button text inflates the minimum size well past the art-sized box
	# (font metrics), which would bleed over the art's baked grid.
	var close := Button.new()
	close.name = "CloseButton"
	close.size = Vector2(56.0, 14.0)
	# Vertically centered in the bottom red band (canvas y ~287..308 between the
	# last row's grid line and the marquee bulbs).
	close.position = Vector2(SRC_W * 0.5 - close.size.x * 0.5, 290.0)
	var close_label := _score_label(close, "BACK", Vector2.ZERO, 9,
		NEON_GOLD, close.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	close_label.size = close.size
	close_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The pixel font's line box leaves its slack above the glyph, so a pure
	# vertical center reads low in the 14px band — pull the label up to comp.
	close_label.position.y = -4.0
	close_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Assets.small_neon_button_style(close, NEON_GOLD, 6, 2.0)
	# Pressed squash: shrink around the centre while held, spring back on release
	# (same feel as the row info buttons).
	close.pivot_offset = close.size * 0.5
	close.button_down.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(close, "scale", Vector2(0.9, 0.9), 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	close.button_up.connect(func() -> void:
		if is_instance_valid(close):
			var tw := create_tween()
			tw.tween_property(close, "scale", Vector2.ONE, 0.1) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	close.pressed.connect(_close_score_table)
	_score_overlay.add_child(close)

	# Vertical focus chain (close -> rows -> close, wrapping) so keyboard and
	# controller navigation can reach every interactive element (issue #119).
	var chain: Array[Button] = [close]
	# Interleave per row: the LVL column's pct peek, then the row's info button.
	for i in _score_info_buttons.size():
		if i < _score_pct_buttons.size():
			chain.append(_score_pct_buttons[i])
		chain.append(_score_info_buttons[i])
	for c in chain.size():
		var node := chain[c]
		var up := chain[(c - 1 + chain.size()) % chain.size()]
		var down := chain[(c + 1) % chain.size()]
		node.focus_neighbor_top = node.get_path_to(up)
		node.focus_neighbor_bottom = node.get_path_to(down)
		node.focus_next = node.get_path_to(down)
		node.focus_previous = node.get_path_to(up)
	close.grab_focus()

## Warm additive glow behind every baked marquee bulb, chased in two alternating
## phases like a casino sign (issue #119 feedback). Drawn between the art and
## the value labels; the looping tween is killed on close.
func _spawn_score_bulb_glows() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.92, 0.45, 0.85))
	grad.set_color(1, Color(1.0, 0.82, 0.25, 0.0))
	var glow_tex := GradientTexture2D.new()
	glow_tex.gradient = grad
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(0.5, 0.0)
	glow_tex.width = 32
	glow_tex.height = 32
	var add_material := CanvasItemMaterial.new()
	add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var phases: Array[Control] = []
	for p in 2:
		var layer := Control.new()
		layer.name = "BulbGlowPhase%d" % p
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_score_overlay.add_child(layer)
		phases.append(layer)
	for i in SCORE_TABLE_BULBS.size():
		var glow := TextureRect.new()
		glow.texture = glow_tex
		glow.material = add_material
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.size = Vector2.ONE * SCORE_TABLE_BULB_GLOW_SIZE
		glow.position = SCORE_TABLE_BULBS[i] - glow.size * 0.5
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		phases[i % 2].add_child(glow)

	phases[0].modulate.a = 1.0
	phases[1].modulate.a = 0.25
	_score_bulb_tween = create_tween().set_loops()
	_score_bulb_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_score_bulb_tween.set_parallel(true)
	_score_bulb_tween.tween_property(phases[0], "modulate:a", 0.25, 0.55)
	_score_bulb_tween.tween_property(phases[1], "modulate:a", 1.0, 0.55)
	_score_bulb_tween.chain().tween_property(phases[0], "modulate:a", 1.0, 0.55)
	_score_bulb_tween.parallel().tween_property(phases[1], "modulate:a", 0.25, 0.55)

## The cropped "i" button from the information sheet (issue #119): the authored
## icon with a slightly larger invisible hit/focus box around it. Shared by the
## effect-info peek (row right edge) and the draw-chance peek (LVL column, #153).
func _make_score_i_button(node_name: String, icon_top_left: Vector2) -> Button:
	var b := Button.new()
	b.name = node_name
	b.position = icon_top_left - Vector2(3.0, 3.0)
	b.size = Vector2(SCORE_TABLE_INFO_W + 6.0, SCORE_TABLE_INFO_H + 6.0)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(0.0, 0.9, 1.0)
	focus.set_border_width_all(1)
	b.add_theme_stylebox_override("focus", focus)

	var atlas := AtlasTexture.new()
	atlas.atlas = _load_texture(SCORE_TABLE_INFO_ART, true)
	atlas.region = SCORE_TABLE_INFO_SRC
	var icon := TextureRect.new()
	icon.name = "InfoIcon"
	icon.texture = atlas
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.position = Vector2(3.0, 3.0)
	icon.size = Vector2(SCORE_TABLE_INFO_W, SCORE_TABLE_INFO_H)
	icon.pivot_offset = icon.size * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	_score_overlay.add_child(b)
	return b

func _build_score_info_button(symbol_id: String, art_y: float) -> Button:
	var b := _make_score_i_button("InfoButton_%s" % symbol_id,
		Vector2(SCORE_TABLE_INFO_X, art_y))
	var icon := b.get_node("InfoIcon") as TextureRect
	b.button_down.connect(_on_score_info_down.bind(symbol_id, b, icon))
	b.button_up.connect(_on_score_info_up.bind(icon))
	return b

## "i" under a row's LVL value (issue #153): while held, a bubble shows the
## symbol's live draw chance — the peek that used to sit on the baked symbol
## box, now matching the dealer odds table's under-the-meter info buttons.
## Sits on the same y as the row's triple-effect "i" so the pair reads aligned.
func _build_score_pct_button(symbol_id: String, art_y: float) -> Button:
	var b := _make_score_i_button("PctButton_%s" % symbol_id,
		Vector2(SCORE_TABLE_LVL_CX - SCORE_TABLE_INFO_W * 0.5, art_y))
	var icon := b.get_node("InfoIcon") as TextureRect
	b.button_down.connect(_on_score_pct_down.bind(symbol_id, b, icon))
	b.button_up.connect(_on_score_info_up.bind(icon))
	return b

func _on_score_pct_down(symbol_id: String, button: Button, icon: TextureRect) -> void:
	icon.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.tween_property(icon, "scale", Vector2(0.82, 0.82), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_show_score_pct_popup(symbol_id, button)

## Draw-chance bubble for a score-table symbol row: percent text and contour in
## the symbol's row color, anchored right of the held "i" button.
func _show_score_pct_popup(symbol_id: String, button: Button) -> void:
	_hide_score_info_popup()
	if _score_overlay == null:
		return
	_score_info_popup = Control.new()
	_score_info_popup.name = "PctPopup"
	_score_info_popup.z_index = 5
	_score_info_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color_v: Variant = SCORE_TABLE_PCT_COLORS.get(symbol_id, Color(0.0, 0.9, 1.0))
	var color: Color = color_v if color_v is Color else Color(0.0, 0.9, 1.0)
	var text := "%.1f%%" % _symbol_draw_percent(symbol_id)
	var font: Font = _font if _font != null else ThemeDB.fallback_font
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
	var popup_size := Vector2(maxf(text_width + 8.0, 24.0), 14.0)
	var bg_style := StyleBoxFlat.new()
	# Deep black body for flatline (same as the odds table's bubble) so the
	# dark-red contour and text stay legible.
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.97) if symbol_id == "flatline" \
		else Color(0.045, 0.035, 0.075, 0.97)
	bg_style.border_color = color
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.size = popup_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_info_popup.add_child(bg)
	var label := Label.new()
	label.text = text
	label.size = popup_size
	label.custom_minimum_size = Vector2.ZERO
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 5)
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	bg.add_child(label)
	label.set_deferred("size", popup_size)
	# Right of the symbol box, vertically centered on the row.
	var pos := button.position + Vector2(button.size.x + 3.0,
		button.size.y * 0.5 - popup_size.y * 0.5)
	pos.x = clampf(pos.x, 2.0, SRC_W - popup_size.x - 2.0)
	pos.y = clampf(pos.y, 2.0, SRC_H - popup_size.y - 2.0)
	_score_info_popup.position = pos.round() # off-grid blurs the pixel font
	_score_overlay.add_child(_score_info_popup)

## A symbol's current draw chance (percent) with all persisted levels applied —
## mirrors OddsTableOverlay._symbol_percent / Evaluate._build_weights.
func _symbol_draw_percent(symbol_id: String) -> float:
	var total := 0.0
	var weight := 0.0
	for sym in Symbols.BASE_SYMBOL_CYCLE:
		var s := String(sym)
		# Symbol Level augments bought from the in-run dealer are live weights, so
		# the score table has to quote the level the reels roll on, not just the
		# permanent one (see RunStateStore.effective_symbol_level).
		var w := float(int(Symbols.WEIGHT[s])
			+ RunStateStore.effective_symbol_level(s)
				* RunStateStore.probability_increase_per_upgrade)
		total += w
		if s == symbol_id:
			weight = w
	return (weight / total) * 100.0 if total > 0.0 else 0.0

## Pressed state (issue #119): squash the "i" icon and pop up the triple-effect
## blurb next to the row for as long as the button is held.
func _on_score_info_down(symbol_id: String, button: Button, icon: TextureRect) -> void:
	icon.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.tween_property(icon, "scale", Vector2(0.82, 0.82), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_show_score_info_popup(symbol_id, button)

func _on_score_info_up(icon: TextureRect) -> void:
	if is_instance_valid(icon):
		var tw := create_tween()
		tw.tween_property(icon, "scale", Vector2.ONE, 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hide_score_info_popup()

func _show_score_info_popup(symbol_id: String, button: Button) -> void:
	_hide_score_info_popup()
	if _score_overlay == null:
		return
	_score_info_popup = Control.new()
	_score_info_popup.name = "InfoPopup"
	_score_info_popup.z_index = 5
	_score_info_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Size from the actual font: Label.get_minimum_size() before the popup is in
	# the tree measures with the fallback theme font and comes out huge.
	var text := _triple_effect_text(symbol_id)
	var font: Font = _font if _font != null else ThemeDB.fallback_font
	var text_size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 5)
	# Center each line inside the bubble as its own label, positioned from the
	# font's measured line width: a single aligned Label can't do it because its
	# minimum size clamps to the theme font's metrics, not the small pixel font.
	var lines := text.split("\n")
	for li in lines.size():
		var line_w := font.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
		# Snap to whole pixels: a fractional offset knocks the pixel font off the
		# grid and blurs the glyphs.
		var line_x := roundf(4.0 + (text_size.x - line_w) * 0.5)
		var line_y := 3.0 + float(li) * 10.0
		for seg in _info_line_segments(symbol_id, lines[li]):
			_score_label(_score_info_popup, seg[0], Vector2(line_x, line_y), 5, seg[1])
			line_x = roundf(line_x + font.get_string_size(seg[0],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x)
	# Rounded box: dark panel with a thin gold outline and soft corners.
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.045, 0.035, 0.075, 0.97)
	bg_style.border_color = Color(1.0, 0.82, 0.28)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", bg_style)
	# Height by line count: the Label's rendered line height exceeds the font's
	# measured extent, so metric-based heights clip multi-line blurbs.
	var line_count := text.split("\n").size()
	bg.size = Vector2(text_size.x + 8.0, float(line_count) * 10.0 + 4.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_info_popup.add_child(bg)
	_score_info_popup.move_child(bg, 0)
	# Anchored left of the held button, clamped onto the canvas.
	var pos := button.position + Vector2(-bg.size.x - 2.0, button.size.y * 0.5 - bg.size.y * 0.5)
	pos.x = clampf(pos.x, 2.0, SRC_W - bg.size.x - 2.0)
	pos.y = clampf(pos.y, 2.0, SRC_H - bg.size.y - 2.0)
	_score_info_popup.position = pos.round() # off-grid blurs the pixel font
	_score_overlay.add_child(_score_info_popup)

func _hide_score_info_popup() -> void:
	if _score_info_popup != null:
		_score_info_popup.queue_free()
		_score_info_popup = null

# Labels sized by their text and placed from the right edge / centre — the only
# reliable way to align DTM-Sans columns (min size = text width, no shrinking).
func _score_label_right(parent: Control, text: String, right_x: float, y: float,
		font_size: int, color: Color) -> Label:
	var l := _score_label(parent, text, Vector2.ZERO, font_size, color)
	l.position = Vector2(right_x - l.get_minimum_size().x, y)
	return l

# A table value centered on its cell's midpoint (both axes), so numbers sit in
# the middle of the art's baked boxes (issue #119 feedback).
func _score_label_cell(text: String, center_x: float, center_y: float,
		font_size: int, color: Color) -> Label:
	var l := _score_label(_score_overlay, text, Vector2.ZERO, font_size, color)
	var min_size := l.get_minimum_size()
	l.position = Vector2(center_x - min_size.x * 0.5, center_y - min_size.y * 0.5)
	return l

func _score_label_centered(parent: Control, text: String, center_x: float, y: float,
		font_size: int, color: Color) -> Label:
	var l := _score_label(parent, text, Vector2.ZERO, font_size, color)
	l.position = Vector2(center_x - l.get_minimum_size().x * 0.5, y)
	return l

func _reward_bonus_text(bonus: float) -> String:
	return "+%d%%" % int(round(bonus * 100.0))

## Short 3x-bonus blurb per symbol, shown under the TRIPLE value (issue #51).
## Dynamic counts pull from the reaction exports so the copy never drifts.
func _triple_effect_text(symbol_id: String) -> String:
	match symbol_id:
		"brain":
			# Augmented heart modifier (issue #111): no free spin, jackpot halved.
			if RunStateStore.augmented_modifier_active(1):
				return "JACKPOT %d, NO SPIN" % (Payouts.JACKPOT_SCORE / 2)
			return "JACKPOT +%d SPIN" % triple_brain_free_spins
		"eye":
			return "REVEALS A REEL"
		"pill":
			return "ALL POWERS BACK"
		"syringe":
			return "LAST ITEM BACK"
		"vial":
			return "+%d SPINS" % triple_vial_free_spins
		"flatline":
			return "CLOSE CALL %d/%d,\n2X REWARDS NEXT SPIN" % [
				RunStateStore.flatlineResultCount, fatal_flatline_count]
	return ""

## Splits an info-blurb line into [text, color] segments. The flatline strike
## count heats up as it nears the fatal third strike: 0 white, 1 orange, 2 red.
func _info_line_segments(symbol_id: String, line: String) -> Array:
	var base := Color(0.9, 0.94, 1.0)
	if symbol_id == "flatline":
		var count_text := "%d/%d" % [RunStateStore.flatlineResultCount, fatal_flatline_count]
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

func _close_score_table() -> void:
	_hide_score_info_popup()
	_score_info_buttons.clear()
	_score_pct_buttons.clear()
	if _score_bulb_tween != null:
		_score_bulb_tween.kill()
		_score_bulb_tween = null
	if _score_overlay != null:
		_score_overlay.queue_free()
		_score_overlay = null

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
			_burst_prev_score = int((RunStateStore.lastResult as Dictionary).get("scoreEarned", 0))
		else:
			_burst_prev_score = int(RunStateStore.scoreEarned)
	# Energy Drink taken during an x3 defeat clears it in the store — drop the
	# beeping loss overlay and let the normal post-spin tail resume.
	if defeat_was_pending and not RunStateStore.comboDefeatPending:
		_close_pending_combo_defeat()
		_finish_post_spin_sequence()
	_refresh_reels_from_state()
	_update_hud()
	# Water adds score directly (no score popup carries it), so the odometer
	# rolls up right here instead of waiting for a reward sequence.
	if int(RunStateStore.scoreEarned) > _display_lucidity:
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
	# arms its downside so the activation hook can pop it later.
	if id in HOOKED_DEFERRED_NEGATIVES:
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
	var hint: Dictionary = use_hints.get(id, {})
	if hint.is_empty():
		return null
	if _hint_layer == null or not is_instance_valid(_hint_layer):
		_build_hint_layer()
	if _hint_layer == null:
		return null
	var hint_label := HintLabel.new()
	hint_label.grow_time = hint_grow_time
	hint_label.set_font(_font)
	_hint_layer.add_child(hint_label)
	var pos := "" if negative_only else String(hint["pos"])
	var neg := "" if positive_only else String(hint["neg"])
	hint_label.play(pos, neg, _item_display_name(id), HintLabel.item_is_corrupted(id))
	return hint_label

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

const SERUM_PICKER_RECT := Rect2(12.0, 132.0, 136.0, 58.0)

func _begin_serum() -> void:
	if _serum_picker != null \
			or (_sequence_lock_active and not RunStateStore.comboDefeatPending):
		return
	if not RunStateStore._can_use_consumable():
		return
	_build_serum_picker()

func _build_serum_picker() -> void:
	_serum_picker = Control.new()
	_serum_picker.name = "SerumPicker"
	_serum_picker.size = Vector2(SRC_W, SRC_H)
	_serum_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_serum_picker.z_index = 95
	_serum_picker.gui_input.connect(_on_serum_picker_input)
	add_child(_serum_picker)

	var pool: Array[String] = []
	for s in Symbols.BASE_SYMBOL_CYCLE:
		if String(s) != "brain":
			pool.append(String(s))
	Assets.build_symbol_picker_panel(_serum_picker, pool, "PICK A SYMBOL", SERUM_PICKER_RECT,
		Callable(self, "_on_serum_pick"), Callable(self, "_close_serum_picker"), true)

func _on_serum_picker_input(event: InputEvent) -> void:
	# Any tap that no symbol button consumed cancels the pick (charge kept).
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close_serum_picker()

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
	if _serum_picker != null and is_instance_valid(_serum_picker):
		_serum_picker.queue_free()
	_serum_picker = null

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
const FX_COVER_PAD_TOP := 1.0
const FX_COVER_PAD_BOTTOM := 3.0

func _fx_cover_rect(hole: Dictionary) -> Rect2:
	return Rect2(
		float(hole["left"]),
		float(hole["top"]) - FX_COVER_PAD_TOP,
		float(hole["width"]),
		float(hole["height"]) + FX_COVER_PAD_TOP + FX_COVER_PAD_BOTTOM
	)

func _build_fx_layer() -> void:
	_fx_layer = _authored_control("ConsumableFxLayer")
	if _fx_layer == null:
		_fx_layer = Control.new()
		_fx_layer.name = "ConsumableFxLayer"
		add_child(_fx_layer)
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_tobacco_fx()
	_build_energy_edges()
	_build_hidden_covers()
	_build_blur_covers()

## Serum frost (issue #53): translucent per-reel covers — symbols show through but
## read harder. Reuses the hidden-cover geometry.
func _build_blur_covers() -> void:
	_blur_covers.clear()
	for i in 3:
		var cover := ColorRect.new()
		cover.name = "BlurCover%d" % i
		cover.color = blur_cover_color
		var rect := _fx_cover_rect(REEL_HOLES[i])
		cover.position = rect.position
		cover.size = rect.size
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.visible = false
		_fx_layer.add_child(cover)
		_blur_covers.append(cover)

func _build_tobacco_fx() -> void:
	_tobacco_covers.clear()
	_tobacco_smoke.clear()
	for i in 3:
		var hole: Dictionary = REEL_HOLES[i]
		var cover := ColorRect.new()
		cover.name = "TobaccoCover%d" % i
		cover.color = tobacco_cover_color
		var rect := _fx_cover_rect(hole)
		cover.position = rect.position
		cover.size = rect.size
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.visible = false
		_fx_layer.add_child(cover)
		_tobacco_covers.append(cover)
		var smoke := CPUParticles2D.new()
		smoke.name = "TobaccoSmoke%d" % i
		smoke.amount = 14
		smoke.lifetime = 1.8
		smoke.preprocess = 1.2 # already smoking when it first appears
		smoke.position = Vector2(
			float(hole["left"]) + float(hole["width"]) * 0.5,
			float(hole["top"]) + float(hole["height"]) * 0.75
		)
		smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		smoke.emission_rect_extents = Vector2(float(hole["width"]) * 0.3, 2.0)
		smoke.direction = Vector2(0, -1)
		smoke.spread = 18.0
		smoke.gravity = Vector2(0, -10)
		smoke.initial_velocity_min = 2.0
		smoke.initial_velocity_max = 6.0
		smoke.scale_amount_min = 1.0
		smoke.scale_amount_max = 2.6
		smoke.color = tobacco_smoke_color
		smoke.emitting = false
		smoke.visible = false
		_fx_layer.add_child(smoke)
		_tobacco_smoke.append(smoke)

func _build_energy_edges() -> void:
	_energy_edges = Control.new()
	_energy_edges.name = "EnergyEdges"
	_energy_edges.set_anchors_preset(Control.PRESET_FULL_RECT)
	_energy_edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy_edges.visible = false
	var t := energy_edge_thickness
	var rects := [
		Rect2(0.0, 0.0, SRC_W, t),           # top
		Rect2(0.0, SRC_H - t, SRC_W, t),     # bottom
		Rect2(0.0, t, t, SRC_H - 2.0 * t),   # left
		Rect2(SRC_W - t, t, t, SRC_H - 2.0 * t), # right
	]
	for r in rects:
		var edge := ColorRect.new()
		edge.color = energy_edge_color
		edge.position = r.position
		edge.size = r.size
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_energy_edges.add_child(edge)
	_fx_layer.add_child(_energy_edges)

func _build_hidden_covers() -> void:
	_hidden_covers.clear()
	for i in 3:
		var hole: Dictionary = REEL_HOLES[i]
		var cover := ColorRect.new()
		cover.name = "HiddenResultCover%d" % i
		cover.color = hidden_cover_color
		var rect := _fx_cover_rect(hole)
		cover.position = rect.position
		cover.size = rect.size
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.visible = false
		var glyph := Label.new()
		glyph.text = "?"
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.add_theme_font_size_override("font_size", 12)
		if _font != null:
			glyph.add_theme_font_override("font", _font)
		glyph.add_theme_color_override("font_color", hidden_glyph_color)
		glyph.add_theme_color_override("font_outline_color", Color.BLACK)
		glyph.add_theme_constant_override("outline_size", 1)
		cover.add_child(glyph)
		_fx_layer.add_child(cover)
		_hidden_covers.append(cover)

func _refresh_consumable_fx() -> void:
	if _fx_layer == null:
		return
	_refresh_tobacco_fx()
	_refresh_energy_fx()

## Tobacco hides the LAST reels from scoring (reels.slice keeps the first ones),
## so smoke exactly those. Hallucination changes scoring/reward scale but leaves
## all three reels visible.
func _refresh_tobacco_fx() -> void:
	var tobacco_active := RunStateStore.pairBoostSpins > 0 \
		or _boost_zero_linger.has("pairBoostSpins")
	var active := consumable_fx_enabled and tobacco_fx_enabled and tobacco_active
	# Every reel the scoring ignores is covered, whatever took it away: Tobacco's smoke for
	# its two spins, or Tunnel Vision for the whole run. Only Tobacco actually smokes —
	# Tunnel Vision blinds the reel silently (issue #181).
	var hidden := _blind_reel_count()
	for i in 3:
		var smoked: bool = i >= 3 - hidden
		if i < _tobacco_covers.size():
			(_tobacco_covers[i] as ColorRect).visible = smoked
		if i < _tobacco_smoke.size():
			var smoke := _tobacco_smoke[i] as CPUParticles2D
			var emits_smoke := smoked and active
			smoke.visible = emits_smoke
			smoke.emitting = emits_smoke

## Reels currently out of the scoring, read from live state rather than the last result so a
## run that owns Tunnel Vision is blind from its first frame, before any spin has landed.
## Tobacco keeps its reel covered through the zero-count linger, like its icon.
func _blind_reel_count() -> int:
	var hidden := _active_hidden_reel_count() # whatever the last scored result used
	if Economy.has_tunnel_vision(RunStateStore.ownedUpgrades):
		hidden = maxi(hidden, 1)
	if RunStateStore.pairBoostSpins > 0 or _boost_zero_linger.has("pairBoostSpins"):
		hidden = maxi(hidden, clampi(RunStateStore.pairBoostHiddenReels, 0, 2))
	return clampi(hidden, 0, 2)

func _refresh_energy_fx() -> void:
	if _energy_edges == null:
		return
	var active := consumable_fx_enabled and energy_fx_enabled and RunStateStore.decaySkips > 0
	if active == _energy_fx_active:
		return
	_energy_fx_active = active
	if _energy_pulse_tween != null and _energy_pulse_tween.is_valid():
		_energy_pulse_tween.kill()
		_energy_pulse_tween = null
	_energy_edges.visible = active
	if active:
		_energy_edges.modulate.a = 0.35
		_energy_pulse_tween = create_tween().set_loops()
		_energy_pulse_tween.tween_property(_energy_edges, "modulate:a", 1.0, energy_pulse_time * 0.5)
		_energy_pulse_tween.tween_property(_energy_edges, "modulate:a", 0.35, energy_pulse_time * 0.5)
	# The drink used to fade the spins tube out for its duration. It stays up now — the
	# rush is told by the edges alone, and hiding the tube took away the one readout the
	# player still needs while it runs. Any fade left mid-flight is returned here.
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
	if _fx_layer == null:
		return
	var petals := CPUParticles2D.new()
	petals.name = "TeaSakuraPetals"
	petals.z_index = 65
	petals.amount = tea_petal_count
	petals.lifetime = tea_petal_time
	petals.one_shot = true
	petals.explosiveness = 0.35
	petals.position = Vector2(-8.0, SRC_H * 0.45)
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(4.0, SRC_H * 0.32)
	petals.direction = Vector2(1.0, 0.08)
	petals.spread = 10.0
	petals.gravity = Vector2(0.0, 1.5)
	petals.initial_velocity_min = 48.0
	petals.initial_velocity_max = 70.0
	petals.angular_velocity_min = -90.0
	petals.angular_velocity_max = 90.0
	petals.scale_amount_min = 0.7
	petals.scale_amount_max = 1.25
	petals.color = tea_petal_color
	var tex := _load_texture("ui/sakura_petal.png", false)
	if tex != null:
		petals.texture = tex
		petals.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fx_layer.add_child(petals)
	petals.emitting = true
	var tw := create_tween()
	tw.tween_interval(tea_petal_time + 0.2)
	tw.tween_callback(petals.queue_free)

func _play_white_powder_distortion() -> void:
	if _fx_layer == null or not (consumable_fx_enabled and white_powder_fx_enabled):
		return
	if _white_powder_distortion_tween != null and _white_powder_distortion_tween.is_valid():
		_white_powder_distortion_tween.kill()
	var ripple := ColorRect.new()
	ripple.name = "WhitePowderDistortion"
	ripple.size = Vector2(SRC_W, SRC_H)
	ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ripple.z_index = 70
	var mat := ShaderMaterial.new()
	mat.shader = WHITE_POWDER_DISTORTION_SHADER
	mat.set_shader_parameter("amount", white_powder_distortion_strength)
	mat.set_shader_parameter("ripple_time", 0.0)
	ripple.material = mat
	_fx_layer.add_child(ripple)
	_white_powder_distortion_tween = create_tween()
	_white_powder_distortion_tween.set_parallel(true)
	_white_powder_distortion_tween.tween_property(mat, "shader_parameter/ripple_time", 1.0, white_powder_distortion_time)
	_white_powder_distortion_tween.tween_property(mat, "shader_parameter/amount", 0.0, white_powder_distortion_time)
	_white_powder_distortion_tween.set_parallel(false)
	_white_powder_distortion_tween.tween_callback(ripple.queue_free)

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
	if text.is_empty() or _fx_layer == null:
		return
	var label := Label.new()
	label.add_to_group(WEALTH_TRANSIENT_FX_GROUP)
	label.text = text
	label.position = Vector2(30.0, 112.0) # between the TV and the multiplier strip
	label.size = Vector2(100.0, 10.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 8)
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	_fx_layer.add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 10.0, potion_popup_time)
	tw.tween_property(label, "modulate:a", 0.0, potion_popup_time)
	tw.set_parallel(false)
	tw.tween_callback(label.queue_free)

func _set_hidden_result_active(active: bool) -> void:
	_hide_result_active = active
	# Covers are (re)shown per reel as each reveal lands; toggling always clears.
	for c in _hidden_covers:
		(c as ColorRect).visible = false

func _set_hidden_cover(index: int, visible_now: bool) -> void:
	if index >= 0 and index < _hidden_covers.size():
		(_hidden_covers[index] as ColorRect).visible = visible_now

# Serum downside: after the guaranteed-symbol spins, hide the strip neighbours above
# and below each center symbol so only the actual result remains readable.
func _set_adjacent_symbols_hidden_active(active: bool) -> void:
	_adjacent_symbols_hidden_active = active
	for i in _reel_sprites.size():
		_apply_adjacent_symbol_visibility(i)

# Legacy frost covers stay built but inactive; Serum now hides adjacent strip symbols.
func _set_blur_result_active(active: bool) -> void:
	_blur_result_active = active
	for c in _blur_covers:
		(c as ColorRect).visible = false

func _set_blur_cover(index: int, visible_now: bool) -> void:
	if index >= 0 and index < _blur_covers.size():
		(_blur_covers[index] as ColorRect).visible = visible_now

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
			# Augmented heart modifier (issue #111): the jackpot grants no free spin.
			if RunStateStore.augmented_modifier_active(1):
				color = triple_brain_color
				label = "JACKPOT"
			else:
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

## Centre of the reel window — where triple-grant "+N" fly-ins spawn (issue #66).
const BOOK_CHOICE_RECT := Rect2(11.0, 130.0, 138.0, 54.0)

func _show_book_triple_choice(free_spins_granted: int, power_triggered: bool) -> void:
	_close_book_choice_overlay()
	_set_sequence_lock(true)
	_book_choice_overlay = Control.new()
	_book_choice_overlay.name = "BookTripleChoice"
	_book_choice_overlay.size = Vector2(SRC_W, SRC_H)
	_book_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_book_choice_overlay.z_index = 96
	add_child(_book_choice_overlay)

	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.03, 0.1, 0.94)
	panel.position = BOOK_CHOICE_RECT.position
	panel.size = BOOK_CHOICE_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_choice_overlay.add_child(panel)

	var title := _reaction_label(_book_choice_overlay, "BOOK EFFECT",
		Vector2(BOOK_CHOICE_RECT.position.x, BOOK_CHOICE_RECT.position.y + 3.0),
		7, Color(1.0, 0.82, 0.28))
	title.size = Vector2(BOOK_CHOICE_RECT.size.x, 9.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var choices := ["brain", "eye", "pill", "syringe", "vial", "flatline"]
	var cell_w := BOOK_CHOICE_RECT.size.x / float(choices.size())
	for i in choices.size():
		var sym := String(choices[i])
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(BOOK_CHOICE_RECT.position.x + float(i) * cell_w,
			BOOK_CHOICE_RECT.position.y + 17.0)
		b.size = Vector2(cell_w, 30.0)
		b.pressed.connect(_on_book_triple_choice.bind(sym, free_spins_granted, power_triggered))
		_book_choice_overlay.add_child(b)
		var tex := _load_texture("symbols/%s.png" % sym, true)
		if tex != null:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.position = Vector2((cell_w - 16.0) * 0.5, 3.0)
			icon.size = Vector2(16.0, 16.0)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(icon)

func _on_book_triple_choice(symbol_id: String, free_spins_granted: int, power_triggered: bool) -> void:
	_close_book_choice_overlay()
	_set_sequence_lock(false)
	if symbol_id == "flatline":
		var count := RunStateStore.register_flatline_result()
		_show_flatline_result_reaction(count)
	else:
		_apply_symbol_triple(symbol_id, free_spins_granted, power_triggered)

func _close_book_choice_overlay() -> void:
	if _book_choice_overlay != null:
		_book_choice_overlay.queue_free()
	_book_choice_overlay = null

func _reel_window_center() -> Vector2:
	return Vector2(SRC_W * 0.5 - 6.0,
		float(REEL_WINDOW["top"]) + float(REEL_WINDOW["height"]) * 0.5)

# ── 3x eye reveal (player-picked reel) ───────────────────────────────────────────
# Reuses the shared reel-selection UI. Tapping a reel reveals its NEXT-spin symbol
# INSTANTLY (issue #53): the store rolls it through the normal weight pipeline and
# commits it, so the next spin's evaluate() honours the revealed promise.

const EYE_REVEAL_POPUP_TIME := 1.1
const EYE_REVEAL_FRAME_ASSET := "ui/vision.png"

func _arm_eye_reveal_picker() -> void:
	_arm_reel_picker(func(reel_index: int) -> void: _on_eye_reveal_pick(reel_index))

func _on_eye_reveal_pick(reel_index: int) -> void:
	_clear_targeting()
	var symbol := RunStateStore.reveal_next_reel_symbol(reel_index)
	if symbol == "":
		return
	_reveal_reel_next_spin = reel_index # that reel also stops early next spin
	_show_eye_reveal_popup(reel_index, symbol)

## Popup over the picked reel naming its revealed next-spin symbol.
func _show_eye_reveal_popup(reel_index: int, symbol_id: String) -> void:
	var w := 32.0
	var h := 32.0
	var popup := Control.new()
	popup.add_to_group(WEALTH_TRANSIENT_FX_GROUP)
	popup.z_index = 40
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cx := float(REEL_CELL_CENTERS[reel_index])
	popup.position = Vector2(clampf(cx - w * 0.5, 2.0, SRC_W - w - 2.0), float(REEL_WINDOW["top"]) - h - 7.0)
	popup.size = Vector2(w, h)
	add_child(popup)

	var frame_tex := _load_texture(EYE_REVEAL_FRAME_ASSET, true)
	if frame_tex != null:
		var frame := TextureRect.new()
		frame.texture = frame_tex
		frame.size = popup.size
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(frame)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.05, 0.03, 0.1, 0.92)
		bg.size = popup.size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(bg)

	var pointer := ColorRect.new()
	pointer.color = triple_eye_color
	pointer.position = Vector2(w * 0.5 - 1.0, h - 1.0)
	pointer.size = Vector2(2.0, 8.0)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(pointer)

	var tex := _load_texture("symbols/%s.png" % symbol_id, true)
	if tex != null:
		var icon := Sprite2D.new()
		icon.texture = tex
		icon.position = popup.size * 0.5
		icon.centered = true
		var icon_scale := minf(1.0, STRIP_CENTER_H / float(tex.get_height()))
		icon.scale = Vector2(icon_scale, icon_scale)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		popup.add_child(icon)
	else:
		var sym := _reaction_label(popup, symbol_id.to_upper(), Vector2(0.0, 8.0), 6, Color(0.1, 0.08, 0.2))
		sym.size = Vector2(w, 14.0)
		sym.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	popup.pivot_offset = popup.size * 0.5
	popup.scale = Vector2(0.4, 0.4)
	var tw := popup.create_tween()
	tw.tween_property(popup, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(EYE_REVEAL_POPUP_TIME)
	tw.tween_property(popup, "modulate:a", 0.0, 0.3)
	tw.tween_callback(popup.queue_free)

## Instant death: too many flatline results ends THIS RUN through the normal
## flatline ending (banks lucidity, shows the #38 fatal text, offers CONTINUE
## while campaign neurons remain) — it does not fail the whole campaign.
func _check_flatline_instant_death() -> bool:
	if RunStateStore.flatlineResultCount < fatal_flatline_count:
		return false
	var run := {
		"neurons": RunStateStore.neurons,
		"scoreEarned": RunStateStore.scoreEarned,
		"lucidityCoins": RunStateStore.lucidityCoins,
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
	var host := Control.new()
	host.add_to_group(WEALTH_TRANSIENT_FX_GROUP)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.z_index = 30
	add_child(host)
	var cy := REEL_WINDOW["top"] + REEL_WINDOW["height"] * 0.5
	var line := ColorRect.new()
	line.color = flatline_result_color
	line.size = Vector2(0.0, 2.0)
	line.position = Vector2(0.0, cy - 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(line)
	var text := "CLOSE CALL" if count < fatal_flatline_count else "FLATLINE"
	var label := _reaction_label(host, "%s  %d/%d" % [text, count, fatal_flatline_count],
		Vector2(0.0, cy + 8.0), 10, flatline_result_color)
	label.pivot_offset = Vector2(SRC_W * 0.5, 6.0)
	# Issue #76: a non-fatal strike charges the next winning pair/triple — say so, since
	# the payoff lands on a later spin and would otherwise feel disconnected. (A fatal
	# strike ends the run, so there is no next win to charge.)
	if count < fatal_flatline_count:
		_play_close_call_heartbeat()
		var charge := _reaction_label(host, "NEXT WIN x%d" % EconomyConst.FLATLINE_WIN_BOOST_MULT,
			Vector2(0.0, cy + 20.0), 8, flatline_result_color)
		charge.pivot_offset = Vector2(SRC_W * 0.5, 5.0)
	var tw := create_tween()
	tw.tween_property(line, "size:x", float(SRC_W), reaction_flash_time * 0.5)
	tw.tween_interval(reaction_flash_time * 0.3)
	tw.tween_property(host, "modulate:a", 0.0, reaction_flash_time * 0.3)
	tw.tween_callback(host.queue_free)

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
	var host := Control.new()
	host.add_to_group(WEALTH_TRANSIENT_FX_GROUP)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.z_index = 30
	add_child(host)
	var flash := ColorRect.new()
	flash.color = Color(color.r, color.g, color.b, 0.0)
	flash.size = Vector2(SRC_W, SRC_H)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(flash)
	var label := _reaction_label(host, text, Vector2(0.0, 150.0), 14, color)
	label.pivot_offset = Vector2(SRC_W * 0.5, 10.0)
	label.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "color:a", 0.32, reaction_flash_time * 0.25)
	tw.tween_property(label, "scale", Vector2.ONE, reaction_flash_time * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(reaction_flash_time * 0.4)
	tw.chain().tween_property(host, "modulate:a", 0.0, reaction_flash_time * 0.35)
	tw.chain().tween_callback(host.queue_free)

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
## has to pull the lever again just to be told the target was already beaten.
## Returns true when the transition took the screen.
func _proc_wealth_target() -> bool:
	if _wealth_target_transition_active or RunStateStore.comboDefeatPending:
		return false
	if not _wealth_target_due_now():
		return false
	var target_info := RunStateStore.begin_wealth_target()
	return not target_info.is_empty() and _start_wealth_target_transition(target_info)

## Score gained outside the spin sequence (item / power). Pops the target payout the
## moment it is earned; returns true when something took the screen and the caller
## must not carry on with its own presentation.
func _settle_off_spin_score_change() -> bool:
	if _proc_wealth_target():
		return true
	return _check_ending()

func _check_ending() -> bool:
	if RunStateStore.comboDefeatPending:
		return false
	if _proc_wealth_target():
		return true
	var run := {
		"neurons": RunStateStore.neurons,
		"scoreEarned": RunStateStore.scoreEarned,
		"lucidityCoins": RunStateStore.lucidityCoins,
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
	_stop_combo_loss_beep()
	_set_combo_loss_display(0)
	if _pending_combo_overlay != null:
		_pending_combo_overlay.queue_free()
		_pending_combo_overlay = null
	_stop_win_animation()
	_stop_combo_effect()
	for fx in [_mult_fx_2, _mult_fx_3, _mult_fx_fire]:
		if fx != null:
			(fx as Sprite2D).visible = false
	_hide_compulsive_overlay()
	_clear_targeting()
	_set_stash_elevated(false)

func _show_ending(ending: String, run: Dictionary) -> void:
	_cleanup_transient_presentation()
	_stop_flatline_countdown()
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
		- (1 if RunStateStore.campaignNeuronPending else 0)
	var resolved_ending := "game_over" if ending == "flatline" \
		and neurons_after_run <= 0 else ending
	RunStateStore.end_run(resolved_ending)
	MetaStateStore.mark_ending_reached(resolved_ending)
	# Wealth banking is deferred until the player chooses Start Again so the ending
	# animation can show the full run total before the wallet is updated.
	if resolved_ending != "wealth":
		MetaStateStore.bank_run(run, resolved_ending)

	# The stash tray draws at z 50 and would float over the ending presentation.
	_set_stash_tray_visible(false)
	if resolved_ending == "wealth":
		_build_wealth_screen(run)
		return
	if resolved_ending == "game_over":
		_build_game_over_screen(run)
		return
	if resolved_ending == "flatline":
		_build_flatline_screen(run)
		return

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.size = Vector2(SRC_W, SRC_H)
	_overlay.add_child(dim)

	var title := Label.new()
	if resolved_ending == "flatline":
		# The fatal copy only applies when the campaign is truly over — a routine
		# flatline with neurons left just reads FLATLINE.
		var fatal := not _has_campaign_neurons_remaining()
		title.text = fatal_flatline_text if fatal else "FLATLINE"
		title.position = Vector2(20, 58)
		title.size = Vector2(120, 28)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 9 if fatal else 14)
	else:
		title.text = resolved_ending.to_upper()
		title.position = Vector2(20, 120)
		title.size = Vector2(120, 20)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 16)
	if _font != null:
		title.add_theme_font_override("font", _font)
	title.add_theme_color_override("font_color", Color(1, 0.4, 0.5) if resolved_ending == "flatline" else Color(0.5, 1, 0.6))
	_overlay.add_child(title)

	if resolved_ending == "flatline":
		_build_flatline_countdown(run)
	else:
		var wallet := Label.new()
		wallet.position = Vector2(20, 145)
		wallet.add_theme_font_size_override("font_size", 9)
		if _font != null:
			wallet.add_theme_font_override("font", _font)
		wallet.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
		wallet.text = "CREDITS %d" % MetaStateStore.lucidityWallet
		_overlay.add_child(wallet)

	var to_menu := Button.new()
	to_menu.text = _flatline_action_text()
	to_menu.position = Vector2(30, 238 if resolved_ending == "flatline" else 175)
	to_menu.size = Vector2(100, 20)
	to_menu.add_theme_font_size_override("font_size", 9)
	if _font != null:
		to_menu.add_theme_font_override("font", _font)
	Assets.skin_negative_button(to_menu)
	to_menu.pressed.connect(_on_flatline_action_pressed)
	_overlay.add_child(to_menu)

## Dedicated issue #140 flatline presentation. The visual layer owns the focused
## message, animated trace, and action; MachineScene retains countdown state,
## banking, and the existing dealer/menu transition.
func _build_flatline_screen(run: Dictionary) -> void:
	var flatline_screen := FLATLINE_ENDING_SCENE.instantiate() as FlatlineEndingOverlay
	_overlay.add_child(flatline_screen)
	var fatal_copy := fatal_flatline_text if not _has_campaign_neurons_remaining() else ""
	flatline_screen.present(_flatline_action_text(), fatal_copy)
	flatline_screen.action_pressed.connect(_on_flatline_action_pressed)
	_build_flatline_countdown(run, flatline_screen)


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
	for entry: Dictionary in _boost_indicator_slots:
		var slot := entry.get("slot") as Control
		if slot != null:
			slot.visible = false

	_clear_targeting()
	_close_score_table()
	_hide_augmented_popup()
	_hide_pacte_augment_popup()
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

	if _energy_pulse_tween != null and _energy_pulse_tween.is_valid():
		_energy_pulse_tween.kill()
	_energy_pulse_tween = null
	_energy_fx_active = false
	if _energy_edges != null:
		_energy_edges.visible = false
	for cover: CanvasItem in _tobacco_covers:
		cover.visible = false
	for smoke_node: Node in _tobacco_smoke:
		var smoke := smoke_node as CPUParticles2D
		if smoke != null:
			smoke.emitting = false
			smoke.visible = false
	for cover: CanvasItem in _hidden_covers:
		cover.visible = false
	for cover: CanvasItem in _blur_covers:
		cover.visible = false
	_hide_result_active = false
	_blur_result_active = false
	_adjacent_symbols_hidden_active = false

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

	if _white_powder_distortion_tween != null and _white_powder_distortion_tween.is_valid():
		_white_powder_distortion_tween.kill()
	_white_powder_distortion_tween = null
	if _wealth_odometer != null:
		_wealth_odometer.stop_roll()
	# A teardown mid-payout must not strand a black TV, a muted dealer bar, or blanked
	# wealth digits — the group sweep below only hides nodes, it restores nothing.
	_end_tv_blackout()
	if _jackpot_flash_tween != null and _jackpot_flash_tween.is_valid():
		_jackpot_flash_tween.kill()
	_jackpot_flash_tween = null
	_jackpot_flashing = false
	_clear_jackpot_coins()
	_set_sheet_frame(_jackpot_sprite, JACKPOT_FRAME_OFF)

	if _burst_layer != null:
		for child: Node in _burst_layer.get_children():
			var item := child as CanvasItem
			if item != null:
				item.visible = false
				item.modulate.a = 0.0
	if _coin_layer != null:
		for child: Node in _coin_layer.get_children():
			var item := child as CanvasItem
			if item != null:
				item.visible = false
				item.modulate.a = 0.0
	if _hint_layer != null:
		for child: Node in _hint_layer.get_children():
			var item := child as CanvasItem
			if item != null:
				item.visible = false
				item.modulate.a = 0.0
	if _fx_layer != null:
		var persistent_fx: Array[Node] = []
		for node: Node in _tobacco_covers:
			persistent_fx.append(node)
		for node: Node in _tobacco_smoke:
			persistent_fx.append(node)
		if _energy_edges != null:
			persistent_fx.append(_energy_edges)
		for node: Node in _hidden_covers:
			persistent_fx.append(node)
		for node: Node in _blur_covers:
			persistent_fx.append(node)
		for child: Node in _fx_layer.get_children():
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
	_set_stash_tray_visible(false)
	_build_game_over_screen()

func _start_fresh_again() -> void:
	MetaStateStore.start_new_campaign()
	RunStateStore.reset_run_state()
	_to_menu()

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
			_on_flatline_first_revival_beep):
			flatline_screen.first_revival_beep.connect(_on_flatline_first_revival_beep)
		flatline_screen.play_continue_animation()
		await flatline_screen.continue_animation_finished
	if _overlay == null or not is_instance_valid(_overlay):
		return
	if flatline_screen == null:
		_attach_flatline_meter(Vector2(80.0, 286.0), Vector2(80.0, 270.0))
	await get_tree().create_timer(NeuronMeter.LOSS_ANIM_DELAY + 0.38).timeout
	if _has_campaign_neurons_remaining():
		# The campaign-neuron threshold Pacte is a post-flatline handoff. It must
		# never interrupt a live machine spin or a reward sequence.
		if RunStateStore.pacteThresholdPending \
				and RunStateStore.pacteAfterFlatlinePending \
				and RunStateStore.open_threshold_pacte():
			SceneNav.change_to(PACTE_SCENE)
			return
		_to_dealer()
	else:
		_to_menu()

func _on_flatline_first_revival_beep() -> void:
	_attach_flatline_meter(FlatlineEndingOverlay.REVIVAL_METER_CENTER,
		FlatlineEndingOverlay.REVIVAL_METER_CENTER + Vector2(0.0, 27.0))

func _attach_flatline_meter(center: Vector2, feedback_center: Vector2) -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	if _flatline_meter != null and is_instance_valid(_flatline_meter):
		return
	_flatline_meter = NeuronMeter.attach(_overlay, center)
	_flatline_meter.play_loss_animation()
	_show_neuron_spend_feedback(_overlay, feedback_center)

func _has_campaign_neurons_remaining() -> bool:
	return int(MetaStateStore.campaignNeuronsLeft) > 0

func _build_flatline_countdown(run: Dictionary,
		flatline_screen: FlatlineEndingOverlay = null) -> void:
	_flatline_total = int(run["lucidityCoins"])
	_flatline_kept = floori(float(_flatline_total) * _end_run_lucidity_kept_fraction())
	_flatline_display = _flatline_total
	_flatline_countdown_elapsed = 0.0
	_flatline_countdown_active = _flatline_kept < _flatline_total

	# Retained-percent line only ("10% kept", or "20% kept" with Smart Saving);
	# the draining number below it is the whole story.
	var kept_pct := roundi(_end_run_lucidity_kept_fraction() * 100.0)
	if flatline_screen != null:
		flatline_screen.set_kept_percentage(kept_pct)
		_flatline_score_label = flatline_screen.score_label
		_flatline_lost_label = flatline_screen.lost_label
	else:
		_score_label(_overlay, "%d%% kept" % kept_pct, Vector2(20.0, 96.0), 8,
			Color(0.58, 0.64, 0.72), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
		_flatline_score_label = _score_label(_overlay, str(_flatline_display),
			Vector2(20.0, 110.0), 28, Color(0.97, 0.98, 1.0), 120.0,
			HORIZONTAL_ALIGNMENT_CENTER)
		_flatline_lost_label = _score_label(_overlay, "", Vector2(20.0, 148.0), 10,
			Color(0.93, 0.27, 0.27), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	_update_flatline_countdown_labels()

	# Keep the neuron-loss treatment only for the legacy fallback. The dedicated
	# flatline screen intentionally stays focused on the money drain and trace.
	if flatline_screen == null:
		_flatline_meter = NeuronMeter.attach(_overlay, Vector2(80.0, 198.0))
		_flatline_meter.play_loss_animation()
		_show_neuron_spend_feedback(_overlay, Vector2(80.0, 190.0))

func _step_flatline_countdown(delta: float) -> void:
	_flatline_countdown_elapsed += delta
	if _flatline_countdown_elapsed < FLATLINE_HOLD_TIME:
		return
	var drain_elapsed := _flatline_countdown_elapsed - FLATLINE_HOLD_TIME
	var p := clampf(drain_elapsed / FLATLINE_DRAIN_TIME, 0.0, 1.0)
	var eased := 1.0 - (1.0 - p) * (1.0 - p)
	_flatline_display = _flatline_kept if p >= 1.0 else int(round(float(_flatline_total) - float(_flatline_total - _flatline_kept) * eased))
	_update_flatline_countdown_labels()
	if p >= 1.0:
		_flatline_countdown_active = false

func _update_flatline_countdown_labels() -> void:
	if _flatline_score_label != null:
		_flatline_score_label.text = str(_flatline_display)
	if _flatline_lost_label != null:
		var lost := _flatline_total - _flatline_display
		_flatline_lost_label.text = "-%d lost" % lost if lost > 0 else ""

func _stop_flatline_countdown() -> void:
	_flatline_countdown_active = false
	_flatline_countdown_elapsed = 0.0
	_flatline_total = 0
	_flatline_kept = 0
	_flatline_display = 0
	_flatline_score_label = null
	_flatline_lost_label = null
	_flatline_meter = null
	_flatline_transition_active = false

# The stash tray (z 50) would draw over full-screen ending overlays; hide it while
# one is up and restore it when the run visuals resync.
func _set_stash_tray_visible(v: bool) -> void:
	var tray := get_node_or_null("stash") as Control
	if tray != null:
		tray.visible = v
	_set_stash_visible(v)

# While the dealer offer is open the stash must draw (and receive drags) above his
# overlay; every close path drops it back to its normal slot under the HUD.
func _set_stash_elevated(elevated: bool) -> void:
	var tray := get_node_or_null("stash") as Control
	if tray != null:
		tray.z_index = DEALER_STASH_Z_INDEX if elevated else STASH_TRAY_Z_INDEX

func _set_tv_progress_bars_visible(visible: bool) -> void:
	if not visible and _tv_content_muted():
		_tv_info_pop_restore_dealer_bar_visible = false
		_tv_info_pop_restore_dealer_icon_visible = false
	for node_name: String in [
		"WealthOdometer", "HealthBar", "DealerBar", "DealerBarOverlay1",
		"DealerBarOverlay2", "DealerBarOverlay3", "DealerIcon"]:
		var node := get_node_or_null(NodePath(node_name)) as CanvasItem
		if node != null:
			node.visible = visible
	# The FREE SPINS banner re-derives from state on the next HUD refresh; a
	# mid-flight coin drop never outlives the bars it belongs to.
	if not visible:
		_cancel_coin_insert()
		_set_free_spin_display(false)
	elif not _tv_info_pop_sources.is_empty():
		_hide_tv_info_layers()

func _end_run_lucidity_kept_fraction() -> float:
	var frac := EconomyConst.SMART_SAVE_LUCIDITY_KEPT \
		if MetaStateStore.ownedPermanents.has(EconomyConst.SMART_SAVE_UPGRADE_ID) \
		else EconomyConst.END_OF_RUN_LUCIDITY_KEPT
	# Augmented spade modifier (issue #111): end-of-run gain kept is halved.
	# Mirrors MetaStateStore.bank_run so the "% kept" countdown matches the bank.
	return frac * 0.5 if RunStateStore.augmented_modifier_active(2) else frac

# ── Augmented Run badge (issue #111) ─────────────────────────────────────────────────
# The active suit stays visible during the run; holding it peeks at the list of
# active restrictions in the shared bubble style.

func _build_augmented_badge() -> void:
	if RunStateStore.augmentedTier == "":
		return
	var icon_tex := Assets.augmented_suit_icon(RunStateStore.augmentedTier)
	if icon_tex == null:
		return
	var b := Button.new()
	b.name = "AugmentedBadge"
	b.position = AUGMENTED_BADGE_POS
	b.size = Vector2.ONE * AUGMENTED_BADGE_SIZE
	b.z_index = 40
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.02, 0.05, 0.85)
	style.border_color = Color(0.86, 0.84, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, style)
	var icon := TextureRect.new()
	icon.texture = icon_tex
	# expand_mode BEFORE size: with the default EXPAND_KEEP_SIZE the texture's
	# native size becomes the minimum and the size assignment gets clamped up.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2.ONE * 2.0
	icon.size = Vector2.ONE * (AUGMENTED_BADGE_SIZE - 4.0)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	b.button_down.connect(_show_augmented_popup.bind(b))
	b.button_up.connect(_hide_augmented_popup)
	add_child(b)

func _augmented_restrictions_text() -> String:
	var lines: Array[String] = []
	if RunStateStore.augmented_modifier_active(1):
		lines.append("JACKPOT %d, NO FREE SPIN" % (Payouts.JACKPOT_SCORE / 2))
	if RunStateStore.augmented_modifier_active(2):
		lines.append("END-OF-RUN GAIN HALVED")
	if RunStateStore.augmented_modifier_active(3):
		lines.append("MAX 2 POWERS PER SPIN")
	if RunStateStore.augmented_modifier_active(4):
		lines.append("DEALER + REWARDS HALVED")
	return "\n".join(lines)

func _show_augmented_popup(button: Button) -> void:
	_hide_augmented_popup()
	var text := _augmented_restrictions_text()
	if text == "":
		return
	_augmented_popup = Control.new()
	_augmented_popup.name = "AugmentedPopup"
	_augmented_popup.z_index = 41
	_augmented_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = _font if _font != null else ThemeDB.fallback_font
	var lines := text.split("\n")
	var text_w := 0.0
	for line in lines:
		text_w = maxf(text_w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x)
	var popup_size := Vector2(text_w + 8.0, float(lines.size()) * 8.0 + 6.0)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.045, 0.035, 0.075, 0.97)
	bg_style.border_color = Color(0.86, 0.84, 0.24)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.size = popup_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_augmented_popup.add_child(bg)
	var label := Label.new()
	label.text = text
	label.size = popup_size
	label.custom_minimum_size = Vector2.ZERO
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 5)
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.7))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	bg.add_child(label)
	label.set_deferred("size", popup_size)
	var pos := button.position + Vector2(button.size.x + 3.0,
		button.size.y * 0.5 - popup_size.y * 0.5)
	pos.x = clampf(pos.x, 2.0, SRC_W - popup_size.x - 2.0)
	pos.y = clampf(pos.y, 2.0, SRC_H - popup_size.y - 2.0)
	_augmented_popup.position = pos.round()
	add_child(_augmented_popup)

func _hide_augmented_popup() -> void:
	if _augmented_popup != null:
		_augmented_popup.queue_free()
		_augmented_popup = null

func _active_pacte_augment_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in RunStateStore.selectedAugmentCardIds:
		var id := String(raw_id)
		if not ids.has(id) and PacteCards.augment_map().has(id):
			ids.append(id)
	return ids

## The glitching chip: only the augment whose effect glitches the dealer gets one, keyed off
## the card's effect rather than its id so a renamed card keeps the treatment.
const AUGMENT_GLITCH_SLICES := 4
const AUGMENT_GLITCH_STEP_TIME := 0.09
const AUGMENT_GLITCH_COLORS: Array[Color] = [
	Color("#3ee0ff"), Color("#ff3ea5"), Color("#e8ff5a"), Color("#3ee0ff"),
]

func _augment_glitches(card_id: String) -> bool:
	var entry := PacteCards.card(card_id)
	var effect: Dictionary = entry.get("effect", {})
	return String(effect.get("type", "")) == "glitch_dealer"

func _step_augment_glitch(delta: float) -> void:
	if _pacte_augment_badges.is_empty():
		return
	_augment_glitch_time += delta
	if _augment_glitch_time < AUGMENT_GLITCH_STEP_TIME:
		return
	_augment_glitch_time = 0.0
	for entry: Dictionary in _pacte_augment_badges:
		var glitch := entry.get("glitch") as Control
		if glitch == null or not glitch.visible:
			continue
		if not (entry["badge"] as Button).visible:
			continue
		_scramble_augment_glitch(glitch)

## One frame of the effect: each slice jumps to a new row, overhangs the chip sideways so the
## clip cuts it, and takes a fresh alpha. Seeded, so the same frame count always looks the same.
func _scramble_augment_glitch(host: Control) -> void:
	for i in host.get_child_count():
		var slice := host.get_child(i) as ColorRect
		if slice == null:
			continue
		var height := floorf(_augment_glitch_rng.randf_range(1.0, 3.0))
		slice.position = Vector2(
			floorf(_augment_glitch_rng.randf_range(-2.0, 2.0)),
			floorf(_augment_glitch_rng.randf_range(0.0, maxf(1.0, host.size.y - height))))
		slice.size = Vector2(host.size.x + 4.0, height)
		var color: Color = AUGMENT_GLITCH_COLORS[i % AUGMENT_GLITCH_COLORS.size()]
		color.a = _augment_glitch_rng.randf_range(0.4, 1.0)
		slice.color = color

func _pacte_augment_icon(card_id: String) -> Texture2D:
	var entry := PacteCards.card(card_id)
	var sheet := _load_texture(String(entry.get("sheet", "")), true)
	var icon_rect := entry.get("icon_rect", Rect2()) as Rect2
	if sheet == null or icon_rect.size == Vector2.ZERO:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = icon_rect
	return atlas

## A row of augment icons along the TV's bottom-left, one badge per held card up to
## PACTE_AUGMENT_BADGE_MAX (issue #181). The row stops short of the TARGET goal number
## in the middle of the screen; a fourth augment turns the last badge into a "+N".
## Every badge opens the same description popup.
func _build_pacte_augment_badge() -> void:
	if _pacte_augment_badge != null:
		_refresh_pacte_augment_badge()
		return
	for i in PACTE_AUGMENT_BADGE_MAX:
		var badge := Button.new()
		# The first badge keeps the historical node name; the scene smoke and the popup
		# anchoring both look it up by it.
		badge.name = "PacteAugmentBadge" if i == 0 else "PacteAugmentBadge%d" % (i + 1)
		badge.position = PACTE_AUGMENT_BADGE_POS + Vector2(float(i) * PACTE_AUGMENT_BADGE_PITCH, 0.0)
		badge.size = PACTE_AUGMENT_BADGE_SIZE
		badge.z_index = 40
		badge.text = ""
		badge.flat = true
		badge.visible = false
		badge.focus_mode = Control.FOCUS_NONE
		badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(0.03, 0.02, 0.05, 0.9)
		badge_style.border_color = PACTE_AUGMENT_CONTOUR_COLOR
		badge_style.set_border_width_all(1)
		badge_style.set_corner_radius_all(1)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			badge.add_theme_stylebox_override(state, badge_style)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = (PACTE_AUGMENT_BADGE_SIZE
			- Vector2(PACTE_AUGMENT_ICON_SIZE, PACTE_AUGMENT_ICON_SIZE)) * 0.5
		icon.size = Vector2(PACTE_AUGMENT_ICON_SIZE, PACTE_AUGMENT_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(icon)
		# The overflow count replaces the last icon rather than sitting on top of one,
		# so it can never obscure the art it is counting.
		var count := Label.new()
		count.name = "Count"
		count.position = Vector2.ZERO
		count.size = PACTE_AUGMENT_BADGE_SIZE
		count.visible = false
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_font_size_override("font_size", 5)
		if _font != null:
			count.add_theme_font_override("font", _font)
		count.add_theme_color_override("font_color", NEON_GOLD)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 1)
		badge.add_child(count)
		# GLITCH has no authored chip art, so its badge carries the effect itself: a few
		# neon slices that jump and flicker inside the chip (clipped to it), stepped by
		# _step_augment_glitch. It draws over the icon, so authored art can arrive later
		# and keep the effect.
		var glitch := Control.new()
		glitch.name = "Glitch"
		glitch.position = icon.position
		glitch.size = icon.size
		glitch.clip_contents = true
		glitch.visible = false
		glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for _slice_index in AUGMENT_GLITCH_SLICES:
			var slice := ColorRect.new()
			slice.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glitch.add_child(slice)
		badge.add_child(glitch)
		badge.pressed.connect(_toggle_pacte_augment_popup)
		add_child(badge)
		_pacte_augment_badges.append({
			"badge": badge, "icon": icon, "count": count, "glitch": glitch,
		})
	if not _pacte_augment_badges.is_empty():
		_pacte_augment_badge = _pacte_augment_badges[0]["badge"]
		_pacte_augment_badge_icon = _pacte_augment_badges[0]["icon"]
		_pacte_augment_count = _pacte_augment_badges[0]["count"]
	_refresh_pacte_augment_badge()

func _refresh_pacte_augment_badge() -> void:
	if _pacte_augment_badges.is_empty():
		return
	var ids := _active_pacte_augment_ids()
	# The row lives on the power bar now, not on the TV, so a TV callout no longer
	# hides it — only the description popup steps aside for one.
	if not _tv_info_pop_sources.is_empty():
		_hide_pacte_augment_popup()
	if ids.is_empty():
		for entry: Dictionary in _pacte_augment_badges:
			(entry["badge"] as Button).visible = false
		if _augment_plate_sprite != null:
			_augment_plate_sprite.visible = false # no augments, no sockets
		_hide_pacte_augment_popup()
		return
	var shown := mini(ids.size(), _pacte_augment_badges.size())
	# One socket per badge on show, so the plate never offers an empty bed.
	if _augment_plate_sprite != null:
		_augment_plate_sprite.visible = true
		_set_sheet_frame(_augment_plate_sprite, clampi(shown - 1, 0, AUGMENT_PLATE_FRAMES - 1))
	for i in _pacte_augment_badges.size():
		var entry: Dictionary = _pacte_augment_badges[i]
		var badge: Button = entry["badge"]
		var icon: TextureRect = entry["icon"]
		var count: Label = entry["count"]
		badge.visible = i < shown
		if not badge.visible:
			icon.texture = null
			continue
		# The last slot counts the remainder instead of showing one more icon.
		var overflow := i == shown - 1 and ids.size() > shown
		count.visible = overflow
		icon.visible = not overflow
		var glitch := entry.get("glitch") as Control
		if overflow:
			count.text = "+%d" % (ids.size() - shown + 1)
			icon.texture = null
			if glitch != null:
				glitch.visible = false
		else:
			icon.texture = _pacte_augment_icon(ids[i])
			if glitch != null:
				glitch.visible = _augment_glitches(String(ids[i]))

func _pacte_augment_popup_text() -> String:
	var lines: Array[String] = []
	for card_id in _active_pacte_augment_ids():
		var entry := PacteCards.card(card_id)
		lines.append("%s\n%s" % [
			String(entry.get("name", card_id)), String(entry.get("description", ""))])
	return "\n".join(lines)

func _toggle_pacte_augment_popup() -> void:
	if _pacte_augment_popup != null:
		_hide_pacte_augment_popup()
		return
	if _pacte_augment_badge == null or _active_pacte_augment_ids().is_empty():
		return
	var text := _pacte_augment_popup_text()
	if text == "":
		return
	var popup := Control.new()
	popup.name = "PacteAugmentPopup"
	popup.z_index = 41
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var popup_size := Vector2(126.0,
		minf(116.0, 8.0 + float(_active_pacte_augment_ids().size()) * 22.0))
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.045, 0.035, 0.075, 0.97)
	bg_style.border_color = NEON_CYAN
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	var bg := Panel.new()
	bg.size = popup_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", bg_style)
	popup.add_child(bg)
	var label := Label.new()
	label.position = Vector2(4.0, 3.0)
	label.size = popup_size - Vector2(8.0, 6.0)
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 5)
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	bg.add_child(label)
	var pos := _pacte_augment_badge.position + Vector2(
		_pacte_augment_badge.size.x - popup_size.x,
		-_pacte_augment_badge.size.y - popup_size.y - 3.0)
	pos.x = clampf(pos.x, 2.0, SRC_W - popup_size.x - 2.0)
	pos.y = clampf(pos.y, 2.0, SRC_H - popup_size.y - 2.0)
	popup.position = pos.round()
	_pacte_augment_popup = popup
	add_child(popup)

func _hide_pacte_augment_popup() -> void:
	if _pacte_augment_popup != null:
		_pacte_augment_popup.queue_free()
		_pacte_augment_popup = null

## A wealth CONTINUE only makes sense if the resumed run can still take a spin:
## neurons (or banked free spins) remain (issue #62). The normal spin pool is capped
## at 18, including after a Wealth continuation.
func _can_resume_after_wealth() -> bool:
	return int(RunStateStore.neurons) >= 1 or int(RunStateStore.freeSpinsRemaining) > 0

func _continue_from_wealth() -> void:
	RunStateStore.continue_run()
	if _can_resume_after_wealth():
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
		"lucidityCoins": RunStateStore.lucidityCoins,
	})

## Wealth screen Start Again: bank the run and return to the menu hub.
func _start_again_from_wealth(run: Dictionary) -> void:
	MetaStateStore.bank_run(run, "wealth")
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
	_dealer_visit()

func _dealer_visit() -> void:
	RunStateStore.reveal_dealer()
	# Ordinary in-run dealer visits stay inline (issue #22); the full dealer scene
	# is also used after the threshold Pacte completion and for post-Wealth odds.
	_show_dealer_offers()

func _show_dealer_offers() -> void:
	var offers: Variant = RunStateStore.dealerOfferIds
	if offers == null:
		_close_dealer()
		return
	_set_sequence_lock(true)
	_clear_targeting()
	if _dealer_overlay != null:
		_dealer_overlay.queue_free()
	_dealer_offer_popup = IN_RUN_DEALER_OFFER_SCENE.instantiate()
	_dealer_overlay = _dealer_offer_popup
	# The dealer draws above the loss overlays (97) but under the HUD (120); the
	# machine stash rides above him while his offer is up so it stays draggable.
	_dealer_offer_popup.z_index = DEALER_OVERLAY_Z_INDEX
	add_child(_dealer_offer_popup)
	_set_stash_elevated(true)
	_refresh_score_button_lock()
	_dealer_offer_popup.item_selected.connect(_dealer_take)
	_dealer_offer_popup.item_discarded.connect(_dealer_discard_stash)
	_dealer_offer_popup.dealer_ignored.connect(_dealer_leave)
	_dealer_offer_popup.offer_finished.connect(_on_dealer_offer_finished)
	_set_stash_visible(true)
	_dealer_offer_popup.start_offer((offers as Array).duplicate(), [])
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
	# Points table (issue #119): back/cancel closes the overlay from keyboard
	# (Esc) or controller (B) without needing to focus the CLOSE button.
	if _score_overlay != null and event.is_action_pressed("ui_cancel"):
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
				Assets.add_drag_shadow(_dealer_drag_node)
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
		Assets.remove_drag_shadow(node)
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
	if _dealer_overlay != null:
		_dealer_overlay.queue_free()
		_dealer_overlay = null
	_dealer_offer_popup = null
	_dealer_message_label = null
	_dealer_portrait_sprite = null
	_dealer_drag_active = false
	_dealer_drag_node = null
	_dealer_drag_id = ""
	_dealer_drag_kind = ""
	_set_stash_visible(true) # overlay gone — restore the machine's own stash (issue #26)
	_set_stash_elevated(false)
	if not restore_sequence:
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
