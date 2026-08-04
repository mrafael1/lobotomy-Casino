class_name ReactionFlash
extends RefCounted

## The full-screen announcements: a colour wash with a word over it, and the
## flatline result's line-across-the-reels.
##
## Both build the same throwaway host — a Control in the machine's transient-fx
## group, z 30, some art, a tween, free — and both were sitting in the middle of
## the file next to the run logic that triggers them. Neither survives its own
## tween, so there is nothing to close and nothing to remember.
##
## The close-call heartbeat is NOT here, for the same reason the cocktail shake
## stayed out of ConsumableFx: it zooms the machine node itself rather than
## drawing anything, so it belongs to whoever owns that node.
##
## Every word and colour is passed in. Whether a strike reads "CLOSE CALL" or
## "FLATLINE" is a question about how many are left in the run, and this class
## does not know what a run is.

const Z_INDEX := 30
const FLASH_ALPHA := 0.32
const LINE_HEIGHT := 2.0

var _view: MachineView = null
var _canvas := Vector2.ZERO
var _fx_group := &""

func _init(view: MachineView, canvas: Vector2, fx_group: StringName) -> void:
	_view = view
	_canvas = canvas
	_fx_group = fx_group

## A colour wash over the whole cabinet with one word punched into it. Used for
## triple grants and item reactions.
func play(color: Color, text: String, flash_time: float) -> void:
	var host := _spawn_host()
	var flash := ColorRect.new()
	flash.color = Color(color.r, color.g, color.b, 0.0)
	flash.size = _canvas
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(flash)
	var label := _view.reaction_label(host, text, Vector2(0.0, 150.0), 14, color)
	label.pivot_offset = Vector2(_canvas.x * 0.5, 10.0)
	label.scale = Vector2(0.7, 0.7)
	var tw := _view.tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "color:a", FLASH_ALPHA, flash_time * 0.25)
	tw.tween_property(label, "scale", Vector2.ONE, flash_time * 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(flash_time * 0.4)
	tw.chain().tween_property(host, "modulate:a", 0.0, flash_time * 0.35)
	tw.chain().tween_callback(host.queue_free)

## The flatline strike: a line drawn across the reel window, the strike's count
## under it, and — when the run survives it — the charge it puts on the next win.
##
## `charge_text` empty means a fatal strike, which ends the run and so has no next
## win to promise. That is the caller's call, not this one's.
func play_flatline(reel_window: Dictionary, color: Color, headline: String,
		charge_text: String, flash_time: float) -> void:
	var host := _spawn_host()
	var cy := float(reel_window["top"]) + float(reel_window["height"]) * 0.5
	var line := ColorRect.new()
	line.color = color
	line.size = Vector2(0.0, LINE_HEIGHT)
	line.position = Vector2(0.0, cy - LINE_HEIGHT * 0.5)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(line)
	var label := _view.reaction_label(host, headline, Vector2(0.0, cy + 8.0), 10, color)
	label.pivot_offset = Vector2(_canvas.x * 0.5, 6.0)
	if charge_text != "":
		var charge := _view.reaction_label(host, charge_text,
			Vector2(0.0, cy + 20.0), 8, color)
		charge.pivot_offset = Vector2(_canvas.x * 0.5, 5.0)
	var tw := _view.tween()
	tw.tween_property(line, "size:x", _canvas.x, flash_time * 0.5)
	tw.tween_interval(flash_time * 0.3)
	tw.tween_property(host, "modulate:a", 0.0, flash_time * 0.3)
	tw.tween_callback(host.queue_free)

## In the machine's transient-fx group so an ending sweeps a flash still counting
## down — the run is over and its announcement should go with it.
func _spawn_host() -> Control:
	var host := Control.new()
	host.add_to_group(_fx_group)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.z_index = Z_INDEX
	_view.add_layer(host)
	return host
