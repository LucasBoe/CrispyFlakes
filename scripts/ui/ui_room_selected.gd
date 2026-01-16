extends Control

@onready var camera = %Camera
@onready var root = $MarginContainer

@onready var room_name_label = $MarginContainer/MarginContainer/VBoxContainer/Label

func _ready():
	HoverHandler.click_room_signal.connect(_on_clicked_room)
	
func _on_clicked_room(room : RoomEmpty):
	
	root.visible = room != null
	
	if room == null:
		return
		
	room_name_label.text = room.name
	
	var rect = camera.get_camera_world_rect() as Rect2	
	var relative_pos = (room.get_top_center_position() - rect.position)/rect.size	
	var ui_space_size = get_viewport().get_visible_rect().size
	root.global_position = relative_pos * ui_space_size - Vector2(root.size.x / 2, root.size.y)
