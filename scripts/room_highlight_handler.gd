extends Node2D

@onready var rectDummy = $Rect;
@onready var arrowDummy = $Arrow;

var active : Dictionary[RoomBase, Array] = {}

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
	
func create(dummy, room : RoomBase):
	var instance = dummy.duplicate()
	instance.visible = true
	instance.position = room.get_center_position()
	add_child(instance)
	
	if not active.has(room):
		active[room] = []
		
	active[room].append(instance)
	
	return instance
	
func end_request(room):
	
	if not active.has(room):
		return
		
	for all in active[room]:
		all.queue_free()
		
	active.erase(room)
	
func dispose(highlight):
	
	if not is_instance_valid(highlight):
		return

	for key in active.keys():
		if active[key].has(highlight):
			active[key].erase(highlight)
		
	highlight.queue_free()
