extends Node

signal guest_injured(guest: NPCGuest)
signal guest_recovered(guest: NPCGuest)

var _injured: Array[NPCGuest] = []

func on_guest_injured(guest: NPCGuest) -> void:
	if not _injured.has(guest):
		_injured.append(guest)
	guest_injured.emit(guest)

func on_guest_recovered(guest: NPCGuest) -> void:
	_injured.erase(guest)
	guest_recovered.emit(guest)

func get_injured_guests() -> Array[NPCGuest]:
	for i: int in range(_injured.size() - 1, -1, -1):
		if not is_instance_valid(_injured[i]):
			_injured.remove_at(i)
	return _injured
