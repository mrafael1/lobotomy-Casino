@tool
class_name WealthEndingOverlay
extends Control

signal start_again_pressed

const CANVAS_SIZE := Vector2(160.0, 320.0)
const GOLD := Color("#ffd75a")
const PALE_GOLD := Color("#fff0a3")
const DEEP_PURPLE := Color("#16091c")
const HOT_MAGENTA := Color("#ff2f87")
const NEON_CYAN := Color("#3ff5eb")
const SOFT_PINK := Color("#ffc2df")
const COIN_COUNT := 400
const COIN_SIZE := Vector2(8.0, 8.0)
const COIN_FLOOD_HEIGHT := 90.0
const COIN_FLOOD_SEED := 0x5745414C5448
const DEFAULT_CASH_TRAY_POS := Vector2(80.0, 298.0)
const COIN_PILE_COLUMNS := 20
const COIN_PILE_ROW_SPACING := 4.25
const COIN_RELEASE_START_DELAY := 0.12
const COIN_RELEASE_STAGGER := 0.0025
const COIN_TRAY_POP_TIME := 0.12
const COIN_TRAY_HOLD_TIME := 0.02
const COIN_PILE_FLIGHT_TIME := 0.24
const COIN_TRAY_POP_RISE := 3.0
const COIN_PILE_FLIGHT_RISE := 18.0
const JOKER_OPACITY := 0.16

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var joker_icon: TextureRect = %JokerIcon
@onready var score_caption_label: Label = %ScoreCaptionLabel
@onready var score_label: Label = %ScoreLabel
@onready var coin_flood_clip: Control = %CoinFloodClip
@onready var coin_field: Control = %CoinField
@onready var start_again_button: Button = %StartAgainButton

var _font: FontFile = null
var _coin_texture: Texture2D = null
var _coin_rng := RandomNumberGenerator.new()
var _cash_tray_pos: Vector2 = DEFAULT_CASH_TRAY_POS
var _presentation_started := false
var _coins: Array[TextureRect] = []
var _coin_tray_piles: Array[Vector2] = []
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
		label.add_theme_color_override(&"font_outline_color", DEEP_PURPLE)
		label.add_theme_constant_override(&"outline_size", 2)
	title_label.add_theme_color_override(&"font_color", GOLD)
	title_label.add_theme_color_override(&"font_shadow_color", HOT_MAGENTA)
	title_label.add_theme_constant_override(&"shadow_offset_x", 1)
	title_label.add_theme_constant_override(&"shadow_offset_y", 1)
	subtitle_label.add_theme_color_override(&"font_color", SOFT_PINK)
	score_caption_label.add_theme_color_override(&"font_color", GOLD)
	score_label.add_theme_color_override(&"font_color", PALE_GOLD)
	score_label.add_theme_color_override(&"font_shadow_color", HOT_MAGENTA)
	score_label.add_theme_constant_override(&"shadow_offset_x", 1)
	score_label.add_theme_constant_override(&"shadow_offset_y", 1)


func _style_button() -> void:
	if _font != null:
		start_again_button.add_theme_font_override(&"font", _font)
	start_again_button.add_theme_color_override(&"font_color", PALE_GOLD)
	start_again_button.add_theme_color_override(&"font_hover_color", Color.WHITE)
	start_again_button.add_theme_color_override(&"font_pressed_color", DEEP_PURPLE)
	start_again_button.add_theme_color_override(&"font_focus_color", PALE_GOLD)
	start_again_button.add_theme_stylebox_override(&"normal",
		_button_style(DEEP_PURPLE, GOLD, HOT_MAGENTA))
	start_again_button.add_theme_stylebox_override(&"hover",
		_button_style(Color("#32113c"), PALE_GOLD, NEON_CYAN))
	start_again_button.add_theme_stylebox_override(&"pressed",
		_button_style(GOLD, PALE_GOLD, HOT_MAGENTA))
	start_again_button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())


