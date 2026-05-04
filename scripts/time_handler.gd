extends Node

signal on_time_changed_signal

var _requested_time = 1
var _pause_locks: Dictionary = {}

func set_time(t):
	_requested_time = t
	_apply_time()

func push_pause_lock(owner) -> void:
	_pause_locks[owner] = true
	_apply_time()

func pop_pause_lock(owner) -> void:
	_pause_locks.erase(owner)
	_apply_time()

func _apply_time() -> void:
	var time = 0 if not _pause_locks.is_empty() else _requested_time
	Engine.time_scale = time
	on_time_changed_signal.emit(time)
