class_name EquipmentModule
extends RefCounted

var npc

func _init(owner) -> void:
	npc = owner

func get_equipped_instance() -> EquipmentInstance:
	return EquipmentInventory.get_equipped_by(npc)

func get_equipped_data() -> EquipmentData:
	var inst := get_equipped_instance()
	return inst.data if inst != null else null

func get_equipped_weapon() -> WeaponData:
	return get_equipped_data() as WeaponData

func has_equipped() -> bool:
	return get_equipped_instance() != null

func get_work_duration_multiplier() -> float:
	var data := get_equipped_data()
	return data.work_duration_multiplier if data != null else 1.0

func equip(instance: EquipmentInstance) -> bool:
	return EquipmentInventory.equip(npc, instance)

func unequip() -> void:
	EquipmentInventory.unequip(npc)
