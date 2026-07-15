@tool
class_name WealthEndingOverlay
extends Control

signal start_again_pressed

const CANVAS_SIZE := Vector2(160.0, 320.0)
const NEON_PINK := Color(1.0, 0.5, 0.7)
const NEON_YELLOW := Color(1.0, 0.86, 0.36)
const NEON_YELLOW_GLOW := Color(1.0, 0.86, 0.36, 0.72)
const COIN_COUNT := 400
const COIN_SIZE := Vector2(8.0, 8.0)
const COIN_FLOOD_HEIGHT := 90.0
const COIN_FLOOD_SEED := 0x5745414C5448
const DEFAULT_CASH_TRAY_POS := Vector2(80.0, 298.0)
const COIN_PILE_COLUMNS := 20
const COIN_PILE_ROW_SPACING := 3.35
const COIN_RELEASE_START_DELAY := 0.12
const COIN_RELEASE_STAGGER := 0.004
const COIN_TRAY_POP_TIME := 0.26
const COIN_TRAY_HOLD_TIME := 0.12
const COIN_PILE_FLIGHT_TIME := 0.42
const COIN_TRAY_POP_RISE := 3.0
const COIN_BURST_FRAC := 0.4
const COIN_BURST_RISE := 24.0
const COIN_BURST_SCATTER := 26.0
const JOKER_OPACITY := 0.16

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var joker_icon: TextureRect = %JokerIcon
@onready var score_caption_label: Label = %ScoreCaptionLabel
@onready var score_label: Label = %ScoreLabel
@onready var coin_flood_clip: Control = %CoinFloodClip
@onready var coin_field: Control = %CoinField
@onready var button_host: Control = %ButtonHost
@onready var start_again_button: Button = %StartAgainButton

var _font: FontFile = null
var _coin_texture: Texture2D = null
var _coin_rng := RandomNumberGenerator.new()
var _cash_tray_pos: Vector2 = DEFAULT_CASH_TRAY_POS
var _presentation_started := false
var _coins: Array[TextureRect] = []
var _coin_tray_piles: Array[Vector2] = []
var _coin_burst_positions: Array[Vector2] = []
var _coin_targets: Array[Vector2] = []
var _coin_rotations: Array[float] = []
var _coin_delays: Array[float] = []
var _coin_alphas: Array[float] = []


func _ready() -> void:
	set_deferred("size", CANVAS_SIZE)
	_font = Assets.font()
	_style_labels()
	_style_button()
	_setup_joker()
	if not start_again_button.pressed.is_connected(_on_start_again_pressed):
		start_again_button.pressed.connect(_on_start_again_pressed)
	Assets.start_menu_button_press_feedback(start_again_button)
	button_host.pivot_offset = button_host.size * 0.5
	if Engine.is_editor_hint():
		set_final_score(999999)
		return


func present(total_score: int, cash_tray_pos: Vector2 = DEFAULT_CASH_TRAY_POS) -> void:
	set_final_score(total_score)
	_cash_tray_pos = cash_tray_pos
	if _presentation_started:
		return
	_presentation_started = true
	_prepare_coin_flood()
	_play_reveal()


func set_final_score(total_score: int) -> void:
	if score_label != null:
		score_label.text = _score_with_separators(total_score)


func _score_with_separators(value: int) -> String:
	var digits := str(absi(value))
	var groups: Array[String] = []
	while digits.length() > 3:
		groups.push_front(digits.right(3))
		digits = digits.left(digits.length() - 3)
	groups.push_front(digits)
	return ("-" if value < 0 else "") + ",".join(groups)


