class_name UiKit
extends RefCounted

## The small UI chores every screen does the same way.
##
## Each of these existed three or four times over, copied into whichever scene needed it
## next, and the copies had already started to drift: one _apply_font knew about
## RichTextLabel, another had a CheckBox branch that could never fire because CheckBox is
## a Button and the Button branch caught it first. None of that drift was intentional and
## none of it was visible from any single file.
##
## Kept deliberately thin. This is the place for a chore that is genuinely identical
## everywhere, not a home for "UI stuff" — a scene whose needs differ should keep its own
## version rather than grow a flag here.

## ── reaching the Assets cache ─────────────────────────────────────────────────────
##
## Resolved through the tree at call time rather than written as `Assets.` directly.
##
## An autoload is not a known identifier while a script is being COMPILED, and for
## anything in the dependency chain of a `-s` main script that compile happens before the
## autoloads are registered at all. Naming Assets directly in a class like this one works
## everywhere inside the game — every scene loads long after startup — and then fails on
## the debug entry points under test/, which reach these classes from a script that is
## itself the main script. That is a bad trade: the failure lands nowhere near the cause,
## and only on the tooling. A node lookup costs a dictionary hit and works in both.
##
## The kits all come through here rather than each repeating the dance.
static func assets() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(^"Assets")
	return null

static func texture(rel: String, mipmaps := false) -> Texture2D:
	var a := assets()
	return a.texture(rel, mipmaps) if a != null else null

static func font() -> FontFile:
	var a := assets()
	return a.font() if a != null else null

## Tiny5 is drawn only on its native eight-pixel grid (or an exact multiple).
## Dense body copy keeps its existing metrics until its layout is migrated.
static func control_font() -> FontFile:
	var a := assets()
	return a.font("font/Tiny5-Regular.ttf") if a != null else null

static func control_font_size(requested: int) -> int:
	return maxi(8, roundi(float(requested) / 8.0) * 8) if requested >= 6 else requested

static func style_display_label(label: Label, size: int = 8, available_width: float = 0.0) -> void:
	if label == null:
		return
	label.add_theme_font_override("font", control_font())
	var resolved_size := control_font_size(size)
	if available_width > 0.0 and resolved_size > 8:
		var text_width := control_font().get_string_size(String(TranslationServer.translate(label.text)), HORIZONTAL_ALIGNMENT_LEFT, -1, resolved_size).x
		if text_width > available_width:
			resolved_size = 8
	label.add_theme_font_size_override("font_size", resolved_size)
	label.add_theme_constant_override("outline_size", 0)

static func centered_text_nudge(font_size: int) -> float:
	var a := assets()
	return a.centered_text_nudge(font_size) if a != null else 0.0

## An AtlasTexture cut from one of the shared sheets.
static func atlas(asset: String, region: Rect2) -> AtlasTexture:
	var out := AtlasTexture.new()
	out.atlas = texture(asset)
	out.region = region
	return out

## Connects a button once. The guard matters because several screens rebuild their
## contents in place and would otherwise stack a second connection on every rebuild,
## firing the callback twice per press.
static func connect_button(button: Button, cb: Callable) -> void:
	if button == null:
		return
	if not button.pressed.is_connected(cb):
		button.pressed.connect(cb)

## Puts the game font on every text node under `node`, recursively.
##
## RichTextLabel takes "normal_font" rather than "font"; only the upgrades screen knew
## that, and it is the reason this version is the one that was kept. CheckBox needs no
## branch of its own -- it is a Button.
static func apply_font(node: Node) -> void:
	var f := font()
	if f == null:
		return
	for child in node.get_children():
		if child is Label:
			(child as Label).add_theme_font_override("font", f)
		elif child is RichTextLabel:
			(child as RichTextLabel).add_theme_font_override("normal_font", f)
		elif child is Button:
			(child as Button).add_theme_font_override("font", f)
		apply_font(child)
