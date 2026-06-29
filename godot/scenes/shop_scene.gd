extends Control

## Pre-run shop + scores hub (Milestone 3). Spend wallet Lucidity on permanent
## upgrades (buy_upgrade) and pre-run consumables (buy_consumable_charge), review
## run history, then START RUN. All purchases go through MetaStateStore, which
## persists to user:// immediately — so the wallet/upgrades survive an app restart
## (the M3 save QA gate). This scene is the loop hub: shop -> run -> bank -> shop.

const MACHINE_SCENE := "res://scenes/machine_scene.tscn"
const SCORES_SCENE := "res://scenes/scores_scene.tscn"
const MENU_SCENE := "res://scenes/start_menu_scene.tscn"

# Debug top-up is disabled for Android polish builds; parity/dev fixtures can
# still seed wallet state through MetaStateStore or save JSON when needed.
const DEBUG := false

const ITEM_ICONS := {
	"cons_focus": "items/focus_serum.png",
	"cons_white_powder": "items/white_powder.png",
	"cons_syringe": "items/consumable_placeholder.png",
	"cons_tea": "items/herbal_tea.png",
}

var _font: FontFile = null
var _tex_cache := {}
var _header: Label = null
var _endings: Label = null
var _list: VBoxContainer = null
var _rows := {} # id -> Button

func _ready() -> void:
	_font = _load_font("font/DTM-Sans.otf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	MetaStateStore.meta_changed.connect(_refresh)
	_refresh()

func _load_font(rel: String) -> FontFile:
	return Assets.font(rel)

func _load_texture(rel: String, mipmaps := false) -> Texture2D:
	return Assets.texture(rel, mipmaps)

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
	spr.scale = Vector2(160.0 / frame_w, 320.0 / float(tex.get_height()))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(spr)
	return spr

func _build_shop_art_background() -> void:
	_build_full_canvas_sheet("dealer_shop_bg.png", 1)
	_build_full_canvas_sheet("dealer_portrait.png", 2)
	_build_full_canvas_sheet("dealer_shop_counter.png", 1)

	var readability := ColorRect.new()
	readability.color = Color(0.02, 0.015, 0.035, 0.68)
	readability.position = Vector2(3, 3)
	readability.size = Vector2(154, 286)
	add_child(readability)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	return l

func _styled_button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if _font != null:
		b.add_theme_font_override("font", _font)
	return b

func _build() -> void:
	_build_shop_art_background()

	var root := VBoxContainer.new()
	root.position = Vector2(6, 6)
	root.custom_minimum_size = Vector2(148, 0)
	add_child(root)

	root.add_child(_label("LOBOTOMY — SHOP", 11, Color(0.8, 0.9, 1.0)))
	_header = _label("", 8, Color(0.9, 0.9, 0.7))
	root.add_child(_header)
	_endings = _label("", 8, Color(0.7, 0.8, 0.9))
	root.add_child(_endings)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(148, 230)
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(146, 0)
	scroll.add_child(_list)

	_list.add_child(_label("— UPGRADES —", 8, Color(1.0, 0.7, 0.5)))
	for u in Upgrades.all_upgrades():
		var b := _styled_button("", 8)
		b.pressed.connect(_buy_upgrade.bind(String(u["id"])))
		_list.add_child(b)
		_rows["U:" + String(u["id"])] = b

	_list.add_child(_label("— CONSUMABLES —", 8, Color(1.0, 0.7, 0.5)))
	for c in Consumables.LIST:
		var b := _styled_button("", 8)
		var icon := _load_texture(ITEM_ICONS.get(String(c["id"]), "items/consumable_placeholder.png"))
		if icon != null:
			b.icon = icon
			b.expand_icon = true
		b.pressed.connect(_buy_consumable.bind(String(c["id"])))
		_list.add_child(b)
		_rows["C:" + String(c["id"])] = b

	var footer := HBoxContainer.new()
	footer.position = Vector2(6, 296)
	add_child(footer)
	var start := _styled_button("START RUN", 10)
	start.pressed.connect(_start_run)
	footer.add_child(start)
	var scores := _styled_button("SCORES", 8)
	scores.pressed.connect(func(): get_tree().change_scene_to_file(SCORES_SCENE))
	footer.add_child(scores)
	var back := _styled_button("MENU", 8)
	Assets.skin_negative_button(back)
	back.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	footer.add_child(back)
	if DEBUG:
		var dbg := _styled_button("+200", 8)
		dbg.pressed.connect(_debug_add_lucidity)
		footer.add_child(dbg)

# ── refresh ────────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_header.text = "CREDITS %d   RUNS %d   BEST %d" % [
		MetaStateStore.lucidityWallet,
		int(MetaStateStore.history.get("runsPlayed", 0)),
		int(MetaStateStore.history.get("bestScoreRun", 0)),
	]
	var reached: Array = MetaStateStore.endingsReached
	_endings.text = "REACHED: %s" % ("none" if reached.is_empty() else ", ".join(PackedStringArray(reached)))

	var owned: Array = MetaStateStore.ownedPermanents
	for u in Upgrades.all_upgrades():
		var id := String(u["id"])
		var b: Button = _rows["U:" + id]
		var cost := int(u["cost"])
		var tier := (" " + String(u["tierLabel"])) if u.has("tierLabel") else ""
		if owned.has(id):
			b.text = "%s%s  OWNED" % [String(u["name"]), tier]
			b.disabled = true
		elif u.has("requiresId") and not owned.has(String(u["requiresId"])):
			b.text = "%s%s  (needs prev)" % [String(u["name"]), tier]
			b.disabled = true
		else:
			b.text = "%s%s  %dL" % [String(u["name"]), tier, cost]
			b.disabled = MetaStateStore.lucidityWallet < cost

	var pending: Dictionary = MetaStateStore.get_pending_consumables()
	var slots_full := Consumables.total_copies(pending) >= Consumables.MAX_CONSUMABLE_SLOTS
	for c in Consumables.LIST:
		var id := String(c["id"])
		var b: Button = _rows["C:" + id]
		var cost := int(c["shopCost"])
		var held := int(pending.get(id, 0))
		b.text = "%s  %dL  x%d" % [String(c["name"]), cost, held]
		b.disabled = slots_full or MetaStateStore.lucidityWallet < cost

# ── actions ──────────────────────────────────────────────────────────────────────────

func _buy_upgrade(id: String) -> void:
	MetaStateStore.buy_upgrade(id)

func _buy_consumable(id: String) -> void:
	MetaStateStore.buy_consumable_charge(id)

func _debug_add_lucidity() -> void:
	MetaStateStore.lucidityWallet += 200
	MetaStateStore.save_state()
	MetaStateStore.meta_changed.emit()

func _start_run() -> void:
	RunStateStore.start_new_run(MetaStateStore.ownedPermanents, MetaStateStore.get_pending_consumables())
	get_tree().change_scene_to_file(MACHINE_SCENE)
