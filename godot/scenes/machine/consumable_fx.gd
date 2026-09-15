class_name ConsumableFx
extends RefCounted

## The layer every consumable's effect draws on, and each of those effects.
##
## Six items paint the cabinet: Tobacco's per-reel covers and smoke, Energy
## Drink's burning edges, White Powder's "?" covers and its screen ripple, Tea's
## sakura drift, Water's pour. They had nothing in common in the machine except
## the layer they shared and the teardown that had to remember all of them — which
## is exactly what made a new effect cost an edit in four unrelated places
## (`_build_fx_layer`, the refresh, the ending sweep, the run reset).
##
## What stays in the machine is every question about WHETHER an effect should be
## up. That is run state — how many reels the scoring is ignoring, whether the
## drink is still running, whether a joker Water should get the pour or its
## absence — plus the @export gates, which are the machine's tuning surface. This
## class is told "two reels are smoking" or "ripple for 0.55s" and does it.
##
## The colours and thicknesses come in at build(), because that is the only place
## they are read; the timings come in per call, because a tuning tweak between two
## uses should take effect on the second one.
##
## The cabinet shake and the potion jump are deliberately NOT here. They animate
## the machine node itself rather than anything on this layer, so they belong to
## whoever owns that node.

## The cabinet's transparent reel holes are y169-203 in the art (measured with
## pngjs), 1px taller above and 3px below REEL_HOLES — full-reel covers must span
## the real hole or the symbol strip peeks out underneath.
const COVER_PAD_TOP := 1.0
const COVER_PAD_BOTTOM := 3.0

## Water's on-use pour: an authored full-canvas sheet, played once.
const WATER_SHEET := "machine new view/water.png"
const WATER_SHEET_FRAMES := 3
## Over the cabinet and the TV, under the overlays.
const WATER_Z_INDEX := 30

const PETALS_Z_INDEX := 65
const RIPPLE_Z_INDEX := 70

const SMOKE_AMOUNT := 14
const SMOKE_LIFETIME := 1.8
## Already smoking when it first appears, rather than starting from a clear reel.
const SMOKE_PREPROCESS := 1.2

## The edges breathe between these two alphas rather than blinking.
const ENERGY_ALPHA_LOW := 0.35
const ENERGY_ALPHA_HIGH := 1.0

var _view: MachineView = null
var _holes: Array = []
var _canvas := Vector2.ZERO
var _distortion_shader: Shader = null

var _layer: Control = null
var _tobacco_covers: Array = []
var _tobacco_smoke: Array = []
var _tunnel_shutter: TextureRect = null
var _learning_attachment: TextureRect = null
var _tunnel_shutter_tween: Tween = null
var _energy_edges: Control = null
var _hidden_covers: Array = []

var _energy_pulse_tween: Tween = null
var _energy_active := false
var _water_sprite: Sprite2D = null
var _water_tween: Tween = null
var _ripple_tween: Tween = null

func _init(view: MachineView, reel_holes: Array, canvas: Vector2,
		distortion_shader: Shader) -> void:
	_view = view
	_holes = reel_holes
	_canvas = canvas
	_distortion_shader = distortion_shader

## The full-reel rect a cover must span. Public because the blur covers are
## ReelBlur's but live on this layer and have to line up with these ones.
func cover_rect(hole: Dictionary) -> Rect2:
	return Rect2(
		float(hole["left"]),
		float(hole["top"]) - COVER_PAD_TOP,
		float(hole["width"]),
		float(hole["height"]) + COVER_PAD_TOP + COVER_PAD_BOTTOM)

## `style` carries the tuning read only here: tobacco_cover, tobacco_smoke,
## energy_edge, energy_thickness, hidden_cover, hidden_glyph.
func build(style: Dictionary) -> void:
	_layer = _view.authored_control("ConsumableFxLayer")
	if _layer == null:
		_layer = Control.new()
		_layer.name = "ConsumableFxLayer"
		_view.add_layer(_layer)
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_tobacco(style["tobacco_cover"], style["tobacco_smoke"])
	_build_energy_edges(style["energy_edge"], float(style["energy_thickness"]))
	_build_hidden_covers(style["hidden_cover"], style["hidden_glyph"])
	_build_tunnel_shutter()
	_build_learning_attachment()

func layer() -> Control:
	return _layer

## --- what the smoke checks read ------------------------------------------------
## The effects are only observable as nodes, so the checks assert on them directly:
## which reel is covered, whether its smoke emits, whether the edges are lit.

