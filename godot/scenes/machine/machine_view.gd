class_name MachineView
extends RefCounted

## The contract between machine_scene.gd and the components being cut out of it.
##
## machine_scene.gd is 8,800 lines and holds ~220 fields; the components carved
## from it still need a handful of things that genuinely belong to the whole
## machine — the node to parent into, the shared font, the helpers that build a
## texture or an info bubble the same way everywhere. Handing each component the
## machine itself would make every one of those 220 fields reachable, and the
## split would buy nothing: the god object would simply have aliases.
##
## So this is the list, written down. A component can reach exactly what is on
## this class and nothing else, which means the coupling between a component and
## its host is countable — you are reading it. It grows one entry at a time, as
## each seam is cut and proves it needs something, and any growth is a deliberate
## edit to this file rather than a field access nobody notices.
##
## Signals are deliberately not the mechanism here. The codebase already uses
## them correctly, upward from overlays to the scenes that own them; forcing them
## sideways between six siblings of the same scene would replace one big object
## with a web that is harder to follow than the object was.

var host: Node = null

func _init(machine: Node) -> void:
	host = machine

## Parent a node into the machine's own children, which is where every one of
## these overlays has always lived — the z_index each component sets is only
## meaningful against that shared parent.
func add_layer(node: Node) -> void:
	host.add_child(node)

## The machine's pixel font. Read through a call rather than copied at
## construction: components are built during _ready, and the font is not
## necessarily loaded by the time the first one exists.
func font() -> Font:
	return host._font

func texture(rel: String, mipmaps := false) -> Texture2D:
	return host._load_texture(rel, mipmaps)

func set_sheet_frame(sprite: Sprite2D, frame: int) -> void:
	host._set_sheet_frame(sprite, frame)

## A full-canvas animation strip, built the machine's way: it reuses an authored
## sprite from the .tscn when one exists under the derived name and only creates
## a node when it does not. A component that built its own Sprite2D would
## silently orphan the authored placement.
func full_canvas_sheet(rel: String, hframes: int, frame := 0) -> Sprite2D:
	return host._build_full_canvas_sheet(rel, hframes, frame)

## Tweens belong to a Node, and the components are RefCounted — so they borrow
## the machine's, which also means a component's animations die with the scene
## exactly like the machine's own always have.
func tween() -> Tween:
	return host.create_tween()

## The TV callout priority stack. A component that takes the screen over holds a
## source for as long as its presentation runs; the machine restores the
## persistent TV layers once the last source lets go.
func begin_tv_info_pop(source: StringName) -> void:
	host._begin_tv_info_pop(source)

func end_tv_info_pop(source: StringName) -> void:
	host._end_tv_info_pop(source)

## True while anything owns the TV — a callout or the FREE SPIN banner. The
## persistent components check it before showing themselves.
func tv_content_muted() -> bool:
	return host._tv_content_muted()

## Push the wealth odometer up to at least `value`, never down. The odometer is
## still the machine's (it is 4.3's seam); a callout that has been holding the
## final score releases it through here.
func raise_display_lucidity(value: int) -> void:
	host._set_display_lucidity(maxi(host._display_lucidity, value))

## Re-apply the frenzy-gauge effects' visibility. The combo-loss art draws over
## the same band, so showing or clearing it changes what the gauge may draw.
func apply_multiplier_fx_visibility() -> void:
	host._apply_multiplier_fx_visibility()

func info_bubble(node_name: String, source: String, border: Color,
		font_color: Color, max_width := 0.0) -> Control:
	return host._make_info_bubble(node_name, source, border, font_color, max_width)

## True while the TV is showing a callout of its own. Components that open a
## description bubble step aside for one rather than stacking on top of it.
func tv_callout_open() -> bool:
	return not (host._tv_info_pop_sources as Dictionary).is_empty()
