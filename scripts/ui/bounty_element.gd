extends MarginContainer
class_name BountyItemUI

@onready var npc_texture_rect = $MarginContainer/VBoxContainer/MarginContainer/TextureRect
@onready var reward_amount_label = $MarginContainer/VBoxContainer/Label2

func init(info):
	reward_amount_label.text = str(info.bounty, "$")
	var mat := npc_texture_rect.material as ShaderMaterial
	if mat != null:
		mat = mat.duplicate() as ShaderMaterial
		npc_texture_rect.material = mat
		mat.set_shader_parameter("base_hue_offset", info.look.color_offsets)
		mat.set_shader_parameter("sprite_index", Vector2(info.look.head_index.x, info.look.head_index.y))
