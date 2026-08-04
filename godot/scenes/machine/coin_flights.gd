class_name CoinFlights
extends RefCounted

## The layer coins fly on, the factory that makes one, and the jackpot payout
## spray (issue #181).
##
## This seam is not in the plan. It surfaced in 4.2c, which wanted the jackpot
## coin fountain and could not take it: the fountain shares the coin layer and
## the coin factory with the power-coin flight, so cutting it would have put both
## on MachineView to serve one of two callers. Cutting the shared floor first is
## what makes the fountain movable, and it makes the power-coin flight movable
## later for the same reason.
##
## The power coin FLOW deliberately stays in the machine: which coins are owed,
## when a batch launches and what a landed coin restores is the power-bar
## economy, not a flight path. Its CURVES are here — where a coin is at time t,
## how the pop sheet plays — because those are the same kind of thing as the
## fountain's arc and were the last motion left outside. The machine keeps the
## tweens, because it owns the callbacks that fire when a coin lands.
##
## Nothing on this class decides anything. Hand it a position and it produces a
## sprite; hand it a `t` and two points and it puts the coin where it belongs;
## ask for a fountain and it sprays one. It is never told WHY a coin is flying,
## and the endpoints are always passed in — the cash tray mouth and the power
## emplacements are the machine's geometry.

const COIN_SIZE := 8.0
const LUCIDITY_ASSET := "ui/coin.png"

## The power chip: flies from the wealth odometer to the gauge when banked score
## buys a restore, or from the cash tray to a power's emplacement on a direct one.
const POWER_ASSET := "ui/power_coin.png"
const POWER_SIZE := 8.0
const POWER_FLIGHT_TIME := 0.64
## The authored pop that plays at the odometer before the chip sets off.
const POP_SHEET := "machine new view/power coin animation.png"
const POP_FRAMES := 4
const POP_FRAME_TIME := 0.06

## Casino-TV payout spray (issue #181): lucidity coins erupt out of the cash tray
## mouth and arc up through the cabinet while the wealth reels roll. Purely
## decorative — no coin corresponds to a Lucidity unit, it just pays in the
## machine's own currency rather than power chips.
const COUNT := 14
const STAGGER := 0.06
const FLIGHT := 0.95
const GRAVITY := 260.0
const RISE := 132.0
const RISE_JITTER := 34.0
const SPREAD := 46.0
const ORIGIN_JITTER := 14.0
const SPIN := 2.5
const FADE_IN := 0.10
const FADE_START := 0.74

var _view: MachineView = null
## The pop is authored cabinet art, so it uses the machine's art filter rather
## than the coins' mipmapped one — those are round and downscaled, this is a sheet
## meant to land on its pixel grid.
var _art_filter := CanvasItem.TEXTURE_FILTER_NEAREST

var _layer: Control = null
var _jackpot_coins: Array[Sprite2D] = []
var _jackpot_tween: Tween = null

func _init(view: MachineView, art_filter: int) -> void:
	_view = view
	_art_filter = art_filter as CanvasItem.TextureFilter

## `z_index` comes from the caller: this layer and the burst layer deliberately
## share one depth, and that is a fact about the machine's layer stack.
func build_layer(z_index: int) -> void:
	_layer = _view.authored_control("CoinLayer")
	if _layer == null:
		_layer = Control.new()
		_layer.name = "CoinLayer"
		_view.add_layer(_layer)
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.z_index = z_index

func layer() -> Control:
	return _layer

## One coin, parented into the layer, scaled to COIN_SIZE and starting invisible —
## every flight fades its own coin in, so a coin that is never driven never shows.
func make_coin(pos: Vector2, asset: String) -> Sprite2D:
	if _layer == null:
		return null
	var tex := _view.texture(asset, true)
	if tex == null:
		return null
	var coin := Sprite2D.new()
	coin.texture = tex
	coin.centered = true
	coin.position = pos
	var coin_scale := COIN_SIZE / float(maxi(1, tex.get_width()))
	coin.scale = Vector2(coin_scale, coin_scale)
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	coin.modulate.a = 0.0
	_layer.add_child(coin)
	return coin

## --- the power chip ------------------------------------------------------------

func make_power_coin(pos: Vector2) -> Sprite2D:
	return make_coin(pos, POWER_ASSET)

## The pop sheet, parented into the coin layer at the origin and starting
## invisible. Uncentered and unpositioned on purpose: it is full-canvas art whose
## frames already sit where the odometer is.
func make_power_pop() -> Sprite2D:
	if _layer == null:
		return null
	var tex := _view.texture(POP_SHEET, true)
	if tex == null:
		return null
	var pop := Sprite2D.new()
	pop.texture = tex
	pop.hframes = POP_FRAMES
	pop.vframes = 1
	pop.frame = 0
	pop.centered = false
	pop.position = Vector2.ZERO
	pop.texture_filter = _art_filter
	pop.modulate.a = 0.0
	_layer.add_child(pop)
	return pop

func power_pop_time() -> float:
	return float(POP_FRAMES) * POP_FRAME_TIME

## Steps the pop sheet, fading in over the first tenth and out over the last fifth
## so it blooms and dissolves rather than cutting.
func drive_power_pop(t: float, pop: Sprite2D) -> void:
	if not is_instance_valid(pop):
		return
	var progress := clampf(t, 0.0, 1.0)
	pop.frame = mini(POP_FRAMES - 1, floori(progress * float(POP_FRAMES)))
	if progress < 0.1:
		pop.modulate.a = progress / 0.1
	elif progress < 0.82:
		pop.modulate.a = 1.0
	else:
		pop.modulate.a = 1.0 - ((progress - 0.82) / 0.18)

