extends Sprite2D

class_name Item

var itemType : Enum.Items


func init(itemType : Enum.Items) -> Item:
	self.itemType = itemType
	var info = get_info(itemType)
	apply_texture(info.Tex, info.Offset.x, info.Offset.y)
	return self
	
func apply_texture(tex, offset_x = 0, offset_y = 0):
	texture = tex
	offset = Vector2(offset_x, -texture.get_height()/2 + offset_y)
	
static func get_info(itemType : Enum.Items) -> TextureInfo:
	var tex = null;
	var offset = Vector2i.ZERO
	
	match itemType:
		Enum.Items.WISKEY_BARREL:
			tex = load("res://assets/sprites/item_barrel.png")
			
		Enum.Items.WISKEY_DRINK:
			tex = load("res://assets/sprites/item_drink.png")
			offset = Vector2i(3 ,-2)
	
	var info = TextureInfo.new()
	info.Tex = tex
	info.Offset = offset
	return info
	
func Destroy():
	queue_free()
	
class TextureInfo:
	var Tex : Texture
	var Offset : Vector2i
