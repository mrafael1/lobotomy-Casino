class_name StashTray
extends RefCounted

## The consumable stash in the machine's bottom-right corner: one icon per slot,
## and where the tray sits in the layer stack.
##
## Seam 4.7a, and the leaf half of the stash. What a tap DOES — which item is
## used, whether the machine will allow it, what it costs — is
## _on_stash_pressed's 58 lines of run flow and stays in the machine. So does
## _stash_slots(), which reads RunStateStore.
##
## That split is what makes this cuttable at all. The stash was originally grouped
## with the augments in the plan and deliberately deferred from seam 4.1, because
## its state is threaded through _sequence_lock_active, _spin_launch_pending and
## _dealer_offer_popup — 16, 19 and 26 readers respectively. None of those three
## is touched here: every one of them lives on the flow side.
##
## Bare TextureRects, tapped rather than dragged. The dealer, shop and in-run
## overlay stashes are drag targets and build their own; this one shares only the
## layout and scale with them (issue #26), through Assets.

## Presentation stack: while the dealer's offer is open the tray must draw — and
## receive drags — above his overlay; every close path drops it back under the HUD.
const TRAY_Z_INDEX := 50
const DEALER_Z_INDEX := 110

var _view: MachineView = null

## The machine's own tap handler, bound per slot. Which item a tap spends is run
## flow and never becomes this component's business.
var _on_input: Callable

var _icons: Array = []

func _init(view: MachineView, on_input: Callable) -> void:
	_view = view
	_on_input = on_input

## Reuses the authored slot nodes when the .tscn has them and builds bare icons
## when it does not, so an authored tray keeps its placement and a scene without
## one still gets a working stash.
func build(slot_count: int) -> void:
	_icons.clear()
	for i in maxi(1, slot_count):
		var slot := slot_node(i)
		var icon := icon_for_slot(slot, i)
		var authored := slot != null
		if icon == null:
			icon = TextureRect.new()
			icon.name = "StashSlot%d" % i
			_view.add_layer(icon)
		if not authored:
			icon.position = Assets.stash_slot_pos(i, slot_count)
			icon.size = Vector2(Assets.STASH_ICON_SIZE, Assets.STASH_ICON_SIZE)
			_apply_icon_fit(icon)
		elif icon.has_meta("_machine_generated_stash_icon"):
			_apply_icon_fit(icon)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		var cb := _on_input.bind(icon, i)
		if not icon.gui_input.is_connected(cb):
			icon.gui_input.connect(cb)
		_icons.append(icon)

## Keeps the icons crisp and the same size as the drag stashes in the other
## scenes. Applied to icons this component made, never to an authored TextureRect
## that came with its own import settings.
func _apply_icon_fit(icon: TextureRect) -> void:
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## The authored slot for one index, under any of the names the scene has used for
## it. The list is history rather than design: the tray has been re-parented and
## re-indexed across issues, and an authored scene from any of those eras still
## has to resolve.
func slot_node(index: int) -> Control:
	var one_based := index + 1
	for path in [
		"stash/StashSlot%d" % one_based,
		"CoinLayer/stash/StashSlot%d" % one_based,
		"StashSlot%d" % index,
		"StashSlot%d" % one_based,
	]:
		var slot := _view.authored_control(path)
		if slot != null:
			return slot
	return null

## The TextureRect inside a slot — the slot itself when it is one, otherwise its
## "Icon" child, created and marked if the authored node is a plain container.
func icon_for_slot(slot: Control, _index: int) -> TextureRect:
	if slot == null:
		return null
	if slot is TextureRect:
		return slot as TextureRect
	var icon := slot.get_node_or_null("Icon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.set_meta("_machine_generated_stash_icon", true)
		icon.position = Vector2.ZERO
		icon.size = slot.size
		slot.add_child(icon)
	return icon

func icons() -> Array:
	return _icons

func set_icons_visible(v: bool) -> void:
	for icon in _icons:
		icon.visible = v

## The authored tray container, when the scene has one. Looked up rather than
## held: it is the .tscn's node, and the icons above may or may not be its
## children depending on which era the scene was authored in.
func _tray() -> Control:
	return _view.authored_control("stash")

func set_tray_visible(v: bool) -> void:
	var tray := _tray()
	if tray != null:
		tray.visible = v
	set_icons_visible(v)

func set_elevated(elevated: bool) -> void:
	var tray := _tray()
	if tray != null:
		tray.z_index = DEALER_Z_INDEX if elevated else TRAY_Z_INDEX
