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

# Visible (non-book) symbols used for the spin-blur animation.
const VISIBLE_SYMBOLS := ["brain", "eye", "pill", "syringe", "vial", "flatline"]

var _reel_sprites: Array[Sprite2D] = []
var _hud_labels := {}
var _overlay: Control = null
var _spin_button: Button = null
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
	RunStateStore.start_new_run(MetaStateStore.ownedPermanents, MetaStateStore.get_pending_consumables())
	for i in 3:
		_set_reel_symbol(i, VISIBLE_SYMBOLS[i])
	_update_hud()

func _do_spin() -> void:
	if _spinning_anim:
		return
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
