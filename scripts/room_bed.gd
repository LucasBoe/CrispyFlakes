extends RoomBase
class_name RoomBed

const SLEEP_DURATION := 8.0

const BED_EMPTY := preload("res://assets/sprites/bed_empty_back.png")
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
	bed_sprite.texture = BED_FULL if occupied else BED_EMPTY
	bed_front.visible = occupied
	bed_sprite.modulate = Color(0.83, 0.78, 0.72, 1.0) if needs_cleaning and not occupied else Color.WHITE
