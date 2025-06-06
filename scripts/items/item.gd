extends Sprite2D

class_name Item


func init(itemType : Enum.Items) -> Item:

	match itemType:
		Enum.Items.WISKEY:
			apply_texture("res://assets/sprites/item_wiskey.png")
	
	return self
	
func apply_texture(path):
	texture = load(path)
	offset = Vector2(0, -texture.get_height()/2)
