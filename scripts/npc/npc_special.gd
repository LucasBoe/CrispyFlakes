extends NPC
class_name SpecialNPC

const SHERIFF_SPRITE_SHEET := preload("res://assets/sprites/sherrif_upper_body.png")
const SCIENTIST_SPRITE_SHEET := preload("res://assets/sprites/scientist__upper_body.png")
const SNAKE_OIL_SPRITE_SHEET := preload("res://assets/sprites/snakeOil__upper_body.png")
const SHERIFF_CELL_PIXEL_SIZE := Vector2(24, 18)
const SPECIAL_PRESET_CELL_PIXEL_SIZE := Vector2(24, 18)
const SHERIFF_HEAD_INDEX := Vector2i(0, 0)
const SPECIAL_PRESET_HEAD_INDEX := Vector2i(0, 0)
const SHERIFF_COLOR_OFFSETS := Vector3(0.6, 0.3, 0.0)
const SPECIAL_PRESET_COLOR_OFFSETS := Vector3.ZERO

var encounter_data: Dictionary = {}

func init(data: Dictionary = {}) -> void:
	encounter_data = data.duplicate(true)
	_apply_encounter_appearance()

func _ready() -> void:
	super._ready()
	if look_info == null:
		_apply_encounter_appearance()

func _process(delta: float) -> void:
	super._process(delta)
	if Behaviour != null and not Behaviour.has_behaviour:
		Behaviour.set_behaviour(SpecialNPCEncounterBehaviour)

func click_on() -> bool:
	return false

func _apply_encounter_appearance() -> void:
	var appearance_id := str(encounter_data.get("appearance_id", "")).to_snake_case()
	match appearance_id:
		"sheriff":
			_apply_sheriff_look()
		"scientist":
			_apply_special_preset_look(SCIENTIST_SPRITE_SHEET)
		"snake_oil":
			_apply_special_preset_look(SNAKE_OIL_SPRITE_SHEET)
		_:
			_apply_random_look()

func _apply_random_look() -> void:
	if Animator == null:
		return

	var mat := Animator.material as ShaderMaterial
	if mat == null:
		return

	look_info = NPCLookInfo.new_random()
	mat.set_shader_parameter("base_hue_offset", look_info.color_offsets)
	mat.set_shader_parameter("sprite_index", Vector2(look_info.head_index.x, look_info.head_index.y))

func _apply_sheriff_look() -> void:
	if Animator == null:
		return

	var mat := Animator.material as ShaderMaterial
	if mat == null:
		return

	look_info = NPCLookInfo.new()
	look_info.head_index = SHERIFF_HEAD_INDEX
	look_info.color_offsets = SHERIFF_COLOR_OFFSETS

	mat.set_shader_parameter("sprite_sheet", SHERIFF_SPRITE_SHEET)
	mat.set_shader_parameter("cell_pixel_size", SHERIFF_CELL_PIXEL_SIZE)
	mat.set_shader_parameter("base_hue_offset", look_info.color_offsets)
	mat.set_shader_parameter("sprite_index", Vector2(look_info.head_index.x, look_info.head_index.y))
	mat.set_shader_parameter("use_apron", false)

func _apply_special_preset_look(sprite_sheet: Texture2D) -> void:
	if Animator == null:
		return

	var mat := Animator.material as ShaderMaterial
	if mat == null:
		return

	look_info = NPCLookInfo.new()
	look_info.head_index = SPECIAL_PRESET_HEAD_INDEX
	look_info.color_offsets = SPECIAL_PRESET_COLOR_OFFSETS

	mat.set_shader_parameter("sprite_sheet", sprite_sheet)
	mat.set_shader_parameter("cell_pixel_size", SPECIAL_PRESET_CELL_PIXEL_SIZE)
	mat.set_shader_parameter("base_hue_offset", look_info.color_offsets)
	mat.set_shader_parameter("sprite_index", Vector2(look_info.head_index.x, look_info.head_index.y))
	mat.set_shader_parameter("use_apron", false)

func get_display_name() -> String:
	return str(encounter_data.get("name", "Special Visitor"))
