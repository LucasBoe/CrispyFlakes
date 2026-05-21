extends Node

signal on_time_changed_signal
signal on_requested_time_changed_signal

const NORMAL_TIME := 1
const FASTEST_TIME := 9

var _requested_time = NORMAL_TIME
var _pause_locks: Dictionary = {}

func set_time(t):
	var requested_time := _sanitize_requested_time(t)
	if _requested_time != requested_time:
		_requested_time = requested_time
		on_requested_time_changed_signal.emit(_requested_time)
	_apply_time()

func push_pause_lock(owner) -> void:
	_pause_locks[owner] = true
	_apply_time()

func pop_pause_lock(owner) -> void:
	_pause_locks.erase(owner)
	_apply_time()

func get_requested_time() -> int:
	return _requested_time

func _ready() -> void:
	if not AlarmHandler.on_alarm_started_signal.is_connected(_on_alarm_started):
		AlarmHandler.on_alarm_started_signal.connect(_on_alarm_started)

func _apply_time() -> void:
	var time = 0 if not _pause_locks.is_empty() else _requested_time
	Engine.time_scale = time
	on_time_changed_signal.emit(time)

func _sanitize_requested_time(time: int) -> int:
	if time >= FASTEST_TIME and AlarmHandler.has_active_alarm():
		return NORMAL_TIME
	return time

func _on_alarm_started(_alarm_type: StringName, _source) -> void:
	if _requested_time >= FASTEST_TIME:
		set_time(NORMAL_TIME)
