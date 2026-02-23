extends Resource
class_name RoomUpgrade

@export var upgrade_name : String
@export var upgrade_price : int
@export var upgrade_preview : Texture2D

@export var item_name : String
@export var item_cost : int
@export var item_icon : Texture2D
@export var opt_associated_item : Enum.Items
@export var room_required : RoomData
