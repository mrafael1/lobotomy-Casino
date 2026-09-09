class_name TvOwnership
extends RefCounted

## Who owns the TV screen, and what steps aside for them.
##
## Five things want the CRT: the PAIR/TRIPLE win callout, the power callout, the
## wealth-target blackout, the blinking FREE SPINS banner, and the persistent
## information layers (objective readout, dealer strip, item badges). They arrive
## in any order and
## overlap freely, so "is this allowed to draw" is never a local question — it is
## the answer to the same arbitration every time, which is why it lives in one
## place instead of being re-decided at each call site.
##
## The model is two tiers, not a stack:
##
##   tier 1 — a CALLOUT owns the screen outright. Held as a key in `_sources` for
##            as long as the presentation runs, so overlapping callouts behave as
##            a refcount: the persistent layers come back when the LAST one lets
##            go, not the first. Which callout is on top is the scene tree's
##            business, not this class's.
##   tier 2 — the FREE SPINS BANNER is a weaker owner. It mutes the objective
##            readout, but deliberately leaves the dealer
##            interface and the item badges lit beside it (issues #181, #185):
##            how close the dealer is stays worth reading while free spins are
##            being spent.
##
## The banner lives here rather than beside the other TV widgets precisely because
## it is an owner. Its blink, its state derivation and its mute are one thing, and
## splitting them was what let a HUD refresh put it on screen next to a callout for
## a frame.
##
## Two constructor arguments are worth the ugliness of a nine-argument `_init`: an
## arbiter's contenders ARE its interface, and listing them is the same discipline
## as MachineView itself. Anything reached through a Callable instead is a machine
## decision (what the dealer countdown should read, what the objective bar should
## fill to) that this class only needs to re-trigger, never to make.

## The banner sheet: one authored placement, and one frame of it (issue #185
## follow-up). The banner briefly carried a second, lowered frame for when the item
## badges still sat in the y81..93 band and it had to duck under them. Moving that
## row below the target bar retired the problem, and the banner's own text moved UP
## to y84..89 instead — into the band the goal number vacates while free spins are
## lit — so it now clears the fill bar at y94..98 outright and the bar can keep
## running underneath it.
const BANNER_SHEET := "machine_polished/free_spin.svg"
const BANNER_FRAMES := 1
const BANNER_BLINK_PERIOD := 0.18
## Lit for the first 72% of each period: a duty cycle, not a square wave, so the
## banner reads as blinking rather than flickering.
const BANNER_LIT_FRACTION := 0.72

## Over everything the TV draws — boost icons (12), dealer bar (11), augment row
## (40) — and below the targeting layer (97) and the ending overlay itself.
const BLACKOUT_Z_INDEX := 45
const BLACKOUT_COLOR := Color(0.004, 0.008, 0.016, 1.0)
const BLACKOUT_ALPHA := 0.94 # not opaque: the CRT keeps a faint presence
const BLACKOUT_SOURCE := &"wealth_target"

var _view: MachineView = null
var _screen: Dictionary = {}
var _fx_group := &""

var _augments: AugmentDisplay = null
var _dealer_bar: DealerBar = null
var _boosts: BoostIndicators = null
var _dealer_icon: CanvasItem = null

## What the machine still decides. Re-triggered from here, never answered here.
var _refresh_dealer_countdown := Callable()
var _refresh_target_readout := Callable()
## Whether a spin animation, a queued launch or a held reward is still on the way.
var _spin_in_flight := Callable()

## Tier 1. Keys are owner names; the value is unused — this is a set.
var _sources: Dictionary = {}

## Tier 2.
var _banner_sprite: Sprite2D = null
var _banner_blink_time := 0.0
var _banner_active := false

## Whether the dealer strip was actually on screen before the mute began, so an
## ending that hid it wholesale does not get it back when the mute lifts.
var _restore_dealer_bar_visible := false
var _restore_dealer_icon_visible := false

var _blackout_rect: ColorRect = null
var _blackout_tween: Tween = null

