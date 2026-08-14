class_name EquipmentInstance

var data: EquipmentData
var equipped_by = null  # NPCWorker or null

func is_available() -> bool:
	return equipped_by == null or not is_instance_valid(equipped_by)