func _style_labels() -> void:
	for label: Label in [title_label, subtitle_label, score_caption_label, score_label]:
		if _font != null:
			label.add_theme_font_override(&"font", _font)
		label.add_theme_color_override(&"font_outline_color", Color.BLACK)
		label.add_theme_constant_override(&"outline_size", 1)
	title_label.add_theme_color_override(&"font_color", NEON_YELLOW)
	title_label.add_theme_color_override(&"font_shadow_color", NEON_YELLOW_GLOW)
	title_label.add_theme_constant_override(&"shadow_offset_x", 1)
	title_label.add_theme_constant_override(&"shadow_offset_y", 1)
	subtitle_label.add_theme_color_override(&"font_color", NEON_PINK)
	score_caption_label.add_theme_color_override(&"font_color", NEON_PINK)
	score_label.add_theme_color_override(&"font_color", NEON_YELLOW)
	score_label.add_theme_color_override(&"font_shadow_color", NEON_YELLOW_GLOW)
	score_label.add_theme_constant_override(&"shadow_offset_x", 1)
	score_label.add_theme_constant_override(&"shadow_offset_y", 1)


func _style_button() -> void:
	Assets.small_neon_button_style(start_again_button, NEON_YELLOW, 8, 2.0)


func _setup_joker() -> void:
	var texture := Assets.augmented_suit_icon("joker")
	if texture == null:
		joker_icon.visible = false
		return
	joker_icon.texture = texture
	joker_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	joker_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	joker_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	joker_icon.pivot_offset = joker_icon.size * 0.5
	joker_icon.scale = Vector2(0.72, 0.72)
	joker_icon.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _play_reveal() -> void:
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	score_caption_label.modulate.a = 0.0
	score_label.modulate.a = 0.0
	button_host.modulate.a = 0.0
	title_label.pivot_offset = title_label.size * 0.5
	score_label.pivot_offset = score_label.size * 0.5
	button_host.pivot_offset = button_host.size * 0.5
	title_label.scale = Vector2(0.86, 0.86)
	score_label.scale = Vector2(0.45, 0.45)
	button_host.scale = Vector2(0.9, 0.9)

	var title_tween := create_tween()
	title_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title_tween.tween_interval(0.08)
	title_tween.tween_property(title_label, "modulate:a", 1.0, 0.22)
	title_tween.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.34)
	title_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	title_tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.18)

	var joker_tween := create_tween()
	joker_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	joker_tween.tween_interval(0.76)
	joker_tween.tween_property(joker_icon, "modulate:a", JOKER_OPACITY, 0.34)
	joker_tween.parallel().tween_property(joker_icon, "scale", Vector2.ONE, 0.34)

	var score_tween := create_tween()
	score_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	score_tween.tween_interval(0.62)
	score_tween.tween_property(score_caption_label, "modulate:a", 1.0, 0.16)
	score_tween.tween_property(score_label, "modulate:a", 1.0, 0.16)
	score_tween.parallel().tween_property(score_label, "scale", Vector2.ONE, 0.42)

	var button_tween := create_tween()
	button_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	button_tween.tween_interval(1.24)
	button_tween.tween_property(button_host, "modulate:a", 1.0, 0.22)
	button_tween.parallel().tween_property(button_host, "scale", Vector2.ONE, 0.34)

	_play_coin_flood()


