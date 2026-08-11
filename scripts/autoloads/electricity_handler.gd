extends Node

class ElectricityDebugCanvas extends Node2D:
	var handler

	func _ready() -> void:
		z_index = 5000
		z_as_relative = false

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		if handler == null:
			return
		handler.draw_debug_overlay(self)

signal state_changed

const ELECTRICITY_LAYER := BuildingInfrastructure.ELECTRICITY_LAYER
const MAX_UI_PERCENT := 300.0
const DEBUG_CANVAS_NAME := "ElectricityDebugCanvas"
const DEBUG_FONT := preload("res://assets/fonts/modern_dos/ModernDOS8x8.ttf")
const DEBUG_FONT_SIZE := 8
const DEBUG_TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const DEBUG_TEXT_BG_COLOR := Color(0.05, 0.05, 0.05, 0.84)
const DEBUG_LABEL_PADDING := Vector2(3.0, 2.0)
const DEBUG_ROOM_PADDING := Vector2(6.0, 10.0)
const DEBUG_PRODUCER_COLOR := Color(0.25, 0.95, 1.0, 0.95)
const DEBUG_CONSUMER_POWERED_COLOR := Color(0.25, 0.95, 0.32, 0.95)
const DEBUG_CONSUMER_CAPACITY_COLOR := Color(1.0, 0.7, 0.15, 0.95)
const DEBUG_CONSUMER_DISCONNECTED_COLOR := Color(1.0, 0.25, 0.25, 0.95)
const DEBUG_STUB_COLOR := Color(1.0, 1.0, 1.0, 0.45)
const DEBUG_CONNECTION_HEAD_SIZE := 4.0
const DEBUG_LINE_THICKNESS := 2.0
const DEBUG_MARKER_SIZE := Vector2(10.0, 10.0)
const DEBUG_MARKER_RADIUS := 5.0

var _powered_consumer_ids: Dictionary = {}
var _stats := {
	"production": 0,
	"demand": 0,
	"percent": 0.0,
	"active_producers": 0,
	"consumers": 0,
	"powered_consumers": 0,
}
var _recompute_pending := false
var _debug_overlay := false
var _debug_canvas: ElectricityDebugCanvas = null
var _debug_snapshot := {
	"producers": [],
	"consumers": [],
}

func _ready() -> void:
	GlobalEventHandler.on_room_created_signal.connect(_queue_recompute)
	GlobalEventHandler.on_room_deleted_signal.connect(_queue_recompute)
	GlobalEventHandler.on_infrastructure_changed_signal.connect(_queue_recompute)
	Console.add_command("debug_electricity", _console_toggle_debug_overlay, 0, 0, "Toggles electricity debug drawing of producers, consumers, and live service connections.")
	call_deferred("_flush_recompute")

func _process(_delta: float) -> void:
	if not _debug_overlay:
		if is_instance_valid(_debug_canvas):
			_debug_canvas.visible = false
		return
	if _ensure_debug_canvas():
		_debug_canvas.visible = true

func get_stats() -> Dictionary:
	return _stats.duplicate(true)

func is_production_stable() -> bool:
	var demand := int(_stats["demand"])
	if demand <= 0:
		return true
	return float(_stats["percent"]) >= 100.0

func room_is_powered(room: RoomBase) -> bool:
	if room == null or room.get_electricity_consumption_amount() <= 0:
		return false
	return _powered_consumer_ids.has(_get_consumer_group_id(room))

func _queue_recompute(_value = null) -> void:
	if _recompute_pending:
		return
	_recompute_pending = true
	call_deferred("_flush_recompute")

func _flush_recompute() -> void:
	_recompute_pending = false
	_recompute_state()
	state_changed.emit()

func _recompute_state() -> void:
	var powered_consumer_ids := {}
	var active_producers := 0
	var total_production := 0
	var total_demand := 0
	var total_consumers := 0
	var powered_consumers := 0
	var remaining_power := 0
	var consumer_groups: Array[Dictionary] = []
	var consumer_ids := {}
	var producer_entries: Array[Dictionary] = []

	for room: RoomBase in _get_all_rooms_sorted():
		var production := room.get_electricity_production_amount()
		if production > 0:
			total_production += production
			active_producers += 1
			producer_entries.append({
				"room": room,
				"amount": production,
			})

		var demand := room.get_electricity_consumption_amount()
		if demand <= 0:
			continue

		var consumer_id := _get_consumer_group_id(room)
		if consumer_ids.has(consumer_id):
			continue
		consumer_ids[consumer_id] = true

		if not _is_consumer_electrified(room):
			continue

		total_consumers += 1
		total_demand += demand
		consumer_groups.append({
			"id": consumer_id,
			"room": room,
			"demand": demand,
			"provider": _get_live_service_provider(room),
			"reachable": _has_live_service_connection(room),
			"powered": false,
		})

	remaining_power = total_production
	for consumer in consumer_groups:
		if not consumer["reachable"]:
			continue
		if remaining_power < consumer["demand"]:
			continue
		remaining_power -= consumer["demand"]
		powered_consumer_ids[consumer["id"]] = true
		consumer["powered"] = true
		powered_consumers += 1

	_powered_consumer_ids = powered_consumer_ids
	_stats = {
		"production": total_production,
		"demand": total_demand,
		"percent": _compute_percent(total_production, total_demand),
		"active_producers": active_producers,
		"consumers": total_consumers,
		"powered_consumers": powered_consumers,
	}
	_debug_snapshot = {
		"producers": producer_entries,
		"consumers": consumer_groups,
	}

