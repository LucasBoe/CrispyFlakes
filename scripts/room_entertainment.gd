extends RoomBase
class_name RoomEntertainment

const DEFAULT_EFFECT_INTERVAL := 10.0
const DEFAULT_SATISFACTION_BOOST := 0.08
const PERFORMANCE_RANGE := 2

var current_module = null
var _guests_swaying_enabled := false
@onready var music_particles: GPUParticles2D = $MusicParticles

func init_room(_x: int, _y: int):
	associated_job = Enum.Jobs.ENTERTAINMENT
	super.init_room(_x, _y)

	var modules_root = get_node_or_null("ModulesRoot")
	if modules_root:
		for group in modules_root.get_children():
			for module in group.get_children():
				if not module.has_method("set_bought"):
					continue
				module.bought_changed.connect(_on_module_bought)
				if module.bought:
					current_module = module

func _on_module_bought(module) -> void:
	if not module.bought:
		return
	current_module = module

func get_performance_interval() -> float:
	if current_module and current_module.effect_interval > 0.0:
		return current_module.effect_interval
	return DEFAULT_EFFECT_INTERVAL

func get_satisfaction_boost() -> float:
	if current_module and current_module.satisfaction_boost > 0.0:
		return current_module.satisfaction_boost
	return DEFAULT_SATISFACTION_BOOST

func has_active_performance() -> bool:
	return current_module != null and worker != null

func _process(_delta):
	if music_particles == null:
		return
	music_particles.emitting = has_active_performance()

func _exit_tree() -> void:
	set_guests_swaying(false)

func count_guests_in_range() -> int:
	if Global.NPCSpawner == null:
		return 0

	var count := 0
	for guest in Global.NPCSpawner.guests:
		if _is_guest_in_range(guest):
			count += 1
	return count

func set_guests_swaying(value: bool) -> void:
	if _guests_swaying_enabled == value:
		return

	_guests_swaying_enabled = value
	AnimationModule.set_music_sway_enabled(value)

func entertain_guests() -> int:
	if Global.NPCSpawner == null:
		return 0

	var boosted_guest_count := 0
	for guest in Global.NPCSpawner.guests:
		guest.add_satisfaction(get_satisfaction_boost(), "Entertainment")
		boosted_guest_count += 1

	return boosted_guest_count

func _is_guest_in_range(guest: NPCGuest) -> bool:
	if not is_instance_valid(guest):
		return false

	#TODO simplyfy to y position compare
	var guest_room_index: Vector2i = Building.round_room_index_from_global_position(guest.global_position)
	return guest_room_index.y == y and absi(guest_room_index.x - x) <= PERFORMANCE_RANGE
