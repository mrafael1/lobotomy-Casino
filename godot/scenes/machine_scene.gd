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
const IN_RUN_DEALER_OFFER_SCENE := preload("res://scenes/in_run_dealer_offer.tscn")

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
const COIN_TARGET := Vector2(76.0, 75.0)
const COIN_SIZE := 6.0
const POWER_COIN_SIZE := 8.0
const COIN_FLIGHT_TIME := 0.72
const COIN_STAGGER_TIME := 0.09
const COIN_BURST_FRAC := 0.4
const COIN_BURST_RISE := 24.0
const COIN_BURST_SCATTER := 26.0
const MAX_VISIBLE_COINS := 40
const POWER_COIN_FLIGHT_TIME := 0.64
const POWER_PULSE_TIME := 0.36

# Consumable / in-run item id -> icon (under assets/images/). Placeholder fallback.
const ITEM_ICONS := {
	"cons_focus": "items/focus_serum.png",
	"cons_white_powder": "items/white_powder.png",
	"cons_syringe": "items/consumable_placeholder.png",
	"cons_tea": "items/herbal_tea.png",
	"item_energy_drink": "items/energy_drink.png",
	"item_cocktail": "items/cocktail.png",
	"item_water": "items/water.png",
	"item_pill": "items/pill.png",
}

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
var _stash_buttons: Array[Button] = []
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

func _ready() -> void:
	_font = _load_font("font/DTM-Sans.otf")
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
	_build_burst_layer()
	_build_coin_layer()
	RunStateStore.state_changed.connect(_update_hud)
	_enter_run()
	_init_burst_tracking()

# ── asset loading (absolute path into ../assets) ──────────────────────────────────

static func _assets_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../assets/images")

func _load_texture(rel: String, mipmaps := false) -> Texture2D:
	return Assets.texture(rel, mipmaps)

func _load_font(rel: String) -> FontFile:
	return Assets.font(rel)

# ── scene construction ────────────────────────────────────────────────────────────

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
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.position = Vector2.ZERO
	spr.scale = Vector2(SRC_W / tex.get_width(), SRC_H / tex.get_height())
	# Linear+mipmaps so the 8x art downscales crisply rather than aliasing.
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(spr)

func _build_full_canvas_sheet(rel: String, hframes: int, frame: int = 0) -> Sprite2D:
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
	add_child(spr)
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
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.position = Vector2(rect["left"], rect["top"])
	spr.region_enabled = true
	spr.region_rect = Rect2(
		rect["left"] * ASSET_SCALE,
		rect["top"] * ASSET_SCALE,
		rect["width"] * ASSET_SCALE,
		rect["height"] * ASSET_SCALE
	)
	spr.scale = Vector2(1.0 / ASSET_SCALE, 1.0 / ASSET_SCALE)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(spr)
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
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.region_enabled = true
		spr.position = Vector2(REEL_HOLES[i]["left"], REEL_HOLES[i]["top"])
		spr.scale = Vector2(1.0 / ASSET_SCALE, 1.0 / ASSET_SCALE)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		spr.visible = false
		add_child(spr)
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
		var count := Label.new()
		count.position = Vector2(REEL_CELL_CENTERS[i] - 6.0, REEL_WINDOW["top"] + REEL_WINDOW["height"] + 1.0)
		count.size = Vector2(12.0, 8.0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 7)
		if _font != null:
			count.add_theme_font_override("font", _font)
		count.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
		count.text = ""
		count.visible = false
		add_child(count)
		_lock_count_labels.append(count)
	for id in ["reroll", "shift", "memory"]:
		_power_sprites[id] = _build_full_canvas_sheet(String(POWER_SHEETS[id]), 3, POWER_FRAME_DISABLED)

func _transparent_button_style() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

func _make_hit_button(rect: Dictionary, cb: Callable) -> Button:
	var b := Button.new()
	b.text = ""
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(rect["left"], rect["top"])
	b.size = Vector2(rect["width"], rect["height"])
	var empty := _transparent_button_style()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, empty)
	b.pressed.connect(cb)
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

