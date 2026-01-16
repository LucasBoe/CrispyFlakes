extends Control

@onready var camera = %Camera
@onready var root = $MarginContainer

@onready var room_name_label = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/Label
@onready var room_delete_button = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/Button

var room = null

func _ready():
	HoverHandler.click_room_signal.connect(_on_clicked_room)
	room_delete_button.pressed.connect(_on_delete_room_clicked)
	
func _on_clicked_room(clicked_room : RoomBase):
	
	room = clicked_room
	root.visible = clicked_room != null
	
	if clicked_room == null:
		return
		
	room_name_label.text = clicked_room.name
	
	var rect = camera.get_camera_world_rect() as Rect2	
	var relative_pos = (clicked_room.get_top_center_position() - rect.position)/rect.size	
	var ui_space_size = get_viewport().get_visible_rect().size
	root.global_position = relative_pos * ui_space_size - Vector2(root.size.x / 2, root.size.y)

func _on_delete_room_clicked():
	if room == null:
		return
		
	Global.Building.delete_room(room)
