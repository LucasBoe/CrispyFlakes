extends Behaviour
class_name SnakeOilSalesmanBehaviour

const NEED_SNAKE_OIL_BEHAVIOUR := preload("res://scripts/npc/behaviours/need_snake_oil_behaviour.gd")

const ACTIVE_DURATION := 60.0
const SALE_DURATION := 2.0
const TIMEOUT_MSEC := 15000
const QUEUE_SPACING := 10.0
const QUEUE_CLAMP_STEP := 4.0
const NO_SEAT_RETRY_SECONDS := 1.5
const NO_SEAT_NOTIFICATION_DURATION := 1.5

class SaleRequest:
	var status: Enum.RequestStatus = Enum.RequestStatus.OPEN
	var time: int = 0
	var customer: NPCGuest = null

var table: RoomTable = null
var sale_requests: Array[SaleRequest] = []
var waiting_queue: Array[NPCGuest] = []

func loop() -> void:
	var remaining_duration := ACTIVE_DURATION

	while not stopped and is_instance_valid(npc) and remaining_duration > 0.0:
		var seated = await _ensure_seated()
		if not seated:
			continue

		_timeout_old_requests()
		var request := _pop_invalid_request()
		if request == null:
			_narrative = ["Peddling miracle cures...", "Waiting for a gullible customer...", "Trying to make the next sale..."].pick_random()
			var wait_duration := minf(0.5, remaining_duration)
			await pause(wait_duration)
			remaining_duration -= wait_duration
			continue

		request.status = Enum.RequestStatus.IN_PROGRESS
		_narrative = ["Making the pitch...", "Selling a miracle tonic...", "Talking up the cure-all..."].pick_random()
		var sale_duration := minf(SALE_DURATION, remaining_duration)
		await progress(sale_duration)
		remaining_duration -= sale_duration

		if stopped or not is_instance_valid(npc):
			return

		if request.status != Enum.RequestStatus.IN_PROGRESS:
			continue

		request.status = Enum.RequestStatus.FULFILLED
		sale_requests.erase(request)
		await ResourceHandler.add_animated(
			Enum.Resources.MONEY,
			Pricing.ENCOUNTER_SNAKE_OIL_CUSTOMER_PAYOUT,
			npc.global_position + Vector2(0, -20)
		)

	await _leave()

func request_sale(customer: NPCGuest = null):
	if not accepts_customer(customer):
		return null

	for req: SaleRequest in sale_requests:
		if req.customer == customer and req.status != Enum.RequestStatus.TIMEOUT:
			req.time = Time.get_ticks_msec()
			return req

	var req := SaleRequest.new()
	req.time = Time.get_ticks_msec()
	req.customer = customer
	sale_requests.append(req)
	return req

func join_queue(waiting_customer: NPCGuest) -> void:
	if waiting_customer != null and not waiting_queue.has(waiting_customer):
		waiting_queue.append(waiting_customer)

func leave_queue(waiting_customer: NPCGuest) -> void:
	waiting_queue.erase(waiting_customer)

func accepts_customer(customer: NPCGuest) -> bool:
	return customer != null and is_instance_valid(customer) and _is_ready_for_customers()

func get_waiting_room_position() -> Vector2:
	if is_instance_valid(table):
		return table.get_random_floor_position()
	return npc.global_position

func get_queue_position(waiting_customer: NPCGuest) -> Vector2:
	if not is_instance_valid(table):
		return npc.global_position

	var index: int = waiting_queue.find(waiting_customer)
	if index < 0:
		return table.get_center_floor_position()

	var direction: float = table.get_preferred_horizontal_queue_direction(1.0 if table.global_position.x >= 0.0 else -1.0)
	var queue_target: Vector2 = table.get_center_floor_position() + Vector2(direction * (index + 1) * QUEUE_SPACING, 0.0)
	return _get_valid_queue_position(queue_target)

func get_service_position() -> Vector2:
	if is_instance_valid(table):
		return table.get_center_floor_position()
	return npc.global_position

func get_assigned_table() -> RoomTable:
	return table if _is_ready_for_customers() else null

