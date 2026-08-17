extends Control
class_name UICampaignWon

@onready var _title_label: Label = $MarginContainer/MarginContainer/GridContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/MarginContainer/GridContainer/DescriptionLabel
@onready var _keep_playing_button: Button = $MarginContainer/MarginContainer/GridContainer/ButtonRow/KeepPlayingButton
@onready var _leave_button: Button = $MarginContainer/MarginContainer/GridContainer/ButtonRow/LeaveButton

const MAIN_MENU_SCENE_PATH := "res://scenes/mainmenuscene.tscn"


func _ready() -> void:
	hide()
	ScenarioHandler.scenario_won_signal.connect(_on_scenario_won)
	_keep_playing_button.pressed.connect(_on_keep_playing_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)


func _on_scenario_won() -> void:
	var scenario := ScenarioHandler.get_current_scenario()
	_title_label.text = "Campaign Complete!"
	_description_label.text = "\"%s\" is solved. Keep playing this save freely, or leave for the main menu." % (scenario.display_name if scenario != null else "Campaign")
	show()


func _on_keep_playing_pressed() -> void:
	hide()


func _on_leave_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
