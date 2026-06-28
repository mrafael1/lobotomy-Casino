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
const TV_SCREEN := { "left": 24.0, "top": 42.0, "width": 112.0, "height": 66.0 }
const LEVER_HIT := { "left": 133.0, "top": 160.0, "width": 20.0, "height": 40.0 }
const SYMBOL_TARGET_H := 26.0 # fit within the ~30px reel hole

# Machine-mounted power button hit rects (source px).
const POWER_HITS := {
	"reroll": { "left": 21.0, "top": 223.0, "width": 15.0, "height": 15.0 },
	"shift": { "left": 36.0, "top": 223.0, "width": 13.0, "height": 15.0 },
	"memory": { "left": 49.0, "top": 223.0, "width": 13.0, "height": 15.0 },
}
# Per-reel up/down shift-arrow hit rects (source px).
const SHIFT_ARROW_HITS := [
	{ "up": { "left": 33.0, "top": 153.0, "width": 21.0, "height": 15.0 }, "down": { "left": 33.0, "top": 204.0, "width": 21.0, "height": 15.0 } },
	{ "up": { "left": 65.0, "top": 153.0, "width": 21.0, "height": 15.0 }, "down": { "left": 65.0, "top": 204.0, "width": 21.0, "height": 15.0 } },
	{ "up": { "left": 97.0, "top": 153.0, "width": 21.0, "height": 15.0 }, "down": { "left": 97.0, "top": 204.0, "width": 21.0, "height": 15.0 } },
]

# Set true to grant the Shift/Memory permanents + a couple of test consumables at
# run start, so powers and the stash can be exercised before the M3 shop/dealer
# exist. Leave false for faithful play.
const DEBUG_GRANT := true

# Visible (non-book) symbols used for the spin-blur animation.
const VISIBLE_SYMBOLS := ["brain", "eye", "pill", "syringe", "vial", "flatline"]

var _reel_sprites: Array[Sprite2D] = []
var _hud_labels := {}
var _overlay: Control = null
var _spin_button: Button = null
var _bet_button: Button = null
var _power_buttons := {}      # id -> Button
var _stash_buttons: Array[Button] = []
var _targeting_layer: Control = null # reel/arrow target buttons while a power is armed
var _font: FontFile = null
var _tex_cache := {}

# Reveal animation state
var _spinning_anim := false
var _anim_elapsed := 0.0
var _blur_accum := 0.0
var _final_reels: Array = []
var _reel_stop_times := [0.55, 0.8, 1.05]

func _ready() -> void:
	_font = _load_font("font/DTM-Mono.otf")
	# Draw order (back -> front): reel background -> symbols -> cabinet (with
	# transparent holes that mask symbol overflow) -> HUD -> spin button.
	_build_full_canvas_sprite("machine new view/reel_final_machine.png")
	_build_reels()
	_build_full_canvas_sprite("machine new view/final_machine.png")
	_build_hud()
	_build_spin_button()
	_build_bet_button()
	_build_power_buttons()
	_build_stash()
	RunStateStore.state_changed.connect(_update_hud)
	_start_run()

# ── asset loading (absolute path into ../assets) ──────────────────────────────────

static func _assets_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../assets/images")

func _load_texture(rel: String, mipmaps := false) -> Texture2D:
	if _tex_cache.has(rel):
		return _tex_cache[rel]
	var path := _assets_dir().path_join(rel)
	var img := Image.new()
	if img.load(path) != OK:
		push_warning("Missing art: " + path)
		return null
	if mipmaps:
		img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[rel] = tex
	return tex

func _load_font(rel: String) -> FontFile:
	var path := ProjectSettings.globalize_path("res://").path_join("../assets").path_join(rel)
	var f := FontFile.new()
	if f.load_dynamic_font(path) != OK:
		push_warning("Missing font: " + path)
		return null
	return f

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

