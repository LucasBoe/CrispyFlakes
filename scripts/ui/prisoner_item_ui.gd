extends Button
class_name PrisonerItemUI

@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var bounty_label: Label = $MarginContainer/VBoxContainer/BountyLabel
@onready var npc_texture: TextureRect = $MarginContainer/VBoxContainer/MarginContainer/TextureRect

var prisoner: NPCGuest = null
var bounty: int = 0
var fine: int = 0
var fill_duration: float = 0.0
var elapsed: float = 0.0
var ready_to_collect: bool = false

func init(p: NPCGuest, b: int, f: int = 0) -> void:
	prisoner = p
	bounty = b
	fine = f
	var total = bounty + fine
	fill_duration = total / 10.0
	bounty_label.text = str(bounty + fine, "$")

	var mat := npc_texture.material as ShaderMaterial
	if mat != null and prisoner.look_info != null:
		mat = mat.duplicate() as ShaderMaterial
		npc_texture.material = mat
		mat.set_shader_parameter("base_hue_offset", prisoner.look_info.color_offsets)
		mat.set_shader_parameter("sprite_index", Vector2(prisoner.look_info.head_index.x, prisoner.look_info.head_index.y))

	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	disabled = true

	pressed.connect(_on_pressed)

func _process(delta: float) -> void:
	if ready_to_collect:
		return

	elapsed += delta
	var t = clamp(elapsed / fill_duration, 0.0, 1.0) if fill_duration > 0.0 else 1.0
	progress_bar.value = t

	if t >= 1.0:
		ready_to_collect = true
		disabled = false

func _on_pressed() -> void:
	if not ready_to_collect:
		return
	if not is_instance_valid(prisoner):
		return

	ResourceHandler.change_money(bounty + fine)
	if prisoner.look_info != null:
		BountyHandler.npc_bounties.erase(prisoner.look_info)
		BountyHandler.npc_fight_fines.erase(prisoner)

	prisoner.force_behaviour(NeedLeaveBehaviour)
	queue_free()
