class_name CampaignScenarioData
extends ScenarioData

@export var goal_definitions: Array[ScenarioGoalDefinition] = []

## RefCounted script exposing load_entries() -> Array[Dictionary], same
## _encounter()/_choice() shape as EncounterCatalog plus a "trigger_condition"
## Callable per entry. Godot resources can't hold arbitrary bound Callables in
## exported fields, so beats are authored in code, not directly in the .tres.
@export var story_beat_script: GDScript

## RefCounted script providing get_goal_conditions() -> Dictionary (goal key
## -> Callable[]->bool]), get_win_conditions() -> Array[Dictionary] and
## get_lose_conditions() -> Array[Dictionary], each entry shaped as
## {"condition": Callable, "description": String}. Kept in code for the same
## reason as story_beat_script above.
@export var conditions_script: GDScript
