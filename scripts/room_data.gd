extends BuildableData
class_name RoomData

@export var packed_scene: PackedScene
@export var is_outdoor: bool = false
@export var ignore_foreground_tiles: bool = false
@export var money_capacity: int = 100
@export var has_consumed_item: bool = false
@export var consumed_item_type: Enum.Items
@export var produces_item: bool
@export var produced_item_type: Enum.Items
@export var produced_item_name: String
@export var produces_money: bool = false
