extends NeedBehaviour
class_name NeedSnakeOilBehaviour

const MOOD_BOOST := 0.2

var salesman = null
var request = null

static func get_probability_by_needs(needs: NeedsModule):
	return needs.mood.strength * maxf(0.0, 1.0 - needs.drunkenness.strength)

func loop() -> void:
	_narrative = ["Curious about the tonic...", "Thinking about a miracle cure...", "Looking for a quick pick-me-up..."].pick_random()
	salesman = _find_salesman()
	if salesman == null:
		await pause(2)
		return

	_narrative = ["Heading for the tonic table...", "Going to hear the sales pitch..."].pick_random()
	await move(salesman.get_waiting_room_position())

	if not _can_use_salesman():
		return

	request = salesman.request_sale(npc)
	if request == null:
		return

	salesman.join_queue(npc)
	_narrative = ["Waiting for the tonic...", "Listening to the pitch...", "Queued for snake oil..."].pick_random()
	while _should_wait_for_sale():
		var target_pos: Vector2 = salesman.get_queue_position(npc)
		if npc.global_position.distance_squared_to(target_pos) > 16.0:
			await move(target_pos)
		else:
			await end_of_frame()

	salesman.leave_queue(npc)

	if request == null or request.status != Enum.RequestStatus.IN_PROGRESS or not _can_use_salesman():
		return

	_narrative = ["Buying a bottle...", "Taking the tonic...", "Hearing the final pitch..."].pick_random()
	await move(salesman.get_service_position())

	while request.status == Enum.RequestStatus.IN_PROGRESS and _can_use_salesman():
		await end_of_frame()

	if request.status == Enum.RequestStatus.FULFILLED:
		add_mood(MOOD_BOOST, "Snake Oil")

func stop_loop() -> BehaviourSaveData:
	if salesman != null:
		salesman.leave_queue(npc)

	if request != null and (request.status == Enum.RequestStatus.OPEN or request.status == Enum.RequestStatus.IN_PROGRESS):
		request.status = Enum.RequestStatus.TIMEOUT
		if salesman != null:
			salesman.sale_requests.erase(request)

	return super.stop_loop()

func _find_salesman():
	if Global.NPCSpawner == null:
		return null
	return Global.NPCSpawner.find_snake_oil_salesman_provider(npc)

func _can_use_salesman() -> bool:
	return salesman != null and is_instance_valid(salesman.npc) and salesman.accepts_customer(npc)

func _should_wait_for_sale() -> bool:
	return not stopped and request != null and request.status == Enum.RequestStatus.OPEN and _can_use_salesman()
