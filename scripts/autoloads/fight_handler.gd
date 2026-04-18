extends Node

var active_fights = []
var fight_particles = {}
var npc_health_bars = {}  # NPC -> instance_info

@onready var fight_particle_scene : PackedScene = preload("res://scenes/fight_particles.tscn")


func get_or_create_fight(npc : NPC) -> Fight:
	var fight = null
	var created := false
	var room := _get_actor_room(npc)

	if room != null:
		fight = get_fight_for_floor(room.y)

	if fight == null:
		fight = _create_fight(npc.global_position)
		created = true

	if not fight.participants.has(npc):
		fight.participants.append(npc)
	if created:
		_dispatch_saloon_workers(fight)
	return fight

func create_arrest_fight(guest: NPC, _worker: NPC) -> Fight:
	var fight = _create_fight(guest.global_position)
	fight.is_arrest_fight = true
	fight.participants.append(guest)
	# worker is appended by StopFightBehaviour when it starts
	_dispatch_saloon_workers(fight, guest)
	return fight

func create_robbery_fight(npc: NPC, room: RoomBase) -> Fight:
	var existing = get_fight_for_room(room)
	if existing != null:
		if not existing.participants.has(npc):
			existing.participants.append(npc)
		return existing

	var fight = Fight.new()
	active_fights.append(fight)
	fight.start_fight(room)

	var particle_scene = fight_particle_scene.instantiate() as GPUParticles2D
	add_child(particle_scene)
	particle_scene.global_position = room.get_center_position()
	fight_particles[fight] = particle_scene

	fight.participants.append(npc)
	_dispatch_saloon_workers(fight)
	return fight

func get_fight_for_room(room : RoomBase):
	for a in active_fights:
		if a.room == room:
			return a
	return null

func get_fight_for_floor(floor_y: int):
	for fight: Fight in active_fights:
		if fight.room != null and fight.room.y == floor_y:
			return fight
	return null

func _create_fight(position):
	var room = Building.query.closest_room_of_type(RoomBase, position) as RoomBase
	var fight = Fight.new()
	active_fights.append(fight)
	fight.start_fight(room)

	var particle_scene = fight_particle_scene.instantiate() as GPUParticles2D
	add_child(particle_scene)
	particle_scene.global_position = room.get_center_position()
	fight_particles[fight] = particle_scene

	return fight

func try_start_auto_arrest(guest: NPCGuest, initiating_worker: NPCWorker = null) -> bool:
	if guest == null or not is_instance_valid(guest):
		return false
	if guest.is_in_fight_state():
		return false

	var room := _get_actor_room(guest)
	if room == null:
		return false
	if get_fight_for_room(room) != null:
		return false

	var responders: Array = []
	if is_instance_valid(initiating_worker):
		if not initiating_worker.should_auto_respond_to_arrest(room):
			return false
		if not initiating_worker.is_within_conflict_engage_range(guest.global_position):
			return false
		responders.append(initiating_worker)

	for worker: NPCWorker in _get_saloon_workers_for_room(room, guest.global_position):
		if worker != initiating_worker:
			responders.append(worker)
	if responders.is_empty():
		return false

	var fight = _create_fight(guest.global_position)
	fight.is_arrest_fight = true
	fight.participants.append(guest)
	guest.Behaviour.set_behaviour(FightBehaviour)
	(guest.Behaviour.behaviour_instance as FightBehaviour).fight = fight
	_dispatch_saloon_workers(fight, guest, responders)
	return true

func _dispatch_saloon_workers(fight: Fight, arrest_target: NPCGuest = null, responders: Array = []) -> void:
	if fight == null or fight.room == null:
		return

	var engage_position := _get_conflict_engage_position(fight, arrest_target)

	if responders.is_empty():
		responders = _get_saloon_workers_for_room(fight.room, engage_position)
	if responders.is_empty():
		return

	var arrest_room: RoomPrison = null
	if arrest_target != null:
		arrest_room = Building.query.closest_room_of_type(RoomPrison, fight.room.get_center_position()) as RoomPrison

	var lead_assigned := arrest_target == null
	for worker: NPCWorker in responders:
		if not is_instance_valid(worker):
			continue
		if not lead_assigned:
			lead_assigned = worker.auto_join_saloon_fight(fight, arrest_target, arrest_room, engage_position)
		else:
			worker.auto_join_saloon_fight(fight, null, null, engage_position)

func _get_saloon_workers_for_room(room: RoomBase, target_position: Vector2 = Vector2.INF) -> Array:
	var responders: Array = []
	if Global.NPCSpawner == null:
		return responders

	for worker: NPCWorker in Global.NPCSpawner.workers:
		if is_instance_valid(worker) and worker.should_auto_join_saloon_fight(room, target_position):
			responders.append(worker)
	return responders

func _get_saloon_arrest_responders(room: RoomBase) -> Array:
	var responders: Array = []
	if Global.NPCSpawner == null:
		return responders

	for worker: NPCWorker in Global.NPCSpawner.workers:
		if is_instance_valid(worker) and worker.should_auto_respond_to_arrest(room):
			responders.append(worker)
	return responders

func _get_actor_room(actor: Node2D) -> RoomBase:
	if actor == null or not is_instance_valid(actor):
		return null

	var exact := Building.query.room_at_position(actor.global_position) as RoomBase
	if exact != null:
		return exact
	return Building.query.closest_room_of_type(RoomBase, actor.global_position) as RoomBase

func _get_conflict_engage_position(fight: Fight, arrest_target: NPCGuest = null) -> Vector2:
	if arrest_target != null and is_instance_valid(arrest_target):
		return arrest_target.global_position

	for participant in fight.participants:
		if is_instance_valid(participant):
			return participant.global_position

	return fight.room.get_center_position()

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
			Building.set_room(load("res://assets/resources/room_junk.tres"), room.x, room.y)
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
	_update_auto_arrests()

	for f : Fight in active_fights:
		if f.is_arrest_fight:
			var arrest_target := _get_arrest_target_for_fight(f)
			if arrest_target != null:
				_dispatch_saloon_workers(f, arrest_target)

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

func _update_auto_arrests() -> void:
	if Global.NPCSpawner == null:
		return

	for guest: NPCGuest in Global.NPCSpawner.guests:
		if not is_instance_valid(guest) or not guest.pending_arrest:
			continue
		if guest.Behaviour.behaviour_instance is ArrestedBehaviour:
			continue
		var room := _get_actor_room(guest)
		if room == null:
			continue
		for worker: NPCWorker in _get_saloon_arrest_responders(room):
			worker.begin_auto_arrest_response(guest)

func _get_arrest_target_for_fight(fight: Fight) -> NPCGuest:
	if fight == null or not fight.is_arrest_fight:
		return null

	for participant in fight.participants:
		if participant is NPCGuest and is_instance_valid(participant):
			return participant
	return null
