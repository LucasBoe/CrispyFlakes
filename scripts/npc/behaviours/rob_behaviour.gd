extends FightBehaviour
class_name RobBehaviour

const ROBBERY_FINE := 5
const PRE_FIGHT_PAUSE := 1.0
const POST_FIGHT_PAUSE := 1.0
const THREAT_TEXT := "gimme $$$"

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

	_narrative = ["Demanding the cash...", "Starting a robbery...", "Threatening the staff..."].pick_random()
	fight = FightHandler.create_rob_fight(npc, target_room, PRE_FIGHT_PAUSE)
	arrived_at_room = true
	UiNotifications.create_notification_dynamic(THREAT_TEXT, npc, Vector2(0, -40), null, Color.RED, PRE_FIGHT_PAUSE + 0.75)
	await pause(PRE_FIGHT_PAUSE)
	if stopped or not is_instance_valid(target_room) or fight == null:
		return

	if npc is NPCGuest:
		BountyHandler.add_fine(npc, ROBBERY_FINE, "Robbery")
	npc.Tint.add_tint(Color(1, .5, .5, 1), 10, self)

	while not fight.is_over:
		await end_of_frame()

	if stopped:
		return
	if fight.result != Fight.Result.NO_CONTEST:
		_narrative = ["Foiled!", "Empty-handed...", "Time to run..."].pick_random()
		if npc.has_meta("horse"):
			npc.force_behaviour(LeaveOnHorseBehaviour)
		else:
			npc.force_behaviour(NeedLeaveBehaviour)
		return
	_narrative = ["Grabbing the loot...", "Stuffing pockets...", "Making a break for it..."].pick_random()
	await pause(POST_FIGHT_PAUSE)
	if stopped:
		return

	var stolen: int = MoneyHandler.steal(_target_location)
	if stolen > 0:
		ResourceHandler.notify_stolen(stolen)
		(npc as NPCGuest).stolen_amount = stolen
		UiNotifications.create_notification_dynamic("$%d stolen!" % stolen, npc, Vector2(0, -40), UiNotifications.ICON_MINUS_3)
	if npc.has_meta("horse"):
		npc.force_behaviour(LeaveOnHorseBehaviour)
	else:
		npc.force_behaviour(NeedLeaveBehaviour)

func stop_loop():
	(npc as NPCGuest).is_robber = false
	return super.stop_loop()
