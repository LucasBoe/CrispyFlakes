extends Behaviour
class_name ScientistBeerQuestBehaviour

const ELECTRICITY_I_PROGRESSION := preload("res://assets/resources/progression/prog_group_electricity_I.tres")

const QUEST_TITLE := "For Science!"
const QUEST_TARGET_BARRELS := 100
const BARREL_CONSUME_DURATION := 3.0
const QUEST_REWARD_TEXT := "Unlocks Electricity I."

var quest = null
var consumed_barrels := 0

static func can_offer_encounter() -> bool:
	if ProgressionHandler.is_item_unlocked(ELECTRICITY_I_PROGRESSION):
		return false
	return TutorialHandler.get_quest(QUEST_TITLE) == null

func start_loop() -> void:
	quest = _ensure_quest()
	consumed_barrels = int(quest.metadata.get("barrels_consumed", 0))

func loop() -> void:
	while not stopped and is_instance_valid(npc) and consumed_barrels < QUEST_TARGET_BARRELS:
		var source := _find_next_barrel_source()
		if source.is_empty():
			_narrative = ["Waiting for more beer...", "Needs another barrel...", "Still missing experimental fuel..."].pick_random()
			await pause(1.0)
			continue

		var barrel := await _take_barrel_from_source(source)
		if stopped or not is_instance_valid(npc):
			return
		if barrel == null or not is_instance_valid(barrel):
			await end_of_frame()
			continue

		_narrative = ["Consuming a beer barrel...", "Conducting liquid science...", "Testing another sample..."].pick_random()
		await progress(BARREL_CONSUME_DURATION)

		if stopped or not is_instance_valid(npc):
			return

		_destroy_barrel(barrel)
		_register_consumed_barrel()

	_complete_quest()
	await _leave()

func stop_loop() -> BehaviourSaveData:
	if npc.Item.current_item != null:
		npc.Item.drop_current()
	return super.stop_loop()

func _ensure_quest():
	var existing = TutorialHandler.get_quest(QUEST_TITLE)
	if existing != null:
		TutorialHandler.set_quest_reward(existing, 0, QUEST_REWARD_TEXT)
		TutorialHandler.set_quest_reward_effects(existing, [Callable(ProgressionHandler, "force_unlock").bind(ELECTRICITY_I_PROGRESSION)])
		TutorialHandler.activate_quest(existing)
		existing.metadata["barrels_consumed"] = int(existing.metadata.get("barrels_consumed", 0))
		existing.set_text(_get_quest_text(int(existing.metadata.get("barrels_consumed", 0))))
		return existing

	var created = TutorialHandler.create_quest(
		QUEST_TITLE,
		_get_quest_text(0),
		[
			"The scientist drinks loose Beer Barrels first.",
			"He also takes Beer Barrels straight out of storage.",
		],
		0,
		QUEST_REWARD_TEXT,
		TutorialHandler.TutorialPhase.HIDDEN
	)
	created.metadata["barrels_consumed"] = 0
	TutorialHandler.set_quest_reward_effects(created, [Callable(ProgressionHandler, "force_unlock").bind(ELECTRICITY_I_PROGRESSION)])
	TutorialHandler.activate_quest(created)
	return created

func _find_next_barrel_source() -> Dictionary:
	var best_source := {}
	var best_distance := INF

	var loose_barrel := LooseItemHandler.get_closest_to(npc.global_position, Enum.Items.BEER_BARREL) as Item
	if is_instance_valid(loose_barrel):
		best_source = {
			"type": "loose",
			"item": loose_barrel,
		}
		best_distance = npc.global_position.distance_squared_to(loose_barrel.global_position)

	for storage: RoomStorageBase in get_all_rooms_of_type_ordered_by_distance(RoomStorageBase):
		if not is_instance_valid(storage) or not storage.has(Enum.Items.BEER_BARREL):
			continue

		var storage_distance := npc.global_position.distance_squared_to(storage.get_center_floor_position())
		if storage_distance < best_distance:
			best_source = {
				"type": "storage",
				"storage": storage,
			}
			best_distance = storage_distance
		break

	return best_source

func _take_barrel_from_source(source: Dictionary) -> Item:
	var source_type := str(source.get("type", ""))
	if source_type == "loose":
		var loose_barrel := source.get("item") as Item
		if not is_instance_valid(loose_barrel):
			return null
		_narrative = ["Heading for a loose barrel...", "Spotted an unattended barrel...", "Making for the nearest beer..."].pick_random()
		await move(loose_barrel)
		if not is_instance_valid(loose_barrel):
			return null
		npc.Item.pick_up(loose_barrel)
		return loose_barrel

	if source_type == "storage":
		var storage := source.get("storage") as RoomStorageBase
		if not is_instance_valid(storage):
			return null
		_narrative = ["Raiding the stockpile...", "Inspecting the beer reserves...", "Helping himself to storage barrels..."].pick_random()
		await move(storage.get_center_floor_position())
		if not is_instance_valid(storage):
			return null
		var stored_barrel := storage.take(Enum.Items.BEER_BARREL)
		if stored_barrel == null:
			return null
		npc.Item.pick_up(stored_barrel)
		return stored_barrel

	return null

func _destroy_barrel(barrel: Item) -> void:
	if barrel == null:
		return

	var consumed_barrel := barrel
	if npc.Item.current_item == barrel:
		consumed_barrel = npc.Item.drop_current()
	if consumed_barrel != null:
		consumed_barrel.destroy()

func _register_consumed_barrel() -> void:
	consumed_barrels = mini(consumed_barrels + 1, QUEST_TARGET_BARRELS)
	if quest != null:
		quest.metadata["barrels_consumed"] = consumed_barrels
		quest.set_text(_get_quest_text(consumed_barrels))
		if consumed_barrels >= QUEST_TARGET_BARRELS:
			quest.set_done()
	say(_get_barrel_comment())

func _get_barrel_comment() -> String:
	var ratio := float(consumed_barrels) / QUEST_TARGET_BARRELS
	if ratio < 0.1:
		return ["Sample logged.", "Fermentation index nominal.", "Ph balance recorded.", "Data looks clean."].pick_random()
	elif ratio < 0.25:
		return ["Slightly... off-nominal data.", "Hic. Noting that down.", "Results seem warmer than expected.", "Odd aftertaste. Logging it."].pick_random()
	elif ratio < 0.5:
		return ["Fasscinating resullts!", "Thiss iss pure science!", "The data ish converging!", "Hic. Ssomething iss working!"].pick_random()
	elif ratio < 0.75:
		return ["Sscience! Hic!", "More beeeer for reseearch!", "I am hic researchhing!", "The truth iss in the barrel!"].pick_random()
	else:
		return ["I am... sscience... hic!", "Beeeer makess you ssmarter! Hic!", "Hiccc... more... data...", "Ssciennnce! Hic hic!"].pick_random()

func _complete_quest() -> void:
	if quest != null and TutorialHandler.has_quest(quest):
		quest.metadata["barrels_consumed"] = consumed_barrels
		quest.set_text(_get_quest_text(consumed_barrels))
		quest.set_done(consumed_barrels >= QUEST_TARGET_BARRELS)

func _leave() -> void:
	_narrative = ["Packing up the notes...", "Satisfied with the experiment...", "Leaving with a head full of theories..."].pick_random()
	await move(Global.LEAVE_POSITION)
	if is_instance_valid(npc):
		npc.destroy()

func _get_quest_text(progress: int) -> String:
	return "Deliver 100 Beer Barrels to the Scientist (%d/%d)" % [progress, QUEST_TARGET_BARRELS]
