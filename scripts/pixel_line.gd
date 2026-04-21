extends Node2D
class_name PixelLine

@export var pixel_size: int = 1
@export var line_width: int = 1
@export var line_color: Color = Color.WHITE
@export var snap_to_grid: bool = true

var target_position = Vector2.ZERO

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var a := Vector2i.ZERO

	var b_raw = target_position - global_position
	var b_vec = b_raw / float(pixel_size) if snap_to_grid else b_raw
	var b := Vector2i(roundi(b_vec.x), roundi(b_vec.y))

	var perp := _perp_offsets(a, b)
	var half: int = line_width >> 1

	for p in bresenham_line(a, b):
		for w in range(-(half), line_width - half):
			var offset := perp * w
			var pos := Vector2(p.x + offset.x, p.y + offset.y) * float(pixel_size)
			draw_rect(Rect2(pos, Vector2.ONE * float(pixel_size)), line_color, true)

static func _perp_offsets(a: Vector2i, b: Vector2i) -> Vector2i:
	var dx := b.x - a.x
	var dy := b.y - a.y
	if abs(dx) >= abs(dy):
		return Vector2i(0, 1)
	else:
		return Vector2i(1, 0)

static func bresenham_line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var x0 := a.x
	var y0 := a.y
	var x1 := b.x
	var y1 := b.y

	var dx = abs(x1 - x0)
	var sx = 1 if x0 < x1 else -1
	var dy = -abs(y1 - y0)
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy

	var points: Array[Vector2i] = []
	while true:
		points.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 = err * 2
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

	return points
