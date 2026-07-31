extends Behaviour
class_name BarberSurgeonTemperatureQuestBehaviour

const FIREPLACE_ROOM_DATA := preload("res://assets/resources/rooms/room_fireplace.tres")
const QUESTION_MARK_TEXTURE := preload("res://assets/sprites/ui/question_mark.png")
const GOLDEN_GLOW_SHADER := preload("res://assets/shaders/golden_glow_red_replace.gdshader")
const LEGACY_QUEST_TITLE := "Winter Is Coming"
const PREPARE_QUEST_TITLE := "Snow from the North"
const HEAT_QUEST_TITLE := "Heat Out the Cold"
const QUEST_REWARD := 10
const QUEST_CHECK_INTERVAL := 2.0
const MARKER_OFFSET := Vector2(0, -26)
const MARKER_HOVER_HEIGHT := 1.0
const MARKER_HOVER_SPEED := 6.0

enum QuestPhase {
	OPEN_FORECAST,
	BUILD_FIREPLACES,
	AWAIT_HEAT_INTRO,
	WAIT_FOR_WINTER,
	LIGHT_FIRES,
}

var _prepare_quest = null
var _heat_quest = null
var _quest_phase: QuestPhase = QuestPhase.OPEN_FORECAST
var _heat_intro_requested := false
var _heat_intro_marker = null
var _heat_intro_marker_material: ShaderMaterial
var _heat_intro_marker_base_offset := MARKER_OFFSET

func start_loop() -> void:
	_migrate_legacy_quest()
	_ensure_quests()
	_quest_phase = _resolve_phase()
	_sync_forecast_prompt()
	_update_quest_texts()

func loop() -> void:
	while not stopped and is_instance_valid(npc):
		match _quest_phase:
			QuestPhase.OPEN_FORECAST:
				await _handle_open_forecast_phase()
			QuestPhase.BUILD_FIREPLACES:
				await _handle_build_fireplaces_phase()
			QuestPhase.AWAIT_HEAT_INTRO:
				await _handle_await_heat_intro_phase()
			QuestPhase.WAIT_FOR_WINTER:
				await _handle_wait_for_winter_phase()
			QuestPhase.LIGHT_FIRES:
				if await _handle_light_fires_phase():
					return

func stop_loop() -> BehaviourSaveData:
	if Global.UI != null and Global.UI.temperature_forecast != null:
		Global.UI.temperature_forecast.clear_tutorial_foldout_prompt()
	if Global.UI != null and Global.UI.menu != null and Global.UI.menu.build_tab != null:
		Global.UI.menu.build_tab.clear_tutorial_buildable_prompt()
	HoverHandler.remove_click_interceptor(_try_intercept_heat_intro_click)
	_clear_heat_intro_marker()
	return super.stop_loop()

func _handle_open_forecast_phase() -> void:
	_sync_forecast_prompt()
	if _has_opened_forecast():
		if _get_fireplace_count() > 0:
			_complete_prepare_quest()
		else:
			_advance_to_phase(QuestPhase.BUILD_FIREPLACES)
		return

	_narrative = [
		"Open the forecast first...",
		"Look at the weather board...",
		"You need to see what's coming...",
	].pick_random()
	_update_quest_texts()
	await pause(QUEST_CHECK_INTERVAL)

func _handle_build_fireplaces_phase() -> void:
	if _get_fireplace_count() > 0:
		_complete_prepare_quest()
		return

	_narrative = [
		"You'll want a fireplace ready...",
		"Build a hearth before winter...",
		"One fireplace is better than none...",
	].pick_random()
	_update_quest_texts()
	await pause(QUEST_CHECK_INTERVAL)

func _handle_await_heat_intro_phase() -> void:
	if _has_heat_intro_started():
		_advance_to_phase(QuestPhase.LIGHT_FIRES if _is_winter() else QuestPhase.WAIT_FOR_WINTER)
		return

	if not _is_heat_intro_time():
		HoverHandler.remove_click_interceptor(_try_intercept_heat_intro_click)
		_clear_heat_intro_marker()
		_narrative = [
			"The cold is still a little way off...",
			"Not yet. Watch the forecast...",
			"We still have a little time before winter...",
		].pick_random()
		_update_quest_texts()
		await pause(QUEST_CHECK_INTERVAL)
		return

	_narrative = [
		"The cold front is nearly here...",
		"It's time for one last warning...",
		"Winter is almost at your door...",
	].pick_random()
	HoverHandler.remove_click_interceptor(_try_intercept_heat_intro_click)
	HoverHandler.add_click_interceptor(_try_intercept_heat_intro_click)
	_create_heat_intro_marker()
	while not stopped and is_instance_valid(npc):
		_refresh_heat_intro_marker_hover()
		if _heat_intro_requested:
			break
		await end_of_frame()

	HoverHandler.remove_click_interceptor(_try_intercept_heat_intro_click)
	_clear_heat_intro_marker()
	if stopped or not is_instance_valid(npc):
		return
	if not _heat_intro_requested:
		return

	_heat_intro_requested = false
	await _show_heat_intro_dialogue()
	_activate_heat_quest()

