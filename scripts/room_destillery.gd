extends RoomBase
class_name RoomDestillery

const EXPLOSION_CHANCE := 0.05

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.DESTILLERY

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func _on_module_bought(module) -> void:
	if not module.bought:
		return
	var used_water_before := uses_infrastructure_layer(&"water")
	current_module = module
	if used_water_before != uses_infrastructure_layer(&"water"):
		refresh_infrastructure_visuals()

func uses_infrastructure_layer(layer_name: StringName) -> bool:
	return layer_name == &"water" and current_module != null and Building.infrastructure.room_has_service(self, &"water")

func wants_infrastructure_layer(layer_name: StringName) -> bool:
	return layer_name == &"water" and current_module != null

func should_explode() -> bool:
	return not FireHandler.is_room_on_fire(self) and randf() < EXPLOSION_CHANCE
