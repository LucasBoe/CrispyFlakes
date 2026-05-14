extends Behaviour
class_name SpecialNPCEncounterBehaviour

const QUESTION_MARK_TEXTURE := preload("res://assets/sprites/ui/question_mark.png")

var _marker = null

func stop_loop() -> BehaviourSaveData:
	_set_waiting_for_click(false)
	_clear_marker()
	return BehaviourSaveData.new(get_script())

func loop() -> void:
	_narrative = ["Looking for the owner...", "Coming in with a proposition...", "Walking in for a word..."].pick_random()

	var target_room := _get_encounter_room()
	if target_room != null:
		await move(target_room.get_center_floor_position())

	if stopped or not is_instance_valid(npc):
		return

	var special := npc as SpecialNPC
	var encounter := special.encounter_data if special != null else {}
	if encounter.is_empty():
		encounter = EncounterCatalog.get_random_entry()
	if encounter.is_empty():
		await _leave()
		return

	if special != null:
		special.encounter_data = encounter

	_narrative = ["Waiting to talk...", "Trying to get your attention...", "Has something to say..."].pick_random()
	_set_waiting_for_click(true)
	_marker = UiNotifications.create_npc_notification(npc, QUESTION_MARK_TEXTURE, true, Vector2(0, -30))
	SoundPlayer.play_npc_notification()
	while is_instance_valid(npc) and not stopped:
		if special != null and special.consume_encounter_click_request():
			break
		await end_of_frame()
	_set_waiting_for_click(false)
	if stopped or not is_instance_valid(npc):
		return

	_narrative = ["Making an offer...", "Waiting for an answer...", "Talking business..."].pick_random()
	_clear_marker()
	SoundPlayer.play_npc_notification_activated()
	var choice: Dictionary = await Global.UI.encounter.start_encounter(npc, encounter)
	_apply_choice(encounter, choice)
	var outcome_text := str(choice.get("outcome_text", ""))
	if outcome_text != "":
		await Global.UI.encounter.show_outcome(npc, outcome_text)
	await _leave()

func _set_waiting_for_click(waiting: bool) -> void:
	if npc is SpecialNPC:
		(npc as SpecialNPC).set_waiting_for_encounter_click(waiting)

func _clear_marker() -> void:
	UiNotifications.try_kill(_marker)
	_marker = null

func _get_encounter_room() -> RoomBase:
	var saloons: Array = Building.query.all_rooms_of_type(RoomSaloon)
	if not saloons.is_empty():
		return Util.get_closest(saloons, npc.global_position) as RoomBase

	var bars: Array = Building.query.all_rooms_of_type(RoomBar)
	if not bars.is_empty():
		return Util.get_closest(bars, npc.global_position) as RoomBase

	var rooms: Array = Building.query.all_rooms_of_type(RoomBase)
	var valid: Array = []
	for room: RoomBase in rooms:
		if room != null and not room.is_outside_room and room.y == 0:
			valid.append(room)
	if valid.is_empty():
		return null
	return Util.get_closest(valid, npc.global_position) as RoomBase

func _apply_choice(encounter: Dictionary, choice: Dictionary) -> void:
	var context := EncounterCatalog.EncounterContext.new(npc as SpecialNPC, encounter, choice)
	var effects: Array = choice.get("effects", [])
	for effect: Callable in effects:
		if effect.is_valid():
			effect.call(context)

func _leave() -> void:
	_narrative = ["Heading out...", "Leaving the saloon...", "Done with business..."].pick_random()
	await move(Global.LEAVE_POSITION)
	if is_instance_valid(npc):
		npc.destroy()
