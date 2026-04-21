extends Button
class_name TimeButton

@onready var background_rect = $Background
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
		background_rect.position = Vector2(2,2)
		iconTexture.position = Vector2.ZERO
	else:
		background_rect.position = Vector2(2,2)
		iconTexture.position = Vector2(-2,-2)
