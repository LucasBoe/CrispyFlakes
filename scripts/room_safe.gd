extends RoomBase
class_name RoomSafe

const MAX_MONEY_FRAME := 9

@onready var safe_money_back: Sprite2D = $Safe_Money_Back
@onready var safe_money_front: Sprite2D = $Safe_Money_Front

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.SAFE
	if not MoneyHandler.changed.is_connected(_update_money_visual):
		MoneyHandler.changed.connect(_update_money_visual)
	_update_money_visual()

func _update_money_visual() -> void:
	if data == null:
		return

	var capacity := float(data.money_capacity)
	var amount := MoneyHandler.get_money_at(Vector2i(x, y))
	var frame := 0

	if capacity > 0.0:
		var fill_ratio := pow(clampf(amount / capacity, 0.0, 1.0), 2)
		frame = mini(MAX_MONEY_FRAME, int(floor(1 + fill_ratio * float(MAX_MONEY_FRAME))))
		if amount == 0:
			frame = 0

	safe_money_back.frame = frame
	safe_money_front.frame = frame

func destroy():
	if MoneyHandler.changed.is_connected(_update_money_visual):
		MoneyHandler.changed.disconnect(_update_money_visual)
	super.destroy()
