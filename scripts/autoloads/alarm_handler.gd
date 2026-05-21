extends Node

signal on_alarm_started_signal(alarm_type: StringName, source)
signal on_alarm_ended_signal(alarm_type: StringName, source)
signal on_alarm_state_changed_signal(has_active_alarm: bool)

const TYPE_FIGHT := &"fight"
const TYPE_ROBBERY := &"robbery"
const TYPE_FIRE := &"fire"
const ALARM_COLOR := Color(1.0, 0.08, 0.02, 1.0)
const ALARM_PULSE_COLOR := Color(1.0, 0.46, 0.02, 1.0)
const ALARM_PULSE_SPEED := 8.0

var _active_alarms: Dictionary = {}
var _active_highlights: Dictionary = {}

func _process(_delta: float) -> void:
	_prune_invalid_sources()
	if _active_highlights.is_empty():
		return

	var pulse_time := Time.get_ticks_msec() * 0.001
	var pulse := (sin(pulse_time * ALARM_PULSE_SPEED) + 1.0) * 0.5
	var pulse_color := ALARM_COLOR.lerp(ALARM_PULSE_COLOR, pulse)

	for source in _active_highlights.keys():
		var highlight = _active_highlights[source]
		if not is_instance_valid(highlight):
			_active_highlights.erase(source)
			continue
		highlight.modulate = pulse_color

func start_alarm(source, alarm_type: StringName, force_sound := false) -> void:
	if source == null:
		return

	_prune_invalid_sources()
	var had_active_alarm := not _active_alarms.is_empty()
	var previous_type: StringName = _active_alarms.get(source, &"")
	_active_alarms[source] = alarm_type
	_ensure_alarm_presentation(source)

	SoundPlayer.play_alarm(force_sound)

	if previous_type != alarm_type:
		on_alarm_started_signal.emit(alarm_type, source)
	if had_active_alarm != not _active_alarms.is_empty():
		on_alarm_state_changed_signal.emit(not _active_alarms.is_empty())

func end_alarm(source) -> void:
	_prune_invalid_sources()
	if not _active_alarms.has(source):
		return

	var had_active_alarm := not _active_alarms.is_empty()
	var alarm_type: StringName = _active_alarms[source]
	_active_alarms.erase(source)
	_clear_alarm_presentation(source)
	on_alarm_ended_signal.emit(alarm_type, source)
	if had_active_alarm != not _active_alarms.is_empty():
		on_alarm_state_changed_signal.emit(not _active_alarms.is_empty())

func has_active_alarm() -> bool:
	_prune_invalid_sources()
	return not _active_alarms.is_empty()

func has_alarm_for(source) -> bool:
	_prune_invalid_sources()
	return _active_alarms.has(source)

func get_alarm_type(source) -> StringName:
	_prune_invalid_sources()
	return _active_alarms.get(source, &"")

func _ensure_alarm_presentation(source) -> void:
	var room := _get_alarm_room(source)
	if room == null:
		return

	var highlight = _active_highlights.get(source, null)
	if is_instance_valid(highlight):
		return

	highlight = RoomHighlighter.request_rect(room, ALARM_COLOR, 2, RoomHighlighter.Priority.FIRE)
	_active_highlights[source] = highlight

func _clear_alarm_presentation(source) -> void:
	var highlight = _active_highlights.get(source, null)
	if is_instance_valid(highlight):
		RoomHighlighter.dispose(highlight)
	_active_highlights.erase(source)

func _get_alarm_room(source) -> RoomBase:
	if source is RoomBase:
		return source as RoomBase
	if not (source is Object) or not is_instance_valid(source):
		return null

	var room = source.get("room")
	if room is RoomBase and is_instance_valid(room):
		return room
	return null

func _prune_invalid_sources() -> void:
	for source in _active_alarms.keys():
		if source is Object and not is_instance_valid(source):
			_active_alarms.erase(source)
			_clear_alarm_presentation(source)

	for source in _active_highlights.keys():
		var highlight = _active_highlights[source]
		if source is Object and not is_instance_valid(source):
			_clear_alarm_presentation(source)
			continue
		if not is_instance_valid(highlight):
			_active_highlights.erase(source)
