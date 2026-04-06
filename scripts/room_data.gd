extends Resource
class_name RoomData

@export var packed_scene : PackedScene
@export var room_name : String
@export var room_desc : String
@export var room_upgrades = []
@export var room_icon : Texture
@export var room_preview : Texture
@export var construction_price = -1
@export var tier : int = 0
@export var is_outdoor : bool = false
@export var money_capacity : int = 100
@export var has_consumed_item : bool = false
@export var consumed_item_type : Enum.Items
@export var produces_item : bool
@export var produced_item_type : Enum.Items
@export var produced_item_name : String
