extends Sprite2D

class_name Item

var itemType : Enum.Items


func init(itemType : Enum.Items) -> Item:

	self.itemType = itemType

	match itemType:
		Enum.Items.WISKEY_BARREL:
			apply_texture("res://assets/sprites/item_barrel.png")
			
		Enum.Items.WISKEY_DRINK:
			apply_texture("res://assets/sprites/item_drink.png",3 ,-2)
	
	return self
	
func apply_texture(path, offset_x = 0, offset_y = 0):
	texture = load(path)
	offset = Vector2(offset_x, -texture.get_height()/2 + offset_y)
	
func Destroy():
	queue_free()
