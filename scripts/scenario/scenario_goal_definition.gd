class_name ScenarioGoalDefinition
extends Resource

@export var key: String
@export var title: String
@export_multiline var text: String
@export_multiline var description: String
@export var reward_money: int
@export var reward_text: String
@export var is_required_for_win: bool = false

var completion_condition: Callable