func _button_style(fill: Color, border: Color, shadow: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	style.shadow_color = Color(shadow, 0.75)
	style.shadow_size = 2
	style.set_content_margin(SIDE_LEFT, 3.0)
	style.set_content_margin(SIDE_RIGHT, 3.0)
	return style


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
	start_again_button.modulate.a = 0.0
	title_label.pivot_offset = title_label.size * 0.5
	score_label.pivot_offset = score_label.size * 0.5
	start_again_button.pivot_offset = start_again_button.size * 0.5
	title_label.scale = Vector2(0.86, 0.86)
	score_label.scale = Vector2(0.45, 0.45)
	start_again_button.scale = Vector2(0.9, 0.9)

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
	button_tween.tween_property(start_again_button, "modulate:a", 1.0, 0.22)
	button_tween.parallel().tween_property(start_again_button, "scale", Vector2.ONE, 0.34)

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
	_coin_targets.clear()
	_coin_rotations.clear()
	_coin_delays.clear()
	_coin_alphas.clear()
	for child: Node in coin_field.get_children():
		child.queue_free()
	var source_local := _cash_tray_pos - coin_flood_clip.position
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
			_coin_rng.randf_range(-4.0, 4.0), _coin_rng.randf_range(-2.0, 2.0))
		var column := index % COIN_PILE_COLUMNS
		var row := index / COIN_PILE_COLUMNS
		var column_width := CANVAS_SIZE.x / float(COIN_PILE_COLUMNS)
		var target_x := float(column) * column_width + column_width * 0.5 - COIN_SIZE.x * 0.5 \
			+ _coin_rng.randf_range(-2.0, 2.0)
		var target_y := COIN_FLOOD_HEIGHT - COIN_SIZE.y \
			- float(row) * COIN_PILE_ROW_SPACING + _coin_rng.randf_range(-1.1, 1.1)
		var target := Vector2(target_x, target_y)
		var start := source_local + Vector2(
			_coin_rng.randf_range(-4.0, 4.0), _coin_rng.randf_range(-2.0, 2.0))
		coin.position = start
		coin.rotation = _coin_rng.randf_range(-0.25, 0.25)
		coin.modulate = Color(1.0, 1.0, 1.0, 0.0)
		coin_field.add_child(coin)
		_coins.append(coin)
		_coin_tray_piles.append(pile_pos)
		_coin_targets.append(target)
		_coin_rotations.append(_coin_rng.randf_range(-0.18, 0.18))
		_coin_delays.append(COIN_RELEASE_START_DELAY + float(index) * COIN_RELEASE_STAGGER)
		_coin_alphas.append(_coin_rng.randf_range(0.78, 1.0))


func _play_coin_flood() -> void:
	for index in _coins.size():
		var coin := _coins[index]
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_interval(_coin_delays[index])
		tween.tween_method(_drive_coin_tray_pop.bind(
			coin, coin.position, _coin_tray_piles[index]), 0.0, 1.0, COIN_TRAY_POP_TIME)
		tween.tween_interval(COIN_TRAY_HOLD_TIME)
		tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		tween.tween_method(_drive_coin_to_pile.bind(
			coin, _coin_tray_piles[index], _coin_targets[index], _coin_rotations[index],
			_coin_alphas[index]), 0.0, 1.0, COIN_PILE_FLIGHT_TIME)


func _drive_coin_tray_pop(t: float, coin: TextureRect, from_pos: Vector2,
		pile_pos: Vector2) -> void:
	if not is_instance_valid(coin):
		return
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var pop := sin(t * PI) * COIN_TRAY_POP_RISE
	coin.position = from_pos.lerp(pile_pos, eased) + Vector2(0.0, -pop)
	coin.modulate.a = minf(t / 0.06, 1.0)


func _drive_coin_to_pile(t: float, coin: TextureRect, from_pos: Vector2,
		to_pos: Vector2, target_rotation: float, target_alpha: float) -> void:
	if not is_instance_valid(coin):
		return
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var arc := sin(t * PI) * COIN_PILE_FLIGHT_RISE
	coin.position = from_pos.lerp(to_pos, eased) + Vector2(0.0, -arc)
	coin.rotation = lerpf(0.0, target_rotation, eased)
	coin.modulate.a = lerpf(0.0, target_alpha, minf(t / 0.08, 1.0))


func _on_start_again_pressed() -> void:
	start_again_pressed.emit()
