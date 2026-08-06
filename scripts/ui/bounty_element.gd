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
		info.look.apply_to_material(mat)
