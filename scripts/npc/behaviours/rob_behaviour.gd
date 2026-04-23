extends FightBehaviour
class_name RobBehaviour

var _target_location: Vector2i = Vector2i(-9999, -9999)

func start_loop():
	#UiNotifications.create_notification_dynamic("I love robbing", npc, Vector2(0,-32), null, Color.RED, INF)
	super.start_loop()

func loop():
	_narrative = ["Casing the joint...", "Eyeing the valuables..."].pick_random()

	_target_location = MoneyHandler.richest_location()
	var target_room: RoomBase = Building.get_room_from_index(_target_location) as RoomBase
	if not is_instance_valid(target_room):
		return

	_narrative = ["Moving on the safe...", "Going for the loot...", "Heading for the money..."].pick_random()
	await move(target_room.get_random_floor_position())

	FightHandler.create_rob_fight(npc, target_room)
	arrived_at_room = true
	npc.Tint.add_tint(Color(1, .5, .5, 1), 10, self)

	while not fight.is_over:
		await end_of_frame()

	if stopped:
		return

	var stolen: int = MoneyHandler.steal(_target_location)
	if stolen > 0:
		UiNotifications.create_notification_dynamic("$%d stolen!" % stolen, npc, Vector2(0, -40), UiNotifications.ICON_MINUS_3)
	if npc.has_meta("horse"):
		npc.force_behaviour(LeaveOnHorseBehaviour)
	else:
		npc.force_behaviour(NeedLeaveBehaviour)

func stop_loop():
	print_debug("stop rob!");
	#UiNotifications.create_notification_dynamic("I'm done robbing", npc, Vector2(0,-32), null, Color.RED, INF)
	(npc as NPCGuest).is_robber = false
	return super.stop_loop()