func tobacco_covers() -> Array:
	return _tobacco_covers

func tobacco_smoke() -> Array:
	return _tobacco_smoke

func hidden_covers() -> Array:
	return _hidden_covers

func energy_edges() -> Control:
	return _energy_edges

func water_sprite() -> Sprite2D:
	return _water_sprite

## Kills a ripple mid-flight without waiting out its tween. The distortion shader
## keeps drawing until its tween finishes, so a check that moves on to the next
## scenario has to be able to end it.
func stop_ripple() -> void:
	if _ripple_tween != null and _ripple_tween.is_valid():
		_ripple_tween.kill()
	_ripple_tween = null

## The nodes that must survive the ending's layer sweep — they are state, not
## transient flourishes, and a sweep that freed them would leave a smoked reel
## uncoverable for the rest of the run.
func persistent_nodes() -> Array:
	var nodes: Array = []
	nodes.append_array(_tobacco_covers)
	nodes.append_array(_tobacco_smoke)
	if _energy_edges != null:
		nodes.append(_energy_edges)
	nodes.append_array(_hidden_covers)
	if _tunnel_shutter != null:
		nodes.append(_tunnel_shutter)
	if _learning_attachment != null:
		nodes.append(_learning_attachment)
	return nodes

func _build_learning_attachment() -> void:
	_learning_attachment = TextureRect.new()
	_learning_attachment.name = "LearningAttachment"
	_learning_attachment.texture = preload("res://assets/images/machine_polished/learning_attachment.svg")
	_learning_attachment.size = _canvas
	_learning_attachment.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_learning_attachment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_learning_attachment.visible = false
	_layer.add_child(_learning_attachment)

func set_learning_attachment(active: bool) -> void:
	if _learning_attachment != null:
		_learning_attachment.visible = active

## A fitted mechanical attachment. The opaque scoring cover underneath remains
## authoritative, including when Tobacco and Tunnel Vision coexist.
func _build_tunnel_shutter() -> void:
	_tunnel_shutter = TextureRect.new()
	_tunnel_shutter.name = "TunnelVisionShutter"
	_tunnel_shutter.texture = preload("res://assets/images/machine_polished/tunnel_shutter.svg")
	var rect := cover_rect(_holes.back())
	_tunnel_shutter.position = rect.position
	_tunnel_shutter.size = rect.size
	_tunnel_shutter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tunnel_shutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tunnel_shutter.visible = false
	_layer.add_child(_tunnel_shutter)