func _new_reel_sprite(pos: Vector2, alpha: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = true
	s.position = pos
	s.modulate = Color(1, 1, 1, alpha)
	# Symbols are authored large and drawn at 12-16px, so downscale with
	# linear+mipmaps (supersampled, crisp) rather than nearest (aliased).
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(s)
	return s

func _build_reels() -> void:
	var cy := REEL_WINDOW["top"] + REEL_WINDOW["height"] * 0.5
	for i in 3:
		var cx: float = REEL_CELL_CENTERS[i]
		# Add neighbours first, centre last so it draws on top where they meet.
		_reel_top_sprites.append(_new_reel_sprite(Vector2(cx, cy - STRIP_OFFSET), STRIP_ADJ_ALPHA))
		_reel_bottom_sprites.append(_new_reel_sprite(Vector2(cx, cy + STRIP_OFFSET), STRIP_ADJ_ALPHA))
		_reel_sprites.append(_new_reel_sprite(Vector2(cx, cy), 1.0))

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
	_build_bar_label("goal", Vector2(43.0, 64.0), Color(0.9, 0.85, 0.45))
	_build_bar_label("life", Vector2(43.0, 85.0), Color(0.75, 1.0, 0.8))

func _build_score_button() -> void:
	_score_button = Button.new()
	_score_button.text = "SCORES"
	_score_button.size = Vector2(41.0, 15.0)
	# Pulled off the top-right corner so it isn't glued to the edge.
	_score_button.position = Vector2(160.0 - _score_button.size.x - 9.0, 9.0)
	_score_button.flat = false
	_score_button.focus_mode = Control.FOCUS_NONE
	_score_button.add_theme_font_size_override("font_size", 7)
	if _font != null:
		_score_button.add_theme_font_override("font", _font)
	Assets.skin_negative_button(_score_button)
	_score_button.pressed.connect(_show_score_table)
	add_child(_score_button)

func _build_bar_label(id: String, pos: Vector2, color: Color) -> void:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 6)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	l.text = ""
	add_child(l)
	_bar_labels[id] = l

func _build_spin_button() -> void:
	_spin_button = _make_hit_button(LEVER_HIT, _do_spin)
	add_child(_spin_button)

# ── run loop ──────────────────────────────────────────────────────────────────────

# Entered from the shop (which already started the run) or standalone. If no run is
# in progress, begin one from meta so the machine works on its own too.
func _enter_run() -> void:
	if RunStateStore.runPhase != "running":
		_begin_fresh_run()
	_sync_visuals()

func _begin_fresh_run() -> void:
	var permanents: Array = MetaStateStore.ownedPermanents.duplicate()
	var consumables: Dictionary = MetaStateStore.get_pending_consumables().duplicate(true)
	if DEBUG_GRANT:
		for p in ["perm_shift", "perm_memory"]:
			if not permanents.has(p):
				permanents.append(p)
		if consumables.is_empty():
			consumables = { "cons_focus": 1, "item_water": 1 }
	RunStateStore.start_new_run(permanents, consumables)

func _sync_visuals() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_stop_flatline_countdown()
	_close_score_table()
	_clear_targeting()
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

func _do_spin() -> void:
	if _spinning_anim or _reroll_anim_active:
		return
	_clear_targeting()
	_close_score_table()
	_copy_source = -1 # abandon any half-armed white-powder copy
	_refresh_jackpot_lamp(false)
	var locked_before := RunStateStore.lockedReels.duplicate()
	var result: Variant = RunStateStore.spin()
	if result == null:
		return
	_final_reels = result["reels"]
	# Third-reel tension: if reels 1 & 2 will match, hold reel 3 a little longer.
	var tension := TENSION_DELAY if String(_final_reels[0]) == String(_final_reels[1]) else 0.0
	_reel_stop_times = [0.55, 0.8, 1.05 + tension]
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
	RunStateStore.set_spinning(false)
	_update_hud()
	_refresh_lock_art()
	_refresh_jackpot_lamp()
	_emit_score_burst(null) # normal spin: source reel derived from the result
	_spin_button.disabled = false
	if _check_ending():
		return
	# Dealer may appear between spins (logic + offers are vector-pinned in dealer.gd).
	RunStateStore.check_dealer_trigger()
	if RunStateStore.dealerIncoming:
		_show_dealer_incoming()

