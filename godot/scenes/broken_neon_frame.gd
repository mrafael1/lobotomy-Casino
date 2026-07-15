@tool
class_name BrokenNeonFrame
extends Control

@export var neon_color := Color("#ff334d")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var right := size.x
	var bottom := size.y
	var segments := [
		[Vector2(1.0, 1.0), Vector2(29.0, 1.0)],
		[Vector2(34.0, 1.0), Vector2(69.0, 1.0)],
		[Vector2(75.0, 1.0), Vector2(right - 2.0, 1.0)],
		[Vector2(1.0, bottom - 1.0), Vector2(20.0, bottom - 1.0)],
		[Vector2(25.0, bottom - 1.0), Vector2(81.0, bottom - 1.0)],
		[Vector2(88.0, bottom - 1.0), Vector2(right - 2.0, bottom - 1.0)],
		[Vector2(1.0, 1.0), Vector2(1.0, 13.0)],
		[Vector2(1.0, 18.0), Vector2(1.0, bottom - 1.0)],
		[Vector2(right - 1.0, 1.0), Vector2(right - 1.0, 9.0)],
		[Vector2(right - 1.0, 14.0), Vector2(right - 1.0, bottom - 1.0)],
	]
	for segment: Array in segments:
		_draw_neon_segment(segment[0] as Vector2, segment[1] as Vector2)
	# Short inward fractures make the gaps read as damage instead of decoration.
	_draw_neon_segment(Vector2(29.0, 1.0), Vector2(34.0, 5.0))
	_draw_neon_segment(Vector2(81.0, bottom - 1.0), Vector2(86.0, bottom - 5.0))
	_draw_neon_segment(Vector2(right - 1.0, 9.0), Vector2(right - 5.0, 14.0))


func _draw_neon_segment(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, Color(neon_color, 0.2), 5.0, false)
	draw_line(from, to, neon_color, 1.0, false)