func _build_reels() -> void:
	var cy := REEL_WINDOW["top"] + REEL_WINDOW["height"] * 0.5
	for i in 3:
		var s := Sprite2D.new()
		s.centered = true
		s.position = Vector2(REEL_CELL_CENTERS[i], cy)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
		_reel_sprites.append(s)

func _set_reel_symbol(index: int, symbol_id: String) -> void:
	var tex := _load_texture("symbols/%s.png" % symbol_id)
	var s := _reel_sprites[index]
	if tex == null:
		return
	s.texture = tex
	var k := SYMBOL_TARGET_H / tex.get_height()
	s.scale = Vector2(k, k)

func _build_hud() -> void:
	var lines := ["neurons", "score", "lucidity", "free"]
	var labels := ["NEURONS", "SCORE", "LUCID", "FREE"]
	var y := TV_SCREEN["top"] + 4.0
	for i in lines.size():
		var l := Label.new()
		l.position = Vector2(TV_SCREEN["left"] + 4.0, y)
		l.add_theme_font_size_override("font_size", 8)
		if _font != null:
			l.add_theme_font_override("font", _font)
		l.add_theme_color_override("font_color", Color(0.7, 1.0, 0.85))
		l.text = "%s --" % labels[i]
		add_child(l)
		_hud_labels[lines[i]] = l
		y += 11.0

func _build_spin_button() -> void:
	# A plain SPIN button over the lever hit area so the loop is testable now;
	# the 6-frame lever animation is later polish.
	_spin_button = Button.new()
	_spin_button.text = "SPIN"
	_spin_button.position = Vector2(LEVER_HIT["left"] - 10.0, LEVER_HIT["top"])
	_spin_button.size = Vector2(SRC_W - (LEVER_HIT["left"] - 10.0) - 2.0, LEVER_HIT["height"])
	_spin_button.add_theme_font_size_override("font_size", 8)
	if _font != null:
		_spin_button.add_theme_font_override("font", _font)
	_spin_button.pressed.connect(_do_spin)
	add_child(_spin_button)

# ── run loop ──────────────────────────────────────────────────────────────────────

func _start_run() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_clear_targeting()

	var permanents: Array = MetaStateStore.ownedPermanents.duplicate()
	var consumables: Dictionary = MetaStateStore.get_pending_consumables().duplicate(true)
	if DEBUG_GRANT:
		for p in ["perm_shift", "perm_memory"]:
			if not permanents.has(p):
				permanents.append(p)
		if consumables.is_empty():
			consumables = { "cons_focus": 1, "item_water": 1 }

	RunStateStore.start_new_run(permanents, consumables)
	for i in 3:
		_set_reel_symbol(i, VISIBLE_SYMBOLS[i])
	_update_hud()

func _do_spin() -> void:
	if _spinning_anim:
		return
	_clear_targeting()
	var result: Variant = RunStateStore.spin()
	if result == null:
		return
	_final_reels = result["reels"]
	_spinning_anim = true
	_anim_elapsed = 0.0
	_blur_accum = 0.0
	_spin_button.disabled = true

func _process(delta: float) -> void:
	if not _spinning_anim:
		return
	_anim_elapsed += delta
	_blur_accum += delta
	if _blur_accum >= 0.05:
		_blur_accum = 0.0
		for i in 3:
			if _anim_elapsed < _reel_stop_times[i]:
				_set_reel_symbol(i, VISIBLE_SYMBOLS[randi() % VISIBLE_SYMBOLS.size()])
	if _anim_elapsed >= _reel_stop_times[2]:
		for i in 3:
			_set_reel_symbol(i, String(_final_reels[i]))
		_spinning_anim = false
		_on_reveal_complete()

func _on_reveal_complete() -> void:
	RunStateStore.set_spinning(false)
	_update_hud()
	_spin_button.disabled = false
	_check_ending()

