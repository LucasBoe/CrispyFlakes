class_name WeaponInstance

var data  # WeaponData
var equipped_by = null  # NPCWorker or null

func is_available() -> bool:
	return equipped_by == null or not is_instance_valid(equipped_by)
