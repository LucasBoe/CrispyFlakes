extends RoomBase
class_name RoomBed

const SLEEP_DURATION := 60.0
const SLEEP_PRICE := 6

const BED_EMPTY := preload("res://assets/sprites/bed_empty_back.png")
const BED_EMPTY_DIRTY := preload("res://assets/sprites/bed_empty_back_dirty.png")
const BED_FULL := preload("res://assets/sprites/bed_full_back.png")

var current_guest: NPCGuest
var needs_cleaning := false

@onready var bed_sprite: Sprite2D = $Bed
@onready var bed_front: Sprite2D = $Bed/Bed_Front
@onready var progressBar: TextureProgressBar = $ProgressBar

func init_room(_x: int, _y: int):
	associated_job = Enum.Jobs.BED_CLEANER
	super.init_room(_x, _y)
	progressBar.visible = false
	_refresh_visual()

func is_used_by_other_then(npc: NPC) -> bool:
	return current_guest != null and current_guest != npc

func is_available_for(npc: NPC) -> bool:
	return not needs_cleaning and not is_used_by_other_then(npc)

func occupy(guest: NPCGuest):
	current_guest = guest
	_refresh_visual()
	
func get_sleep_position():
	return get_center_floor_position() + Vector2(10,-6)

func release(guest: NPCGuest):
	if current_guest != guest:
		return
	current_guest = null
	needs_cleaning = true
	_refresh_visual()

func clean_bed():
	needs_cleaning = false
	_refresh_visual()

func _refresh_visual():
	if bed_sprite == null or bed_front == null:
		return

	var occupied := current_guest != null
	if occupied:
		bed_sprite.texture = BED_FULL
	elif needs_cleaning:
		bed_sprite.texture = BED_EMPTY_DIRTY
	else:
		bed_sprite.texture = BED_EMPTY
	bed_front.visible = occupied
	bed_sprite.modulate = Color.WHITE