func _handle_wait_for_winter_phase() -> void:
	if _is_winter():
		_advance_to_phase(QuestPhase.LIGHT_FIRES)
		return

	_narrative = [
		"Still warm. Good. Prepare now.",
		"Use the summer while you've got it.",
		"The cold hasn't reached you yet...",
	].pick_random()
	_update_quest_texts()
	await pause(QUEST_CHECK_INTERVAL)

func _handle_light_fires_phase() -> bool:
	if _is_winter() and _all_fireplaces_burning():
		_complete_heat_quest()
		await _leave()
		return true

	_narrative = _get_winter_narrative()
	_update_quest_texts()
	await pause(QUEST_CHECK_INTERVAL)
	return false

func _migrate_legacy_quest() -> void:
	var legacy_quest = TutorialHandler.get_quest(LEGACY_QUEST_TITLE)
	if legacy_quest != null:
		TutorialHandler.mark_quest_done(legacy_quest)

func _ensure_quests() -> void:
	_prepare_quest = TutorialHandler.get_quest(PREPARE_QUEST_TITLE)
	_heat_quest = TutorialHandler.get_quest(HEAT_QUEST_TITLE)

	if _prepare_quest == null and _heat_quest == null:
		_prepare_quest = TutorialHandler.create_quest(
			PREPARE_QUEST_TITLE,
			"",
			_get_prepare_hints(),
			QUEST_REWARD,
			"",
			TutorialHandler.TutorialPhase.HIDDEN
		)
		_heat_quest = TutorialHandler.create_quest(
			HEAT_QUEST_TITLE,
			"",
			_get_heat_hints(),
			QUEST_REWARD,
			"",
			TutorialHandler.TutorialPhase.HIDDEN
		)
		_heat_quest.metadata["intro_started"] = false
		TutorialHandler.activate_quest(_prepare_quest)
	elif _prepare_quest != null:
		TutorialHandler.set_quest_reward(_prepare_quest, QUEST_REWARD)
		_prepare_quest.hints = _get_prepare_hints()
		if _heat_quest == null:
			_heat_quest = TutorialHandler.create_quest(
				HEAT_QUEST_TITLE,
				"",
				_get_heat_hints(),
				QUEST_REWARD,
				"",
				TutorialHandler.TutorialPhase.HIDDEN
			)
			_heat_quest.metadata["intro_started"] = false
		else:
			TutorialHandler.set_quest_reward(_heat_quest, QUEST_REWARD)
			_heat_quest.hints = _get_heat_hints()
			_heat_quest.metadata["intro_started"] = bool(_heat_quest.metadata.get("intro_started", false))
		if _prepare_quest.phase != TutorialHandler.TutorialPhase.COMPLETED:
			TutorialHandler.activate_quest(_prepare_quest)
	else:
		if _heat_quest == null:
			_heat_quest = TutorialHandler.create_quest(
				HEAT_QUEST_TITLE,
				"",
				_get_heat_hints(),
				QUEST_REWARD,
				"",
				TutorialHandler.TutorialPhase.HIDDEN
			)
			_heat_quest.metadata["intro_started"] = false
		TutorialHandler.set_quest_reward(_heat_quest, QUEST_REWARD)
		_heat_quest.hints = _get_heat_hints()
		_heat_quest.metadata["intro_started"] = bool(_heat_quest.metadata.get("intro_started", false))
		if _has_heat_intro_started() and _heat_quest.phase != TutorialHandler.TutorialPhase.COMPLETED:
			TutorialHandler.activate_quest(_heat_quest)

