extends Node2D

@export var icon : Texture
@export var price : int
@export var module_name : String
@export var describtion : String
@export var item_cost : int
@export var max_guests : int = 0
@export var seat_positions: Array[Vector2] = []
@export var brew_duration : float = 20.0
@export var brews_per_water : int = 1
@export var effect_interval : float = 10.0
@export var satisfaction_boost : float = 0.1
@export var action_duration : float = 1.0
@export var requires_water_tower: bool = false

@export var bought: bool = false

signal bought_changed(module)

func _ready() -> void:
	visible = bought

func set_bought(value: bool) -> void:
	bought = value
	visible = value
	bought_changed.emit(self)

func is_dependency_met() -> bool:
	if not requires_water_tower:
		return true
	return Building.count_rooms_by_data(Building.room_data_water_tower) > 0

func get_unmet_dependency_text() -> String:
	if requires_water_tower:
		if is_dependency_met():
			return "([color=#48D98E]uses water tower[/color])"
		else:
			return "[color=#ff8f5a]requires water tower[/color]"
	return ""
