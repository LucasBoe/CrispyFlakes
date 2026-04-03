extends Node

var active_fights = []
var fight_particles = {}
var fight_bars = {}

@onready var fight_particle_scene : PackedScene = preload("res://scenes/fight_particles.tscn")

func get_or_create_fight(npc : NPC) -> Fight:
	var fight = null

	if active_fights.size() > 0:
		fight = active_fights[0]
	else:
		fight = _create_fight(npc.global_position)

	fight.participants.append(npc)
	return fight

func create_arrest_fight(guest: NPC, _worker: NPC) -> Fight:
	var fight = _create_fight(guest.global_position)
	fight.is_arrest_fight = true
	fight.participants.append(guest)
	# worker is appended by StopFightBehaviour when it starts
	return fight

func get_fight_for_room(room : RoomBase):
	for a in active_fights:
		if a.room == room:
			return a
	return null

func _create_fight(position):
	var room = Global.Building.query.closest_room_of_type(RoomBase, position) as RoomBase
	var fight = Fight.new()
	active_fights.append(fight)
	fight.start_fight(room)

	var particle_scene = fight_particle_scene.instantiate() as GPUParticles2D
	add_child(particle_scene)
	particle_scene.global_position = room.get_center_position()
	fight_particles[fight] = particle_scene

	fight_bars[fight] = UiNotifications.create_fight_bar(room)

	return fight

func _end_fight(fight):
	_destroy_particles(fight_particles[fight])
	fight_particles.erase(fight)

	UiNotifications.try_kill(fight_bars[fight])
	fight_bars.erase(fight)

	fight.end_fight()
	active_fights.erase(fight)

func _destroy_particles(particles : GPUParticles2D):
	particles.emitting = false
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func _get_valid_participant_positions(fight: Fight) -> Array:
	var positions = []
	for p in fight.participants:
		var b = p.Behaviour.behaviour_instance as FightBehaviour
		if b and b.arrived_at_roon:
			positions.append(p.global_position + Vector2(0, -12))
	return positions

func _process(delta):
	for f : Fight in active_fights:
		var worker_strength := 0.0
		var npc_strength := 0.0

		for p in f.participants:
			var arrived := false
			var b = p.Behaviour.behaviour_instance
			if b is FightBehaviour:
				arrived = (b as FightBehaviour).arrived_at_roon
			elif b is StopFightBehaviour:
				arrived = (b as StopFightBehaviour).arrived_at_room
			print("[FIGHT] participant:", p.name, " behaviour:", b, " arrived:", arrived)
			if not arrived:
				continue
			if p is NPCWorker:
				worker_strength += p.strength
			elif p is NPCGuest:
				npc_strength += p.strength

		print("[FIGHT] bar:", f.bar, " worker_str:", worker_strength, " npc_str:", npc_strength)
		if worker_strength > 0.0 and npc_strength > 0.0:
			f.bar += (worker_strength - npc_strength) * delta

		f.bar = clamp(f.bar, 0.0, 1.0)

		if f.bar >= 1.0 or f.bar <= 0.0:
			_end_fight(f)
			continue

		if fight_bars.has(f):
			UiNotifications.update_fight_bar(fight_bars[f], f.bar)

		if fight_particles.has(f):
			var positions = _get_valid_participant_positions(f)
			var particles = fight_particles[f]
			if positions.is_empty():
				particles.emitting = false
			else:
				var sum = Vector2.ZERO
				for pos in positions:
					sum += pos
				particles.global_position = sum / positions.size()
				particles.emitting = true
