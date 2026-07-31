extends Node

class TemperatureDebugCanvas extends Node2D:
	var handler

	func _ready() -> void:
		z_index = 4095
		z_as_relative = false

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		if handler == null:
			return
		handler.draw_debug_temperature(self)


const DEBUG_CANVAS_NAME := "TemperatureDebugCanvas"
const DEBUG_TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const DEBUG_TEXT_BG_COLOR := Color(0.05, 0.05, 0.05, 0.8)
const DEBUG_NEUTRAL_COLOR := Color(0.7, 0.7, 0.7, 1.0)
const DEBUG_COLD_COLOR := Color(0.32, 0.62, 1.0, 1.0)
const DEBUG_WARM_COLOR := Color(1.0, 0.66, 0.24, 1.0)
const DEBUG_ROOM_FILL_ALPHA := 0.18
const DEBUG_ROOM_BORDER_ALPHA := 0.9
const DEBUG_SOURCE_ALPHA := 0.14
const DEBUG_LABEL_PADDING := Vector2(3.0, 2.0)
const TEMPERATURE_CACHE_INTERVAL := 0.25
const PRIMARY_HEAT_TEMPERATURE := 26.0
const SECONDARY_HEAT_TEMPERATURE := 16.0
const TERTIARY_HEAT_TEMPERATURE := 12.0
const DEBUG_COLD_REFERENCE_TEMPERATURE := -12.0
const DEBUG_WARM_REFERENCE_TEMPERATURE := PRIMARY_HEAT_TEMPERATURE

# Daily forecast — a fixed, always-the-same sequence of daily base
# temperatures (cold days negative, warm days positive), repeating by
# calendar day index rather than rolling random numbers. Kept simple for
# players to learn: "negative = cold, positive = warm", no in-between fuzz.
# Grouped into spells of 3+ identical days in a row (rather than alternating
# daily) so cold/warm stretches actually read as connected runs, both to the
# player and on the forecast strip's markers.
const DAILY_TEMPERATURE_PRESETS: Array[float] = [
	-6.0, -6.0, -6.0,                # cold spell, 3 days
	4.0, 4.0, 4.0, 4.0,               # warm spell, 4 days
	-8.0, -8.0, -8.0,                 # cold spell, 3 days
	2.0, 2.0, 2.0, 2.0, 2.0,          # warm spell, 5 days
	-3.0, -3.0, -3.0,                 # cold spell, 3 days
	5.0, 5.0, 5.0, 5.0,                # warm spell, 4 days
]
# Intraday swing is intentionally small now — a day's warm/cold read stays
# consistent through the day instead of the old ±4° wobble around it.
const DAILY_SWING := 2.0
const COLD_THRESHOLD := 0.0
# Returned in place of the real forecast whenever Feature.TEMPERATURE_SYSTEM
# is gated off — sits inside RoomTemperatureOverlayHandler's neutral band
# (COLD_VISIBLE_TEMPERATURE 8..WARM_VISIBLE_TEMPERATURE 14) and above the sky
# shader's WEATHER_FADE_WARM_TEMPERATURE (3), so every downstream consumer
# (NPC cold status, the room overlay, snow/weather tint) naturally goes idle
# on its own without needing its own separate gate check.
const NEUTRAL_TEMPERATURE_WHEN_DISABLED := 11.0
const FORECAST_DAYS_BEFORE := 3
# Generously larger than UITemperatureForecast.VISIBLE_SLOT_COUNT needs, plus
# one extra day as a scroll buffer so the strip always has a segment ready to
# slide in from the right as it drifts. The forecast UI's pointer sits near
# the left edge of its row, so almost its whole width shows future days —
# if VISIBLE_SLOT_COUNT there ever grows past what fits here, markers run
# out and a gap opens up on the right (with fewer, narrower days shown
# overall) rather than actually showing more days.
const FORECAST_DAYS_AFTER := 20
const FORECAST_WINDOW_SIZE := FORECAST_DAYS_BEFORE + FORECAST_DAYS_AFTER + 1
const TUTORIAL_SUMMER_START_DAY_INDEX := 3

