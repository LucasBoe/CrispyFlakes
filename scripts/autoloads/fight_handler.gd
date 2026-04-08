extends Node

var active_fights = []
var fight_particles = {}
var npc_health_bars = {}  # NPC -> instance_info

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

	return fight

func _end_fight(fight):
	_destroy_particles(fight_particles[fight])
	fight_particles.erase(fight)

	for p in fight.participants:
		if npc_health_bars.has(p):
			UiNotifications.try_kill(npc_health_bars[p])
			npc_health_bars.erase(p)

	fight.is_over = true

	var room = fight.room

	if fight.npc_won() and not fight.is_arrest_fight:
		if _is_destructable_room(room):
			GlobalEventHandler.on_room_deleted_signal.emit(room)
			Global.Building.set_room(load("res://assets/resources/room_junk.tres"), room.x, room.y)
			room.destroy()

	fight.end_fight()
	active_fights.erase(fight)

func _is_destructable_room(room):
	if room is RoomJunk:
		return false
	elif room is RoomBountyBoard:
		return false
	elif room is RoomEmpty:
		return false

	return true

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
		var arrived_workers = []
		var arrived_guests = []

		for p in f.participants:
			if not is_instance_valid(p):
				continue
			var arrived := false
			var b = p.Behaviour.behaviour_instance
			if b is FightBehaviour:
				arrived = (b as FightBehaviour).arrived_at_roon
			elif b is StopFightBehaviour:
				arrived = (b as StopFightBehaviour).arrived_at_room
			if not arrived:
				continue
			if p is NPCWorker:
				arrived_workers.append(p)
			elif p is NPCGuest:
				arrived_guests.append(p)

			# Create health bar on first arrival
			if not npc_health_bars.has(p):
				p.health = 1.0
				var color = Color.GREEN if p is NPCWorker else Color.RED
				npc_health_bars[p] = UiNotifications.create_npc_health_bar(p, color)

		f.time_elapsed += delta

		# Workers deal damage to guests, guests deal damage to workers
		var worker_strength := 0.0
		for w in arrived_workers:
			worker_strength += w.strength * w.stamina

		var guest_strength := 0.0
		for g in arrived_guests:
			var sobriety = 1.0 - g.Needs.drunkenness.strength
			guest_strength += g.strength * g.stamina * sobriety

		if worker_strength > 0.0 and arrived_guests.size() > 0:
			var dmg = worker_strength * delta / arrived_guests.size() / 4.0
			for g in arrived_guests:
				g.health = max(0.0, g.health - dmg)

		# Guest damage is split evenly across all participants (workers + other guests)
		var all_targets = arrived_workers + arrived_guests
		if guest_strength > 0.0 and all_targets.size() > 0:
			var dmg = guest_strength * delta / all_targets.size() / 4.0
			for t in all_targets:
				t.health = max(0.0, t.health - dmg)

		# Escalating fatigue — guests tire out over time, guaranteeing a resolution
		if arrived_guests.size() > 0:
			var fatigue = (f.time_elapsed / Fight.MAX_DURATION_IN_SECONDS) * 0.12 * delta / 4.0
			for g in arrived_guests:
				g.health = max(0.0, g.health - fatigue)

		# Knock out individual guests that hit 0 health
		var fight_ending = f.worker_won() or f.npc_won() or f.guests_all_down()
		for g in arrived_guests:
			if g.health <= 0.0:
				if npc_health_bars.has(g):
					UiNotifications.try_kill(npc_health_bars[g])
					npc_health_bars.erase(g)
				# Only force intermediate KnockedOutBehaviour if fight continues;
				# if the fight is ending this frame, end_fight() sets the final state.
				if not fight_ending:
					g.force_behaviour(KnockedOutBehaviour)

		# Update health bar visuals
		for p in f.participants:
			if npc_health_bars.has(p) and is_instance_valid(p):
				UiNotifications.update_npc_health_bar(npc_health_bars[p], p.health)

		if fight_ending:
			_end_fight(f)
			continue

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
