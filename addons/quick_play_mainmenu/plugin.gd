@tool
extends EditorPlugin

const MAIN_MENU_SCENE_PATH := "res://scenes/mainmenuscene.tscn"

var _button: Button


func _enter_tree() -> void:
	_button = Button.new()
	_button.text = "▶ Menu"
	_button.tooltip_text = "Run scenes/mainmenuscene.tscn directly."
	_button.pressed.connect(_on_button_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _button)
	_button.get_parent().move_child(_button, 5)


func _exit_tree() -> void:
	remove_control_from_container(CONTAINER_TOOLBAR, _button)
	_button.queue_free()


func _on_button_pressed() -> void:
	get_editor_interface().play_custom_scene(MAIN_MENU_SCENE_PATH)
