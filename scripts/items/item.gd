extends Sprite2D

class_name Item

var itemType : Enum.Items
var crate_item_type: int = -1
var crate_item_amount: int = 0
var trade_office_owner = null

const WISKEY_AGING_DURATION: float = Global.DAY_DURATION
var age: float = 0.0
var aging_multiplier: float = 1.0

func _process(delta):
	if itemType == Enum.Items.WISKEY_BOX_RAW:
		age += delta * aging_multiplier
		if age >= WISKEY_AGING_DURATION:
			itemType = Enum.Items.WISKEY_BOX
			refresh_texture()

func init(itemType : Enum.Items) -> Item:
	self.itemType = itemType
	crate_item_type = -1
	crate_item_amount = 0
	trade_office_owner = null

	refresh_texture()
	return self

func configure_trade_crate(contained_item_type: Enum.Items, amount: int, office = null) -> Item:
	itemType = Enum.Items.CRATE
	crate_item_type = contained_item_type
	crate_item_amount = maxi(0, amount)
	trade_office_owner = office
	refresh_texture()
	return self

func is_trade_crate() -> bool:
	return itemType == Enum.Items.CRATE and crate_item_type >= 0 and crate_item_amount > 0

func get_trade_crate_item_type() -> int:
	return crate_item_type

func get_trade_crate_item_amount() -> int:
	return crate_item_amount

func is_owned_by_trade_office(office) -> bool:
	return trade_office_owner == office

func spawn_one_from_trade_crate(spawn_pos: Vector2 = global_position) -> Item:
	if not is_trade_crate():
		return null

	crate_item_amount -= 1
	var spawned := Global.ItemSpawner.create(crate_item_type, spawn_pos)
	if crate_item_amount < 0:
		crate_item_amount = 0
	refresh_texture()
	return spawned

func refresh_texture():
	var info = get_info(itemType)
	apply_texture(info.Tex, info.Offset.x, info.Offset.y)

func apply_texture(tex, offset_x = 0, offset_y = 0):
	texture = tex
	offset = Vector2(offset_x, -texture.get_height()/2 + offset_y)

static func get_info(itemType : Enum.Items) -> TextureInfo:
	var tex = null;
	var offset = Vector2i.ZERO
	var display_name := ""
	var trade_price := -1
	var trade_orderable := false

	match itemType:
		Enum.Items.BEER_BARREL:
			tex = load("res://assets/sprites/item_barrel.png")
			display_name = "Beer Barrel"
			trade_price = 16
			trade_orderable = true

		Enum.Items.WISKEY_BOX:
			tex = load("res://assets/sprites/item_wiskey_crate.png")
			display_name = "Whiskey Box"
			trade_price = 28
			trade_orderable = true

		Enum.Items.WISKEY_BOX_RAW:
			tex = load("res://assets/sprites/item_wiskey_crate_raw.png")
			display_name = "Fresh Whiskey"

		Enum.Items.DRINK:
			tex = load("res://assets/sprites/item_drink.png")
			offset = Vector2i(3 ,-2)
			display_name = "Drink"

		Enum.Items.WATER_BUCKET:
			tex = load("res://assets/sprites/item_water-bucket.png")
			display_name = "Water Bucket"
			trade_price = 6
			trade_orderable = true

		Enum.Items.BROOM:
			tex = load("res://assets/sprites/item_broom.png")
			display_name = "Broom"
			trade_price = 10
			trade_orderable = true

		Enum.Items.MONEY:
			tex = get_money_texture()
			display_name = "Money"

		Enum.Items.CRATE:
			tex = load("res://assets/sprites/item_crate.png")
			display_name = "Crate"

		Enum.Items.WOOD:
			tex = load("res://assets/sprites/ui/item_wood.png")
			display_name = "Wood"
			trade_price = 8
			trade_orderable = true

	var info = TextureInfo.new()
	info.Tex = tex
	info.Offset = offset
	info.Name = display_name
	info.TradePrice = trade_price
	info.TradeOrderable = trade_orderable
	return info

static func get_trade_price(itemType: Enum.Items) -> int:
	return get_info(itemType).TradePrice

static func get_display_name(itemType: Enum.Items) -> String:
	return get_info(itemType).Name

static func get_trade_orderable_items() -> Array[int]:
	var orderable: Array[int] = []
	for item_type in Enum.Items.values():
		var info := get_info(item_type)
		if info.TradeOrderable and info.TradePrice > 0:
			orderable.append(item_type)
	return orderable

static func get_money_texture() -> AtlasTexture:
	var tex = AtlasTexture.new()
	tex.atlas = load("res://assets/sprites/coins-sprite-sheet.png")
	tex.region = Rect2(0, 0, 8, 8)
	return tex

func play_spawn_sound() -> void:
	if itemType == Enum.Items.WATER_BUCKET:
		SoundPlayer.play_water(global_position)

func destroy():
	play_spawn_sound()

	# preventive
	LooseItemHandler.unregister_loose_item_instance(self)
	queue_free()

class TextureInfo:
	var Tex : Texture
	var Offset : Vector2i
	var Name : String
	var TradePrice : int = -1
	var TradeOrderable : bool = false