func _update_hud() -> void:
	if _hud_labels.is_empty():
		return
	_hud_labels["neurons"].text = "NEURONS %d" % RunStateStore.neurons
	_hud_labels["score"].text = "SCORE %d" % RunStateStore.scoreEarned
	_hud_labels["lucidity"].text = "LUCID %d" % RunStateStore.lucidityCoins
	_hud_labels["free"].text = "FREE %d" % RunStateStore.freeSpinsRemaining
	_refresh_controls()

func _refresh_reels_from_state() -> void:
	var lr: Variant = RunStateStore.lastResult
	if lr == null:
		return
	for i in 3:
		_set_reel_symbol(i, String(lr["reels"][i]))

# ── bet / powers / stash controls ─────────────────────────────────────────────────

func _build_bet_button() -> void:
	_bet_button = Button.new()
	_bet_button.position = Vector2(4, LEVER_HIT["top"])
	_bet_button.size = Vector2(28, 14)
	_bet_button.add_theme_font_size_override("font_size", 8)
	if _font != null:
		_bet_button.add_theme_font_override("font", _font)
	_bet_button.pressed.connect(_cycle_bet)
	add_child(_bet_button)

func _cycle_bet() -> void:
	if not RunStateStore._can_act():
		return
	RunStateStore.set_bet_multiplier((RunStateStore.betMultiplier % 3) + 1)

func _build_power_buttons() -> void:
	for id in ["reroll", "shift", "memory"]:
		var hit: Dictionary = POWER_HITS[id]
		var b := Button.new()
		b.text = id.substr(0, 1).to_upper()
		b.position = Vector2(hit["left"], hit["top"])
		b.size = Vector2(maxf(hit["width"], 11.0), hit["height"])
		b.add_theme_font_size_override("font_size", 7)
		if _font != null:
			b.add_theme_font_override("font", _font)
		b.pressed.connect(_on_power_pressed.bind(id))
		add_child(b)
		_power_buttons[id] = b

func _build_stash() -> void:
	var y := 240.0
	for i in Consumables.MAX_CONSUMABLE_SLOTS:
		var b := Button.new()
		b.position = Vector2(95.0 + i * 30.0, y)
		b.size = Vector2(28, 14)
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
	if _bet_button != null:
		_bet_button.text = "x%d" % RunStateStore.betMultiplier
		_bet_button.disabled = not RunStateStore._can_act()

	var can_use := RunStateStore.runPhase == "running" and not _spinning_anim \
		and RunStateStore.lastResult != null and RunStateStore.blockPowersSpins <= 0
	if not _power_buttons.is_empty():
		var used: Array = RunStateStore.abilitiesUsed
		var owned: Array = RunStateStore.ownedUpgrades
		_power_buttons["reroll"].disabled = not (can_use and not used.has("reroll"))
		_power_buttons["shift"].disabled = not (can_use and owned.has("perm_shift") and not used.has("shift"))
		_power_buttons["memory"].disabled = not (can_use and owned.has("perm_memory") and not used.has("memory"))

	var slots := _stash_slots()
	for i in _stash_buttons.size():
		var b := _stash_buttons[i]
		if i < slots.size():
			b.text = _short_name(slots[i])
			b.disabled = not RunStateStore._can_act()
		else:
			b.text = "--"
			b.disabled = true

func _short_name(consumable_id: String) -> String:
	return consumable_id.replace("cons_", "").replace("item_", "").substr(0, 4)

# ── power targeting ────────────────────────────────────────────────────────────────

func _on_power_pressed(id: String) -> void:
	if _targeting_layer != null:
		_clear_targeting()
		return
	if id == "shift":
		_arm_shift_targets()
	else:
		_arm_reel_targets(id) # reroll / memory pick a single reel

