extends NPC
class_name SpecialNPC

var encounter_data: Dictionary = {}
var _waiting_for_encounter_click := false
var _encounter_click_requested := false

func init(data: Dictionary = {}) -> void:
	encounter_data = data.duplicate(true)
	_apply_random_look()

func _ready() -> void:
	super._ready()
	if look_info == null:
		_apply_random_look()

func _process(delta: float) -> void:
	super._process(delta)
	if Behaviour != null and not Behaviour.has_behaviour:
		Behaviour.set_behaviour(SpecialNPCEncounterBehaviour)

func click_on() -> bool:
	if not _waiting_for_encounter_click:
		return false
	_encounter_click_requested = true
	return true

func set_waiting_for_encounter_click(waiting: bool) -> void:
	_waiting_for_encounter_click = waiting
	if waiting:
		_encounter_click_requested = false

func is_waiting_for_encounter_click() -> bool:
	return _waiting_for_encounter_click

func consume_encounter_click_request() -> bool:
	if not _encounter_click_requested:
		return false
	_encounter_click_requested = false
	return true

func _apply_random_look() -> void:
	if Animator == null:
		return

	var mat := Animator.material as ShaderMaterial
	if mat == null:
		return

	look_info = NPCLookInfo.new_random()
	mat.set_shader_parameter("base_hue_offset", look_info.color_offsets)
	mat.set_shader_parameter("sprite_index", Vector2(look_info.head_index.x, look_info.head_index.y))

func get_display_name() -> String:
	return str(encounter_data.get("name", "Special Visitor"))