func stop_loop() -> BehaviourSaveData:
	for req: SaleRequest in sale_requests:
		if req.status == Enum.RequestStatus.OPEN or req.status == Enum.RequestStatus.IN_PROGRESS:
			req.status = Enum.RequestStatus.TIMEOUT
	sale_requests.clear()
	waiting_queue.clear()
	_stand_up()
	return super.stop_loop()

func _ensure_seated():
	while not stopped and is_instance_valid(npc):
		if _is_ready_for_customers():
			return true

		table = _find_free_table()
		if table == null:
			_narrative = ["Needs a table...", "Looking for a place to sit...", "Can't sell from thin air..."].pick_random()
			UiNotifications.create_notification_dynamic("i need to sit", npc, Vector2(0, -32), null, Color.BLACK, NO_SEAT_NOTIFICATION_DURATION)
			await pause(NO_SEAT_RETRY_SECONDS)
			continue

		_narrative = ["Heading for a table...", "Setting out the tonics...", "Looking for a good selling spot..."].pick_random()
		await move(table.get_center_floor_position())

		if stopped or not is_instance_valid(npc):
			return false
		if not is_instance_valid(table) or not table.is_free():
			table = null
			await end_of_frame()
			continue

		var seat_position: Vector2 = table.sit(npc)
		table.on_seated(npc)
		npc.global_position = seat_position
		return true

	return false

func _find_free_table() -> RoomTable:
	return get_least_loaded_room_of_type(
		RoomTable,
		func(candidate: RoomTable): return candidate.is_free(),
		func(candidate: RoomTable): return candidate.max_guest_count - candidate.get_free_count(),
		func(candidate: RoomTable): return candidate.max_guest_count
	) as RoomTable

func _is_ready_for_customers() -> bool:
	return is_instance_valid(table) and table.is_guest_seated(npc)

func _timeout_old_requests() -> void:
	var now: int = Time.get_ticks_msec()
	for req: SaleRequest in sale_requests.duplicate():
		if now - req.time > TIMEOUT_MSEC:
			req.status = Enum.RequestStatus.TIMEOUT
			sale_requests.erase(req)

func _pop_invalid_request() -> SaleRequest:
	while not sale_requests.is_empty():
		var req: SaleRequest = sale_requests[0]
		if _is_request_valid(req):
			return req
		req.status = Enum.RequestStatus.TIMEOUT
		sale_requests.remove_at(0)
	return null

func _is_request_valid(req: SaleRequest) -> bool:
	if req == null or req.customer == null:
		return false
	if not is_instance_valid(req.customer):
		return false

	var behaviour := req.customer.Behaviour.behaviour_instance if req.customer.Behaviour != null else null
	if behaviour == null or behaviour.get_script() != NEED_SNAKE_OIL_BEHAVIOUR:
		return false

	if req.status == Enum.RequestStatus.IN_PROGRESS:
		return _is_ready_for_customers()

	return accepts_customer(req.customer) and waiting_queue.has(req.customer)

func _get_valid_queue_position(queue_target: Vector2) -> Vector2:
	var center: Vector2 = table.get_center_floor_position()
	var clamped_target: Vector2 = queue_target

	while true:
		var room := Building.query.room_at_position(clamped_target) as RoomBase
		if room != null and room.y == table.y and room is not RoomStairs:
			return clamped_target

		if is_equal_approx(clamped_target.x, center.x):
			return center

		clamped_target.x = move_toward(clamped_target.x, center.x, QUEUE_CLAMP_STEP)

	return center

func _stand_up() -> void:
	if _is_ready_for_customers():
		table.stand_up(npc)
		npc.global_position = table.get_center_floor_position()
	elif is_instance_valid(npc) and npc.Animator != null:
		npc.Animator.set_sitting(false)
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	table = null

func _leave() -> void:
	_stand_up()
	_narrative = ["Packing up the bottles...", "Heading to the next town...", "Moving on after the pitch..."].pick_random()
	await move(Global.LEAVE_POSITION)
	if is_instance_valid(npc):
		npc.destroy()
