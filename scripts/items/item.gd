extends Sprite2D

class_name Item

var itemType : Enum.Items


func init(itemType : Enum.Items) -> Item:
	self.itemType = itemType
	refresh_texture()
	return self	

func refresh_texture():
	var info = get_info(itemType)
	apply_texture(info.Tex, info.Offset.x, info.Offset.y)
	
func apply_texture(tex, offset_x = 0, offset_y = 0):
	texture = tex
	offset = Vector2(offset_x, -texture.get_height()/2 + offset_y)
	
static func get_info(itemType : Enum.Items) -> TextureInfo:
	var tex = null;
	var offset = Vector2i.ZERO
	
	match itemType:
		Enum.Items.BEER_BARREL:
			tex = load("res://assets/sprites/item_barrel.png")
			
		Enum.Items.WISKEY_BOX:
			tex = load("res://assets/sprites/item_wiskey_crate.png")
			
		Enum.Items.WISKEY_BOX_RAW:
			tex = load("res://assets/sprites/item_wiskey_crate_raw.png")
			
		Enum.Items.DRINK:
			tex = load("res://assets/sprites/item_drink.png")
			offset = Vector2i(3 ,-2)
			
		Enum.Items.WATER_BUCKET:
			tex = load("res://assets/sprites/item_water-bucket.png")
	
	var info = TextureInfo.new()
	info.Tex = tex
	info.Offset = offset
	return info
	
func Destroy():
	# preventive
	LooseItemHandler.unregister_loose_item_instance(self)
	queue_free()
	
class TextureInfo:
	var Tex : Texture
	var Offset : Vector2i