func _update_hud() -> void:
	_refresh_tv_indicators()
	_refresh_controls()

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
	var goal_ratio := clampf(float(_display_lucidity) / float(EconomyConst.LUCIDITY_OBJECTIVE), 0.0, 1.0)
	_set_bar_fill(_goal_fill_sprite, WEALTH_BAR, goal_ratio)
	var start_n := maxi(1, RunStateStore.startingNeurons)
	var life_ratio := clampf(float(RunStateStore.neurons) / float(start_n), 0.0, 1.0)
	_set_bar_fill(_life_fill_sprite, HEALTH_BAR, life_ratio)
	if _bar_labels.has("goal"):
		_bar_labels["goal"].text = "%d/%d" % [_display_lucidity, EconomyConst.LUCIDITY_OBJECTIVE]
	if _bar_labels.has("life"):
		_bar_labels["life"].text = str(_display_remaining_spins(life_ratio))

func _display_remaining_spins(life_ratio: float) -> int:
	if RunStateStore.neurons <= 0:
		return 0
	return clampi(int(ceili(life_ratio * float(DISPLAY_SPIN_BUDGET))), 1, DISPLAY_SPIN_BUDGET)

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
		_bar_labels["goal"].text = "%d/%d" % [_display_lucidity, EconomyConst.LUCIDITY_OBJECTIVE]
	var goal_ratio := clampf(float(_display_lucidity) / float(EconomyConst.LUCIDITY_OBJECTIVE), 0.0, 1.0)
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
	_burst_layer = Control.new()
	_burst_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_burst_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_burst_layer)

func _build_coin_layer() -> void:
	_coin_layer = Control.new()
	_coin_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_coin_layer)

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
func _emit_score_burst(source_reel) -> void:
	var lr: Variant = RunStateStore.lastResult
	if lr == null:
		return
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
		var visible_coins := _spawn_lucidity_coins(lucidity_gain)
		_start_lucidity_countup(RunStateStore.lucidityCoins, visible_coins, _coin_flight_time_for_count(visible_coins))

	# Cocktail miss: one "+rarity" mini-burst from each reel.
	if is_new_spin and win_type == "miss" and bool(lr.get("cocktailApplied", false)):
		for i in 3:
			_spawn_burst("", int(Symbols.RARITY.get(String(reels[i]), 0)), COCKTAIL_COLOR, i)
		_nudge(0.8)
		return

	# A rescore that doesn't increase the score must NOT pop (gain <= 0).
	if gain > 0 and win_type != "miss":
		# Jackpot is special (issue #22): a large GOLDEN number rising out of the
		# machine centre — never a reel-anchored pair/triple-style burst.
		if win_type == "jackpot":
			_spawn_jackpot_burst(score)
			_flash_jackpot_lamp()
			_nudge(2.2)
			return
		var label := "TRIPLE" if win_type == "triple" else ("PAIR" if win_type == "pair" else "BONUS")
		var reel := int(source_reel) if source_reel != null else _derive_source_reel(reels)
		_spawn_burst(label, score, color, reel)
		_nudge(1.0)
		# Cocktail + pair: surface the unpaired reel's rarity gain from its own reel.
		if is_new_spin and bool(lr.get("cocktailApplied", false)) and win_type == "pair":
			var solo := _solo_reel(reels)
			if solo != -1:
				_spawn_burst("", int(Symbols.RARITY.get(String(reels[solo]), 0)), COCKTAIL_COLOR, solo)

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

