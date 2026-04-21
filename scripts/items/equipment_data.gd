class_name EquipmentData

var equipment_name : String = ""
var slot : int = 0
var icon : Texture2D = null
var equiped_overlay_texture : Texture2D

static func get_catalog_for_slot(_p_slot: int) -> Array:
	return []

static func _make(p_name: String, p_slot: int) -> EquipmentData:
	var d := EquipmentData.new()
	d.equipment_name = p_name
	d.slot = p_slot
	return d
