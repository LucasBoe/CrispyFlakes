extends Resource
class_name InfrastructureData

@export var room_name: String
@export var room_desc: String
@export var room_icon: Texture2D
@export var room_preview: Texture2D
@export var construction_price: int = -1
@export var tier: int = 0
@export var width: int = 1
@export var height: int = 1
@export var layer_name: StringName = &""

func get_display_icon() -> Texture2D:
	return room_icon if room_icon != null else room_preview

@export var has_consumed_item: bool = false
@export var produces_item: bool = false
@export var produces_money: bool = false