## The chip lifts before it travels: straight up for the first third, then across
## to the target. It grows as it leaves and shrinks as it arrives, which reads as
## the coin coming toward the player and then away into the cabinet.
func drive_power_coin(t: float, coin: Sprite2D, from_pos: Vector2, to_pos: Vector2) -> void:
	if not is_instance_valid(coin):
		return
	var lift := Vector2(from_pos.x, from_pos.y - 26.0)
	var p: Vector2
	if t < 0.35:
		p = from_pos.lerp(lift, t / 0.35)
	else:
		p = lift.lerp(to_pos, (t - 0.35) / 0.65)
	coin.position = p
	var base_scale := POWER_SIZE / float(maxi(1, coin.texture.get_width()))
	var s := lerpf(0.4, 1.15, minf(t / 0.18, 1.0)) if t < 0.18 else lerpf(1.15, 0.9, (t - 0.18) / 0.82)
	coin.scale = Vector2(base_scale * s, base_scale * s)
	if t < 0.12:
		coin.modulate.a = t / 0.12
	elif t < 0.9:
		coin.modulate.a = 1.0
	else:
		coin.modulate.a = 1.0 - ((t - 0.9) / 0.1)

## --- the payout fountain --------------------------------------------------------

## Sprays the payout fountain from `tray` — the cash tray mouth, which is the
## machine's geometry and so is asked for. Returns how long the spray runs, so
## the caller can keep the sequence locked until the money has finished landing.
func spawn_jackpot_fountain(tray: Vector2) -> float:
	# Back-to-back jackpots (a rescore, a power) must not stack two tweens.
	clear_jackpot_coins()
	if _layer == null:
		return 0.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_jackpot_tween = _view.tween()
	_jackpot_tween.set_parallel(true)
	for i in COUNT:
		var origin := tray + Vector2(rng.randf_range(-ORIGIN_JITTER, ORIGIN_JITTER), 0.0)
		var coin := make_coin(origin, LUCIDITY_ASSET)
		if coin == null:
			break
		_jackpot_coins.append(coin)
		var rise := RISE + rng.randf_range(-RISE_JITTER, RISE_JITTER)
		# Launch speed for the wanted apex; the coins fade while still rising, so the
		# spray reads as leaving the cabinet rather than raining back into the tray.
		var velocity := Vector2(
			rng.randf_range(-SPREAD, SPREAD),
			-sqrt(2.0 * GRAVITY * maxf(8.0, rise)))
		var base_scale := COIN_SIZE / float(maxi(1, coin.texture.get_width()))
		var delay := float(i) * STAGGER
		_jackpot_tween.tween_method(
			_drive_jackpot_coin.bind(coin, origin, velocity, base_scale, rng.randf() * TAU),
			0.0, 1.0, FLIGHT).set_delay(delay)
		_jackpot_tween.tween_callback(_free_jackpot_coin.bind(coin)) \
			.set_delay(delay + FLIGHT)
	return jackpot_fountain_time()

func jackpot_fountain_time() -> float:
	return float(COUNT - 1) * STAGGER + FLIGHT

func _drive_jackpot_coin(t: float, coin: Sprite2D, origin: Vector2, velocity: Vector2,
		base_scale: float, spin_phase: float) -> void:
	if not is_instance_valid(coin):
		return
	var elapsed := t * FLIGHT
	coin.position = origin + velocity * elapsed \
		+ Vector2(0.0, 0.5 * GRAVITY * elapsed * elapsed)
	# Horizontal squash only: a flat pixel coin reads as tumbling without needing
	# authored spin frames.
	var squash := maxf(0.16, absf(cos(spin_phase + t * TAU * SPIN)))
	coin.scale = Vector2(base_scale * squash, base_scale)
	if t < FADE_IN:
		coin.modulate.a = t / FADE_IN
	elif t > FADE_START:
		coin.modulate.a = clampf(1.0 - (t - FADE_START) / (1.0 - FADE_START), 0.0, 1.0)
	else:
		coin.modulate.a = 1.0

func _free_jackpot_coin(coin: Node) -> void:
	if coin != null and is_instance_valid(coin):
		_jackpot_coins.erase(coin)
		coin.queue_free()

## The coin-layer sweep only hides its children, so the spray needs an explicit free or
## it leaks across an ending.
func clear_jackpot_coins() -> void:
	if _jackpot_tween != null and _jackpot_tween.is_valid():
		_jackpot_tween.kill()
	_jackpot_tween = null
	for coin: Sprite2D in _jackpot_coins:
		if is_instance_valid(coin):
			coin.queue_free()
	_jackpot_coins.clear()

## Hides whatever is mid-flight on the layer without freeing it, matching how the
## machine sweeps its other transient layers.
func hide_pending() -> void:
	if _layer == null:
		return
	for child: Node in _layer.get_children():
		var item := child as CanvasItem
		if item != null:
			item.visible = false
			item.modulate.a = 0.0

## --- what the smoke checks read ------------------------------------------------

func jackpot_coins() -> Array[Sprite2D]:
	return _jackpot_coins