signal on_forecast_changed_signal()

var _sources: Array = []
var _debug_temperature_enabled := false
var _debug_canvas: TemperatureDebugCanvas = null
var _temperature_curve: Curve = null
var _temperature_cache_by_room_id: Dictionary = {}
var _cached_outdoor_temperature := 0.0
var _cache_timestamp := -INF
var _cache_dirty := true

var _daily_base_temperatures: Array[float] = []
var _forecast_center_day_index := -1
var _day_index_offset := 0


func _ready() -> void:
	Console.add_command("debug_temperature", _console_toggle_debug_temperature, 0, 0, "Toggles room temperature debug drawing.")
	if not GlobalEventHandler.on_room_created_signal.is_connected(_on_rooms_changed):
		GlobalEventHandler.on_room_created_signal.connect(_on_rooms_changed)
	if not GlobalEventHandler.on_room_deleted_signal.is_connected(_on_rooms_changed):
		GlobalEventHandler.on_room_deleted_signal.connect(_on_rooms_changed)
	_ensure_temperature_curve()
	_ensure_forecast()


func _process(_delta: float) -> void:
	if not _debug_temperature_enabled:
		if is_instance_valid(_debug_canvas):
			_debug_canvas.visible = false
		return

	if _ensure_debug_canvas():
		_debug_canvas.visible = true

func register_source(source) -> void:
	if source == null or _sources.has(source):
		return
	_sources.append(source)
	_cache_dirty = true

func unregister_source(source) -> void:
	_sources.erase(source)
	_cache_dirty = true

func get_temperature_at_global_position(global_pos: Vector2) -> float:
	if not is_instance_valid(Building):
		return get_outdoor_temperature()

	var room := Building.query.room_at_floor_position(global_pos) as RoomBase
	if room == null:
		room = Building.query.closest_on_current_floor(RoomBase, global_pos) as RoomBase
	if room == null:
		return get_outdoor_temperature()
	return get_temperature_for_room(room)

func get_temperature_for_room(room: RoomBase) -> float:
	if room == null or room.data == null:
		return get_outdoor_temperature()

	_ensure_temperature_cache()
	return float(_temperature_cache_by_room_id.get(room.get_instance_id(), _cached_outdoor_temperature))

func is_room_heated(room: RoomBase, threshold: float = 16.0) -> bool:
	return get_temperature_for_room(room) >= threshold


func get_outdoor_temperature() -> float:
	if not FeatureGateHandler.is_enabled(FeatureGateHandler.Feature.TEMPERATURE_SYSTEM):
		return NEUTRAL_TEMPERATURE_WHEN_DISABLED
	_ensure_temperature_curve()
	_ensure_forecast()
	var normalized_time := _get_normalized_time_of_day()
	var curve_value := clampf(_temperature_curve.sample_baked(normalized_time), 0.0, 1.0)
	# Blend continuously toward tomorrow's base as the day progresses, rather
	# than holding flat all day and jumping at midnight — matches the
	# forecast UI, which slides the same way, so whatever's under its arrow
	# always equals this value, with no discrete snap either place.
	var today := _daily_base_temperatures[FORECAST_DAYS_BEFORE]
	var tomorrow := _daily_base_temperatures[FORECAST_DAYS_BEFORE + 1]
	var base := lerpf(today, tomorrow, normalized_time)
	return base - DAILY_SWING * 0.5 + curve_value * DAILY_SWING


func get_time_of_day_hours() -> float:
	return _get_normalized_time_of_day() * 24.0


func is_cold(temperature: float) -> bool:
	return temperature < COLD_THRESHOLD


