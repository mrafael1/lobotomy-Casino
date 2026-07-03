extends Node2D

## Main slot-machine scene (Milestone 2, first increment): the playable run loop —
## start run -> spin -> reel/result reveal -> HUD update -> ending -> bank/restart,
## driven entirely by RunStateStore (which delegates rules to the parity-verified
## core). Built programmatically so every position comes straight from the
## documented source-pixel constants in src/content/machineAssets.ts (alignment is
## correct by construction, mirroring the Expo renderer).
##
## Coordinate space is the 160x320 virtual canvas (project stretch scales it to the
## device). Art is loaded by absolute path from ../assets so the Expo project stays
## the single source of art (no duplication).

const SRC_W := 160.0
const SRC_H := 320.0
const ASSET_SCALE := 8.0 # machine PNGs are 8x the 160x320 source (1280x2560)

# Geometry mirrored from src/content/machineAssets.ts (source px).
const REEL_CELL_CENTERS := [43.5, 75.5, 107.5]
const REEL_WINDOW := { "top": 170.0, "height": 30.0 }
# Per-reel hole rects (source px) — used to mask the spin blur per reel on stop.
const REEL_HOLES := [
	{ "left": 33.0, "top": 170.0, "width": 21.0, "height": 30.0 },
	{ "left": 65.0, "top": 170.0, "width": 21.0, "height": 30.0 },
	{ "left": 97.0, "top": 170.0, "width": 21.0, "height": 30.0 },
]
const TV_SCREEN := { "left": 24.0, "top": 42.0, "width": 112.0, "height": 66.0 }
const BAR_FILL := { "left": 43.0, "width": 66.0 }
const WEALTH_BAR := { "left": 43.0, "top": 73.0, "width": 66.0, "height": 4.0 }
const HEALTH_BAR := { "left": 43.0, "top": 94.0, "width": 66.0, "height": 5.0 }
const MULT_STRIP := { "top": 119.0, "height": 16.0 }
const MULT_BADGE_CENTERS := [47.0, 78.0, 106.0]
const LEVER_HIT := { "left": 133.0, "top": 160.0, "width": 20.0, "height": 40.0 }
# Centre of the reel window — consumable-use hint popups originate here.
const MACHINE_HINT_CENTER := Vector2(75.5, 185.0)
const SYMBOL_TARGET_H := 32.0 # 32px symbols render 1:1 in the virtual canvas.
# Landed reel strip (mirrors Expo's ReelCellV3): a smaller centre symbol with dim
# 0.9x neighbours peeking above/below, clipped by the cabinet hole.
const STRIP_CENTER_H := 16.0
const STRIP_ADJ_H := 12.0
const STRIP_OFFSET := 14.0 # vertical gap between symbol centres ((center+adj)/2)
const STRIP_ADJ_ALPHA := 0.5

