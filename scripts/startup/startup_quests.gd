extends RefCounted
class_name StartupQuests

const QUEST_KEY_CLEANUP := &"cleanup"
const QUEST_KEY_BUILD_BAR := &"build_bar"
const QUEST_KEY_SERVE_GUESTS := &"serve_guests"
const QUEST_KEY_BUILD_TABLE := &"build_table"

const CLEANUP_TUTORIAL_TITLE := "What a shithole"
const BUILD_BAR_TUTORIAL_TITLE := "This place needs a Bar"
const SERVE_GUESTS_TUTORIAL_TITLE := "A new Beginning"
const BUILD_TABLE_TUTORIAL_TITLE := "I have nowhere to sit"

const CLEANUP_TASK_TEXT := "Clean Up the Mess"
const BUILD_BAR_TASK_TEXT := "Run your first Bar"
const BUILD_TABLE_TASK_TEXT := "Build a Table"
const CLEANUP_REWARD := 10
const BUILD_BAR_REWARD := 10
const SERVE_GUESTS_REWARD := 10
const BUILD_TABLE_REWARD := 10
const SERVE_GUESTS_TARGET := 3
const BUILD_TABLE_TRIGGER_SERVED_GUEST_COUNT := 4

const CLEANUP_REWARD_TEXT := "10 $ Reward"
const BUILD_BAR_REWARD_TEXT := "10 $ Reward"
const SERVE_GUESTS_REWARD_TEXT := "10 $ Reward"
const BUILD_TABLE_REWARD_TEXT := "10 $ Reward"

class QuestDefinition:
	extends RefCounted

	var key: StringName
	var title: String
	var text: String
	var hints: Array[String]
	var reward_money: int
	var reward_text: String

	func _init(
		new_key: StringName,
		new_title: String,
		new_text: String,
		new_hints: Array[String],
		new_reward_money: int,
		new_reward_text: String
	) -> void:
		key = new_key
		title = new_title
		text = new_text
		hints = new_hints.duplicate()
		reward_money = new_reward_money
		reward_text = new_reward_text

var cleanup
var build_bar
var serve_guests
var build_table
var by_key := {}


func _init(cleanup_room_count: int) -> void:
	TutorialHandler.clear_quests()

	for definition in _build_definitions(cleanup_room_count):
		_register_definition(definition)

	cleanup = by_key.get(QUEST_KEY_CLEANUP)
	build_bar = by_key.get(QUEST_KEY_BUILD_BAR)
	serve_guests = by_key.get(QUEST_KEY_SERVE_GUESTS)
	build_table = by_key.get(QUEST_KEY_BUILD_TABLE)


func _build_definitions(cleanup_room_count: int) -> Array[QuestDefinition]:
	return [
		QuestDefinition.new(
			QUEST_KEY_CLEANUP,
			CLEANUP_TUTORIAL_TITLE,
			cleanup_text(0, cleanup_room_count),
			_cleanup_hints(),
			CLEANUP_REWARD,
			CLEANUP_REWARD_TEXT
		),
		QuestDefinition.new(
			QUEST_KEY_BUILD_BAR,
			BUILD_BAR_TUTORIAL_TITLE,
			BUILD_BAR_TASK_TEXT,
			_build_bar_hints(),
			BUILD_BAR_REWARD,
			BUILD_BAR_REWARD_TEXT
		),
		QuestDefinition.new(
			QUEST_KEY_SERVE_GUESTS,
			SERVE_GUESTS_TUTORIAL_TITLE,
			serve_guests_text(0, SERVE_GUESTS_TARGET),
			_serve_guests_hints(),
			SERVE_GUESTS_REWARD,
			SERVE_GUESTS_REWARD_TEXT
		),
		QuestDefinition.new(
			QUEST_KEY_BUILD_TABLE,
			BUILD_TABLE_TUTORIAL_TITLE,
			BUILD_TABLE_TASK_TEXT,
			_build_table_hints(),
			BUILD_TABLE_REWARD,
			BUILD_TABLE_REWARD_TEXT
		),
	]


func _register_definition(definition: QuestDefinition) -> void:
	by_key[definition.key] = TutorialHandler.create_quest(
		definition.title,
		definition.text,
		definition.hints,
		definition.reward_money,
		definition.reward_text,
		TutorialHandler.TutorialPhase.HIDDEN
	)


static func _cleanup_hints() -> Array[String]:
	return [
		"Click and hold the worker",
		"Move it onto the junk to assign them for cleanup",
	]


static func _build_bar_hints() -> Array[String]:
	return [
		"Pick the bar from build menu",
		"Place the bar in an empty room",
		"Asign a worker onto the bar",
	]


static func _serve_guests_hints() -> Array[String]:
	return [
		str("Wait until ", SERVE_GUESTS_TARGET, " guests have had a drink")
	]


static func _build_table_hints() -> Array[String]:
	return [
		"Open the build menu",
		"Place table",
	]


static func cleanup_text(amount_done: int, amount_needed: int) -> String:
	return "%s (%d/%d)" % [CLEANUP_TASK_TEXT, amount_done, amount_needed]


static func serve_guests_text(amount_done: int, amount_needed: int) -> String:
	return "Serve %d Guests (%d/%d)" % [amount_needed, amount_done, amount_needed]