func _prepare_coin_flood() -> void:
	_coin_texture = Assets.texture("ui/coin_cumulable.png", true)
	if _coin_texture == null:
		return
	_coin_rng.seed = COIN_FLOOD_SEED
	coin_flood_clip.size = Vector2(CANVAS_SIZE.x, COIN_FLOOD_HEIGHT)
	coin_field.size = coin_flood_clip.size
	_coins.clear()
	_coin_tray_piles.clear()
	_coin_burst_positions.clear()
	_coin_targets.clear()
	_coin_rotations.clear()
	_coin_delays.clear()
	_coin_alphas.clear()
	for child: Node in coin_field.get_children():
		child.queue_free()
	var source_local := _cash_tray_pos - coin_flood_clip.position
	var surface_offsets: Array[float] = []
	for column in COIN_PILE_COLUMNS:
		surface_offsets.append(_coin_rng.randf_range(-3.5, 3.5))
	for index in COIN_COUNT:
		var coin := TextureRect.new()
		coin.name = "Coin%02d" % index
		coin.texture = _coin_texture
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.size = COIN_SIZE
		coin.pivot_offset = COIN_SIZE * 0.5
		var pile_pos := source_local + Vector2(
			_coin_rng.randf_range(-11.0, 11.0), -_coin_rng.randf_range(0.0, 6.0))
		var burst_pos := source_local + Vector2(
			_coin_rng.randf_range(-COIN_BURST_SCATTER * 0.5, COIN_BURST_SCATTER * 0.5),
			-COIN_BURST_RISE - _coin_rng.randf_range(0.0, 4.0))
		var column := index % COIN_PILE_COLUMNS
		var row := index / COIN_PILE_COLUMNS
		var column_width := CANVAS_SIZE.x / float(COIN_PILE_COLUMNS)
		var row_offset := column_width * 0.5 if row % 2 == 1 else 0.0
		var target_x := float(column) * column_width + row_offset \
			- COIN_SIZE.x * 0.5 + _coin_rng.randf_range(-1.2, 1.2)
		target_x = clampf(target_x, -1.0, CANVAS_SIZE.x - COIN_SIZE.x + 1.0)
		var row_depth := clampf(float(row) / 19.0, 0.0, 1.0)
		var target_y := COIN_FLOOD_HEIGHT - COIN_SIZE.y \
			- float(row) * COIN_PILE_ROW_SPACING \
			+ surface_offsets[column] * row_depth + _coin_rng.randf_range(-0.7, 0.7)
		var target := Vector2(target_x, target_y)
		var start := source_local
		coin.position = start
		coin.rotation = 0.0
		coin.modulate = Color(1.0, 1.0, 1.0, 0.0)
		coin_field.add_child(coin)
		_coins.append(coin)
		_coin_tray_piles.append(pile_pos)
		_coin_burst_positions.append(burst_pos)
		_coin_targets.append(target)
		_coin_rotations.append(_coin_rng.randf_range(-0.26, 0.26))
		_coin_delays.append(COIN_RELEASE_START_DELAY + float(index) * COIN_RELEASE_STAGGER)
		_coin_alphas.append(_coin_rng.randf_range(0.85, 1.0))


func _play_coin_flood() -> void:
	var fall_phase_time := float(_coins.size() - 1) * COIN_RELEASE_STAGGER \
		+ COIN_TRAY_POP_TIME
	var travel_start_time := fall_phase_time + COIN_TRAY_HOLD_TIME
	for index in _coins.size():
		var coin := _coins[index]
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_interval(_coin_delays[index])
		tween.tween_method(_drive_coin_tray_pop.bind(
			coin, coin.position, _coin_tray_piles[index]), 0.0, 1.0, COIN_TRAY_POP_TIME)
		tween.tween_interval(maxf(0.0, travel_start_time - _coin_delays[index] \
			- COIN_TRAY_POP_TIME))
		tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		tween.tween_method(_drive_coin_to_pile.bind(
			coin, _coin_tray_piles[index], _coin_burst_positions[index], _coin_targets[index],
			_coin_rotations[index], _coin_alphas[index]), 0.0, 1.0, COIN_PILE_FLIGHT_TIME)


func _drive_coin_tray_pop(t: float, coin: TextureRect, from_pos: Vector2,
		pile_pos: Vector2) -> void:
	if not is_instance_valid(coin):
		return
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var pop := sin(t * PI) * COIN_TRAY_POP_RISE
	coin.position = from_pos.lerp(pile_pos, eased) + Vector2(0.0, -pop)
	coin.modulate.a = minf(t / 0.06, 1.0)


func _drive_coin_to_pile(t: float, coin: TextureRect, from_pos: Vector2,
		burst_pos: Vector2, to_pos: Vector2, target_rotation: float, target_alpha: float) -> void:
	if not is_instance_valid(coin):
		return
	var p: Vector2
	if t < COIN_BURST_FRAC:
		p = from_pos.lerp(burst_pos, t / COIN_BURST_FRAC)
	else:
		p = burst_pos.lerp(to_pos, (t - COIN_BURST_FRAC) / (1.0 - COIN_BURST_FRAC))
	coin.position = p
	coin.rotation = lerpf(0.0, target_rotation, t)
	if t < 0.1:
		coin.modulate.a = t / 0.1
	else:
		# Unlike normal reward coins, these are the permanent wealth-ending pile.
		coin.modulate.a = target_alpha


func _on_start_again_pressed() -> void:
	start_again_pressed.emit()
