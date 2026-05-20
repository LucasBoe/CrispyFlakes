extends RoomBase
class_name RoomGeneratorWheel

const ACTIVE_SPIN_SPEED := 4.0
const IDLE_SPIN_SPEED := 0.35
const ELECTRICITY_LAYER := BuildingInfrastructure.ELECTRICITY_LAYER

@onready var wheel_sprite: Sprite2D = $Wheel

var _is_generating := false

func init_room(_x: int, _y: int) -> void:
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.GENERATOR_WHEEL

func _process(delta: float) -> void:
	if wheel_sprite == null:
		return
	wheel_sprite.rotation += (ACTIVE_SPIN_SPEED if _is_generating else IDLE_SPIN_SPEED) * delta

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func get_runner_position() -> Vector2:
	return global_position + Vector2(24, 0)

func set_generating(value: bool) -> void:
	if _is_generating == value:
		return
	_is_generating = value
	if is_instance_valid(Building.infrastructure):
		Building.infrastructure.notify_layer_state_changed(ELECTRICITY_LAYER)

func is_generating() -> bool:
	return _is_generating

func get_provided_infrastructure_layers() -> Array[StringName]:
	if _is_generating:
		return [ELECTRICITY_LAYER]
	return []

func destroy():
	set_generating(false)
	super.destroy()