## Rolling window of daily base temperatures, oldest to newest. Index
## get_forecast_center_index() is today; everything before it is past days,
## everything after is the future forecast.
func get_forecast_temperatures() -> Array[float]:
	_ensure_forecast()
	return _daily_base_temperatures.duplicate()


func get_forecast_center_index() -> int:
	return FORECAST_DAYS_BEFORE


func get_today_base_temperature() -> float:
	_ensure_forecast()
	return _daily_base_temperatures[FORECAST_DAYS_BEFORE]


func activate_tutorial_summer_start() -> void:
	FeatureGateHandler.set_enabled(FeatureGateHandler.Feature.TEMPERATURE_SYSTEM, true)
	var real_day_index := 0
	if Global.DAY_DURATION > 0.0:
		real_day_index = floori(Global.time_now / Global.DAY_DURATION)
	_day_index_offset = TUTORIAL_SUMMER_START_DAY_INDEX - real_day_index
	_daily_base_temperatures.clear()
	_forecast_center_day_index = -1
	_cache_dirty = true
	_temperature_cache_by_room_id.clear()
	_ensure_forecast()


func _get_current_day_index() -> int:
	if Global.DAY_DURATION <= 0.0:
		return _day_index_offset
	return floori(Global.time_now / Global.DAY_DURATION) + _day_index_offset


## Same calendar day index always maps to the same preset value — the
## sequence repeats indefinitely rather than picking randomly.
func _get_preset_daily_base_temperature(day_index: int) -> float:
	return DAILY_TEMPERATURE_PRESETS[posmod(day_index, DAILY_TEMPERATURE_PRESETS.size())]


func _ensure_forecast() -> void:
	var day_index := _get_current_day_index()

	if _daily_base_temperatures.is_empty():
		_forecast_center_day_index = day_index
		for i in FORECAST_WINDOW_SIZE:
			var slot_day := day_index - FORECAST_DAYS_BEFORE + i
			_daily_base_temperatures.append(_get_preset_daily_base_temperature(slot_day))
		on_forecast_changed_signal.emit()
		return

	if day_index <= _forecast_center_day_index:
		return

	while day_index > _forecast_center_day_index:
		_daily_base_temperatures.pop_front()
		_forecast_center_day_index += 1
		var new_slot_day := _forecast_center_day_index + FORECAST_DAYS_AFTER
		_daily_base_temperatures.append(_get_preset_daily_base_temperature(new_slot_day))
	on_forecast_changed_signal.emit()


func _console_toggle_debug_temperature() -> void:
	_debug_temperature_enabled = !_debug_temperature_enabled
	if _debug_temperature_enabled and _ensure_debug_canvas():
		_debug_canvas.visible = true
	elif is_instance_valid(_debug_canvas):
		_debug_canvas.visible = false
	Console.print_line("Temperature debug draw " + ("ON" if _debug_temperature_enabled else "OFF"))


func _ensure_debug_canvas() -> bool:
	if is_instance_valid(_debug_canvas) and _debug_canvas.get_parent() == Building:
		return true
	if not is_instance_valid(Building):
		return false

	_debug_canvas = Building.get_node_or_null(DEBUG_CANVAS_NAME) as TemperatureDebugCanvas
	if not is_instance_valid(_debug_canvas):
		_debug_canvas = TemperatureDebugCanvas.new()
		_debug_canvas.name = DEBUG_CANVAS_NAME
		_debug_canvas.handler = self
		Building.add_child(_debug_canvas)
	elif _debug_canvas.handler == null:
		_debug_canvas.handler = self
	return true


