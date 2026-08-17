extends Control
class_name MainMenu

const GAMEPLAY_SCENE_PATH := "res://scenes/mainscene.tscn"
const CAMPAIGN_DEMO_SCENARIO_ID := "scenario_campaign_demo"

@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var sandbox_button: Button = $CenterContainer/VBoxContainer/SandboxButton
@onready var campaign_button: Button = $CenterContainer/VBoxContainer/CampaignButton
@onready var sandbox_config: SandboxConfigMenu = $SandboxConfig

func _ready() -> void:
	Building.visible = false
	continue_button.visible = SaveHandler.has_save()
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	sandbox_button.pressed.connect(_on_sandbox_pressed)
	campaign_button.pressed.connect(_on_campaign_pressed)

	sandbox_config.hide()
	sandbox_config.start_requested.connect(_on_sandbox_start_requested)

	Console.add_command("new_game", _on_new_game_pressed, 0, 0, "Starts a new default tutorial game from the main menu.")
	Console.add_command("start_scenario_from_menu", _console_start_scenario_from_menu, ["id"], 1, "Queues a scenario by id and transitions to gameplay, as if picked from the menu.")
	Console.add_command("continue_game", _on_continue_pressed, 0, 0, "Loads the existing save and transitions to gameplay, as if Continue was pressed.")

func _on_continue_pressed() -> void:
	if not SaveHandler.has_save():
		return
	ScenarioHandler.queue_scenario(null)
	SaveHandler.flag_pending_load()
	_go_to_gameplay()

func _on_new_game_pressed() -> void:
	ScenarioHandler.queue_scenario(null)
	_go_to_gameplay()

func _on_sandbox_pressed() -> void:
	sandbox_config.show()

func _on_campaign_pressed() -> void:
	ScenarioHandler.queue_scenario(ScenarioHandler.get_scenario(CAMPAIGN_DEMO_SCENARIO_ID))
	_go_to_gameplay()

func _on_sandbox_start_requested(scenario: ScenarioData) -> void:
	ScenarioHandler.queue_scenario(scenario)
	_go_to_gameplay()

func _console_start_scenario_from_menu(id: String) -> void:
	var scenario := ScenarioHandler.get_scenario(id)
	if scenario == null:
		Console.print_error("Unknown scenario id '%s'." % id)
		return
	ScenarioHandler.queue_scenario(scenario)
	_go_to_gameplay()

func _go_to_gameplay() -> void:
	get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)