func _arm_reel_targets(power_id: String) -> void:
	_targeting_layer = Control.new()
	_targeting_layer.size = Vector2(SRC_W, SRC_H)
	_targeting_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE # only its buttons capture clicks
	add_child(_targeting_layer)
	var cy := REEL_WINDOW["top"]
	for i in 3:
		var b := Button.new()
		b.text = str(i + 1)
		b.position = Vector2(REEL_CELL_CENTERS[i] - 10.0, cy)
		b.size = Vector2(20, REEL_WINDOW["height"])
		b.add_theme_font_size_override("font_size", 8)
		if _font != null:
			b.add_theme_font_override("font", _font)
		b.pressed.connect(_apply_reel_power.bind(power_id, i))
		_targeting_layer.add_child(b)

func _arm_shift_targets() -> void:
	_targeting_layer = Control.new()
	_targeting_layer.size = Vector2(SRC_W, SRC_H)
	_targeting_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE # only its buttons capture clicks
	add_child(_targeting_layer)
	for i in 3:
		for dir_key in ["up", "down"]:
			var hit: Dictionary = SHIFT_ARROW_HITS[i][dir_key]
			var b := Button.new()
			b.text = "^" if dir_key == "up" else "v"
			b.position = Vector2(hit["left"], hit["top"])
			b.size = Vector2(hit["width"], hit["height"])
			b.add_theme_font_size_override("font_size", 8)
			if _font != null:
				b.add_theme_font_override("font", _font)
			b.pressed.connect(_apply_shift.bind(i, 1 if dir_key == "up" else -1))
			_targeting_layer.add_child(b)

func _apply_reel_power(power_id: String, reel_index: int) -> void:
	if power_id == "reroll":
		RunStateStore.reroll_reel(reel_index)
	elif power_id == "memory":
		RunStateStore.lock_reel(reel_index)
	_clear_targeting()
	_refresh_reels_from_state()

func _apply_shift(reel_index: int, direction: int) -> void:
	RunStateStore.move_reel(reel_index, direction)
	_clear_targeting()
	_refresh_reels_from_state()

func _clear_targeting() -> void:
	if _targeting_layer != null:
		_targeting_layer.queue_free()
		_targeting_layer = null

func _on_stash_pressed(slot_index: int) -> void:
	var slots := _stash_slots()
	if slot_index >= slots.size():
		return
	RunStateStore.use_consumable(slots[slot_index])
	_refresh_reels_from_state()

func _check_ending() -> void:
	var run := {
		"neurons": RunStateStore.neurons,
		"scoreEarned": RunStateStore.scoreEarned,
		"lucidityCoins": RunStateStore.lucidityCoins,
	}
	var ending: Variant = Endings.check_ending(run, {})
	if ending == null:
		return
	if ending == "wealth" and RunStateStore.wealthContinued:
		return
	_show_ending(String(ending), run)

func _show_ending(ending: String, run: Dictionary) -> void:
	RunStateStore.end_run(ending)
	MetaStateStore.mark_ending_reached(ending)
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
	title.position = Vector2(20, 120)
	title.add_theme_font_size_override("font_size", 16)
	if _font != null:
		title.add_theme_font_override("font", _font)
	title.add_theme_color_override("font_color", Color(1, 0.4, 0.5) if ending == "flatline" else Color(0.5, 1, 0.6))
	title.text = ending.to_upper()
	_overlay.add_child(title)

	var wallet := Label.new()
	wallet.position = Vector2(20, 145)
	wallet.add_theme_font_size_override("font_size", 9)
	if _font != null:
		wallet.add_theme_font_override("font", _font)
	wallet.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	wallet.text = "WALLET %d" % MetaStateStore.lucidityWallet
	_overlay.add_child(wallet)

	var restart := Button.new()
	restart.text = "NEW RUN"
	restart.position = Vector2(40, 175)
	restart.size = Vector2(80, 20)
	restart.add_theme_font_size_override("font_size", 9)
	if _font != null:
		restart.add_theme_font_override("font", _font)
	restart.pressed.connect(_start_run)
	_overlay.add_child(restart)