func set_tunnel_shutter(active: bool) -> void:
	if _tunnel_shutter == null or _tunnel_shutter.visible == active:
		return
	if _tunnel_shutter_tween != null and _tunnel_shutter_tween.is_valid():
		_tunnel_shutter_tween.kill()
	_tunnel_shutter.visible = active
	_tunnel_shutter.scale.y = 1.0
	if active:
		_tunnel_shutter.scale.y = 0.08
		_tunnel_shutter_tween = _tunnel_shutter.create_tween()
		_tunnel_shutter_tween.tween_property(_tunnel_shutter, "scale:y", 1.0, 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# --- Tobacco / Tunnel Vision --------------------------------------------------

## Serum frost (issue #53): translucent per-reel covers — symbols show through but
## read harder. Reuses the hidden-cover geometry.
func _build_tobacco(cover_color: Color, smoke_color: Color) -> void:
	_tobacco_covers.clear()
	_tobacco_smoke.clear()
	for i in _holes.size():
		var hole: Dictionary = _holes[i]
		var cover := ColorRect.new()
		cover.name = "TobaccoCover%d" % i
		cover.color = cover_color
		var rect := cover_rect(hole)
		cover.position = rect.position
		cover.size = rect.size
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.visible = false
		_layer.add_child(cover)
		_tobacco_covers.append(cover)
		var smoke := CPUParticles2D.new()
		smoke.name = "TobaccoSmoke%d" % i
		smoke.amount = SMOKE_AMOUNT
		smoke.lifetime = SMOKE_LIFETIME
		smoke.preprocess = SMOKE_PREPROCESS
		smoke.position = Vector2(
			float(hole["left"]) + float(hole["width"]) * 0.5,
			float(hole["top"]) + float(hole["height"]) * 0.75)
		smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		smoke.emission_rect_extents = Vector2(float(hole["width"]) * 0.3, 2.0)
		smoke.direction = Vector2(0, -1)
		smoke.spread = 18.0
		smoke.gravity = Vector2(0, -10)
		smoke.initial_velocity_min = 2.0
		smoke.initial_velocity_max = 6.0
		smoke.scale_amount_min = 1.0
		smoke.scale_amount_max = 2.6
		smoke.color = smoke_color
		smoke.emitting = false
		smoke.visible = false
		_layer.add_child(smoke)
		_tobacco_smoke.append(smoke)

## `hidden` is how many reels the scoring is ignoring, counted from the RIGHT
## (reels.slice keeps the first ones). `smoking` is whether those reels should
## also emit — every ignored reel is covered whatever took it away, but only
## Tobacco actually smokes; Tunnel Vision blinds a reel silently (issue #181).
func set_tobacco(hidden: int, smoking: bool) -> void:
	for i in _tobacco_covers.size():
		var covered: bool = i >= _tobacco_covers.size() - hidden
		(_tobacco_covers[i] as ColorRect).visible = covered
		if i < _tobacco_smoke.size():
			var smoke := _tobacco_smoke[i] as CPUParticles2D
			var emits: bool = covered and smoking
			smoke.visible = emits
			smoke.emitting = emits

# --- Energy Drink -------------------------------------------------------------

func _build_energy_edges(edge_color: Color, thickness: float) -> void:
	_energy_edges = Control.new()
	_energy_edges.name = "EnergyEdges"
	_energy_edges.set_anchors_preset(Control.PRESET_FULL_RECT)
	_energy_edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy_edges.visible = false
	var t := thickness
	var rects := [
		Rect2(0.0, 0.0, _canvas.x, t),                       # top
		Rect2(0.0, _canvas.y - t, _canvas.x, t),             # bottom
		Rect2(0.0, t, t, _canvas.y - 2.0 * t),               # left
		Rect2(_canvas.x - t, t, t, _canvas.y - 2.0 * t),     # right
	]
	for r in rects:
		var edge := ColorRect.new()
		edge.color = edge_color
		edge.position = (r as Rect2).position
		edge.size = (r as Rect2).size
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_energy_edges.add_child(edge)
	_layer.add_child(_energy_edges)

## Returns true when the state actually changed, because the caller pairs a change
## with returning the spins tube's own fade — and re-running that every frame would
## fight whatever else is animating it.
func set_energy(active: bool, pulse_time: float) -> bool:
	if _energy_edges == null or active == _energy_active:
		return false
	_energy_active = active
	if _energy_pulse_tween != null and _energy_pulse_tween.is_valid():
		_energy_pulse_tween.kill()
	_energy_pulse_tween = null
	_energy_edges.visible = active
	if active:
		_energy_edges.modulate.a = ENERGY_ALPHA_LOW
		_energy_pulse_tween = _view.tween().set_loops()
		_energy_pulse_tween.tween_property(_energy_edges, "modulate:a",
			ENERGY_ALPHA_HIGH, pulse_time * 0.5)
		_energy_pulse_tween.tween_property(_energy_edges, "modulate:a",
			ENERGY_ALPHA_LOW, pulse_time * 0.5)
	return true

# --- White Powder -------------------------------------------------------------

func _build_hidden_covers(cover_color: Color, glyph_color: Color) -> void:
	_hidden_covers.clear()
	for i in _holes.size():
		var hole: Dictionary = _holes[i]
		var cover := ColorRect.new()
		cover.name = "HiddenResultCover%d" % i
		cover.color = cover_color
		var rect := cover_rect(hole)
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
		var font := _view.font()
		if font != null:
			glyph.add_theme_font_override("font", font)
		glyph.add_theme_color_override("font_color", glyph_color)
		glyph.add_theme_color_override("font_outline_color", Color.BLACK)
		glyph.add_theme_constant_override("outline_size", 1)
		cover.add_child(glyph)
		_layer.add_child(cover)
		_hidden_covers.append(cover)

func set_hidden_cover(index: int, visible_now: bool) -> void:
	if index >= 0 and index < _hidden_covers.size():
		(_hidden_covers[index] as ColorRect).visible = visible_now

func hide_hidden_covers() -> void:
	for cover in _hidden_covers:
		(cover as ColorRect).visible = false

func white_powder_ripple(strength: float, time: float) -> void:
	if _layer == null or _distortion_shader == null:
		return
	if _ripple_tween != null and _ripple_tween.is_valid():
		_ripple_tween.kill()
	var ripple := ColorRect.new()
	ripple.name = "WhitePowderDistortion"
	ripple.size = _canvas
	ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ripple.z_index = RIPPLE_Z_INDEX
	var mat := ShaderMaterial.new()
	mat.shader = _distortion_shader
	mat.set_shader_parameter("amount", strength)
	mat.set_shader_parameter("ripple_time", 0.0)
	ripple.material = mat
	_layer.add_child(ripple)
	_ripple_tween = _view.tween()
	_ripple_tween.set_parallel(true)
	_ripple_tween.tween_property(mat, "shader_parameter/ripple_time", 1.0, time)
	_ripple_tween.tween_property(mat, "shader_parameter/amount", 0.0, time)
	_ripple_tween.set_parallel(false)
	_ripple_tween.tween_callback(ripple.queue_free)

# --- Tea and Water ------------------------------------------------------------

func tea_petals(count: int, petal_time: float, color: Color) -> void:
	if _layer == null:
		return
	var petals := CPUParticles2D.new()
	petals.name = "TeaSakuraPetals"
	petals.z_index = PETALS_Z_INDEX
	petals.amount = count
	petals.lifetime = petal_time
	petals.one_shot = true
	petals.explosiveness = 0.35
	petals.position = Vector2(-8.0, _canvas.y * 0.45)
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(4.0, _canvas.y * 0.32)
	petals.direction = Vector2(1.0, 0.08)
	petals.spread = 10.0
	petals.gravity = Vector2(0.0, 1.5)
	petals.initial_velocity_min = 48.0
	petals.initial_velocity_max = 70.0
	petals.angular_velocity_min = -90.0
	petals.angular_velocity_max = 90.0
	petals.scale_amount_min = 0.7
	petals.scale_amount_max = 1.25
	petals.color = color
	var tex := _view.texture("ui/sakura_petal.png", false)
	if tex != null:
		petals.texture = tex
		petals.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layer.add_child(petals)
	petals.emitting = true
	var tw := _view.tween()
	tw.tween_interval(petal_time + 0.2)
	tw.tween_callback(petals.queue_free)

## The authored pour, stepped once and then cleared. Built on FIRST use rather
## than at startup: most runs never see a Water, and an unused full-canvas sheet
## is the kind of thing that quietly costs a frame on a phone.
func pour_water(frame_time: float) -> void:
	if _water_sprite == null or not is_instance_valid(_water_sprite):
		_water_sprite = _view.full_canvas_sheet(WATER_SHEET, WATER_SHEET_FRAMES)
		if _water_sprite == null:
			return
		_water_sprite.name = "WaterFx"
		_water_sprite.z_index = WATER_Z_INDEX
	if _water_tween != null and _water_tween.is_valid():
		_water_tween.kill()
	_water_sprite.modulate.a = 1.0
	_water_sprite.visible = true
	_view.set_sheet_frame(_water_sprite, 0)
	_water_tween = _view.tween()
	for frame in range(1, WATER_SHEET_FRAMES):
		_water_tween.tween_interval(frame_time)
		_water_tween.tween_callback(_view.set_sheet_frame.bind(_water_sprite, frame))
	_water_tween.tween_interval(frame_time)
	_water_tween.tween_callback(hide_water)

func hide_water() -> void:
	if _water_sprite != null and is_instance_valid(_water_sprite):
		_water_sprite.visible = false

# --- teardown -----------------------------------------------------------------

## Everything off, every tween dead. The run reset's half — an ending or a new run
## must not inherit a smoked reel or a running pulse.
func reset() -> void:
	set_tunnel_shutter(false)
	set_learning_attachment(false)
	if _energy_pulse_tween != null and _energy_pulse_tween.is_valid():
		_energy_pulse_tween.kill()
	_energy_pulse_tween = null
	_energy_active = false
	if _energy_edges != null:
		_energy_edges.visible = false
	for cover: CanvasItem in _tobacco_covers:
		cover.visible = false
	for smoke_node: Node in _tobacco_smoke:
		var smoke := smoke_node as CPUParticles2D
		if smoke != null:
			smoke.emitting = false
			smoke.visible = false
	hide_hidden_covers()
	if _water_tween != null and _water_tween.is_valid():
		_water_tween.kill()
	_water_tween = null
	hide_water()
	if _ripple_tween != null and _ripple_tween.is_valid():
		_ripple_tween.kill()
	_ripple_tween = null