func _resolve_phase() -> QuestPhase:
	if _prepare_quest != null and TutorialHandler.has_quest(_prepare_quest):
		if _prepare_quest.phase != TutorialHandler.TutorialPhase.COMPLETED:
			if not _has_opened_forecast():
				return QuestPhase.OPEN_FORECAST
			return QuestPhase.BUILD_FIREPLACES
	if not _has_heat_intro_started():
		return QuestPhase.AWAIT_HEAT_INTRO
	if _is_winter():
		return QuestPhase.LIGHT_FIRES
	return QuestPhase.WAIT_FOR_WINTER

func _advance_to_phase(next_phase: QuestPhase) -> void:
	_quest_phase = next_phase
	_sync_forecast_prompt()
	_update_quest_texts()

func _update_quest_texts() -> void:
	if _prepare_quest != null and TutorialHandler.has_quest(_prepare_quest):
		_prepare_quest.hints = _get_prepare_hints()
		_prepare_quest.set_text(_get_prepare_quest_text())
	if _heat_quest != null and TutorialHandler.has_quest(_heat_quest):
		_heat_quest.hints = _get_heat_hints()
		_heat_quest.set_text(_get_heat_quest_text())

func _get_prepare_hints() -> Array[String]:
	return [
		"View forecast",
		"Find Fireplace in build menu",
		"Build a fireplace",
	]

func _get_heat_hints() -> Array[String]:
	return [
		"Wait for Winter",
		"Light all Fires",
	]

func _get_prepare_quest_text() -> String:
	return "Build a fireplace (%d/1)" % mini(_get_fireplace_count(), 1)

func _get_heat_quest_text() -> String:
	var target_count := _get_heat_target_count()
	return "Heat Out the Cold (%d/%d)" % [
		mini(_get_burning_fireplace_count(), target_count),
		target_count,
	]

func _sync_forecast_prompt() -> void:
	if Global.UI == null or Global.UI.temperature_forecast == null:
		pass
	else:
		if _quest_phase == QuestPhase.OPEN_FORECAST:
			Global.UI.temperature_forecast.request_tutorial_foldout_prompt()
		else:
			Global.UI.temperature_forecast.clear_tutorial_foldout_prompt()
	if Global.UI == null or Global.UI.menu == null or Global.UI.menu.build_tab == null:
		return
	if _quest_phase == QuestPhase.OPEN_FORECAST:
		Global.UI.menu.build_tab.clear_tutorial_buildable_prompt()
	elif _quest_phase == QuestPhase.BUILD_FIREPLACES:
		Global.UI.menu.build_tab.request_tutorial_buildable_prompt(FIREPLACE_ROOM_DATA)
	else:
		Global.UI.menu.build_tab.clear_tutorial_buildable_prompt()

func _has_opened_forecast() -> bool:
	return Global.UI != null \
		and Global.UI.temperature_forecast != null \
		and Global.UI.temperature_forecast.has_unlocked_forecast() \
		and Global.UI.temperature_forecast.is_expanded()

func _get_fireplace_count() -> int:
	if not is_instance_valid(Building):
		return 0
	return Building.query.all_rooms_of_type(RoomFireplace).size()

func _get_burning_fireplace_count() -> int:
	if not is_instance_valid(Building):
		return 0
	var burning := 0
	for fireplace: RoomFireplace in Building.query.all_rooms_of_type(RoomFireplace):
		if is_instance_valid(fireplace) and fireplace.is_heating():
			burning += 1
	return burning

func _all_fireplaces_burning() -> bool:
	var fireplace_count := _get_fireplace_count()
	return fireplace_count > 0 and _get_burning_fireplace_count() == fireplace_count

func _get_heat_target_count() -> int:
	return maxi(1, _get_fireplace_count())

func _has_heat_intro_started() -> bool:
	if _heat_quest == null:
		return false
	return bool(_heat_quest.metadata.get("intro_started", false))

func _is_heat_intro_time() -> bool:
	if _is_winter():
		return true
	var forecast := TemperatureHandler.get_forecast_temperatures()
	var tomorrow_index := TemperatureHandler.get_forecast_center_index() + 1
	if tomorrow_index < 0 or tomorrow_index >= forecast.size():
		return false
	return TemperatureHandler.is_cold(float(forecast[tomorrow_index]))

func _is_winter() -> bool:
	return TemperatureHandler.is_cold(TemperatureHandler.get_outdoor_temperature())