func _spawn_lucidity_coins(gain: int) -> int:
	if _coin_layer == null:
		return 0
	var tex := _load_texture("ui/coin.png", true)
	if tex == null:
		return 0
	var count := mini(MAX_VISIBLE_COINS, gain)
	var flight_time := _coin_flight_time_for_count(count)
	var stagger_time := _coin_stagger_time_for_count(count)
	for i in count:
		var coin := Sprite2D.new()
		coin.texture = tex
		coin.centered = true
		coin.position = COIN_TRAY
		var coin_scale := COIN_SIZE / float(maxi(1, tex.get_width()))
		coin.scale = Vector2(coin_scale, coin_scale)
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		coin.modulate.a = 0.0
		_coin_layer.add_child(coin)
		var jitter := randf() - 0.5
		var burst_pos := Vector2(COIN_TRAY.x + jitter * COIN_BURST_SCATTER, COIN_TRAY.y - COIN_BURST_RISE)
		var tw := create_tween()
		tw.tween_interval(float(i) * stagger_time)
		tw.tween_method(_drive_lucidity_coin.bind(coin, COIN_TRAY, burst_pos, COIN_TARGET), 0.0, 1.0, flight_time)
		tw.tween_callback(coin.queue_free)
	return count

func _coin_flight_time_for_count(count: int) -> float:
	var pressure := clampf(float(maxi(0, count - 8)) / float(maxi(1, MAX_VISIBLE_COINS - 8)), 0.0, 1.0)
	return lerpf(COIN_FLIGHT_TIME, 0.48, pressure)

func _coin_stagger_time_for_count(count: int) -> float:
	if count <= 8:
		return COIN_STAGGER_TIME
	var pressure := clampf(float(count - 8) / float(maxi(1, MAX_VISIBLE_COINS - 8)), 0.0, 1.0)
	return lerpf(COIN_STAGGER_TIME, 0.018, pressure)

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
	if _power_coin_active or _spinning_anim or _reroll_anim_active:
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

func _finish_power_coin_flow(power_id: String, coin: TextureRect, target: Vector2) -> void:
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
		var b := _make_hit_button({
			"left": cx - 8.0,
			"top": MULT_STRIP["top"],
			"width": 16.0,
			"height": MULT_STRIP["height"],
		}, _select_bet_multiplier.bind(m))
		add_child(b)
		_multiplier_buttons.append(b)

func _select_bet_multiplier(m: int) -> void:
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
	var can_act := RunStateStore._can_act() and not _spinning_anim and not _reroll_anim_active
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
		var b := _make_hit_button({
			"left": hit["left"],
			"top": hit["top"],
			"width": maxf(hit["width"], 11.0),
			"height": hit["height"],
		}, _on_power_pressed.bind(id))
		add_child(b)
		_power_buttons[id] = b

func _build_stash() -> void:
	var y := 240.0
	for i in Consumables.MAX_CONSUMABLE_SLOTS:
		var b := Button.new()
		b.position = Vector2(95.0 + i * 30.0, y)
		b.size = Vector2(22, 22)
		b.add_theme_font_size_override("font_size", 7)
		if _font != null:
			b.add_theme_font_override("font", _font)
		b.pressed.connect(_on_stash_pressed.bind(i))
		add_child(b)
		_stash_buttons.append(b)

# Snapshot of the stash expanded to one entry per copy (matches buildStashSlots).
func _stash_slots() -> Array:
	var slots: Array = []
	var stash: Dictionary = RunStateStore.runConsumables
	for entry in stash:
		var copies := int(stash[entry])
		for _k in copies:
			if slots.size() < Consumables.MAX_CONSUMABLE_SLOTS:
				slots.append(String(entry))
	return slots

func _refresh_controls() -> void:
	_refresh_multiplier_controls()

	var can_use := RunStateStore.runPhase == "running" and not _spinning_anim and not _reroll_anim_active \
		and RunStateStore.lastResult != null and RunStateStore.blockPowersSpins <= 0
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
	for i in _stash_buttons.size():
		var b := _stash_buttons[i]
		if i < slots.size():
			b.text = "" # icon-only stash slot
			b.icon = _icon_for(slots[i])
			b.expand_icon = true
			b.disabled = not RunStateStore._can_act() or _reroll_anim_active
		else:
			b.text = ""
			b.icon = null
			b.disabled = true

func _power_owned(id: String, owned: Array) -> bool:
	if id == "reroll":
		return true
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
		_emit_score_burst(rerolled) # reroll burst pops from the rerolled reel