func draw_debug_temperature(canvas: TemperatureDebugCanvas) -> void:
	if not _debug_temperature_enabled or not is_instance_valid(Building):
		return

	_ensure_temperature_cache()
	var font := ThemeDB.fallback_font
	var font_size := ThemeDB.fallback_font_size
	var seen_room_ids := {}
	for floor_rooms: Dictionary in Building.floors.values():
		for room in floor_rooms.values():
			if room == null or not is_instance_valid(room) or room.data == null:
				continue
			var room_id: int = room.get_instance_id()
			if seen_room_ids.has(room_id):
				continue
			seen_room_ids[room_id] = true
			_draw_debug_room(canvas, room, font, font_size)

	for source in _sources.duplicate():
		if not is_instance_valid(source):
			_sources.erase(source)
			continue
		_draw_debug_source(canvas, source, font, font_size)


func _draw_debug_room(canvas: TemperatureDebugCanvas, room: RoomBase, font: Font, font_size: int) -> void:
	var rect := Rect2(
		room.position + Vector2(0.0, -float(room.data.height) * 48.0),
		Vector2(float(room.data.width) * 48.0, float(room.data.height) * 48.0)
	)
	var temperature := get_temperature_for_room(room)
	var color := _get_debug_temperature_color(temperature)
	canvas.draw_rect(rect, Color(color, DEBUG_ROOM_FILL_ALPHA), true)
	canvas.draw_rect(rect, Color(color, DEBUG_ROOM_BORDER_ALPHA), false, 1.0)
	_draw_debug_label(canvas, rect.position + Vector2(4.0, 14.0), "%.2f" % temperature, font, font_size)


func _draw_debug_source(canvas: TemperatureDebugCanvas, source, font: Font, font_size: int) -> void:
	if not _is_active_heat_source(source):
		return

	var source_global_pos := _get_heat_source_position(source)
	if not source_global_pos.is_finite():
		return
	var source_pos: Vector2 = Building.to_local(source_global_pos)
	var color := _get_debug_temperature_color(PRIMARY_HEAT_TEMPERATURE)
	canvas.draw_circle(source_pos, 6.0, Color(color, DEBUG_SOURCE_ALPHA))
	canvas.draw_arc(source_pos, 6.0, 0.0, TAU, 24, Color(color, DEBUG_ROOM_BORDER_ALPHA), 1.0)
	_draw_debug_label(
		canvas,
		source_pos + Vector2(8.0, -6.0),
		"%s %.0f" % [_get_heat_source_debug_name(source), PRIMARY_HEAT_TEMPERATURE],
		font,
		font_size
	)


func _draw_debug_label(canvas: TemperatureDebugCanvas, position: Vector2, text: String, font: Font, font_size: int) -> void:
	if font == null or text.is_empty():
		return

	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var bg_rect := Rect2(
		position + Vector2(-DEBUG_LABEL_PADDING.x, -float(font_size) + DEBUG_LABEL_PADDING.y),
		text_size + DEBUG_LABEL_PADDING * 2.0
	)
	canvas.draw_rect(bg_rect, DEBUG_TEXT_BG_COLOR, true)
	canvas.draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, DEBUG_TEXT_COLOR)


func _get_debug_temperature_color(temperature: float) -> Color:
	if temperature < 0.0:
		return DEBUG_NEUTRAL_COLOR.lerp(
			DEBUG_COLD_COLOR,
			clampf(inverse_lerp(0.0, absf(DEBUG_COLD_REFERENCE_TEMPERATURE), absf(temperature)), 0.0, 1.0)
		)
	if temperature > 0.0:
		return DEBUG_NEUTRAL_COLOR.lerp(
			DEBUG_WARM_COLOR,
			clampf(inverse_lerp(0.0, DEBUG_WARM_REFERENCE_TEMPERATURE, temperature), 0.0, 1.0)
		)
	return DEBUG_NEUTRAL_COLOR


func _on_rooms_changed(_room) -> void:
	_cache_dirty = true


