extends Button
class_name ContentSizedButton

@export var content_path: NodePath

func _ready() -> void:
	fit_to_content()

func fit_to_content() -> void:
	var content := _get_content()
	if content == null:
		return

	custom_minimum_size = content.get_combined_minimum_size()

func _get_content() -> Control:
	if content_path != NodePath():
		return get_node_or_null(content_path) as Control

	for child in get_children():
		if child is Control:
			return child

	return null