# Machine-mounted power button hit rects (source px).
const POWER_HITS := {
	"reroll": { "left": 21.0, "top": 223.0, "width": 15.0, "height": 15.0 },
	"shift": { "left": 36.0, "top": 223.0, "width": 13.0, "height": 15.0 },
	"memory": { "left": 49.0, "top": 223.0, "width": 13.0, "height": 15.0 },
}
const LEVER_FRAME_COUNT := 6
const LEVER_FRAME_TIME := 0.042
const LEVER_HOLD_TIME := 0.055
const LEVER_RETURN_TIME := 0.07
const SPIN_FRAME_COUNT := 4
const SPIN_FRAME_TIME := 0.055
const REROLL_REEL_DURATION := 0.55
const FLATLINE_HOLD_TIME := 0.7
const FLATLINE_DRAIN_TIME := 1.6
const MULTIPLIER_FRAME_COUNT := 6
const LOCK_POWER_FRAME_COUNT := 3
const JACKPOT_FRAME_COUNT := 2
const DISPLAY_SPIN_BUDGET := 35
const POWER_FRAME_AVAILABLE := 0
const POWER_FRAME_SELECTED := 1
const POWER_FRAME_DISABLED := 2
const POWER_SHEETS := {
	"reroll": "machine new view/reroll_final_machine.png",
	"shift": "machine new view/shift_final_machine.png",
	"memory": "machine new view/lock_final_machine.png",
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
const IN_RUN_DEALER_OFFER_SCENE := preload("res://scenes/in_run_dealer_offer.tscn")
const OPTIONS_OVERLAY_SCENE := preload("res://scenes/options_overlay.tscn")
const SETTINGS_ASSET := "ui/settings.png"

# Debug-grant Shift/Memory + test consumables when a run is started standalone
# (machine opened directly, not via the shop). The shop is the real source now.
const DEBUG_GRANT := false

# Visible (non-book) symbols used for the spin-blur animation.
const VISIBLE_SYMBOLS := ["brain", "eye", "pill", "syringe", "vial", "flatline"]

# Score-burst (port of src/components/ScoreBurst.tsx). Visual only.
const BURST_TIME := 1.05
const BURST_RISE := 28.0
const MULT_COLORS := {
	1: Color(0.094, 0.227, 0.549), # x1 dark blue  (#183A8C)
	2: Color(0.984, 0.749, 0.141), # x2 gold       (#fbbf24)
	3: Color(0.839, 0.157, 0.157), # x3 red        (#D62828)
}
const COCKTAIL_COLOR := Color(0.941, 0.671, 0.988) # #f0abfc
const JACKPOT_GOLD := Color(1.0, 0.84, 0.18) # jackpot burst is ALWAYS golden (issue #22)
const TENSION_DELAY := 0.4   # extra hold on reel 3 when reels 1 & 2 match
const JACKPOT_FLASH_TIME := 0.9
const COIN_TRAY := Vector2(80.0, 290.0)
const CASH_COIN_TRAY_OFFSET := Vector2(0.0, 8.0)
const COIN_TARGET := Vector2(76.0, 75.0)
const COIN_SIZE := 6.0
const POWER_COIN_SIZE := 8.0
const COIN_FLIGHT_TIME := 0.72
const COIN_STAGGER_TIME := 0.09
const COIN_BURST_FRAC := 0.4
const COIN_BURST_RISE := 24.0
const COIN_BURST_SCATTER := 26.0
const COIN_TRAY_POP_TIME := 0.26
const COIN_FALL_STAGGER_TIME := 0.035
const COIN_TRAY_HOLD_TIME := 0.12
const COIN_TRAY_PILE_SCATTER := 22.0
const COIN_TRAY_PILE_DEPTH := 8.0
const MAX_VISIBLE_COINS := 40
const POWER_COIN_FLIGHT_TIME := 0.64
const POWER_PULSE_TIME := 0.36

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

@export_group("Run Balance")
@export var starting_spin_counter: int = DISPLAY_SPIN_BUDGET
@export var max_consumable_slots: int = Consumables.MAX_CONSUMABLE_SLOTS
@export var coins_per_power_restore: int = EconomyConst.LUCIDITY_COINS_PER_RESTORE
@export var default_run_power_ids: Array[String] = ["reroll"]

@export_group("Feedback")
## Grow-then-fade duration of the on-use +/- hint (issue #33). The animated
## HintLabel owns the +/- and corrupt colours; this only drives its lifetime.
@export_range(0.0, 5.0, 0.1) var hint_grow_time: float = 1.5
## Per-item +/- hint vocabulary shown when a stash item is used in-run. Mirrors
## the dealer scenes' pools (issue #31) so the same item reads the same way.
@export var use_hints: Dictionary = {
	"cons_cigarette": { "pos": "PAIRS", "neg": "BLIND" },
	"cons_white_powder": { "pos": "COPY", "neg": "LOSE" },
	"cons_focus": { "pos": "SHARP", "neg": "HIDDEN" },
	"cons_potion": { "pos": "BRAINS", "neg": "NO POWER" },
	"cons_tea": { "pos": "RESTORE", "neg": "RANDOM" },
	"item_water": { "pos": "REFRESHING", "neg": "WEAK" },
	"item_pill": { "pos": "WIN GUARANTEED", "neg": "NUMB" },
	"item_energy_drink": { "pos": "FREE", "neg": "LIMITED" },
	"item_cocktail": { "pos": "EASY", "neg": "COMPULSIVE" },
}

# ── machine reactions (issue #35) ────────────────────────────────────────────────
# The GDD "flatline result" is a REEL outcome (3 flatline symbols); the pinned
# "flatline" ENDING (neurons <= 0) keeps its serialized name for parity — only this
# new reel event is called flatline_result. Reaching fatal_flatline_count flatline
# results, OR the run_spin_length hard cap, ends the run (added alongside neurons<=0).
@export_group("Machine Reactions")
@export var fatal_flatline_count: int = 3
@export var run_spin_length: int = 35          # NEW hard run-length cap (added, not a replacement)
@export_range(0.1, 3.0, 0.1) var reaction_flash_time: float = 0.7
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
## Cocktail (issue #53): the machine spins by itself once the boost ends — heavy
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
var _bar_labels := {}
var _overlay: Control = null
var _dealer_overlay: Control = null
var _dealer_offer_popup: Control = null
var _dealer_message_label: Label = null
var _dealer_portrait_sprite: Sprite2D = null
var _score_overlay: Control = null
var _options_button: TextureButton = null
var _options_overlay: OptionsOverlay = null
var _score_button: Button = null
var _spin_button: Button = null
var _multiplier_buttons: Array[Button] = []
var _multiplier_sprite: Sprite2D = null
var _goal_fill_sprite: Sprite2D = null
var _life_fill_sprite: Sprite2D = null
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
var _dealer_drag_active := false
var _dealer_drag_node: Control = null
var _dealer_drag_id := ""
var _dealer_drag_kind := ""
var _dealer_drag_home := Vector2.ZERO
var _dealer_drag_moved := false
var _dealer_drag_press := Vector2.ZERO
var _burst_layer: Control = null     # score bursts spawn here (drawn on top)
var _coin_layer: Control = null      # lucidity / power coin flights spawn here
var _burst_prev_score := 0           # last announced result score (for power gain)
var _burst_prev_spin := -1           # spin the last announcement belonged to
var _coin_prev_lucidity := 0
var _display_lucidity := 0
var _lucidity_count_tween: Tween = null
var _power_coin_active := false
var _nudge_tween: Tween = null       # quick machine shake on lucidity/jackpot
var _jackpot_flash_tween: Tween = null
var _jackpot_flashing := false
var _font: FontFile = null
var _tex_cache := {}
var _sequence_lock_active := false
var _post_spin_sequence_active := false

# Reveal animation state
var _spinning_anim := false
var _anim_elapsed := 0.0
var _blur_accum := 0.0
var _spin_frame := 0
var _final_reels: Array = []
var _locked_reels_during_spin := [false, false, false]
var _use_full_spin_sheet := true
var _reel_stop_times := [0.55, 0.8, 1.05]
var _lever_anim_active := false
var _lever_anim_elapsed := 0.0
var _reroll_anim_active := false
var _reroll_reel_index := -1
var _reroll_elapsed := 0.0
var _reroll_accum := 0.0
var _flatline_countdown_active := false
var _flatline_countdown_elapsed := 0.0
var _flatline_total := 0
var _flatline_kept := 0
var _flatline_display := 0
var _flatline_score_label: Label = null
var _flatline_lost_label: Label = null
var _campaign_label: Label = null
var _flatline_meter: NeuronMeter = null # neuron meter shown on the flatline overlay
var _neuron_spend_label: Label = null
var _hint_layer: Control = null  # transient on-use +/- HintLabels (issue #33)
# Machine reactions (issue #35): dedupe key so one reel configuration reacts once,
# and a pending eye-triple reveal for the next spin.
var _last_reacted_reels: Array = []
var _last_reacted_spin := -1
var _reveal_reel_next_spin := -1
# Consumable visuals (issue #34).
var _fx_layer: Control = null              # host for all consumable effect nodes
var _tobacco_covers: Array = []            # per-reel dark cover while smoked out
var _tobacco_smoke: Array = []             # per-reel CPUParticles2D smoke
var _energy_edges: Control = null          # burning-edges frame (Energy Drink)
var _energy_pulse_tween: Tween = null
var _energy_fx_active := false
var _cocktail_shake_tween: Tween = null
var _potion_jump_tween: Tween = null
var _hidden_covers: Array = []             # per-reel "?" cover (White Powder)
var _hide_result_active := false           # the displayed result is hidden
var _blur_covers: Array = []               # per-reel frost cover (Serum, issue #53)
var _blur_result_active := false           # the displayed result renders blurry
var _serum_picker: Control = null          # Serum symbol-pick overlay (issue #53)
var _compulsive_queued := false            # cocktail auto-spin pending (issue #53)
var _compulsive_overlay: ColorRect = null  # red overlay during the compulsive spin

func _ready() -> void:
	_font = _load_font("font/DTM-Sans.otf")
	_apply_balance_exports()
	# Draw order (back -> front): reel background -> symbols -> cabinet (with
	# transparent holes that mask symbol overflow) -> HUD -> spin button.
	_build_full_canvas_sprite("machine new view/reel_final_machine.png")
	_build_reel_animation_art()
	_build_reel_covers()
	_build_reels()
	_build_full_canvas_sprite("machine new view/final_machine.png")
	_build_tv_indicators()
	_build_machine_control_art()
	_build_hud()
	_build_spin_button()
	_build_multiplier_buttons()
	_build_power_buttons()
	_build_stash()
	_build_fx_layer() # before the burst/coin layers so rewards draw above effects
	_build_burst_layer()
	_build_coin_layer()
	_build_options_controls()
	_restore_options_overlay_if_requested()
	RunStateStore.state_changed.connect(_update_hud)
	_enter_run()
	_init_burst_tracking()

func _apply_balance_exports() -> void:
	if Engine.is_editor_hint():
		return
	RunStateStore.max_consumable_slots = maxi(1, max_consumable_slots)
	RunStateStore.coins_per_power_restore = maxi(1, coins_per_power_restore)

# ── asset loading (absolute path into ../assets) ──────────────────────────────────

static func _assets_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../assets/images")

func _load_texture(rel: String, mipmaps := false) -> Texture2D:
	return Assets.texture(rel, mipmaps)

func _load_font(rel: String) -> FontFile:
	return Assets.font(rel)

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
	if rel.ends_with("final_machine.png"):
		return "Cabinet"
	return ""

func _full_canvas_sheet_name(rel: String, frame: int) -> String:
	if rel.ends_with("wealth_track_final_machine.png"):
		return "WealthTrack"
	if rel.ends_with("health_track_final_machine.png"):
		return "HealthTrack"
	if rel.ends_with("multiplier_final_machine.png"):
		return "Multiplier"
	if rel.ends_with("lever_final_machine.png"):
		return "Lever"
	if rel.ends_with("jackpot_final_machine.png"):
		return "Jackpot"
	if rel.ends_with("lock_power.png"):
		return "LockPower%d" % frame
	if rel.ends_with("reroll_final_machine.png"):
		return "RerollPower"
	if rel.ends_with("shift_final_machine.png"):
		return "ShiftPower"
	if rel.ends_with("lock_final_machine.png"):
		return "MemoryPower"
	return ""

func _region_sprite_name(rel: String, rect: Dictionary) -> String:
	if rel.ends_with("wealth_fill_final_machine.png"):
		return "WealthFill"
	if rel.ends_with("health_fill_final_machine.png"):
		return "HealthFill"
	if rel.ends_with("reel_final_machine.png"):
		for i in REEL_HOLES.size():
			if float(rect["left"]) == float(REEL_HOLES[i]["left"]) and float(rect["top"]) == float(REEL_HOLES[i]["top"]):
				return "ReelCover%d" % i
	return ""

func _configure_full_canvas_sprite(spr: Sprite2D, tex: Texture2D, apply_transform := true) -> void:
	spr.texture = tex
	spr.centered = false
	if apply_transform:
		spr.position = Vector2.ZERO
		spr.scale = Vector2(SRC_W / tex.get_width(), SRC_H / tex.get_height())
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _configure_full_canvas_sheet(spr: Sprite2D, tex: Texture2D, hframes: int, frame: int, apply_transform := true) -> void:
	spr.texture = tex
	spr.hframes = hframes
	spr.frame = frame
	spr.centered = false
	var frame_w := float(tex.get_width()) / float(hframes)
	if apply_transform:
		spr.position = Vector2.ZERO
		spr.scale = Vector2(SRC_W / frame_w, SRC_H / float(tex.get_height()))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _build_full_canvas_sprite(rel: String) -> void:
	var tex := _load_texture(rel, true)
	if tex == null:
		# Only the cabinet gets a visible fallback so the scene isn't blank.
		if rel.ends_with("/final_machine.png"):
			var fallback := ColorRect.new()
			fallback.color = Color(0.06, 0.05, 0.08)
			fallback.size = Vector2(SRC_W, SRC_H)
			add_child(fallback)
		return
	var name := _full_canvas_name(rel)
	var spr := _authored_sprite(name) if name != "" else null
	var authored := spr != null
	if spr == null:
		spr = Sprite2D.new()
		if name != "":
			spr.name = name
		add_child(spr)
	_configure_full_canvas_sprite(spr, tex, not authored)

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
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	if not authored:
		spr.position = Vector2(rect["left"], rect["top"])
	spr.region_enabled = true
	spr.region_rect = Rect2(
		rect["left"] * ASSET_SCALE,
		rect["top"] * ASSET_SCALE,
		rect["width"] * ASSET_SCALE,
		rect["height"] * ASSET_SCALE
	)
	if not authored:
		spr.scale = Vector2(1.0 / ASSET_SCALE, 1.0 / ASSET_SCALE)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	_build_full_canvas_sheet("machine new view/wealth_track_final_machine.png", 1)
	_goal_fill_sprite = _build_region_sprite("machine new view/wealth_fill_final_machine.png", WEALTH_BAR)
	_build_full_canvas_sheet("machine new view/health_track_final_machine.png", 1)
	_life_fill_sprite = _build_region_sprite("machine new view/health_fill_final_machine.png", HEALTH_BAR)

func _build_machine_control_art() -> void:
	_multiplier_sprite = _build_full_canvas_sheet("machine new view/multiplier_final_machine.png", MULTIPLIER_FRAME_COUNT)
	_lever_sprite = _build_full_canvas_sheet("machine new view/lever_final_machine.png", LEVER_FRAME_COUNT)
	_jackpot_sprite = _build_full_canvas_sheet("machine new view/jackpot_final_machine.png", JACKPOT_FRAME_COUNT)
	_set_sheet_frame(_jackpot_sprite, 0)
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
	for id in ["reroll", "shift", "memory"]:
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
func _build_reel_covers() -> void:
	for i in 3:
		var cover := _build_region_sprite("machine new view/reel_final_machine.png", REEL_HOLES[i])
		if cover != null:
			cover.visible = false
		_reel_covers.append(cover)

func _set_reel_cover(index: int, visible: bool) -> void:
	if index < _reel_covers.size() and _reel_covers[index] != null:
		_reel_covers[index].visible = visible

# A reel lands: mask its blur, show its final symbol, stop animating that reel.
func _reveal_reel(index: int) -> void:
	_set_spin_reel_visible(index, false)
	_set_reel_cover(index, true)
	_set_reel_symbol(index, String(_final_reels[index]))
	_set_reel_visible(index, true)
	_set_hidden_cover(index, _hide_result_active) # White Powder masks the reveal (issue #34)
	_set_blur_cover(index, _blur_result_active)   # Serum frost blurs the reveal (issue #53)

func _configure_reel_sprite(s: Sprite2D, pos: Vector2, alpha: float, apply_position := true) -> void:
	s.centered = true
	if apply_position:
		s.position = pos
	s.modulate = Color(1, 1, 1, alpha)
	# Symbols are authored large and drawn at 12-16px, so downscale with
	# linear+mipmaps (supersampled, crisp) rather than nearest (aliased).
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

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
	_reel_top_sprites[index].visible = visible
	_reel_bottom_sprites[index].visible = visible

func _set_all_reels_visible(visible: bool) -> void:
	for i in _reel_sprites.size():
		_set_reel_visible(i, visible)

# Symbol above/below `sym` in the canonical cycle (book sits outside it).
func _reel_neighbours(sym: String) -> Dictionary:
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
	var tex := _load_texture("symbols/%s.png" % symbol_id, true) # mipmaps for crisp downscale
	if tex == null:
		return
	s.texture = tex
	var k := minf(1.0, target_h / float(tex.get_height()))
	s.scale = Vector2(k, k)

func _set_reel_symbol(index: int, symbol_id: String) -> void:
	_apply_symbol(_reel_sprites[index], symbol_id, STRIP_CENTER_H)
	var nb := _reel_neighbours(symbol_id)
	_apply_symbol(_reel_top_sprites[index], String(nb["top"]), STRIP_ADJ_H)
	_apply_symbol(_reel_bottom_sprites[index], String(nb["bottom"]), STRIP_ADJ_H)

func _build_hud() -> void:
	_build_score_button()
	_build_campaign_label()
	_build_hint_layer()
	_build_bar_label("goal", Vector2(43.0, 64.0), Color(0.9, 0.85, 0.45))
	_build_bar_label("life", Vector2(43.0, 85.0), Color(0.75, 1.0, 0.8))

func _build_score_button() -> void:
	_score_button = _authored_button("ScoreButton")
	var authored := _score_button != null
	if _score_button == null:
		_score_button = Button.new()
		_score_button.name = "ScoreButton"
		add_child(_score_button)
	_score_button.text = "SCORES"
	if not authored:
		_score_button.size = Vector2(41.0, 15.0)
		# Pulled off the top-right corner so it isn't glued to the edge.
		_score_button.position = Vector2(160.0 - _score_button.size.x - 9.0, 9.0)
	_score_button.flat = false
	_score_button.focus_mode = Control.FOCUS_NONE
	_score_button.add_theme_font_size_override("font_size", 7)
	if _font != null:
		_score_button.add_theme_font_override("font", _font)
	Assets.skin_negative_button(_score_button)
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
	Assets.skin_icon_button(_options_button, SETTINGS_ASSET, 2)
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
	_set_score_button_locked(_sequence_lock_active or _dealer_offer_popup != null)

func _build_campaign_label() -> void:
	var bottom_hud := get_node_or_null("BottomHudLayer") as Control
	if bottom_hud == null:
		bottom_hud = Control.new()
		bottom_hud.name = "BottomHudLayer"
		bottom_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bottom_hud.size = Vector2(160.0, 320.0)
		bottom_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom_hud.z_index = 120
		add_child(bottom_hud)
	_campaign_label = bottom_hud.get_node_or_null("neuron_number") as Label
	var legacy_label := get_node_or_null("neuron_number") as Label
	if _campaign_label == null and legacy_label != null:
		legacy_label.reparent(bottom_hud)
		_campaign_label = legacy_label
	if _campaign_label == null:
		_campaign_label = Label.new()
		_campaign_label.name = "neuron_number"
		bottom_hud.add_child(_campaign_label)
		_campaign_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_campaign_label.offset_left = -46.5
		_campaign_label.offset_top = -14.0
		_campaign_label.offset_right = 46.5
		_campaign_label.offset_bottom = -4.0
	_campaign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campaign_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_campaign_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_campaign_label.add_theme_font_size_override("font_size", 6)
	if _font != null:
		_campaign_label.add_theme_font_override("font", _font)
	_campaign_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	_campaign_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_campaign_label.add_theme_constant_override("outline_size", 1)
	_campaign_label.text = ""
	# The neuron meter no longer lives on the in-run HUD — it shows on the start
	# menu and the flatline overlay only. The label stays as the feedback anchor.

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

func _build_bar_label(id: String, pos: Vector2, color: Color) -> void:
	var node_name := "GoalLabel" if id == "goal" else "HealthLabel"
	var l := get_node_or_null(node_name) as Label
	var authored := l != null
	if l == null:
		l = Label.new()
		l.name = node_name
		add_child(l)
	if not authored:
		l.position = pos
	if id == "life" and not authored:
		l.size = Vector2(float(TV_SCREEN["left"]) + float(TV_SCREEN["width"]) - pos.x, 10.0)
	l.add_theme_font_size_override("font_size", 6)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	l.text = ""
	_bar_labels[id] = l

func _build_spin_button() -> void:
	_spin_button = _make_or_bind_hit_button("SpinButton", LEVER_HIT, _do_spin)

# ── run loop ──────────────────────────────────────────────────────────────────────

# Entered from the shop (which already started the run) or standalone. If no run is
# in progress, begin one from meta so the machine works on its own too.
func _enter_run() -> void:
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
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_set_stash_tray_visible(true)
	_stop_flatline_countdown()
	_close_score_table()
	_clear_targeting()
	_set_hidden_result_active(false)
	_set_blur_result_active(false)
	_close_serum_picker()
	_hide_compulsive_overlay()
	_compulsive_queued = false
	_last_reacted_reels = []
	_last_reacted_spin = -1
	_reveal_reel_next_spin = -1
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
	_update_hud()
	_refresh_lock_art()
	_refresh_jackpot_lamp(false)

func _to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func _to_dealer() -> void:
	get_tree().change_scene_to_file(DEALER_SCENE)

func _do_spin(compulsive := false) -> void:
	if _spinning_anim or _reroll_anim_active or _sequence_lock_active:
		return
	if _dealer_offer_popup != null:
		return
	_clear_targeting()
	_close_score_table()
	_copy_source = -1 # abandon any half-armed white-powder copy
	_refresh_jackpot_lamp(false)
	var locked_before := RunStateStore.lockedReels.duplicate()
	# White Powder (issue #34): hideResultSpins is consumed inside spin(), so read it
	# before spinning — this spin's result reveals as "?" covers.
	var hide_this_spin := RunStateStore.hideResultSpins > 0
	# Serum (issue #53): blurReelsSpins is consumed inside spin() too — this spin's
	# result renders behind the blur frost.
	var blur_this_spin := RunStateStore.blurReelsSpins > 0
	var result: Variant = RunStateStore.spin(compulsive)
	if result == null:
		return
	_set_hidden_result_active(consumable_fx_enabled and hidden_fx_enabled and hide_this_spin)
	_set_blur_result_active(consumable_fx_enabled and blur_this_spin)
	_final_reels = result["reels"]
	# Third-reel tension: if reels 1 & 2 will match, hold reel 3 a little longer.
	var tension := TENSION_DELAY if String(_final_reels[0]) == String(_final_reels[1]) else 0.0
	_reel_stop_times = [0.55, 0.8, 1.05 + tension]
	# Eye triple: the revealed reel was already committed at tap time (issue #53);
	# reels 0/1 also stop early (reel 2 stays last: reveal-complete keys off its time).
	if _reveal_reel_next_spin >= 0 and _reveal_reel_next_spin < 2:
		_reel_stop_times[_reveal_reel_next_spin] = 0.2
	_reveal_reel_next_spin = -1
	_start_lever_pull()
	_start_reel_spin_animation(locked_before)
	_spinning_anim = true
	_anim_elapsed = 0.0
	_blur_accum = 0.0
	_spin_button.disabled = true

func _process(delta: float) -> void:
	if _lever_anim_active:
		_step_lever(delta)
	if _reroll_anim_active:
		_step_reroll(delta)
	if _flatline_countdown_active:
		_step_flatline_countdown(delta)
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
	_locked_reels_during_spin = locked_before.duplicate()
	# Play the authored spin-blur sheet as three clipped reel sprites. Each clip
	# hides the moment that reel's final symbol lands.
	_use_full_spin_sheet = false
	_spin_frame = 0
	if _spin_sheet_sprite != null:
		_spin_sheet_sprite.visible = false
	for i in 3:
		var locked := bool(_locked_reels_during_spin[i])
		_set_reel_visible(i, locked)
		_set_reel_cover(i, locked)
		_set_spin_reel_frame(i, _spin_frame)
		_set_spin_reel_visible(i, not locked)

func _start_lever_pull() -> void:
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
	if _post_spin_sequence_active:
		return
	_post_spin_sequence_active = true
	_run_post_reveal_sequence()

func _run_post_reveal_sequence() -> void:
	RunStateStore.set_spinning(false)
	_set_sequence_lock(true)
	_update_hud()
	_refresh_lock_art()
	_refresh_jackpot_lamp()
	_apply_machine_reactions(false)  # flatline-result / triple reactions (issue #35)
	_play_potion_spin_fx()           # potion hop + rolled-effect popup (issue #34)
	var reward_time := _emit_score_burst(null) # normal spin: source reel derived from the result
	# Dealer may appear between spins (logic + offers are vector-pinned in dealer.gd).
	RunStateStore.check_dealer_trigger()
	var dealer_pending := RunStateStore.dealerIncoming
	if reward_time > 0.0:
		await get_tree().create_timer(reward_time).timeout
	# Instant death from stacked flatline results takes precedence (issue #35).
	if _check_flatline_instant_death():
		_post_spin_sequence_active = false
		return
	if _check_ending():
		_post_spin_sequence_active = false
		_set_sequence_lock(false)
		return
	# New hard run-length cap ends the run after the wealth/neuron checks.
	if _check_spin_cap_ending():
		_post_spin_sequence_active = false
		return
	if dealer_pending:
		_show_dealer_incoming()
	else:
		_set_sequence_lock(false)
		# Cocktail (issue #53): once the boost ends the machine takes the compulsive
		# spin by itself — heavy vibration + red overlay, no player input needed.
		if RunStateStore.compulsiveSpinSkips > 0:
			_queue_compulsive_spin()
	_post_spin_sequence_active = false

# ── cocktail compulsive takeover (issue #53) ─────────────────────────────────────

func _queue_compulsive_spin() -> void:
	if _compulsive_queued or RunStateStore.runPhase != "running":
		return
	_compulsive_queued = true
	_play_compulsive_takeover()

func _play_compulsive_takeover() -> void:
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree() or RunStateStore.runPhase != "running" \
			or RunStateStore.compulsiveSpinSkips <= 0 or _spinning_anim:
		_compulsive_queued = false
		_hide_compulsive_overlay()
		return
	if compulsive_fx_enabled:
		_show_compulsive_overlay()
		_play_compulsive_shake()
		await get_tree().create_timer(0.5).timeout
	_compulsive_queued = false
	if not is_inside_tree() or RunStateStore.runPhase != "running":
		_hide_compulsive_overlay()
		return
	_do_spin(true)
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
	_refresh_tv_indicators()
	_refresh_campaign_label()
	_refresh_controls()
	_refresh_consumable_fx()

# The authored neuron_number Label stays as an anchor/editor placeholder and
# renders no text; the neuron meter lives on the start menu / flatline overlay.
func _refresh_campaign_label() -> void:
	if _campaign_label != null:
		_campaign_label.text = ""

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
		_set_reel_symbol(i, String(lr["reels"][i]))
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
	if RunStateStore.lucidityCoins < _display_lucidity:
		_set_display_lucidity(RunStateStore.lucidityCoins)
	# The wealth bar targets the campaign wealth goal (2000) — the same threshold
	# the wealth ending checks — not the old lucidity objective.
	var goal_ratio := clampf(float(_display_lucidity) / float(maxi(1, campaign_goal_score)), 0.0, 1.0)
	_set_bar_fill(_goal_fill_sprite, WEALTH_BAR, goal_ratio)
	var start_n := maxi(1, RunStateStore.startingNeurons)
	var life_ratio := clampf(float(RunStateStore.neurons) / float(start_n), 0.0, 1.0)
	_set_bar_fill(_life_fill_sprite, HEALTH_BAR, life_ratio)
	if _bar_labels.has("goal"):
		_bar_labels["goal"].text = "%d/%d" % [_display_lucidity, campaign_goal_score]
	if _bar_labels.has("life"):
		_bar_labels["life"].text = "SPINS LEFT: %d" % _display_remaining_spins(life_ratio)

func _display_remaining_spins(life_ratio: float) -> int:
	if RunStateStore.neurons <= 0:
		return 0
	var spin_budget := maxi(1, starting_spin_counter)
	return clampi(int(ceili(life_ratio * float(spin_budget))), 1, spin_budget)

func _set_bar_fill(spr: Sprite2D, rect: Dictionary, ratio: float) -> void:
	if spr == null:
		return
	var width := maxf(0.0, float(rect["width"]) * ratio)
	spr.visible = width > 0.0
	spr.region_rect = Rect2(
		float(rect["left"]) * ASSET_SCALE,
		float(rect["top"]) * ASSET_SCALE,
		width * ASSET_SCALE,
		float(rect["height"]) * ASSET_SCALE
	)

func _set_display_lucidity(value: int) -> void:
	_display_lucidity = maxi(0, value)
	if _bar_labels.has("goal"):
		_bar_labels["goal"].text = "%d/%d" % [_display_lucidity, campaign_goal_score]
	var goal_ratio := clampf(float(_display_lucidity) / float(maxi(1, campaign_goal_score)), 0.0, 1.0)
	_set_bar_fill(_goal_fill_sprite, WEALTH_BAR, goal_ratio)

func _start_lucidity_countup(target: int, visible_coin_count: int, first_arrival_time: float) -> void:
	if _lucidity_count_tween != null and _lucidity_count_tween.is_valid():
		_lucidity_count_tween.kill()
	var from_value := _display_lucidity
	if target <= from_value:
		_set_display_lucidity(target)
		return
	var count_time := clampf(0.22 + float(visible_coin_count) * 0.025, 0.35, 1.15)
	_lucidity_count_tween = create_tween()
	_lucidity_count_tween.tween_interval(first_arrival_time)
	_lucidity_count_tween.tween_method(_drive_lucidity_count.bind(from_value, target), 0.0, 1.0, count_time)
	_lucidity_count_tween.tween_callback(_set_display_lucidity.bind(target))

func _drive_lucidity_count(t: float, from_value: int, to_value: int) -> void:
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	_set_display_lucidity(int(round(lerpf(float(from_value), float(to_value), eased))))

func _refresh_jackpot_lamp(use_result := true) -> void:
	if _jackpot_sprite == null or _jackpot_flashing:
		return # don't fight an active flash
	var lit := false
	if use_result and RunStateStore.lastResult != null:
		lit = bool(RunStateStore.lastResult.get("isJackpot", false))
	_set_sheet_frame(_jackpot_sprite, 1 if lit else 0)

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
	_set_sheet_frame(_jackpot_sprite, 1 if (int(t * 12.0) % 2 == 0) else 0)

# Quick horizontal machine shake — feedback on a Lucidity gain / jackpot.
func _nudge(strength: float) -> void:
	if _nudge_tween != null and _nudge_tween.is_valid():
		_nudge_tween.kill()
	position = Vector2.ZERO
	_nudge_tween = create_tween()
	_nudge_tween.tween_property(self, "position:x", strength, 0.04)
	_nudge_tween.tween_property(self, "position:x", -strength * 0.6, 0.04)
	_nudge_tween.tween_property(self, "position:x", 0.0, 0.05)

# ── score bursts (visual only — mirrors src/components/ScoreBurst.tsx) ──────────────

func _build_burst_layer() -> void:
	_burst_layer = _authored_control("BurstLayer")
	if _burst_layer == null:
		_burst_layer = Control.new()
		_burst_layer.name = "BurstLayer"
		add_child(_burst_layer)
	_burst_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_burst_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_coin_layer() -> void:
	_coin_layer = _authored_control("CoinLayer")
	if _coin_layer == null:
		_coin_layer = Control.new()
		_coin_layer.name = "CoinLayer"
		add_child(_coin_layer)
	_coin_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	_set_display_lucidity(RunStateStore.lucidityCoins)

# Normal-spin source reel: a pair on the first two reels pops on reel 2 (index 1);
# every other win reads from reel 3 (index 2).
func _derive_source_reel(reels: Array) -> int:
	return 1 if (String(reels[0]) == String(reels[1]) and String(reels[1]) != String(reels[2])) else 2

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
	var color: Color = MULT_COLORS[clampi(int(RunStateStore.lastEffectiveBet), 1, 3)]
	var lucidity_gain := maxi(0, int(RunStateStore.lucidityCoins) - _coin_prev_lucidity)
	_coin_prev_lucidity = int(RunStateStore.lucidityCoins)
	if lucidity_gain > 0:
		reward_time = maxf(reward_time, _spawn_lucidity_coins(lucidity_gain, int(RunStateStore.lucidityCoins)))

	# Cocktail miss: one "+rarity" mini-burst from each reel.
	if is_new_spin and win_type == "miss" and bool(lr.get("cocktailApplied", false)):
		for i in 3:
			_spawn_burst("", int(Symbols.RARITY.get(String(reels[i]), 0)), COCKTAIL_COLOR, i)
		_nudge(0.8)
		return maxf(reward_time, BURST_TIME)

	# A rescore that doesn't increase the score must NOT pop (gain <= 0).
	if gain > 0 and win_type != "miss":
		# Jackpot is special (issue #22): a large GOLDEN number rising out of the
		# machine centre — never a reel-anchored pair/triple-style burst.
		if win_type == "jackpot":
			_spawn_jackpot_burst(score)
			_flash_jackpot_lamp()
			_nudge(2.2)
			return maxf(reward_time, maxf(BURST_TIME * 1.25, JACKPOT_FLASH_TIME))
		var label := "TRIPLE" if win_type == "triple" else ("PAIR" if win_type == "pair" else "BONUS")
		var reel := int(source_reel) if source_reel != null else _derive_source_reel(reels)
		_spawn_burst(label, score, color, reel)
		_nudge(1.0)
		reward_time = maxf(reward_time, BURST_TIME)
		# Cocktail + pair: surface the unpaired reel's rarity gain from its own reel.
		if is_new_spin and bool(lr.get("cocktailApplied", false)) and win_type == "pair":
			var solo := _solo_reel(reels)
			if solo != -1:
				_spawn_burst("", int(Symbols.RARITY.get(String(reels[solo]), 0)), COCKTAIL_COLOR, solo)
	return reward_time

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

func _spawn_lucidity_coins(gain: int, target_lucidity: int) -> float:
	if _coin_layer == null:
		_set_display_lucidity(target_lucidity)
		return 0.0
	var tex := _load_texture("ui/coin.png", true)
	if tex == null:
		_set_display_lucidity(target_lucidity)
		return 0.0
	var count := mini(MAX_VISIBLE_COINS, gain)
	if count <= 0:
		_set_display_lucidity(target_lucidity)
		return 0.0
	var stagger_time := _coin_fall_stagger_time_for_count(count)
	var fall_phase_time := float(count - 1) * stagger_time + COIN_TRAY_POP_TIME
	var travel_start_time := fall_phase_time + COIN_TRAY_HOLD_TIME
	var flight_time := _coin_flight_time_for_count(count)
	var total_time := travel_start_time + flight_time
	var cash_tray := COIN_TRAY + CASH_COIN_TRAY_OFFSET
	for i in count:
		var coin := Sprite2D.new()
		coin.texture = tex
		coin.centered = true
		var start_pos := cash_tray
		var pile_pos := cash_tray + Vector2(
			(randf() - 0.5) * COIN_TRAY_PILE_SCATTER,
			-randf() * COIN_TRAY_PILE_DEPTH
		)
		var burst_pos := Vector2(
			cash_tray.x + (randf() - 0.5) * COIN_BURST_SCATTER,
			cash_tray.y - COIN_BURST_RISE
		)
		coin.position = start_pos
		var coin_scale := COIN_SIZE / float(maxi(1, tex.get_width()))
		coin.scale = Vector2(coin_scale, coin_scale)
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		coin.modulate.a = 0.0
		_coin_layer.add_child(coin)
		var fall_delay := float(i) * stagger_time
		var tw := create_tween()
		tw.tween_interval(fall_delay)
		tw.tween_method(_drive_lucidity_coin_tray_pop.bind(coin, start_pos, pile_pos), 0.0, 1.0, COIN_TRAY_POP_TIME)
		tw.tween_interval(maxf(0.0, travel_start_time - fall_delay - COIN_TRAY_POP_TIME))
		tw.tween_method(_drive_lucidity_coin.bind(coin, pile_pos, burst_pos, COIN_TARGET), 0.0, 1.0, flight_time)
		tw.tween_callback(coin.queue_free)
	var value_tw := create_tween()
	value_tw.tween_interval(total_time)
	value_tw.tween_callback(_set_display_lucidity.bind(target_lucidity))
	return total_time

func _coin_flight_time_for_count(count: int) -> float:
	var pressure := clampf(float(maxi(0, count - 8)) / float(maxi(1, MAX_VISIBLE_COINS - 8)), 0.0, 1.0)
	return lerpf(COIN_FLIGHT_TIME, 0.48, pressure)

func _coin_stagger_time_for_count(count: int) -> float:
	if count <= 8:
		return COIN_STAGGER_TIME
	var pressure := clampf(float(count - 8) / float(maxi(1, MAX_VISIBLE_COINS - 8)), 0.0, 1.0)
	return lerpf(COIN_STAGGER_TIME, 0.018, pressure)

func _coin_fall_stagger_time_for_count(count: int) -> float:
	if count <= 8:
		return COIN_FALL_STAGGER_TIME
	var pressure := clampf(float(count - 8) / float(maxi(1, MAX_VISIBLE_COINS - 8)), 0.0, 1.0)
	return lerpf(COIN_FALL_STAGGER_TIME, 0.012, pressure)

func _drive_lucidity_coin_tray_pop(t: float, coin: Sprite2D, from_pos: Vector2, pile_pos: Vector2) -> void:
	if not is_instance_valid(coin):
		return
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var pop := sin(t * PI) * 6.0
	coin.position = from_pos.lerp(pile_pos, eased) + Vector2(0.0, -pop)
	coin.modulate.a = minf(t / 0.12, 1.0)

func _drive_lucidity_coin(t: float, coin: Sprite2D, from_pos: Vector2, burst_pos: Vector2, to_pos: Vector2) -> void:
	if not is_instance_valid(coin):
		return
	var p: Vector2
	if t < COIN_BURST_FRAC:
		p = from_pos.lerp(burst_pos, t / COIN_BURST_FRAC)
	else:
		p = burst_pos.lerp(to_pos, (t - COIN_BURST_FRAC) / (1.0 - COIN_BURST_FRAC))
	coin.position = p
	if t < 0.1:
		coin.modulate.a = t / 0.1
	elif t < 0.85:
		coin.modulate.a = 1.0
	else:
		coin.modulate.a = 1.0 - ((t - 0.85) / 0.15)

func _try_start_power_coin_flow() -> void:
	if _power_coin_active or _spinning_anim or _reroll_anim_active or _sequence_lock_active:
		return
	if RunStateStore.pendingPowerRestores.is_empty():
		return
	_start_power_coin_flow(String(RunStateStore.pendingPowerRestores[0]))

func _start_power_coin_flow(power_id: String) -> void:
	if _coin_layer == null:
		return
	var tex := _load_texture("ui/power_coin.png", true)
	if tex == null:
		RunStateStore.commit_power_restore(power_id)
		return
	_power_coin_active = true
	var coin := Sprite2D.new()
	coin.texture = tex
	coin.centered = true
	coin.position = COIN_TRAY
	var power_scale := POWER_COIN_SIZE / float(maxi(1, tex.get_width()))
	coin.scale = Vector2(power_scale, power_scale)
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	coin.modulate.a = 0.0
	_coin_layer.add_child(coin)
	var target := _power_center(power_id)
	var tw := create_tween()
	tw.tween_method(_drive_power_coin.bind(coin, COIN_TRAY, target), 0.0, 1.0, POWER_COIN_FLIGHT_TIME)
	tw.tween_callback(_finish_power_coin_flow.bind(power_id, coin, target))

func _power_center(power_id: String) -> Vector2:
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

func _finish_power_coin_flow(power_id: String, coin: Node, target: Vector2) -> void:
	if is_instance_valid(coin):
		coin.queue_free()
	RunStateStore.commit_power_restore(power_id)
	_spawn_power_pulse(target)
	_power_coin_active = false

func _spawn_power_pulse(center: Vector2) -> void:
	if _coin_layer == null:
		return
	var pulse := ColorRect.new()
	pulse.color = Color(1.0, 0.88, 0.22, 0.38)
	pulse.size = Vector2(18.0, 18.0)
	pulse.position = center - pulse.size * 0.5
	pulse.pivot_offset = pulse.size * 0.5
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_layer.add_child(pulse)
	var tw := create_tween()
	tw.tween_method(_drive_power_pulse.bind(pulse), 0.0, 1.0, POWER_PULSE_TIME)
	tw.tween_callback(pulse.queue_free)

func _drive_power_pulse(t: float, pulse: ColorRect) -> void:
	if not is_instance_valid(pulse):
		return
	var s := lerpf(0.6, 1.35, t)
	pulse.scale = Vector2(s, s)
	pulse.modulate.a = 1.0 - t

# ── bet / powers / stash controls ─────────────────────────────────────────────────

func _build_multiplier_buttons() -> void:
	for m in [1, 2, 3]:
		var cx := float(MULT_BADGE_CENTERS[m - 1])
		var b := _make_or_bind_hit_button("MultiplierButton%d" % m, {
			"left": cx - 8.0,
			"top": MULT_STRIP["top"],
			"width": 16.0,
			"height": MULT_STRIP["height"],
		}, _select_bet_multiplier.bind(m))
		_multiplier_buttons.append(b)

func _select_bet_multiplier(m: int) -> void:
	if _sequence_lock_active:
		return
	if not RunStateStore._can_act():
		return
	if _is_multiplier_locked(m):
		return
	RunStateStore.set_bet_multiplier(m)

func _highest_affordable_multiplier() -> int:
	if RunStateStore.forcedRandomBetSpins > 0:
		return 2
	var sedative_next := Economy.has_sedative(RunStateStore.ownedUpgrades) \
		and RunStateStore.freeSpinsRemaining <= 0 and (RunStateStore.spinCount + 1) % 3 == 0
	var no_neuron_cost := RunStateStore.freeSpinsRemaining > 0 or RunStateStore.decaySkips > 0 or sedative_next
	if no_neuron_cost:
		return 3
	var base_decay := Economy.compute_neuron_decay(RunStateStore.ownedUpgrades)
	if base_decay <= 0:
		return 3
	return mini(3, maxi(1, int(ceili(float(RunStateStore.neurons) / float(base_decay)))))

func _is_multiplier_locked(m: int) -> bool:
	return m > _highest_affordable_multiplier()

func _refresh_multiplier_controls() -> void:
	var can_act := RunStateStore._can_act() and not _spinning_anim and not _reroll_anim_active \
		and _dealer_offer_popup == null and not _sequence_lock_active
	for i in _multiplier_buttons.size():
		var m := i + 1
		_multiplier_buttons[i].disabled = not can_act or _is_multiplier_locked(m)
	var affordable := _highest_affordable_multiplier()
	var effective := mini(RunStateStore.betMultiplier, affordable)
	var frame := 0
	if affordable <= 1:
		frame = 4
	elif affordable == 2:
		frame = 5 if effective == 2 else 3
	else:
		frame = effective - 1
	_set_sheet_frame(_multiplier_sprite, frame)

func _build_power_buttons() -> void:
	for id in ["reroll", "shift", "memory"]:
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
	if _sequence_lock_active or not RunStateStore._can_act() or _reroll_anim_active:
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

	var can_use := RunStateStore.runPhase == "running" and not _spinning_anim and not _reroll_anim_active \
		and RunStateStore.lastResult != null and RunStateStore.blockPowersSpins <= 0 \
		and _dealer_offer_popup == null and not _sequence_lock_active
	if _spin_button != null:
		_spin_button.disabled = _dealer_offer_popup != null or not RunStateStore._can_act() \
			or _spinning_anim or _reroll_anim_active or _sequence_lock_active
	if not _power_buttons.is_empty():
		var used: Array = RunStateStore.abilitiesUsed
		var owned: Array = RunStateStore.ownedUpgrades
		for id in ["reroll", "shift", "memory"]:
			var visible := _power_owned(id, owned)
			var b: Button = _power_buttons[id]
			b.visible = visible
			b.disabled = not visible
			if visible:
				b.disabled = not (can_use and not used.has(id))
			var frame := POWER_FRAME_DISABLED if b.disabled else POWER_FRAME_AVAILABLE
			if id == _targeting_power_id and not b.disabled:
				frame = POWER_FRAME_SELECTED
			var sprite: Sprite2D = _power_sprites[id]
			if sprite != null:
				sprite.visible = visible
			_set_sheet_frame(sprite, frame)

	var slots := _stash_slots()
	var usable := (RunStateStore._can_act() and not _reroll_anim_active and not _sequence_lock_active) \
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
	if id == "reroll":
		return default_run_power_ids.has("reroll")
	if id == "shift":
		return owned.has("perm_shift")
	if id == "memory":
		return owned.has("perm_memory")
	return false

func _short_name(consumable_id: String) -> String:
	return consumable_id.replace("cons_", "").replace("item_", "").substr(0, 4)

func _icon_for(id: String) -> Texture2D:
	return _load_texture(ITEM_ICONS.get(id, "items/consumable_placeholder.png"))

# ── power targeting ────────────────────────────────────────────────────────────────

func _on_power_pressed(id: String) -> void:
	if _sequence_lock_active:
		return
	if _targeting_layer != null:
		_clear_targeting()
		_refresh_controls()
		return
	if id == "shift":
		_arm_shift_targets()
	else:
		# reroll / memory pick a single reel.
		_arm_reel_picker(func(reel_index: int) -> void: _apply_reel_power(id, reel_index))
	_targeting_power_id = id
	_refresh_controls()

# Builds a per-reel picker overlay; each reel button calls cb(reel_index).
func _arm_reel_picker(cb: Callable) -> void:
	_clear_targeting()
	_targeting_layer = Control.new()
	_targeting_layer.size = Vector2(SRC_W, SRC_H)
	_targeting_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE # only its buttons capture clicks
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
	if _sequence_lock_active:
		return
	if power_id == "reroll":
		if RunStateStore.reroll_reel(reel_index):
			_clear_targeting()
			_start_reroll_animation(reel_index)
			_update_hud()
			return
	elif power_id == "memory":
		RunStateStore.lock_reel(reel_index)
	_clear_targeting()
	_refresh_reels_from_state()
	_update_hud()
	_refresh_jackpot_lamp()

func _start_reroll_animation(reel_index: int) -> void:
	_reroll_anim_active = true
	_reroll_reel_index = reel_index
	_reroll_elapsed = 0.0
	_reroll_accum = 0.0
	_set_reel_visible(reel_index, true)
	if _spin_button != null:
		_spin_button.disabled = true
	_set_reel_symbol(reel_index, VISIBLE_SYMBOLS[randi() % VISIBLE_SYMBOLS.size()])

func _step_reroll(delta: float) -> void:
	_reroll_elapsed += delta
	_reroll_accum += delta
	if _reroll_accum >= SPIN_FRAME_TIME:
		_reroll_accum = 0.0
		_set_reel_symbol(_reroll_reel_index, VISIBLE_SYMBOLS[randi() % VISIBLE_SYMBOLS.size()])
	if _reroll_elapsed >= REROLL_REEL_DURATION:
		_reroll_anim_active = false
		var lr: Variant = RunStateStore.lastResult
		if lr != null:
			_set_reel_symbol(_reroll_reel_index, String(lr["reels"][_reroll_reel_index]))
		var rerolled := _reroll_reel_index
		_reroll_reel_index = -1
		if _spin_button != null:
			_spin_button.disabled = false
		_update_hud()
		_refresh_jackpot_lamp()
		_apply_machine_reactions(true)  # reroll may form a triple (issue #35)
		if _check_flatline_instant_death():
			return
		_play_reward_sequence(rerolled) # reroll burst pops from the rerolled reel

func _apply_shift(reel_index: int, direction: int) -> void:
	if _sequence_lock_active:
		return
	RunStateStore.move_reel(reel_index, direction)
	_clear_targeting()
	_refresh_reels_from_state()
	_update_hud()
	_refresh_jackpot_lamp()
	_apply_machine_reactions(true)  # shift may form a triple (issue #35)
	if _check_flatline_instant_death():
		return
	_play_reward_sequence(reel_index) # shift burst pops from the shifted reel

func _play_reward_sequence(source_reel: int) -> void:
	_set_sequence_lock(true)
	var reward_time := _emit_score_burst(source_reel)
	if reward_time > 0.0:
		await get_tree().create_timer(reward_time).timeout
	_set_sequence_lock(false)

func _clear_targeting() -> void:
	if _targeting_layer != null:
		_targeting_layer.queue_free()
		_targeting_layer = null
	_targeting_power_id = ""

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
	if _sequence_lock_active:
		return
	if _dealer_offer_popup != null:
		return
	if _score_overlay != null:
		_close_score_table()
		return
	_clear_targeting()
	_score_overlay = Control.new()
	_score_overlay.size = Vector2(SRC_W, SRC_H)
	add_child(_score_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.size = Vector2(SRC_W, SRC_H)
	_score_overlay.add_child(dim)

	var panel := ColorRect.new()
	panel.color = Color(0.045, 0.035, 0.075, 0.96)
	panel.position = Vector2(9.0, 26.0)
	panel.size = Vector2(142.0, 260.0)
	_score_overlay.add_child(panel)

	_score_label(_score_overlay, "SCORES", Vector2(17.0, 34.0), 12, Color(1.0, 0.82, 0.28))
	_score_label(_score_overlay, "BEST", Vector2(17.0, 52.0), 7, Color(0.68, 0.86, 1.0))
	_score_label(_score_overlay, str(int(MetaStateStore.history.get("bestScoreRun", 0))), Vector2(63.0, 52.0), 7, Color(0.75, 1.0, 0.8), 72.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_score_label(_score_overlay, "RUNS", Vector2(17.0, 64.0), 7, Color(0.68, 0.86, 1.0))
	_score_label(_score_overlay, str(int(MetaStateStore.history.get("runsPlayed", 0))), Vector2(63.0, 64.0), 7, Color(0.75, 1.0, 0.8), 72.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_score_label(_score_overlay, "CREDITS", Vector2(17.0, 76.0), 7, Color(0.68, 0.86, 1.0))
	_score_label(_score_overlay, str(MetaStateStore.lucidityWallet), Vector2(63.0, 76.0), 7, Color(0.75, 1.0, 0.8), 72.0, HORIZONTAL_ALIGNMENT_RIGHT)

	_score_label(_score_overlay, "POINTS", Vector2(17.0, 99.0), 9, Color(1.0, 0.82, 0.28))
	_score_label(_score_overlay, "SYMBOL", Vector2(19.0, 115.0), 7, Color(0.0, 0.9, 1.0))
	_score_label(_score_overlay, "PAIR", Vector2(77.0, 115.0), 7, Color(0.0, 0.9, 1.0), 24.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_score_label(_score_overlay, "TRIPLE", Vector2(105.0, 115.0), 7, Color(0.0, 0.9, 1.0), 36.0, HORIZONTAL_ALIGNMENT_RIGHT)

	var y := 130.0
	for sym in Symbols.BASE_SYMBOL_CYCLE:
		var symbol_id := String(sym)
		var icon := TextureRect.new()
		# ~20px icons (was 12px) so the symbols read clearly in the table; mipmaps +
		# linear keep the large source art crisp when downscaled (issue #22).
		icon.texture = _load_texture("symbols/%s.png" % symbol_id, true)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.position = Vector2(15.0, y - 6.0)
		icon.size = Vector2(20.0, 20.0)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_score_overlay.add_child(icon)
		_score_label(_score_overlay, symbol_id.to_upper(), Vector2(40.0, y), 7, Color(0.86, 0.9, 0.96))
		var pair := int(Payouts.PAIR_SCORE.get(symbol_id, 0))
		var triple := Payouts.JACKPOT_SCORE if symbol_id == "brain" else int(Payouts.TRIPLE_SCORE.get(symbol_id, 0))
		_score_label(_score_overlay, "+%d" % pair, Vector2(77.0, y), 7, Color(0.75, 1.0, 0.8), 24.0, HORIZONTAL_ALIGNMENT_RIGHT)
		_score_label(_score_overlay, "+%d%s" % [triple, "*" if symbol_id == "brain" else ""], Vector2(105.0, y), 7, Color(1.0, 0.33, 0.58) if symbol_id == "brain" else Color(0.75, 1.0, 0.8), 36.0, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 20.0

	_score_label(_score_overlay, "* BRAIN TRIPLE = JACKPOT", Vector2(19.0, 251.0), 6, Color(0.72, 0.76, 0.86))

	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(50.0, 263.0)
	close.size = Vector2(60.0, 16.0)
	close.add_theme_font_size_override("font_size", 7)
	if _font != null:
		close.add_theme_font_override("font", _font)
	Assets.skin_negative_button(close)
	close.pressed.connect(_close_score_table)
	_score_overlay.add_child(close)

func _close_score_table() -> void:
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
	var free_spins_before := int(RunStateStore.freeSpinsRemaining)
	if not RunStateStore.use_consumable(id):
		return
	_refresh_reels_from_state()
	_update_hud()
	_show_consumable_feedback(id)
	_play_use_fx(id)
	_play_consumable_lucidity_feedback(lucidity_before)
	if id == "cons_tea":
		_try_start_power_coin_flow()
		# Tea (issue #53): restored spins fly from the stash to the spins counter.
		if int(RunStateStore.freeSpinsRemaining) > free_spins_before:
			_play_tea_flight(slot_index)

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
func _show_consumable_feedback(id: String) -> void:
	var hint: Dictionary = use_hints.get(id, {})
	if hint.is_empty():
		return
	if _hint_layer == null or not is_instance_valid(_hint_layer):
		_build_hint_layer()
	if _hint_layer == null:
		return
	var hint_label := HintLabel.new()
	hint_label.grow_time = hint_grow_time
	hint_label.set_font(_font)
	_hint_layer.add_child(hint_label)
	hint_label.play(
		String(hint["pos"]), String(hint["neg"]),
		_item_display_name(id), HintLabel.item_is_corrupted(id)
	)

func _play_consumable_lucidity_feedback(lucidity_before: int) -> void:
	var target_lucidity := int(RunStateStore.lucidityCoins)
	var lucidity_gain := maxi(0, target_lucidity - lucidity_before)
	if lucidity_gain <= 0:
		return
	_coin_prev_lucidity = target_lucidity
	_set_sequence_lock(true)
	var reward_time := _spawn_lucidity_coins(lucidity_gain, target_lucidity)
	if reward_time > 0.0:
		await get_tree().create_timer(reward_time).timeout
	_set_sequence_lock(false)

# ── serum symbol picker (issue #53) ──────────────────────────────────────────────
# Using Serum opens a small overlay listing every reel symbol except brain; the
# picked one is guaranteed to appear at least once next spin (the charge is only
# consumed on pick — tapping anywhere else cancels).

const SERUM_PICKER_RECT := Rect2(14.0, 138.0, 132.0, 44.0)

func _begin_serum() -> void:
	if _sequence_lock_active or _serum_picker != null:
		return
	if not RunStateStore._can_act():
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

	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.03, 0.1, 0.94)
	panel.position = SERUM_PICKER_RECT.position
	panel.size = SERUM_PICKER_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_serum_picker.add_child(panel)

	var title := _reaction_label(_serum_picker, "PICK A SYMBOL",
		Vector2(SERUM_PICKER_RECT.position.x, SERUM_PICKER_RECT.position.y + 3.0), 7, Color(0.72, 1.0, 0.65))
	title.size = Vector2(SERUM_PICKER_RECT.size.x, 9.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var pool: Array = []
	for s in Symbols.BASE_SYMBOL_CYCLE:
		if String(s) != "brain":
			pool.append(String(s))
	var cell_w := SERUM_PICKER_RECT.size.x / float(maxi(1, pool.size()))
	for i in pool.size():
		var sym: String = pool[i]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(SERUM_PICKER_RECT.position.x + float(i) * cell_w, SERUM_PICKER_RECT.position.y + 14.0)
		b.size = Vector2(cell_w, 26.0)
		b.pressed.connect(_on_serum_pick.bind(sym))
		_serum_picker.add_child(b)
		var tex := _load_texture("symbols/%s.png" % sym, true)
		if tex != null:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.position = Vector2((cell_w - 16.0) * 0.5, 4.0)
			icon.size = Vector2(16.0, 16.0)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(icon)

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

## Tea (issue #53): the restored free spins fly from the used stash slot to the
## spins-left counter, which pulses as the tea lands.
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
	icon.position = Assets.stash_slot_pos(slot_index, max_consumable_slots)
	add_child(icon)
	var target := Vector2(43.0, 82.0) # spins counter fallback
	var spins_label := _bar_labels.get("life") as Label
	if spins_label != null:
		target = spins_label.position
	var tw := create_tween()
	tw.tween_property(icon, "position", target, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(icon.queue_free)
	if spins_label != null:
		spins_label.pivot_offset = spins_label.size * 0.5
		var pulse := create_tween()
		pulse.tween_interval(0.55)
		pulse.tween_property(spins_label, "scale", Vector2(1.3, 1.3), 0.1)
		pulse.tween_property(spins_label, "scale", Vector2.ONE, 0.14)

# White Powder: consume the charge, then pick a source reel and a target reel to
# copy onto. copy_reel() applies the copy and its side effect (consume a random
# other supply, or -20 neurons). Needs a spin result to copy from.
func _begin_white_powder() -> void:
	if _sequence_lock_active:
		return
	if not RunStateStore._can_act() or RunStateStore.lastResult == null:
		return
	if not RunStateStore.use_consumable("cons_white_powder"):
		return
	_copy_source = -1
	_arm_reel_picker(func(reel_index: int) -> void: _on_copy_pick(reel_index))

func _on_copy_pick(reel_index: int) -> void:
	if _sequence_lock_active:
		return
	if _copy_source < 0:
		_copy_source = reel_index # source chosen; re-arm to pick the target
		_arm_reel_picker(func(target_index: int) -> void: _on_copy_pick(target_index))
	else:
		var src := _copy_source
		_copy_source = -1
		RunStateStore.copy_reel(src, reel_index)
		_clear_targeting()
		_refresh_reels_from_state()
		_update_hud()
		_refresh_jackpot_lamp()
		_play_reward_sequence(reel_index) # copy burst pops from the target reel

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

## Tobacco: evaluate.gd hides the LAST pairBoostHiddenReels reels from scoring
## (reels.slice keeps the first ones), so smoke exactly those.
func _refresh_tobacco_fx() -> void:
	var active := consumable_fx_enabled and tobacco_fx_enabled and RunStateStore.pairBoostSpins > 0
	var hidden := clampi(RunStateStore.pairBoostHiddenReels, 0, 2) if active else 0
	for i in 3:
		var smoked: bool = i >= 3 - hidden
		if i < _tobacco_covers.size():
			(_tobacco_covers[i] as ColorRect).visible = smoked
		if i < _tobacco_smoke.size():
			var smoke := _tobacco_smoke[i] as CPUParticles2D
			smoke.visible = smoked
			smoke.emitting = smoked

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
	# Fade the spins bar & count out while the drink runs; fade back on end.
	var target_a := 0.0 if active else 1.0
	var tw := create_tween()
	tw.set_parallel(true)
	for node in _spins_bar_nodes():
		tw.tween_property(node, "modulate:a", target_a, energy_fade_time)

func _spins_bar_nodes() -> Array:
	var nodes: Array = []
	for n in [get_node_or_null("HealthTrack"), _life_fill_sprite, _bar_labels.get("life")]:
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
	_show_potion_popup(_potion_effect_text(pick))

func _play_potion_jump() -> void:
	if _potion_jump_tween != null and _potion_jump_tween.is_valid():
		_potion_jump_tween.kill()
	position.y = 0.0
	_potion_jump_tween = create_tween()
	_potion_jump_tween.tween_property(self, "position:y", -potion_jump_height, 0.09)
	_potion_jump_tween.tween_property(self, "position:y", 0.0, 0.14) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _potion_effect_text(pick: Dictionary) -> String:
	match String(pick.get("kind", "")):
		"multNextSpin":
			return "SCORE x%s" % String.num(float(pick["multiplier"]), 2)
		"lucidity":
			var amt := int(pick["amount"])
			return ("+%d LUCIDITY" % amt) if amt >= 0 else ("%d LUCIDITY" % amt)
		"freeReroll":
			return "FREE REROLL"
		"symbolToBrain":
			return "BRAIN SWAP"
	return ""

func _show_potion_popup(text: String) -> void:
	if text.is_empty() or _fx_layer == null:
		return
	var label := Label.new()
	label.text = text
	label.position = Vector2(30.0, 112.0) # between the TV and the multiplier strip
	label.size = Vector2(100.0, 10.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 7)
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", potion_popup_color)
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

# Serum blur (issue #53): the spin after the guaranteed one lands behind a frost
# layer — symbols stay distinguishable, just harder to read.
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
	var a := String(reels[0])
	if not (a == String(reels[1]) and a == String(reels[2])):
		return
	# Tobacco (issue #53): while a reel is hidden the spin scores as pair/miss, so a
	# raw 3-of-a-kind must NOT fire its 3x bonus (jackpot spin, powers back, reveal,
	# flatline strike...). Gating on the scored winType blocks exactly those spins.
	var win_type := String(lr.get("winType", ""))
	if win_type != "triple" and win_type != "jackpot":
		return
	if a == "flatline":
		var count := RunStateStore.register_flatline_result()
		_show_flatline_result_reaction(count)
	else:
		_apply_symbol_triple(a, int(lr.get("freeSpinsGranted", 0)), power_triggered)

func _apply_symbol_triple(symbol: String, free_spins_granted: int, _power_triggered: bool) -> void:
	var color := flatline_result_color
	var label := ""
	match symbol:
		"brain":
			# ALWAYS a free spin: on a natural spin the pinned evaluate already granted
			# one (free_spins_granted > 0); only top up when it didn't (power / free spin).
			if free_spins_granted <= 0:
				RunStateStore.grant_free_spins(triple_brain_free_spins)
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
			RunStateStore.grant_free_spins(triple_vial_free_spins)
			color = triple_vial_color
			label = "+%d SPINS" % triple_vial_free_spins
	_spawn_reaction_flash(color, label)
	_update_hud()

# ── 3x eye reveal (player-picked reel) ───────────────────────────────────────────
# Reuses the shared reel-selection UI. Tapping a reel reveals its NEXT-spin symbol
# INSTANTLY (issue #53): the store rolls it through the normal weight pipeline and
# commits it, so the next spin's evaluate() honours the revealed promise.

const EYE_REVEAL_POPUP_TIME := 1.6

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
	var w := 34.0
	var h := 34.0
	var popup := Control.new()
	popup.z_index = 40
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cx := float(REEL_CELL_CENTERS[reel_index])
	popup.position = Vector2(clampf(cx - w * 0.5, 2.0, SRC_W - w - 2.0), float(REEL_WINDOW["top"]) - h - 6.0)
	popup.size = Vector2(w, h)
	add_child(popup)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.1, 0.92)
	bg.size = popup.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(bg)

	var title := _reaction_label(popup, "REEL %d" % (reel_index + 1), Vector2(0.0, 2.0), 6, triple_eye_color)
	title.size = Vector2(w, 8.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var tex := _load_texture("symbols/%s.png" % symbol_id, true)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.position = Vector2((w - 16.0) * 0.5, 13.0)
		icon.size = Vector2(16.0, 16.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(icon)
	else:
		var sym := _reaction_label(popup, symbol_id.to_upper(), Vector2(0.0, 16.0), 7, Color(0.9, 0.95, 1.0))
		sym.size = Vector2(w, 10.0)
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
	_show_ending("flatline", run)
	return true

## New hard run-length cap (issue #35): reaching run_spin_length ends the run like a
## neuron flatline (banks lucidity), added alongside the neurons<=0 ending.
func _check_spin_cap_ending() -> bool:
	if RunStateStore.spinCount < run_spin_length:
		return false
	var run := {
		"neurons": RunStateStore.neurons,
		"scoreEarned": RunStateStore.scoreEarned,
		"lucidityCoins": RunStateStore.lucidityCoins,
	}
	_show_ending("flatline", run)
	return true

func _show_flatline_result_reaction(count: int) -> void:
	var host := Control.new()
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
	var tw := create_tween()
	tw.tween_property(line, "size:x", float(SRC_W), reaction_flash_time * 0.5)
	tw.tween_interval(reaction_flash_time * 0.3)
	tw.tween_property(host, "modulate:a", 0.0, reaction_flash_time * 0.3)
	tw.tween_callback(host.queue_free)

func _spawn_reaction_flash(color: Color, text: String) -> void:
	var host := Control.new()
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

func _check_ending() -> bool:
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
	_show_ending(String(ending), run)
	return true

func _show_ending(ending: String, run: Dictionary) -> void:
	_stop_flatline_countdown()
	RunStateStore.end_run(ending)
	MetaStateStore.mark_ending_reached(ending)
	# Wealth banking is deferred until the player chooses to leave (so Continue can
	# resume and bank the full total at the real flatline end — no double-bank).
	if ending != "wealth":
		MetaStateStore.bank_run(run, ending)

	_overlay = Control.new()
	_overlay.position = Vector2.ZERO
	_overlay.size = Vector2(SRC_W, SRC_H)
	add_child(_overlay)
	# The stash tray draws at z 50 and would float over the dimmed overlay.
	_set_stash_tray_visible(false)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.size = Vector2(SRC_W, SRC_H)
	_overlay.add_child(dim)

	var title := Label.new()
	if ending == "flatline":
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
		title.text = ending.to_upper()
		title.position = Vector2(20, 120)
		title.size = Vector2(120, 20)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 16)
	if _font != null:
		title.add_theme_font_override("font", _font)
	title.add_theme_color_override("font_color", Color(1, 0.4, 0.5) if ending == "flatline" else Color(0.5, 1, 0.6))
	_overlay.add_child(title)

	if ending == "flatline":
		_build_flatline_countdown(run)
	elif ending == "wealth":
		_build_wealth_screen(run)
		return
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
	to_menu.position = Vector2(30, 238 if ending == "flatline" else 175)
	to_menu.size = Vector2(100, 20)
	to_menu.add_theme_font_size_override("font_size", 9)
	if _font != null:
		to_menu.add_theme_font_override("font", _font)
	Assets.skin_negative_button(to_menu)
	to_menu.pressed.connect(_on_flatline_action_pressed)
	_overlay.add_child(to_menu)

## Dedicated wealth-ending screen: CONTINUE keeps playing under the existing
## wealth-continue rules; EXIT CASINO banks the run (deferred until leave so a
## continue can still bank the full total later) and returns to the menu hub.
func _build_wealth_screen(run: Dictionary) -> void:
	_score_label(_overlay, "YOU MADE IT OUT RICH", Vector2(20.0, 148.0), 8,
		Color(0.9, 0.95, 0.85), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	_score_label(_overlay, "SCORE %d" % int(run["scoreEarned"]), Vector2(20.0, 162.0), 8,
		Color(0.92, 0.86, 0.56), 120.0, HORIZONTAL_ALIGNMENT_CENTER)

	var cont := Button.new()
	cont.text = "CONTINUE"
	cont.position = Vector2(30.0, 192.0)
	cont.size = Vector2(100.0, 20.0)
	cont.add_theme_font_size_override("font_size", 9)
	if _font != null:
		cont.add_theme_font_override("font", _font)
	# Continuing with no possible next spin (0 neurons/free spins, or the hard
	# spin cap already hit) would strand a dead machine (issue #62).
	cont.disabled = not _can_resume_after_wealth()
	cont.pressed.connect(_continue_from_wealth)
	_overlay.add_child(cont)

	var exit := Button.new()
	exit.text = "EXIT CASINO"
	exit.position = Vector2(30.0, 218.0)
	exit.size = Vector2(100.0, 20.0)
	exit.add_theme_font_size_override("font_size", 9)
	if _font != null:
		exit.add_theme_font_override("font", _font)
	Assets.skin_negative_button(exit)
	exit.pressed.connect(_exit_casino.bind(run))
	_overlay.add_child(exit)

func _show_campaign_failed() -> void:
	_stop_flatline_countdown()
	if _overlay != null:
		_overlay.queue_free()
	_overlay = Control.new()
	_overlay.position = Vector2.ZERO
	_overlay.size = Vector2(SRC_W, SRC_H)
	add_child(_overlay)
	_set_stash_tray_visible(false)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.82)
	dim.size = Vector2(SRC_W, SRC_H)
	_overlay.add_child(dim)

	_score_label(_overlay, "FLATLINE", Vector2(20.0, 58.0), 16, Color(1.0, 0.35, 0.45), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	# Issue #38: exact GDD fatal copy, kept byte-for-byte in one label (autowrapped).
	var fatal := _score_label(_overlay, fatal_flatline_text, Vector2(20.0, 84.0), 9, Color(0.86, 0.9, 1.0), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	fatal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fatal.size = Vector2(120.0, 40.0)

	# The campaign-failed screen keeps the neuron meter (fully desaturated mind).
	_flatline_meter = NeuronMeter.attach(_overlay, Vector2(80.0, 162.0))

	var fresh := Button.new()
	fresh.text = "START FRESH AGAIN"
	fresh.position = Vector2(20.0, 208.0)
	fresh.size = Vector2(120.0, 22.0)
	fresh.add_theme_font_size_override("font_size", 8)
	if _font != null:
		fresh.add_theme_font_override("font", _font)
	Assets.skin_negative_button(fresh)
	fresh.pressed.connect(_start_fresh_again)
	_overlay.add_child(fresh)

func _start_fresh_again() -> void:
	MetaStateStore.start_new_campaign()
	RunStateStore.reset_run_state()
	_to_menu()

func _flatline_action_text() -> String:
	return "CONTINUE" if _has_campaign_neurons_remaining() else "MENU"

func _on_flatline_action_pressed() -> void:
	if _has_campaign_neurons_remaining():
		_to_dealer()
	else:
		_to_menu()

func _has_campaign_neurons_remaining() -> bool:
	return int(MetaStateStore.campaignNeuronsLeft) > 0

func _build_flatline_countdown(run: Dictionary) -> void:
	_flatline_total = int(run["lucidityCoins"])
	_flatline_kept = floori(float(_flatline_total) * _end_run_lucidity_kept_fraction())
	_flatline_display = _flatline_total
	_flatline_countdown_elapsed = 0.0
	_flatline_countdown_active = _flatline_kept < _flatline_total

	# Retained-percent line only ("10% kept", or "20% kept" with Smart Saving);
	# the draining number below it is the whole story.
	var kept_pct := roundi(_end_run_lucidity_kept_fraction() * 100.0)
	_score_label(_overlay, "%d%% kept" % kept_pct, Vector2(20.0, 96.0), 8, Color(0.58, 0.64, 0.72), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	_flatline_score_label = _score_label(_overlay, str(_flatline_display), Vector2(20.0, 110.0), 28, Color(0.97, 0.98, 1.0), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	_flatline_lost_label = _score_label(_overlay, "", Vector2(20.0, 148.0), 10, Color(0.93, 0.27, 0.27), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	_update_flatline_countdown_labels()

	# Neuron meter above the continue button, playing the losing pop: the frame
	# switches to reflect the neuron this run just cost. The "-1 NEURON" popup
	# rides the same beat, rising off the meter.
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

# The stash tray (z 50) would draw over full-screen ending overlays; hide it while
# one is up and restore it when the run visuals resync.
func _set_stash_tray_visible(v: bool) -> void:
	var tray := get_node_or_null("stash") as Control
	if tray != null:
		tray.visible = v
	_set_stash_visible(v)

func _end_run_lucidity_kept_fraction() -> float:
	return EconomyConst.SMART_SAVE_LUCIDITY_KEPT \
		if MetaStateStore.ownedPermanents.has(EconomyConst.SMART_SAVE_UPGRADE_ID) \
		else EconomyConst.END_OF_RUN_LUCIDITY_KEPT

## A wealth CONTINUE only makes sense if the resumed run can still take a spin:
## neurons (or free spins) remain and the hard spin cap isn't reached (issue #62).
func _can_resume_after_wealth() -> bool:
	return (int(RunStateStore.neurons) >= 1 or int(RunStateStore.freeSpinsRemaining) > 0) \
		and int(RunStateStore.spinCount) < run_spin_length

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

## Wealth screen EXIT CASINO: bank the run (wealth banking is deferred until the
## player leaves) and return to the menu hub.
func _exit_casino(run: Dictionary) -> void:
	MetaStateStore.bank_run(run, "wealth")
	_to_menu()

# ── dealer flow ────────────────────────────────────────────────────────────────────

func _show_dealer_incoming() -> void:
	_dealer_visit()

func _dealer_visit() -> void:
	RunStateStore.reveal_dealer()
	# In-run dealer stays inline (issue #22): reveal the offers as a modal on the
	# machine; the full dealer scene is reserved for the pre-run shop flow.
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
	add_child(_dealer_offer_popup)
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
	if not _dealer_drag_active:
		return
	if event is InputEventMouseMotion:
		var m := get_global_mouse_position()
		if _dealer_drag_node != null:
			_dealer_drag_node.global_position = m - _dealer_drag_node.size * 0.5
		if m.distance_to(_dealer_drag_press) > 4.0:
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

func _close_dealer() -> void:
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
	_set_sequence_lock(false)
	_update_hud()
