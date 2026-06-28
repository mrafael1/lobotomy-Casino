extends Control

## Pre-run shop + scores hub (Milestone 3). Spend wallet Lucidity on permanent
## upgrades (buy_upgrade) and pre-run consumables (buy_consumable_charge), review
## run history, then START RUN. All purchases go through MetaStateStore, which
## persists to user:// immediately — so the wallet/upgrades survive an app restart
## (the M3 save QA gate). This scene is the loop hub: shop -> run -> bank -> shop.

const MACHINE_SCENE := "res://scenes/machine_scene.tscn"

# Debug: a wallet top-up so the shop is exercisable before runs have banked much.
const DEBUG := true

var _font: FontFile = null
var _header: Label = null
var _endings: Label = null
var _list: VBoxContainer = null
var _rows := {} # id -> Button

func _ready() -> void:
	_font = _load_font("font/DTM-Mono.otf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	MetaStateStore.meta_changed.connect(_refresh)
	_refresh()

func _load_font(rel: String) -> FontFile:
	var path := ProjectSettings.globalize_path("res://").path_join("../assets").path_join(rel)
	var f := FontFile.new()
	if f.load_dynamic_font(path) != OK:
		return null
	return f

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
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

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
		b.pressed.connect(_buy_consumable.bind(String(c["id"])))
		_list.add_child(b)
		_rows["C:" + String(c["id"])] = b

	var footer := HBoxContainer.new()
	footer.position = Vector2(6, 296)
	add_child(footer)
	var start := _styled_button("START RUN", 10)
	start.pressed.connect(_start_run)
	footer.add_child(start)
	if DEBUG:
		var dbg := _styled_button("+200", 8)
		dbg.pressed.connect(_debug_add_lucidity)
		footer.add_child(dbg)

# ── refresh ────────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_header.text = "WALLET %d   RUNS %d   BEST %d" % [
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
