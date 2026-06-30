extends Behaviour
class_name JobJunkBehaviour

const BROOM_PARTICLES_SCENE = preload("res://scenes/fight_particles.tscn")

var room : RoomJunk
var active_broom_particles: GPUParticles2D

static var occupied_rooms = []

func start_loop():
	room = try_get_room_if_not_occupied(data, RoomJunk, occupied_rooms)


func loop():
	var broom := Global.ItemSpawner.create(Enum.Items.BROOM, npc.global_position)
	npc.Item.pick_up(broom)

	for i in 3:
		_narrative = ["Clearing the junk...", "Hauling debris...", "Cleaning up the wreckage..."].pick_random()
		await move(room.get_random_floor_position())
		_start_broom_effect()
		SoundPlayer.play_broom(npc.global_position)
		await progress(1)
		await _stop_broom_effect()

	occupied_rooms.erase(room)
	Building.replace_with_empty(room)


func custom_array_sort(a, b):
	return a[1] < b[1]


func stop_loop() -> BehaviourSaveData:
	_stop_broom_effect_immediately()

	if npc.Item.is_item(Enum.Items.BROOM):
		npc.Item.current_item.destroy()
		npc.Item.current_item = null

	room.worker = null
	occupied_rooms.erase(room)

	var save = super.stop_loop()
	save.room = room
	return save


func _start_broom_effect() -> void:
	_stop_broom_effect_immediately()
	active_broom_particles = BROOM_PARTICLES_SCENE.instantiate() as GPUParticles2D
	npc.add_child(active_broom_particles)
	npc.Animator.is_brooming = true


func _stop_broom_effect() -> void:
	npc.Animator.is_brooming = false
	var particles := active_broom_particles
	active_broom_particles = null
	if not is_instance_valid(particles):
		return
	particles.emitting = false
	await npc.get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()


func _stop_broom_effect_immediately() -> void:
	npc.Animator.is_brooming = false
	if is_instance_valid(active_broom_particles):
		active_broom_particles.queue_free()
	active_broom_particles = null