func _apply_shift(reel_index: int, direction: int) -> void:
	RunStateStore.move_reel(reel_index, direction)
	_clear_targeting()
	_refresh_reels_from_state()
	_update_hud()
	_refresh_jackpot_lamp()
	_emit_score_burst(reel_index) # shift burst pops from the shifted reel

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
	RunStateStore.use_consumable(id)
	_refresh_reels_from_state()

# White Powder: consume the charge, then pick a source reel and a target reel to
# copy onto. copy_reel() applies the copy and its side effect (consume a random
# other supply, or -20 neurons). Needs a spin result to copy from.
func _begin_white_powder() -> void:
	if not RunStateStore._can_act() or RunStateStore.lastResult == null:
		return
	if not RunStateStore.use_consumable("cons_white_powder"):
		return
	_copy_source = -1
	_arm_reel_picker(func(reel_index: int) -> void: _on_copy_pick(reel_index))

func _on_copy_pick(reel_index: int) -> void:
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
		_emit_score_burst(reel_index) # copy burst pops from the target reel

func _check_ending() -> bool:
	var run := {
		"neurons": RunStateStore.neurons,
		"scoreEarned": RunStateStore.scoreEarned,
		"lucidityCoins": RunStateStore.lucidityCoins,
	}
	var ending: Variant = Endings.check_ending(run, {})
	if ending == null:
		return false
	if ending == "wealth" and RunStateStore.wealthContinued:
		return false
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

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.size = Vector2(SRC_W, SRC_H)
	_overlay.add_child(dim)

	var title := Label.new()
	title.position = Vector2(20, 74 if ending == "flatline" else 120)
	title.add_theme_font_size_override("font_size", 16)
	if _font != null:
		title.add_theme_font_override("font", _font)
	title.add_theme_color_override("font_color", Color(1, 0.4, 0.5) if ending == "flatline" else Color(0.5, 1, 0.6))
	title.text = ending.to_upper()
	_overlay.add_child(title)

	if ending == "flatline":
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
	to_menu.text = "BANK & LEAVE" if ending == "wealth" else "MENU"
	to_menu.position = Vector2(30, 238 if ending == "flatline" else 175)
	to_menu.size = Vector2(100, 20)
	to_menu.add_theme_font_size_override("font_size", 9)
	if _font != null:
		to_menu.add_theme_font_override("font", _font)
	# Non-wealth already banked above; wealth banks here on leave.
	Assets.skin_negative_button(to_menu)
	to_menu.pressed.connect(_bank_and_menu.bind(run, ending) if ending == "wealth" else _to_menu)
	_overlay.add_child(to_menu)

	if ending == "wealth":
		var cont := Button.new()
		cont.text = "CONTINUE"
		cont.position = Vector2(40, 200)
		cont.size = Vector2(80, 18)
		cont.add_theme_font_size_override("font_size", 9)
		if _font != null:
			cont.add_theme_font_override("font", _font)
		cont.pressed.connect(_continue_from_wealth)
		_overlay.add_child(cont)

