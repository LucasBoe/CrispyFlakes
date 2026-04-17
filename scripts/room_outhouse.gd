extends RoomOutsideBase
class_name RoomOuthouse

@onready var outhouse_sprite = $Outhouse

const FRAME_DURATION := 0.08
const DEFAULT_MAX_USES := 10

var user : NPC
var uses : int = 0
var current_module = null

func init_room(_x : int, _y : int):
	associated_job = Enum.Jobs.OUTHOUSE_CLEANER
	super.init_room(_x, _y)

	var modules_root = get_node_or_null("ModulesRoot")
	if modules_root:
		for group in modules_root.get_children():
			for module in group.get_children():
				if not module.has_method("set_bought"):
					continue
				module.bought_changed.connect(_on_module_bought)
				if module.bought:
					current_module = module

func is_used_by_other_then(npc : NPC):
	if user == null:
		return false

	return user != npc

func is_full() -> bool:
	return uses >= get_max_uses()

func get_max_uses() -> int:
	if current_module != null and current_module.max_guests > 0:
		return current_module.max_guests
	return DEFAULT_MAX_USES

func _on_module_bought(module) -> void:
	if not module.bought:
		return
	current_module = module

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
