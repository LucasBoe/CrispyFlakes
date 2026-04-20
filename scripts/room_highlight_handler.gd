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


var active = {}

func _ready():
	rect_dummy.visible = false
	arrow_dummy.visible = false

	GlobalEventHandler.on_room_deleted_signal.connect(_on_room_deleted)

func request_rect(room, color = Color.WHITE, size = 2, priority = Priority.STATUS):
	var inst: NinePatchRect = create(rect_dummy, room, priority)

	inst.modulate = color
	inst.texture = texture_from_size(size)

	const TILE_PX: int = 48
	var w: float = room.data.width * TILE_PX
	var h: float = room.data.height * TILE_PX
	inst.anchor_left = 0.0
	inst.anchor_top = 0.0
	inst.anchor_right = 0.0
	inst.anchor_bottom = 0.0
	inst.size = Vector2(w, h)
	inst.position = Vector2(room.global_position.x, room.global_position.y - h)

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
		if is_instance_valid(all):
			all.queue_free()

	active.erase(room)

func dispose(highlight):

	if not is_instance_valid(highlight):
		return

	var invalid_keys = []
	for key in active.keys():
		if key == null or not is_instance_valid(key):
			invalid_keys.append(key)
			continue

		var highlights: Array = active[key]
		if highlights.has(highlight):
			highlights.erase(highlight)
			if highlights.is_empty():
				invalid_keys.append(key)

	for key in invalid_keys:
		if active.has(key):
			active.erase(key)

	highlight.queue_free()
