class_name EquipmentModule

var npc
var equipped: Dictionary = {}

func _init(owner) -> void:
	npc = owner

func get_equipped(slot: int):
	return equipped.get(slot, null)

func equip(slot: int, data) -> void:
	equipped[slot] = data

func unequip(slot: int) -> void:
	equipped.erase(slot)
