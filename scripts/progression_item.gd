class_name ProgressionItem
extends Resource

enum ProgressionFlag {
	NONE,
	BIG_TABLES,
	BIG_BREWER,
	STABLES,
}

@export var sprite: Texture2D
@export var display_name: String
@export var cost: int

## Optional: global flag set to true when this item is unlocked
@export var unlocks_flag: ProgressionFlag = ProgressionFlag.NONE

## Optional: room type that becomes buildable when this item is unlocked
@export var unlocks_room: RoomData

## Optional: infrastructure type that becomes buildable when this item is unlocked
@export var unlocks_infrastructure: InfrastructureData

## Optional: item that must be unlocked before this one is available
@export var depends_on: ProgressionItem
