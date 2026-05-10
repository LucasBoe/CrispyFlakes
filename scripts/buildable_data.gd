extends Resource
class_name BuildableData

@export var room_name: String
@export var room_type: Enum.RoomType = Enum.RoomType.INFRASTRUCTURE
@export var room_desc: String
@export var room_icon: Texture2D
@export var room_preview: Texture2D
@export var construction_price: int = -1
@export var tier: int = 0
@export var width: int = 1
@export var height: int = 1

func get_display_icon() -> Texture2D:
	return room_icon if room_icon != null else room_preview