func _init(view: MachineView, screen: Dictionary, fx_group: StringName,
		augments: AugmentDisplay, dealer_bar: DealerBar,
		boosts: BoostIndicators, refresh_dealer_countdown: Callable,
		refresh_target_readout: Callable, spin_in_flight: Callable) -> void:
	_view = view
	_screen = screen
	_fx_group = fx_group
	_augments = augments
	_dealer_bar = dealer_bar
	_boosts = boosts
	_refresh_dealer_countdown = refresh_dealer_countdown
	_refresh_target_readout = refresh_target_readout
	_spin_in_flight = spin_in_flight

## Built at the machine's own point in the layer stack, like every other component:
## the tree order at the call site IS this sprite's z-order.
func build_banner() -> void:
	_banner_sprite = _view.full_canvas_sheet(BANNER_SHEET, BANNER_FRAMES)
	if _banner_sprite != null:
		_banner_sprite.visible = false

## The dealer portrait is built later than the component block (it is part of the
## HUD pass), so it is handed over rather than passed in.
func set_dealer_icon(icon: CanvasItem) -> void:
	_dealer_icon = icon

# --- tier 1: callout ownership -----------------------------------------------

## The live source set. Exposed so the machine can forward it under its old name
## for the smoke checks, which reach it to clear and to assert it drains.
func sources() -> Dictionary:
	return _sources

## Full-screen TV callouts take visual priority over persistent TV information.
## Multiple callouts can overlap (for example a power callout over a win callout),
## so each owner holds a source until its own presentation has finished.
func begin_pop(source: StringName) -> void:
	_capture_restore_state()
	_sources[source] = true
	_augments.hide_pacte_popup()
	_augments.refresh_pacte_badges()
	_refresh_target_readout.call()
	hide_layers()

func end_pop(source: StringName) -> void:
	if not _sources.has(source):
		return
	_sources.erase(source)
	if not _sources.is_empty():
		return
	restore_layers()
	_augments.refresh_pacte_badges()
	_refresh_target_readout.call()

## A full-screen callout — the only owner that clears the TV outright.
func callout_active() -> bool:
	return not _sources.is_empty()

## Anything that takes the TV over: a callout, or the banner.
func content_muted() -> bool:
	return callout_active() or _banner_active

## Only the FIRST owner captures. A later one would snapshot the already-hidden
## state and the dealer strip would never return.
func _capture_restore_state() -> void:
	if content_muted():
		return
	_restore_dealer_bar_visible = _dealer_bar.bar_sprite() != null \
		and _dealer_bar.bar_sprite().visible
	_restore_dealer_icon_visible = _dealer_icon != null and _dealer_icon.visible

## An ending swept the persistent layers away itself. Forget the snapshot, or
## lifting a mute taken before the ending would resurrect what the ending hid.
func forget_restore_state() -> void:
	_restore_dealer_bar_visible = false
	_restore_dealer_icon_visible = false

## Re-applies the mute after the set of TV owners changes.
func apply_mute() -> void:
	if content_muted():
		hide_layers()
	else:
		restore_layers()

func hide_layers() -> void:
	_view.apply_multiplier_fx_visibility()
	# The banner is an owner in its own right, so it hides only for a callout —
	# never for its own mute. The item badges follow the same rule (issue #185):
	# a callout clears them, the banner beside them does not.
	if _banner_sprite != null and callout_active():
		_banner_sprite.visible = false
	if not callout_active():
		_boosts.refresh(callout_active())
		return
	_boosts.hide_popup()
	_boosts.hide_all()
	# Past this point a callout owns the TV, so the dealer interface clears with
	# everything else; under the banner alone it stayed readable and returned above.
	var dealer_nodes: Array = _dealer_bar.overlays()
	dealer_nodes.append(_dealer_icon)
	for node in dealer_nodes:
		var info := node as CanvasItem
		if info != null:
			info.visible = false

func restore_layers() -> void:
	_view.apply_multiplier_fx_visibility()
	refresh_banner()
	if _banner_sprite != null:
		_banner_sprite.visible = _banner_active \
			and _banner_blink_time < BANNER_BLINK_PERIOD * BANNER_LIT_FRACTION
	# The callout is gone but the banner is lit: the dealer interface comes back with
	# the objective. The item badges
	# come back too (issue #185) — the banner drops a frame for them rather than
	# blanking them.
	_boosts.refresh(callout_active())
	_refresh_dealer_countdown.call()
	if _dealer_bar.bar_sprite() != null:
		_dealer_bar.bar_sprite().visible = _restore_dealer_bar_visible \
			or RunStateStore.comboDefeatPending
	if _dealer_icon != null:
		_dealer_icon.visible = _restore_dealer_icon_visible \
			or RunStateStore.comboDefeatPending

