extends Node

class_name Util

static func get_random_element(collection):
	if collection is Array:
		if collection.size() == 0:
			push_error("Array is empty.")
			return null
		return collection[randi() % collection.size()]
	elif collection is Dictionary:
		var keys = collection.keys()
		if keys.size() == 0:
			push_error("Dictionary is empty.")
			return null
		var random_key = keys[randi() % keys.size()]
		return collection[random_key]
	else:
		push_error("Unsupported collection type. Must be Array or Dictionary.")
		return null

static func world_to_ui_position(world_position, ui, camera):
	var rect = camera.get_camera_world_rect() as Rect2	
	var relative_pos = (world_position - rect.position)/rect.size	
	var ui_space_size = ui.get_viewport().get_visible_rect().size
	return relative_pos * ui_space_size

static func delete_all_children_execept_index_0(parent):
	var amount = parent.get_child_count()
	for i in range(amount - 1, 0, -1):
		parent.get_child(i).free()