func _ensure_temperature_curve() -> void:
	if _temperature_curve != null:
		return

	_temperature_curve = Curve.new()
	_temperature_curve.bake_resolution = 64
	_temperature_curve.add_point(Vector2(0.00, 0.08))
	_temperature_curve.add_point(Vector2(0.18, 0.00))
	_temperature_curve.add_point(Vector2(0.33, 0.20))
	_temperature_curve.add_point(Vector2(0.50, 0.70))
	_temperature_curve.add_point(Vector2(0.63, 1.00))
	_temperature_curve.add_point(Vector2(0.80, 0.48))
	_temperature_curve.add_point(Vector2(1.00, 0.08))


func _get_normalized_time_of_day() -> float:
	if Global.DAY_DURATION <= 0.0:
		return 0.0
	return fposmod(Global.time_now, Global.DAY_DURATION) / Global.DAY_DURATION


func _ensure_temperature_cache() -> void:
	if not _cache_dirty and Global.time_now - _cache_timestamp < TEMPERATURE_CACHE_INTERVAL:
		return

	_rebuild_temperature_cache()


func _rebuild_temperature_cache() -> void:
	_cache_dirty = false
	_cache_timestamp = Global.time_now
	_cached_outdoor_temperature = get_outdoor_temperature()
	_temperature_cache_by_room_id.clear()

	if not is_instance_valid(Building):
		return

	var rooms := _collect_unique_rooms()
	for room: RoomBase in rooms:
		_temperature_cache_by_room_id[room.get_instance_id()] = _cached_outdoor_temperature

	for source in _sources.duplicate():
		if not is_instance_valid(source):
			_sources.erase(source)
			continue
		if not _is_active_heat_source(source):
			continue

		var source_room := _get_heat_source_room(source)
		if source_room == null or source_room.is_outside_room:
			continue

		_apply_stove_heat_bands(source_room)


func _apply_stove_heat_bands(source_room: RoomBase) -> void:
	if source_room == null or source_room.data == null:
		return

	var primary_rooms: Array[RoomBase] = [source_room]
	_append_unique_rooms(primary_rooms, _get_same_level_adjacent_rooms(source_room))
	_apply_heat_to_rooms(primary_rooms, PRIMARY_HEAT_TEMPERATURE)

	var secondary_rooms := _get_adjacent_indoor_rooms_for_group(primary_rooms, _to_room_id_lookup(primary_rooms))
	_apply_heat_to_rooms(secondary_rooms, SECONDARY_HEAT_TEMPERATURE)

	var blocked_room_ids := _to_room_id_lookup(primary_rooms)
	blocked_room_ids.merge(_to_room_id_lookup(secondary_rooms), true)
	var tertiary_rooms := _get_adjacent_indoor_rooms_for_group(secondary_rooms, blocked_room_ids)
	_apply_heat_to_rooms(tertiary_rooms, TERTIARY_HEAT_TEMPERATURE)


func _apply_heat_to_rooms(rooms: Array[RoomBase], temperature: float) -> void:
	if temperature <= _cached_outdoor_temperature:
		return

	for room: RoomBase in rooms:
		if room == null or not is_instance_valid(room):
			continue
		var room_id: int = room.get_instance_id()
		_temperature_cache_by_room_id[room_id] = maxf(
			float(_temperature_cache_by_room_id.get(room_id, _cached_outdoor_temperature)),
			temperature
		)


func _get_same_level_adjacent_rooms(room: RoomBase) -> Array[RoomBase]:
	var neighbors: Array[RoomBase] = []
	if room == null or room.data == null or not is_instance_valid(Building):
		return neighbors

	var seen_room_ids := {}
	for col in room.data.width:
		for row in room.data.height:
			var index := Vector2i(room.x + col, room.y + row)
			for direction in [Vector2i.LEFT, Vector2i.RIGHT]:
				var candidate := Building.get_room_from_index(index + direction) as RoomBase
				if candidate == null or candidate == room or candidate.data == null or candidate.is_outside_room:
					continue
				if candidate.y != room.y:
					continue
				var candidate_room_id: int = candidate.get_instance_id()
				if seen_room_ids.has(candidate_room_id):
					continue
				seen_room_ids[candidate_room_id] = true
				neighbors.append(candidate)
	return neighbors


