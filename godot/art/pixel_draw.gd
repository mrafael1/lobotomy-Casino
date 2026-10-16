class_name PixelDraw
extends RefCounted

## Runtime geometry rasterized into whole layout-pixel spans. Animated values
## remain continuous; only their presentation is stepped onto the art's grid.
static func radial_texture(size: int = 32, tint: Color = Color.WHITE) -> ImageTexture:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var distance := Vector2(x - 3.5, y - 3.5).length()
			var alpha := 1.0 if distance < 1.5 else 0.4 if distance < 2.5 else 0.14 if distance < 3.5 else 0.0
			image.set_pixel(x, y, Color(tint, tint.a * alpha))
	image.resize(size, size, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

static func rect(item: CanvasItem, bounds: Rect2, color: Color, filled := true,
		width := -1.0, _antialiased := false) -> void:
	var r := Rect2(bounds.position.round(), bounds.size.round())
	if filled:
		item.draw_rect(r, color)
		return
	var thickness := maxi(1, roundi(width))
	item.draw_rect(Rect2(r.position, Vector2(r.size.x, thickness)), color)
	item.draw_rect(Rect2(r.position + Vector2(0, r.size.y - thickness), Vector2(r.size.x, thickness)), color)
	item.draw_rect(Rect2(r.position, Vector2(thickness, r.size.y)), color)
	item.draw_rect(Rect2(r.position + Vector2(r.size.x - thickness, 0), Vector2(thickness, r.size.y)), color)

static func line(item: CanvasItem, from: Vector2, to: Vector2, color: Color,
		width := 1.0, _antialiased := false) -> void:
	var a := Vector2i(from.round())
	var b := Vector2i(to.round())
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var error := dx + dy
	var thickness := maxi(1, roundi(width))
	while true:
		item.draw_rect(Rect2(Vector2(a) - Vector2.ONE * floorf(thickness * 0.5),
			Vector2.ONE * thickness), color)
		if a == b:
			break
		var twice := error * 2
		if twice >= dy:
			error += dy
			a.x += sx
		if twice <= dx:
			error += dx
			a.y += sy

static func polyline(item: CanvasItem, points: PackedVector2Array, color: Color,
		width := 1.0, antialiased := false) -> void:
	for index in range(points.size() - 1):
		line(item, points[index], points[index + 1], color, width, antialiased)

static func colored_polygon(item: CanvasItem, points: PackedVector2Array,
		color: Color) -> void:
	if points.size() < 3:
		return
	var top := points[0].y
	var bottom := top
	for point in points:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	for y in range(floori(top), ceili(bottom)):
		var scan := float(y) + 0.5
		var crossings: Array[float] = []
		for index in points.size():
			var a := points[index]
			var b := points[(index + 1) % points.size()]
			if (a.y <= scan and b.y > scan) or (b.y <= scan and a.y > scan):
				crossings.append(a.x + (scan - a.y) * (b.x - a.x) / (b.y - a.y))
		crossings.sort()
		for index in range(0, crossings.size() - 1, 2):
			var left := ceili(crossings[index] - 0.5)
			var right := ceili(crossings[index + 1] - 0.5)
			if right > left:
				item.draw_rect(Rect2(left, y, right - left, 1), color)

static func circle(item: CanvasItem, center: Vector2, radius: float, color: Color,
		filled := true, width := -1.0, _antialiased := false) -> void:
	var origin := center.round()
	var r := maxi(1, roundi(radius))
	var inner := maxi(0, r - maxi(1, roundi(width)))
	for y in range(-r, r + 1):
		var outside := floori(sqrt(maxi(0, r * r - y * y)))
		if filled or absi(y) >= inner:
			item.draw_rect(Rect2(origin + Vector2(-outside, y), Vector2(outside * 2 + 1, 1)), color)
		else:
			var inside := floori(sqrt(maxi(0, inner * inner - y * y)))
			item.draw_rect(Rect2(origin + Vector2(-outside, y), Vector2(maxi(1, outside - inside), 1)), color)
			item.draw_rect(Rect2(origin + Vector2(inside + 1, y), Vector2(maxi(1, outside - inside), 1)), color)

static func arc(item: CanvasItem, center: Vector2, radius: float, start: float,
		end: float, point_count: int, color: Color, width := 1.0,
		_antialiased := false) -> void:
	var previous := center + Vector2.from_angle(start) * radius
	for index in range(1, maxi(2, point_count)):
		var angle := lerpf(start, end, float(index) / float(maxi(2, point_count) - 1))
		var point := center + Vector2.from_angle(angle) * radius
		line(item, previous, point, color, width)
		previous = point
