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
