extends Behaviour
class_name JobDoctorBehaviour

const TREAT_DURATION := 8.0
const WARD_HEAL_AMOUNT := 0.06
const WARD_VISIT_PAUSE := 1.5

static var occupied_infirmaries: Array = []

var room: RoomInfirmary

func start_loop() -> void:
	room = try_get_room_if_not_occupied(data, RoomInfirmary, occupied_infirmaries)

func loop() -> void:
	while true:
		npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)
		await move(room.get_center_floor_position())

		if room.treatment_requests.is_empty():
			await _do_ward_rounds()
			continue

		room.start_next_treatment()
		_narrative = ["Treating patient...", "Applying treatment...", "Working their magic..."].pick_random()
		await progress(TREAT_DURATION)

		var request := room.fulfill_next_request(npc.Traits.get_treatment_quality())
		if request != null and is_instance_valid(request.patient):
			InjuryHandler.apply_treatment(request.patient, request.treatment_quality, room)

func _do_ward_rounds() -> void:
	var wards: Array = get_all_rooms_of_type_ordered_by_distance(RoomSickWard)

	if wards.is_empty():
		_narrative = ["On call...", "Waiting for patients...", "Ready to treat..."].pick_random()
		await pause(1)
		return

	for ward_base in wards:
		var ward: RoomSickWard = ward_base as RoomSickWard
		for guest: NPCGuest in ward.current_guests.duplicate():
			if not room.treatment_requests.is_empty():
				return
			if not is_instance_valid(guest):
				continue
			_narrative = ["Doing rounds...", "Checking on patients...", "Making their rounds..."].pick_random()
			await move(ward.get_bed_position_for(guest))
			if is_instance_valid(guest):
				guest.energy = minf(guest.energy + WARD_HEAL_AMOUNT, guest.get_max_energy())
			await pause(WARD_VISIT_PAUSE)

func stop_loop() -> BehaviourSaveData:
	occupied_infirmaries.erase(room)
	if is_instance_valid(room):
		room.worker = null
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	var _data := BehaviourSaveData.new(get_script())
	_data.room = room
	return _data
