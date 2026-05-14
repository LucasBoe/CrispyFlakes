extends Node

signal quests_changed
signal quest_claimed(section_title: String)

enum TutorialPhase {
	HIDDEN,
	REVEALED,
	ACTIVE,
	COMPLETED,
	DONE,
}


class TutorialQuest:
	extends RefCounted

	var _handler
	var section_title: String
	var reward_money: int
	var reward_text: String
	var phase: int
	var reveal_target: Node2D
	var text: String
	var hints: Array[String] = []
	var is_started: bool = false
	var is_done: bool = false

	func _init(handler, new_section_title: String, new_reward_money: int = 0, new_reward_text: String = "", new_phase: int = 0, new_reveal_target: Node2D = null, new_text: String = "", new_hints: Array[String] = []):
		_handler = handler
		section_title = new_section_title
		reward_money = new_reward_money
		reward_text = new_reward_text
		phase = new_phase
		reveal_target = new_reveal_target
		text = new_text
		hints = new_hints.duplicate()

	func start() -> void:
		if is_started:
			return
		is_started = true
		_handler._on_quest_state_changed(self)

	func finish() -> void:
		set_done()

	func set_done(done := true) -> void:
		var changed := not is_started or is_done != done
		var previous_phase := phase
		is_started = true
		is_done = done
		if done and phase != _handler.TutorialPhase.DONE:
			phase = _handler.TutorialPhase.COMPLETED
		elif not done and phase == _handler.TutorialPhase.COMPLETED:
			phase = _handler.TutorialPhase.ACTIVE
		if done and phase == _handler.TutorialPhase.COMPLETED and previous_phase != _handler.TutorialPhase.COMPLETED:
			SoundPlayer.play_quest_complete()
		if changed:
			_handler._on_quest_state_changed(self)

	func set_text(new_text: String) -> void:
		if text == new_text:
			return
		text = new_text
		_handler._notify_quests_changed()


var quests := {}
var quest_order: Array[String] = []


func _create_or_update_quest(section_title: String, reward_money: int = -1, reward_override_text: String = "", initial_phase: int = TutorialPhase.HIDDEN, reveal_target: Node2D = null) -> TutorialQuest:
	var quest := quests.get(section_title) as TutorialQuest
	if quest == null:
		var resolved_reward := 0 if reward_money < 0 else reward_money
		quest = TutorialQuest.new(self, section_title, resolved_reward, reward_override_text, initial_phase, reveal_target)
		quests[section_title] = quest
		quest_order.append(section_title)
		_notify_quests_changed()
		return quest

	if reward_money >= 0:
		quest.reward_money = reward_money
	if not reward_override_text.is_empty():
		quest.reward_text = reward_override_text
	if reveal_target != null:
		quest.reveal_target = reveal_target
	return quest


func ensure_quest(section_title: String, reward_money: int = -1, reward_override_text: String = "") -> TutorialQuest:
	var quest := quests.get(section_title) as TutorialQuest
	if quest == null:
		return _create_or_update_quest(section_title, reward_money, reward_override_text)

	if reward_money >= 0:
		quest.reward_money = reward_money
	if not reward_override_text.is_empty():
		quest.reward_text = reward_override_text
	return quest


func create_quest(section_title: String, text: String, hints: Array[String] = [], reward_money: int = -1, reward_override_text: String = "", initial_phase: int = TutorialPhase.HIDDEN, reveal_target: Node2D = null) -> TutorialQuest:
	var quest := _create_or_update_quest(section_title, reward_money, reward_override_text, initial_phase, reveal_target)
	quest.text = text
	quest.hints = hints.duplicate()
	_notify_quests_changed()
	return quest


func clear_quests() -> void:
	quests.clear()
	quest_order.clear()
	_notify_quests_changed()


func get_quest(section_title: String) -> TutorialQuest:
	return quests.get(section_title) as TutorialQuest


func get_quest_titles() -> Array[String]:
	return quest_order.duplicate()


func has_quest(quest: TutorialQuest) -> bool:
	return quest != null and quests.values().has(quest)


func get_sidebar_quests() -> Array:
	var visible_quests: Array = []
	for section_title in quest_order:
		var quest := get_quest(section_title)
		if quest == null:
			continue
		if quest.phase == TutorialPhase.HIDDEN or quest.phase == TutorialPhase.REVEALED or quest.phase == TutorialPhase.DONE:
			continue
		visible_quests.append(quest)
	return visible_quests


func get_revealed_quests() -> Array:
	var revealed_quests: Array = []
	for section_title in quest_order:
		var quest := get_quest(section_title)
		if quest == null:
			continue
		if quest.phase != TutorialPhase.REVEALED:
			continue
		if not is_instance_valid(quest.reveal_target):
			continue
		revealed_quests.append(quest)
	return revealed_quests


func get_current_quest() -> TutorialQuest:
	for section_title in quest_order:
		var quest := get_quest(section_title)
		if quest != null and quest.phase == TutorialPhase.ACTIVE:
			return quest

	for section_title in quest_order:
		var quest := get_quest(section_title)
		if quest != null and quest.phase == TutorialPhase.COMPLETED:
			return quest

	for section_title in quest_order:
		var quest := get_quest(section_title)
		if quest != null and quest.phase == TutorialPhase.REVEALED:
			return quest

	return null


func get_quest_reward_text(quest: TutorialQuest) -> String:
	if not has_quest(quest):
		return ""
	if not quest.reward_text.is_empty():
		return quest.reward_text
	if quest.reward_money > 0:
		return "%d $ Reward" % quest.reward_money
	return ""


func set_quest_reveal_target(quest: TutorialQuest, target: Node2D) -> void:
	if not has_quest(quest):
		return
	quest.reveal_target = target
	_notify_quests_changed()


func reveal_quest(quest: TutorialQuest) -> void:
	if not has_quest(quest) or quest.phase == TutorialPhase.DONE:
		return
	if quest.phase == TutorialPhase.REVEALED:
		return
	quest.phase = TutorialPhase.REVEALED
	SoundPlayer.play_npc_notification()
	_notify_quests_changed()


func activate_quest(quest: TutorialQuest) -> void:
	if not has_quest(quest) or quest.phase == TutorialPhase.DONE:
		return
	quest.phase = TutorialPhase.ACTIVE
	_notify_quests_changed()


func claim_quest_reward(quest: TutorialQuest, reward_source_position = null) -> void:
	if not has_quest(quest) or quest.phase != TutorialPhase.COMPLETED:
		return
	if quest.reward_money > 0:
		if reward_source_position is Vector2:
			ResourceHandler.add_animated(Enum.Resources.MONEY, quest.reward_money, reward_source_position)
		else:
			ResourceHandler.change_money(quest.reward_money)

	mark_quest_done(quest)
	quest_claimed.emit(quest.section_title)


func set_quest_reward(quest: TutorialQuest, reward_money: int, reward_override_text: String = "") -> void:
	if not has_quest(quest):
		return
	quest.reward_money = reward_money
	if not reward_override_text.is_empty():
		quest.reward_text = reward_override_text
	_notify_quests_changed()


func mark_quest_done(quest: TutorialQuest) -> void:
	if not has_quest(quest):
		return

	quest.phase = TutorialPhase.DONE
	_remove_quest(quest)
	_notify_quests_changed()


func _remove_quest(quest: TutorialQuest) -> void:
	quests.erase(quest.section_title)
	quest_order.erase(quest.section_title)


func _on_quest_state_changed(quest: TutorialQuest) -> void:
	_notify_quests_changed()


func _notify_quests_changed() -> void:
	quests_changed.emit()
