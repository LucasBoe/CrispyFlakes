extends RoomBase
class_name RoomOutsideBase

var mat : ShaderMaterial

func init_room(_x : int, _y : int):
	is_outside_room = true
	var canvas_item = get_child(0) as CanvasItem
	mat = canvas_item.material.duplicate(true)
	canvas_item.material = mat
	super.init_room(_x, _y)
	
func set_outline(state):
	if mat == null:
		return
		
	var color = Color.WHITE if state else Color.BLACK
	mat.set_shader_parameter("outline_color", color)

static func custom_placement_check(location) -> bool:
	return location.y == 0
