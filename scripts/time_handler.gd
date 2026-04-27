extends Node

signal on_time_changed_signal

func set_time(t):
	Engine.time_scale = t
	on_time_changed_signal.emit(t)
