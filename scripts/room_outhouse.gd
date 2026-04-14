extends RoomOutsideBase
class_name RoomOuthouse

@onready var outhouse_sprite = $Outhouse

const FRAME_DURATION := 0.08

const MAX_USES = 5

var user : NPC
var uses : int = 0

func init_room(_x : int, _y : int):
	associated_job = Enum.Jobs.OUTHOUSE_CLEANER
	super.init_room(_x, _y)

func is_used_by_other_then(npc : NPC):
	if user == null:
		return false

	return user != npc

func is_full() -> bool:
	return uses >= MAX_USES

func play_open_animation() -> void:
	var last_frame : int = outhouse_sprite.hframes * outhouse_sprite.vframes - 1
	for f in range(0, last_frame + 1):
		outhouse_sprite.frame = f
		await get_tree().create_timer(FRAME_DURATION).timeout

func play_close_animation() -> void:
	var last_frame : int = outhouse_sprite.hframes * outhouse_sprite.vframes - 1
	for f in range(last_frame - 1, -1, -1):
		outhouse_sprite.frame = f
		await get_tree().create_timer(FRAME_DURATION).timeout
