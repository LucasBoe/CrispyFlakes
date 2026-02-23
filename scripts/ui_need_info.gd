extends HBoxContainer
class_name UINeedInfo

@onready var icon_texture_rect = $TextureRect
@onready var progress_bar = $ProgressBar
@onready var name_label = $Label

var associated_need_instance : Need

func bind_instance(instance : Need):
	associated_need_instance = instance
	name_label.text = str(Enum.Need.keys()[instance.type]).substr(0, 3)
	icon_texture_rect.texture = Enum.need_to_icon(instance.type)
	
func _process(delta):
	if not associated_need_instance:
		return
		
	progress_bar.value = associated_need_instance.strength
	
	