func _compute_percent(production: int, demand: int) -> float:
	if demand <= 0:
		return 100.0 if production > 0 else 0.0
	return min((float(production) / float(demand)) * 100.0, MAX_UI_PERCENT)

func _get_all_rooms_sorted() -> Array[RoomBase]:
	var rooms: Array[RoomBase] = []
	var seen := {}
	var floors: Array = Building.floors.keys()
	floors.sort()
	for floor in floors:
		var row: Dictionary = Building.floors[floor]
		var xs: Array = row.keys()
		xs.sort()
		for x in xs:
			var room := row[x] as RoomBase
			if room == null:
				continue
			var room_id := room.get_instance_id()
			if seen.has(room_id):
				continue
			seen[room_id] = true
			rooms.append(room)
	return rooms

func _get_consumer_group_id(room: RoomBase) -> int:
	if room is RoomElevator:
		var controller = ElevatorHandler.get_controller_for_room(room)
		if controller != null:
			return controller.get_instance_id()
	return room.get_instance_id()

func _is_consumer_electrified(room: RoomBase) -> bool:
	if not is_instance_valid(Building.infrastructure):
		return false
	if room is RoomElevator:
		var controller = ElevatorHandler.get_controller_for_room(room)
		if controller != null:
			for shaft_room in controller.rooms:
				if is_instance_valid(shaft_room) and Building.infrastructure.room_has_layer(shaft_room, ELECTRICITY_LAYER):
					return true
			return false
	return Building.infrastructure.room_has_layer(room, ELECTRICITY_LAYER)

func _has_live_service_connection(room: RoomBase) -> bool:
	return _get_live_service_provider(room) != null

func _get_live_service_provider(room: RoomBase) -> RoomBase:
	if not is_instance_valid(Building.infrastructure):
		return null
	if room is RoomElevator:
		var controller = ElevatorHandler.get_controller_for_room(room)
		if controller != null:
			for shaft_room in controller.rooms:
				if not is_instance_valid(shaft_room):
					continue
				var provider := Building.infrastructure.get_connected_provider(shaft_room, ELECTRICITY_LAYER) as RoomBase
				if provider != null:
					return provider
			return null
	var provider := Building.infrastructure.get_connected_provider(room, ELECTRICITY_LAYER) as RoomBase
	if provider != null:
		return provider
	return room if Building.infrastructure.room_provides_layer(room, ELECTRICITY_LAYER) else null

func _console_toggle_debug_overlay() -> void:
	_debug_overlay = not _debug_overlay
	Console.print_line("Electricity debug draw " + ("ON" if _debug_overlay else "OFF"))

func draw_debug_overlay(canvas: ElectricityDebugCanvas) -> void:
	for producer_entry in _debug_snapshot["producers"]:
		var room := producer_entry["room"] as RoomBase
		if not is_instance_valid(room):
			continue
		_draw_producer_overlay(canvas, producer_entry)

	for consumer_entry in _debug_snapshot["consumers"]:
		var room := consumer_entry["room"] as RoomBase
		if not is_instance_valid(room):
			continue
		_draw_consumer_overlay(canvas, consumer_entry)

func _ensure_debug_canvas() -> bool:
	if not is_instance_valid(Building):
		return false
	if is_instance_valid(_debug_canvas):
		return true

	_debug_canvas = Building.get_node_or_null(DEBUG_CANVAS_NAME) as ElectricityDebugCanvas
	if _debug_canvas == null:
		_debug_canvas = ElectricityDebugCanvas.new()
		_debug_canvas.name = DEBUG_CANVAS_NAME
		Building.add_child(_debug_canvas)
	_debug_canvas.handler = self
	return true

func _draw_producer_overlay(canvas: ElectricityDebugCanvas, entry: Dictionary) -> void:
	var room := entry["room"] as RoomBase
	if not is_instance_valid(room):
		return
	var anchor_global := _get_debug_anchor(room)
	var anchor_local := canvas.to_local(anchor_global)
	canvas.draw_rect(Rect2(anchor_local - DEBUG_MARKER_SIZE * 0.5, DEBUG_MARKER_SIZE), DEBUG_PRODUCER_COLOR, true)
	_draw_debug_label(
		canvas,
		_get_status_label_position(anchor_global, room),
		_get_producer_status_text(entry),
		DEBUG_PRODUCER_COLOR
	)

