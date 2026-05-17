extends Behaviour
class_name SpecialNPCEncounterBehaviour

const QUESTION_MARK_TEXTURE := preload("res://assets/sprites/ui/question_mark.png")
const GOLDEN_GLOW_SHADER := preload("res://assets/shaders/golden_glow_red_replace.gdshader")
const MARKER_OFFSET := Vector2(0, -26)
const MARKER_HOVER_HEIGHT := 1.0
const MARKER_HOVER_SPEED := 6.0

var _marker = null
var _interaction_requested := false
var _marker_material: ShaderMaterial
var _marker_base_offset := MARKER_OFFSET

func stop_loop() -> BehaviourSaveData:
	HoverHandler.remove_click_interceptor(_try_intercept_world_click)
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
	_interaction_requested = false
	HoverHandler.remove_click_interceptor(_try_intercept_world_click)
	HoverHandler.add_click_interceptor(_try_intercept_world_click)
	_create_marker()
	while is_instance_valid(npc) and not stopped:
		_refresh_marker_hover()
		if _interaction_requested:
			break
		await end_of_frame()
	HoverHandler.remove_click_interceptor(_try_intercept_world_click)
	if stopped or not is_instance_valid(npc):
		return

	_narrative = ["Making an offer...", "Waiting for an answer...", "Talking business..."].pick_random()
	_clear_marker()
	var choice: Dictionary = await Global.UI.encounter.start_encounter(npc, encounter)
	_apply_choice(encounter, choice)
	var outcome_text := str(choice.get("outcome_text", ""))
	if outcome_text != "":
		await Global.UI.encounter.show_outcome(npc, outcome_text)
	else:
		Global.UI.encounter.close_encounter()
	await _leave()

func _create_marker() -> void:
	_clear_marker()
	_marker = UiNotifications.create_npc_action_button(
		npc,
		QUESTION_MARK_TEXTURE,
		Callable(self, "_on_marker_pressed"),
		true,
		MARKER_OFFSET
	)
	if _marker != null:
		_marker_base_offset = _marker.offset
	if _marker != null and _marker.instance is CanvasItem:
		if _marker_material == null:
			_marker_material = ShaderMaterial.new()
			_marker_material.shader = GOLDEN_GLOW_SHADER
		(_marker.instance as CanvasItem).material = _marker_material
	SoundPlayer.play_npc_notification()


func _on_marker_pressed() -> void:
	if _interaction_requested:
		return
	_interaction_requested = true
	SoundPlayer.play_npc_notification_activated()
	if _marker != null and _marker.instance is Control:
		(_marker.instance as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh_marker_hover() -> void:
	if _marker == null:
		return
	var phase := float(abs(npc.name.hash()) % 1000) / 1000.0 * TAU
	var t := float(Time.get_ticks_msec()) / 1000.0
	_marker.offset = _marker_base_offset + Vector2(0.0, sin(t * MARKER_HOVER_SPEED + phase) * MARKER_HOVER_HEIGHT)


func _try_intercept_world_click(node) -> bool:
	if stopped or not is_instance_valid(npc):
		return false
	if _interaction_requested:
		return false
	if node != npc:
		return false
	_on_marker_pressed()
	return true

func _clear_marker() -> void:
	UiNotifications.try_kill(_marker)
	_marker = null
	_marker_base_offset = MARKER_OFFSET

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
