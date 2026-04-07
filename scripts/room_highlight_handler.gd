extends Node2D

enum Priority {
	STATUS = 0,    # General status indicators (e.g. no worker assigned)
	ARREST = 1,    # NPC pending arrest
	FIGHT = 2,     # Active fight in room
	SELECTION = 3, # Player hover / selection / drag
}

const PRIORITY_Z_INDEX = {
	Priority.STATUS:    2150,
	Priority.ARREST:   2160,
	Priority.FIGHT:    2170,
	Priority.SELECTION: 2180,
}

@onready var rect_dummy = $Rect;
@onready var arrow_dummy = $Arrow;

@onready var rect_texture_2px = preload("res://assets/sprites/room_highlight.png")
@onready var rect_texture_1px = preload("res://assets/sprites/room_highlight_slim.png")


var active : Dictionary[RoomBase, Array] = {}

func _ready():
	rect_dummy.visible = false
	arrow_dummy.visible = false

	GlobalEventHandler.on_room_deleted_signal.connect(_on_room_deleted)

func request_rect(room, color = Color.WHITE, size = 2, priority = Priority.STATUS):
	var inst = create(rect_dummy, room, priority)
	inst.modulate = color
	inst.texture = texture_from_size(size)
	return inst

func texture_from_size(size):
	if size == 2:
		return rect_texture_2px

	return rect_texture_1px

func request_arrow(room, priority = Priority.SELECTION):
	var inst = create(arrow_dummy, room, priority)
	return inst

func create(dummy, room : RoomBase, priority : Priority = Priority.STATUS):
	var instance = dummy.duplicate()
	instance.visible = true
	instance.position = room.get_center_position()
	instance.z_index = PRIORITY_Z_INDEX[priority]
	add_child(instance)

	if not active.has(room):
		active[room] = []

	active[room].append(instance)

	return instance

func _on_room_deleted(room):

	if not active.has(room):
		return

	for all in active[room]:
		all.queue_free()

	active.erase(room)

func dispose(highlight):

	if not is_instance_valid(highlight):
		return

	for key in active.keys():

		#TODO find reason why null rooms remain in dict in the first place
		if key == null:
			active.erase(key)
			continue

		if active[key].has(highlight):
			active[key].erase(highlight)

	highlight.queue_free()
