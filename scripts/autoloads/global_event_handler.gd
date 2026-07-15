extends Node

signal on_room_created_signal
signal on_room_deleted_signal
signal on_infrastructure_changed_signal
signal on_item_needed_signal(item_type: int)

func notify_item_needed(item_type: int) -> void:
	on_item_needed_signal.emit(item_type)
