extends RoomBase
class_name RoomDestillery

const EXPLOSION_EFFECT_SCENE := preload("res://scenes/destillery_explosion_particles.tscn")
const EXPLOSION_CHANCE := 0.05
const EXPLOSION_KNOCKOUT_RANGE_X := 72.0
const EXPLOSION_KNOCKOUT_RANGE_Y := 24.0
const EXPLOSION_SHAKE_STRENGTH := 7.0
const EXPLOSION_SHAKE_DURATION := 0.22

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

func trigger_explosion() -> int:
	play_explosion_effect()
	SoundPlayer.play_explosion(get_center_floor_position())
	_shake_camera()
	return knock_out_nearby_workers()

func play_explosion_effect() -> void:
	var effect := EXPLOSION_EFFECT_SCENE.instantiate() as Node2D
	add_child(effect)
	effect.global_position = get_center_position() + Vector2(0.0, 4.0)

func knock_out_nearby_workers() -> int:
	if Global.NPCSpawner == null:
		return 0

	var knocked_out := 0
	var blast_center = get_center_floor_position()
	for worker: NPCWorker in Global.NPCSpawner.get_live_workers():
		if not _is_worker_in_explosion_range(worker, blast_center):
			continue
		worker.Behaviour.set_behaviour(KnockedOutBehaviour)
		knocked_out += 1
	return knocked_out

func _is_worker_in_explosion_range(worker: NPCWorker, blast_center: Vector2) -> bool:
	if not is_instance_valid(worker) or worker.Behaviour == null:
		return false
	if NPCWorker.picked_up_npc == worker:
		return false

	var diff := worker.global_position - blast_center
	return absf(diff.x) <= EXPLOSION_KNOCKOUT_RANGE_X and absf(diff.y) <= EXPLOSION_KNOCKOUT_RANGE_Y

func _shake_camera() -> void:
	if is_instance_valid(Camera):
		Camera.add_shake(EXPLOSION_SHAKE_STRENGTH, EXPLOSION_SHAKE_DURATION)