func _build_flatline_countdown(run: Dictionary) -> void:
	_flatline_total = int(run["lucidityCoins"])
	_flatline_kept = floori(float(_flatline_total) * EconomyConst.END_OF_RUN_LUCIDITY_KEPT)
	_flatline_display = _flatline_total
	_flatline_countdown_elapsed = 0.0
	_flatline_countdown_active = _flatline_kept < _flatline_total

	_score_label(_overlay, "LUCIDITY - 10% KEPT", Vector2(20.0, 100.0), 8, Color(0.58, 0.64, 0.72), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	_flatline_score_label = _score_label(_overlay, str(_flatline_display), Vector2(20.0, 116.0), 28, Color(0.97, 0.98, 1.0), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	_flatline_lost_label = _score_label(_overlay, "", Vector2(20.0, 154.0), 10, Color(0.93, 0.27, 0.27), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	_score_label(_overlay, "FINAL CREDITS %d" % MetaStateStore.lucidityWallet, Vector2(20.0, 182.0), 8, Color(0.92, 0.86, 0.56), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	_update_flatline_countdown_labels()

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

func _continue_from_wealth() -> void:
	RunStateStore.continue_run()
	_sync_visuals()

func _bank_and_menu(run: Dictionary, ending: String) -> void:
	MetaStateStore.bank_run(run, ending)
	_to_menu()

# ── dealer flow ────────────────────────────────────────────────────────────────────

func _make_dealer_modal(show_portrait := true) -> Control:
	if _dealer_overlay != null:
		_dealer_overlay.queue_free()
	_dealer_message_label = null
	_dealer_portrait_sprite = null
	_dealer_overlay = Control.new()
	_dealer_overlay.size = Vector2(SRC_W, SRC_H) # default mouse_filter STOP -> modal, blocks spin
	add_child(_dealer_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.05, 0.18)
	dim.size = Vector2(SRC_W, SRC_H)
	_dealer_overlay.add_child(dim)
	if show_portrait:
		_dealer_portrait_sprite = _build_control_sheet_on(_dealer_overlay, "dealer_portrait.png", 2)
	return _dealer_overlay

func _dealer_label(parent: Control, text: String, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _dealer_button(parent: Control, text: String, pos: Vector2, size: Vector2, cb: Callable, icon: Texture2D = null) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", 8)
	if _font != null:
		b.add_theme_font_override("font", _font)
	if icon != null:
		b.icon = icon
		b.expand_icon = true
	b.pressed.connect(cb)
	parent.add_child(b)

func _show_dealer_incoming() -> void:
	_dealer_visit()

func _dealer_visit() -> void:
	RunStateStore.reveal_dealer()
	# In-run dealer stays inline (issue #22): reveal the offers as a modal on the
	# machine; the full dealer scene is reserved for the pre-run shop flow.
	_show_dealer_offers()

func _dealer_wave_off() -> void:
	RunStateStore.decline_dealer_visit()
	_close_dealer()

func _show_dealer_offers() -> void:
	var offers: Variant = RunStateStore.dealerOfferIds
	if offers == null:
		_close_dealer()
		return
	if _dealer_overlay != null:
		_dealer_overlay.queue_free()
	_dealer_offer_popup = IN_RUN_DEALER_OFFER_SCENE.instantiate()
	_dealer_overlay = _dealer_offer_popup
	add_child(_dealer_offer_popup)
	_dealer_offer_popup.item_selected.connect(_dealer_take)
	_dealer_offer_popup.item_discarded.connect(_dealer_discard_stash)
	_dealer_offer_popup.dealer_ignored.connect(_dealer_leave)
	_dealer_offer_popup.offer_finished.connect(_on_dealer_offer_finished)
	_dealer_offer_popup.start_offer((offers as Array).duplicate(), _stash_slots())

func _dealer_offer_button(parent: Control, item_id: String, text: String, pos: Vector2, icon: Texture2D) -> void:
	var card := Control.new()
	card.position = pos
	card.size = Vector2(56.0, 38.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_dealer_offer_input.bind(card, item_id))
	parent.add_child(card)
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.position = Vector2(16.0, 2.0)
	icon_rect.size = Vector2(24.0, 24.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon_rect)

func _build_dealer_stash(parent: Control) -> void:
	var slots := _stash_slots()
	var start_x := 58.0 if slots.size() == 1 else 47.0
	for i in slots.size():
		var id := String(slots[i])
		var icon := TextureRect.new()
		icon.texture = _icon_for(id)
		icon.position = Vector2(start_x + float(i) * 24.0, 296.0)
		icon.size = Vector2(20.0, 20.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.gui_input.connect(_on_dealer_stash_input.bind(icon, id))
		parent.add_child(icon)

func _on_dealer_stash_input(event: InputEvent, node: Control, id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _dealer_drag_active:
		_begin_dealer_drag(node, id, "stash")

func _on_dealer_offer_input(event: InputEvent, node: Control, id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _dealer_drag_active:
		_begin_dealer_drag(node, id, "offer")

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
			_show_dealer_offers()

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
	if _dealer_offer_popup != null:
		_dealer_offer_popup.set_stash_items(_stash_slots())
	else:
		_show_dealer_offers()

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
	_update_hud()
