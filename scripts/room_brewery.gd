extends RoomBase
class_name RoomBrewery

const BIG_BREWER_FLAG := ProgressionItem.ProgressionFlag.BIG_BREWER

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.BREWERY
	if not ProgressionHandler.flag_unlocked.is_connected(_on_progression_flag_unlocked):
		ProgressionHandler.flag_unlocked.connect(_on_progression_flag_unlocked)
	_apply_progression_upgrade()

func _on_module_bought(module) -> void:
	if not module.bought:
		return
	var used_water_before := uses_infrastructure_layer(&"water")
	current_module = module
	if used_water_before != uses_infrastructure_layer(&"water"):
		refresh_infrastructure_visuals()

func uses_infrastructure_layer(layer_name: StringName) -> bool:
	return layer_name == &"water" and current_module != null and Building.infrastructure.room_has_service(self, &"water")

func _on_progression_flag_unlocked(flag: ProgressionItem.ProgressionFlag) -> void:
	if flag == BIG_BREWER_FLAG:
		_apply_progression_upgrade()

func _apply_progression_upgrade() -> void:
	if not ProgressionHandler.is_flag_set(BIG_BREWER_FLAG):
		return
	var big_brewer := get_node_or_null("ModulesRoot/Brewer/Big")
	if big_brewer == null or big_brewer.bought:
		return
	_activate_module(big_brewer)

func _activate_module(target_module) -> void:
	var module_group: Node = target_module.get_parent()
	for module in module_group.get_children():
		if not module.has_method("set_bought"):
			continue
		module.set_bought(module == target_module)