# --- tier 2: the FREE SPINS banner -------------------------------------------

func banner_active() -> bool:
	return _banner_active

func banner_sprite() -> Sprite2D:
	return _banner_sprite

## Pins the banner to the lit half of its duty cycle, for the debug shots: the blink
## step would otherwise flip a forced-visible sprite straight back on the next frame.
func pin_banner_lit() -> void:
	_banner_blink_time = 0.0
	if _banner_sprite != null:
		_banner_sprite.visible = true

## Blinks for as long as the NEXT spin is free (banked free spins or an Energy
## Drink no-decay rush) and holds until the lever is pulled — the spin's own state
## commit consumes the credit and clears it. A passive indicator: it never blocks
## input.
func step_banner_blink(delta: float) -> void:
	if _banner_sprite == null or not _banner_active:
		return
	if callout_active():
		_banner_sprite.visible = false
		return
	_banner_blink_time = fmod(_banner_blink_time + delta, BANNER_BLINK_PERIOD)
	_banner_sprite.visible = _banner_blink_time < BANNER_BLINK_PERIOD * BANNER_LIT_FRACTION

func refresh_banner() -> void:
	var active := RunStateStore.runPhase == "running" \
		and (int(RunStateStore.freeSpinsRemaining) > 0 \
			or int(RunStateStore.decaySkips) > 0 or RunStateStore.heartPowerArmed)
	# Never turn the banner ON while a spin is in flight or its reward is still
	# held — a grant made by the spin being revealed must not spoil the result.
	# Turning it OFF mid-spin is fine (pressing spin consumed the last credit).
	if active and not _banner_active and bool(_spin_in_flight.call()):
		active = false
	if callout_active():
		if _banner_sprite != null:
			_banner_sprite.visible = false
		return
	set_banner_display(active)

func set_banner_display(active: bool) -> void:
	if active == _banner_active:
		return
	if active:
		_capture_restore_state()
	_banner_active = active
	_banner_blink_time = 0.0
	if _banner_sprite != null:
		_banner_sprite.visible = active
	# Lighting the banner takes the TV; letting it go out hands it back. Either way
	# every other readout has to re-evaluate its mute right here.
	apply_mute()

# --- the wealth-target blackout ----------------------------------------------

func blackout_rect() -> ColorRect:
	return _blackout_rect

## Fades the TV to black behind the payout screen. Reuses the shared content mute
## for the layers that already know how to step aside (dealer bar, combo, free
## spins) and covers everything else — boost icons, augment row, callout sheets —
## with one rect, rather than enumerating a node list that would rot.
func begin_blackout(fade_time: float) -> void:
	begin_pop(BLACKOUT_SOURCE)
	if _blackout_rect == null or not is_instance_valid(_blackout_rect):
		_blackout_rect = ColorRect.new()
		_blackout_rect.name = "TvBlackout"
		_blackout_rect.position = Vector2(_screen["left"], _screen["top"])
		_blackout_rect.size = Vector2(_screen["width"], _screen["height"])
		_blackout_rect.color = BLACKOUT_COLOR
		_blackout_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_blackout_rect.z_index = BLACKOUT_Z_INDEX
		_blackout_rect.add_to_group(_fx_group)
		_view.add_layer(_blackout_rect)
	_blackout_rect.visible = true
	_blackout_rect.modulate.a = 0.0
	if _blackout_tween != null and _blackout_tween.is_valid():
		_blackout_tween.kill()
	_blackout_tween = _view.tween()
	_blackout_tween.tween_property(_blackout_rect, "modulate:a",
		BLACKOUT_ALPHA, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func end_blackout() -> void:
	if _blackout_tween != null and _blackout_tween.is_valid():
		_blackout_tween.kill()
	_blackout_tween = null
	if _blackout_rect != null and is_instance_valid(_blackout_rect):
		_blackout_rect.visible = false
		_blackout_rect.modulate.a = 0.0
	end_pop(BLACKOUT_SOURCE)
