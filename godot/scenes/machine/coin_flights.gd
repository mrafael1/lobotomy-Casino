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
## economy, not a flight path. It builds its coins through make_coin() here and
## keeps its own tweens.
##
## Nothing on this class decides anything. Hand it a position and it produces a
## sprite; ask for a fountain and it sprays one.

const COIN_SIZE := 8.0
const LUCIDITY_ASSET := "ui/coin.png"

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

var _layer: Control = null
var _jackpot_coins: Array[Sprite2D] = []
var _jackpot_tween: Tween = null

func _init(view: MachineView) -> void:
	_view = view

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
