class_name NPCLookInfo

var head_index : Vector2i
var color_offsets : Vector3

static func new_random() -> NPCLookInfo:
	var look = NPCLookInfo.new()
	look.head_index = Vector2i(randi_range(0, 16), randi_range(0, 9))
	look.color_offsets = Vector3(randf(), randf_range(0.5, 0.833333), randf_range(-0.2, 0.5))
	return look
