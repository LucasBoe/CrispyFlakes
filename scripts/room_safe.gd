extends RoomBase
class_name RoomSafe

const MAX_MONEY_FRAME := 9

@onready var safe_money_back: Sprite2D = $Safe_Money_Back
@onready var safe_money_front: Sprite2D = $Safe_Money_Front

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.SAFE
	if not MoneyHandler.on_money_changed_signal.is_connected(_update_money_visual):
		MoneyHandler.on_money_changed_signal.connect(_update_money_visual)
	_update_money_visual()

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func should_warn_cannot_store_more_money() -> bool:
	if data == null:
		return false
	if MoneyHandler.total_stored() < MoneyHandler.total_capacity():
		return false
	return _has_pending_money_to_collect()

func get_full_warning_text() -> String:
	return "safe full"

func _update_money_visual() -> void:
	if data == null:
		return

	var capacity := float(data.money_capacity)
	var amount := MoneyHandler.get_money_at(Vector2i(x, y))
	var frame := 0

	if capacity > 0.0:
		var fill_ratio := sqrt(clampf(amount / capacity, 0.0, 1.0))
		frame = mini(MAX_MONEY_FRAME, int(floor(1 + fill_ratio * float(MAX_MONEY_FRAME))))
		if amount == 0:
			frame = 0

	safe_money_back.frame = frame
	safe_money_front.frame = frame

func _has_pending_money_to_collect() -> bool:
	if LooseItemHandler.get_closest_to(global_position, Enum.Items.MONEY) != null:
		return true

	var safe_location := Vector2i(x, y)
	for location: Vector2i in MoneyHandler.location_money.keys():
		if location == safe_location:
			continue
		if Building.get_room_from_index(location) is RoomSafe:
			continue
		if float(MoneyHandler.location_money[location]) > 0.0:
			return true

	return false

func destroy():
	if MoneyHandler.on_money_changed_signal.is_connected(_update_money_visual):
		MoneyHandler.on_money_changed_signal.disconnect(_update_money_visual)
	super.destroy()
