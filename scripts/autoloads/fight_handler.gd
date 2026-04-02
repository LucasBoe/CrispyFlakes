extends Node

var active_fights = []
var fight_particles = {}

@onready var fight_particle_scene : PackedScene = preload("res://scenes/fight_particles.tscn")

func get_or_create_fight(npc : NPC) -> Fight:
	
	var fight = null
	
	if active_fights.size() > 0:
		fight = active_fights[0]
	else:
		fight = _create_fight(npc.global_position)
	
	fight.participants.append(npc)
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
	#particle_scene.emitting = true
	fight_particles[fight] = particle_scene
	
	return fight
	
func _end_fight(fight):
	_destroy_particles(fight_particles[fight])
	fight_particles.erase(fight)
	
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
		f.energy -= delta / Fight.MAX_DURATION_IN_SECONDS

		if f.energy <= 0:
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
