extends Node2D

@export var icon : Texture
@export var price : int
@export var module_name : String
@export var describtion : String
@export var item_cost : int
@export var max_guests : int = 0
@export var seat_positions: Array[Vector2] = []
@export var brew_duration : float = 20.0
@export var effect_interval : float = 10.0
@export var satisfaction_boost : float = 0.1
@export var action_duration : float = 1.0

@export var bought: bool = false

signal bought_changed(module)

func _ready() -> void:
	visible = bought

func set_bought(value: bool) -> void:
	bought = value
	visible = value
	bought_changed.emit(self)