func _get_winter_narrative() -> String:
	if not _is_winter():
		return [
			"Still warm. Good. Prepare now.",
			"Use the summer while you've got it.",
			"The cold hasn't reached you yet...",
		].pick_random()
	if _all_fireplaces_burning():
		return [
			"That's it. Keep them alive...",
			"Good. Now hold the line...",
			"The hearths are doing their job...",
		].pick_random()
	return [
		"Winter's here. Light every hearth.",
		"Now. Every fireplace burning.",
		"This is the weather I warned you about...",
	].pick_random()

func _complete_prepare_quest() -> void:
	if _prepare_quest == null or not TutorialHandler.has_quest(_prepare_quest):
		return
	_prepare_quest.set_done()
	if _heat_quest == null or not TutorialHandler.has_quest(_heat_quest):
		_heat_quest = TutorialHandler.create_quest(
			HEAT_QUEST_TITLE,
			"",
			_get_heat_hints(),
			QUEST_REWARD,
			"",
			TutorialHandler.TutorialPhase.HIDDEN
		)
	TutorialHandler.set_quest_reward(_heat_quest, QUEST_REWARD)
	_heat_quest.hints = _get_heat_hints()
	_heat_quest.metadata["intro_started"] = false
	_advance_to_phase(QuestPhase.AWAIT_HEAT_INTRO)

func _complete_heat_quest() -> void:
	if _heat_quest == null or not TutorialHandler.has_quest(_heat_quest):
		return
	_heat_quest.set_done()

func _activate_heat_quest() -> void:
	if _heat_quest == null or not TutorialHandler.has_quest(_heat_quest):
		return
	_heat_quest.metadata["intro_started"] = true
	TutorialHandler.activate_quest(_heat_quest)
	_advance_to_phase(QuestPhase.LIGHT_FIRES if _is_winter() else QuestPhase.WAIT_FOR_WINTER)

func _show_heat_intro_dialogue() -> void:
	if Global.UI == null or Global.UI.encounter == null or not is_instance_valid(npc):
		return
	await Global.UI.encounter.show_outcome(
		npc,
		"The next cold day is almost here. When it comes, every fireplace must be burning."
	)

func _create_heat_intro_marker() -> void:
	_clear_heat_intro_marker()
	_heat_intro_marker = UiNotifications.create_npc_action_button(
		npc,
		QUESTION_MARK_TEXTURE,
		Callable(self, "_on_heat_intro_marker_pressed"),
		true,
		MARKER_OFFSET
	)
	if _heat_intro_marker != null:
		_heat_intro_marker_base_offset = _heat_intro_marker.offset
	if _heat_intro_marker != null and _heat_intro_marker.instance is CanvasItem:
		if _heat_intro_marker_material == null:
			_heat_intro_marker_material = ShaderMaterial.new()
			_heat_intro_marker_material.shader = GOLDEN_GLOW_SHADER
		(_heat_intro_marker.instance as CanvasItem).material = _heat_intro_marker_material
	SoundPlayer.play_npc_notification()

func _on_heat_intro_marker_pressed() -> void:
	if _heat_intro_requested:
		return
	_heat_intro_requested = true
	SoundPlayer.play_npc_notification_activated()
	if _heat_intro_marker != null and _heat_intro_marker.instance is Control:
		(_heat_intro_marker.instance as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh_heat_intro_marker_hover() -> void:
	if _heat_intro_marker == null:
		return
	var phase := float(abs(npc.name.hash()) % 1000) / 1000.0 * TAU
	var t := float(Time.get_ticks_msec()) / 1000.0
	_heat_intro_marker.offset = _heat_intro_marker_base_offset + Vector2(
		0.0,
		sin(t * MARKER_HOVER_SPEED + phase) * MARKER_HOVER_HEIGHT
	)

func _try_intercept_heat_intro_click(node) -> bool:
	if stopped or not is_instance_valid(npc) or _heat_intro_requested:
		return false
	if node != npc:
		return false
	_on_heat_intro_marker_pressed()
	return true

func _clear_heat_intro_marker() -> void:
	UiNotifications.try_kill(_heat_intro_marker)
	_heat_intro_marker = null
	_heat_intro_marker_base_offset = MARKER_OFFSET

func _leave() -> void:
	say([
		"Good. Keep the hearths fed and your people might see spring.",
		"That's how you survive winter. Fire first, fear later.",
	].pick_random())
	_narrative = ["Packing away the satchel...", "Satisfied with the warmth...", "Heading back into the road..."].pick_random()
	await move(Global.LEAVE_POSITION)
	if is_instance_valid(npc):
		npc.destroy()
