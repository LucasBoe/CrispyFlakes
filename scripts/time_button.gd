extends Button
class_name TimeButton

@onready var backroundRect = $Background
@onready var iconTexture : TextureRect = $Texture

var hovered = false
var selected = false

func _process(delta):
	
	hovered = is_hovered()
	
	if hovered || selected:
		iconTexture.modulate = Color.WHITE
	else:
		iconTexture.modulate = Color.LIGHT_GRAY
		
	if selected:
		backroundRect.position = Vector2.ZERO
		iconTexture.position = Vector2.ZERO
	else:
		backroundRect.position = Vector2.ONE
		iconTexture.position = -Vector2.ONE