func _get_adjacent_indoor_rooms(room: RoomBase) -> Array[RoomBase]:
	var neighbors: Array[RoomBase] = []
	var seen_room_ids := {}
	if room == null or room.data == null or not is_instance_valid(Building):
		return neighbors

	for col in room.data.width:
		for row in room.data.height:
			var index := Vector2i(room.x + col, room.y + row)
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var candidate := Building.get_room_from_index(index + direction) as RoomBase
				if candidate == null or candidate == room or candidate.data == null or candidate.is_outside_room:
					continue
				var candidate_room_id: int = candidate.get_instance_id()
				if seen_room_ids.has(candidate_room_id):
					continue
				seen_room_ids[candidate_room_id] = true
				neighbors.append(candidate)
	return neighbors


func _get_adjacent_indoor_rooms_for_group(rooms: Array[RoomBase], blocked_room_ids: Dictionary) -> Array[RoomBase]:
	var neighbors: Array[RoomBase] = []
	var seen_room_ids := {}
	for room: RoomBase in rooms:
		if room == null or not is_instance_valid(room):
			continue
		for neighbor: RoomBase in _get_adjacent_indoor_rooms(room):
			var neighbor_room_id: int = neighbor.get_instance_id()
			if blocked_room_ids.has(neighbor_room_id) or seen_room_ids.has(neighbor_room_id):
				continue
			seen_room_ids[neighbor_room_id] = true
			neighbors.append(neighbor)
	return neighbors


func _append_unique_rooms(target: Array[RoomBase], additions: Array[RoomBase]) -> void:
	var seen_room_ids := _to_room_id_lookup(target)
	for room: RoomBase in additions:
		if room == null or not is_instance_valid(room):
			continue
		var room_id: int = room.get_instance_id()
		if seen_room_ids.has(room_id):
			continue
		seen_room_ids[room_id] = true
		target.append(room)


func _to_room_id_lookup(rooms: Array[RoomBase]) -> Dictionary:
	var lookup := {}
	for room: RoomBase in rooms:
		if room == null or not is_instance_valid(room):
			continue
		lookup[room.get_instance_id()] = true
	return lookup


func _collect_unique_rooms() -> Array[RoomBase]:
	var rooms: Array[RoomBase] = []
	if not is_instance_valid(Building):
		return rooms

	var seen_room_ids := {}
	for floor_rooms: Dictionary in Building.floors.values():
		for room in floor_rooms.values():
			var typed_room := room as RoomBase
			if typed_room == null or typed_room.data == null:
				continue
			var room_id: int = typed_room.get_instance_id()
			if seen_room_ids.has(room_id):
				continue
			seen_room_ids[room_id] = true
			rooms.append(typed_room)
	return rooms


func _is_active_heat_source(source) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	if source.has_method("is_heating"):
		return bool(source.is_heating())
	if source.has_method("get_temperature_strength"):
		return float(source.get_temperature_strength()) > 0.0
	return false


func _get_heat_source_room(source) -> RoomBase:
	if source == null or not is_instance_valid(source):
		return null
	if source is RoomBase:
		return source as RoomBase
	if source.has_method("get_heat_room"):
		return source.get_heat_room() as RoomBase
	return null


func _get_heat_source_position(source) -> Vector2:
	if source == null or not is_instance_valid(source):
		return Vector2.INF
	if source.has_method("get_heat_source_position"):
		return source.get_heat_source_position()
	var node := source as Node2D
	if node != null:
		return node.global_position
	return Vector2.INF


func _get_heat_source_debug_name(source) -> String:
	if source == null or not is_instance_valid(source):
		return "heat"
	if source.has_method("get_heat_source_debug_name"):
		return String(source.get_heat_source_debug_name())
	if source is RoomStove:
		return "stove"
	return "heat"
