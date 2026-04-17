extends Behaviour
class_name ArriveOnHorseBehaviour

const HorseScene = preload("res://scenes/npcs/horse_npc.tscn")

var horse: Node2D = null  # HorseNPC

func loop():
	_narrative = ["Riding in...", "Arriving on horseback...", "Coming in from the range..."].pick_random()
	var horse_post := _find_available_horse_post()

	# Spawn the HorseNPC alongside the guest
	horse = HorseScene.instantiate()
	Global.NPCSpawner.add_child(horse)
	horse.global_position = npc.global_position
	horse.owner_guest = npc
	horse.visible = true

	npc.set_meta("horse", horse)
	npc.Animator.set_riding(true)

	# Always ride to just outside the building entrance — never inside
	if horse_post:		
		await _ride_to(horse_post.get_center_floor_position())
	else:
		var stop_x = _get_entrance_x() - 8.0
		await _ride_to(Vector2(stop_x, npc.global_position.y))

	# Dismount at the entrance
	npc.Animator.set_riding(false)

	if is_instance_valid(horse_post):
		horse.tie_to(horse_post)
	else:
		horse.drop_at(npc.global_position)

	var bouncer_room := Building.query.closest_room_of_type(RoomBouncer, npc.global_position) as RoomBouncer
	if bouncer_room != null:
		npc.force_behaviour(ArriveThroughBouncerBehaviour)
		return

# Returns the world x of the leftmost ground-floor room's left pixel edge.
func _get_entrance_x() -> float:
	if not Building.floors.has(0):
		return 0.0
	var min_x = INF
	for x in Building.floors[0]:
		var room = Building.floors[0][x]
		if room != null and room is not RoomEmpty:
			min_x = minf(min_x, float(x))
	if min_x == INF:
		return 0.0
	return Building.global_position_from_room_index(Vector2i(int(min_x), 0)).x - 24.0

# Bypass room pathfinder — move directly in world space
func _ride_to(target: Vector2) -> void:
	npc.Navigation.stop_navigation()
	npc.Navigation.is_moving = true
	var speed = 80.0
	while npc.global_position.distance_to(target) > 2.0:
		var dir = (target - npc.global_position).normalized()
		npc.global_position += dir * speed * npc.get_process_delta_time()
		npc.Animator.direction = dir
		await end_of_frame()
	npc.Animator.direction = Vector2.ZERO
	npc.Navigation.is_moving = false

func _find_available_horse_post() -> RoomHorsePost:
	for post: RoomHorsePost in get_all_rooms_of_type_ordered_by_distance(RoomHorsePost):
		if post.can_accept_horse():
			return post
	return null