func _draw_consumer_overlay(canvas: ElectricityDebugCanvas, entry: Dictionary) -> void:
	var room := entry["room"] as RoomBase
	if not is_instance_valid(room):
		return
	var color := _get_consumer_debug_color(entry)
	var anchor_global := _get_debug_anchor(room)
	var anchor_local := canvas.to_local(anchor_global)
	canvas.draw_circle(anchor_local, DEBUG_MARKER_RADIUS, color)
	canvas.draw_arc(anchor_local, DEBUG_MARKER_RADIUS, 0.0, TAU, 10, color, 1.0)

	var provider := entry["provider"] as RoomBase
	if is_instance_valid(provider):
		_draw_debug_arrow(canvas, canvas.to_local(_get_debug_anchor(provider)), anchor_local, color)

	_draw_debug_label(
		canvas,
		_get_status_label_position(anchor_global, room),
		_get_consumer_status_text(entry),
		color
	)

func _get_debug_anchor(room: RoomBase) -> Vector2:
	if room == null or room.data == null:
		return Vector2.ZERO
	var room_size := Vector2(float(room.data.width) * 48.0, float(room.data.height) * 48.0)
	var room_top_left := room.global_position + Vector2(0.0, -room_size.y)
	return room_top_left + Vector2(room_size.x - DEBUG_ROOM_PADDING.x - DEBUG_MARKER_RADIUS, DEBUG_ROOM_PADDING.y + DEBUG_MARKER_RADIUS)

func _get_consumer_debug_color(entry: Dictionary) -> Color:
	if bool(entry["powered"]):
		return DEBUG_CONSUMER_POWERED_COLOR
	if bool(entry["reachable"]):
		return DEBUG_CONSUMER_CAPACITY_COLOR
	return DEBUG_CONSUMER_DISCONNECTED_COLOR

func _get_status_label_position(anchor_global: Vector2, room: RoomBase) -> Vector2:
	if room == null or room.data == null:
		return anchor_global
	var room_size := Vector2(float(room.data.width) * 48.0, float(room.data.height) * 48.0)
	var room_top_left := room.global_position + Vector2(0.0, -room_size.y)
	return room_top_left + Vector2(DEBUG_ROOM_PADDING.x, DEBUG_ROOM_PADDING.y + float(DEBUG_FONT_SIZE))

func _get_producer_status_text(entry: Dictionary) -> String:
	return "producer +%d" % int(entry["amount"])

func _get_consumer_status_text(entry: Dictionary) -> String:
	var demand := int(entry["demand"])
	if bool(entry["powered"]):
		return "powered -%d" % demand
	if bool(entry["reachable"]):
		return "unpowered -%d" % demand
	return "disconnected -%d" % demand

func _draw_debug_label(canvas: CanvasItem, global_position: Vector2, text: String, accent: Color) -> void:
	if DEBUG_FONT == null or text.is_empty():
		return

	var local_position: Vector2 = canvas.to_local(global_position)
	var text_size := DEBUG_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, DEBUG_FONT_SIZE)
	var bg_rect := Rect2(
		local_position + Vector2(-DEBUG_LABEL_PADDING.x, -float(DEBUG_FONT_SIZE) + DEBUG_LABEL_PADDING.y),
		text_size + DEBUG_LABEL_PADDING * 2.0
	)
	canvas.draw_rect(bg_rect, DEBUG_TEXT_BG_COLOR, true)
	canvas.draw_rect(bg_rect, Color(accent.r, accent.g, accent.b, 0.95), false, 1.0)
	canvas.draw_string(DEBUG_FONT, local_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, DEBUG_FONT_SIZE, DEBUG_TEXT_COLOR)

func _draw_debug_arrow(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color) -> void:
	var direction := to - from
	var arrow_len := direction.length()
	if arrow_len <= 0.001:
		return
	var arrow_dir := direction / arrow_len
	var arrow_head_start := to - arrow_dir * DEBUG_CONNECTION_HEAD_SIZE
	var arrow_normal := Vector2(arrow_dir.y, -arrow_dir.x)
	var arrow_start_1 := arrow_head_start + arrow_normal * DEBUG_CONNECTION_HEAD_SIZE
	var arrow_start_2 := arrow_head_start - arrow_normal * DEBUG_CONNECTION_HEAD_SIZE

	canvas.draw_line(from, to, color, DEBUG_LINE_THICKNESS)
	canvas.draw_line(arrow_start_1, to - arrow_dir * DEBUG_LINE_THICKNESS * 0.5, color, DEBUG_LINE_THICKNESS)
	canvas.draw_line(arrow_start_2, to - arrow_dir * DEBUG_LINE_THICKNESS * 0.5, color, DEBUG_LINE_THICKNESS)
