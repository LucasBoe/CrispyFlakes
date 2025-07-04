extends Node2D

@onready var rectDummy = $Rect;
@onready var arrowDummy = $Arrow;

var active = []

func _ready():
	rectDummy.visible = false
	arrowDummy.visible = false

func request_rect(room, color = Color.WHITE):
	var inst = create(rectDummy, room)
	inst.modulate = color
	return inst
	
func request_arrow(room):
	var inst = create(arrowDummy, room)
	return inst
	
func create(dummy, room : RoomEmpty):
	var instance = dummy.duplicate()
	instance.visible = true
	instance.position = room.get_center_position()
	add_child(instance)
	return instance
	
func dispose(highlight):
	
	if not highlight:
		return
		
	active.erase(highlight)
	highlight.queue_free()
