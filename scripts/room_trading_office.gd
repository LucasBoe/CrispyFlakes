extends RoomStorageBase
class_name RoomTradingOffice

const TRADER_WAGON_SCENE = preload("res://scenes/npcs/trader_wagon.tscn")
const ORDER_BASE_DURATION := 8.0
const ORDER_PER_ITEM_DURATION := 2.5

@onready var progress_bar: TextureProgressBar = $ProgressBar

var order_start_time: float = -1.0
var order_arrival_time: float = -1.0
var delivery_in_progress := false
var pending_order: Dictionary = {}
var tracked_crates: Array[Item] = []

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.TRADING_OFFICE
	_refresh_progress_bar()

func has_assigned_worker() -> bool:
	return is_instance_valid(worker)

func can_receive(item: Item) -> bool:
	return item != null and item.itemType == Enum.Items.CRATE and super.can_receive(item)

func try_receive(item: Item) -> bool:
	if not can_receive(item):
		return false
	return super.try_receive(item)

func place_order(order_amounts: Dictionary) -> bool:
	if not has_assigned_worker():
		return false
	if has_active_delivery():
		return false

	var normalized := _normalize_order(order_amounts)
	if normalized.is_empty():
		return false

	pending_order = normalized
	order_start_time = Global.time_now
	order_arrival_time = order_start_time + get_order_duration_for(normalized)
	delivery_in_progress = false
	_refresh_progress_bar()
	return true

func has_active_delivery() -> bool:
	return order_arrival_time >= 0.0

func is_waiting_for_trader() -> bool:
	return has_active_delivery() and not delivery_in_progress and Global.time_now < order_arrival_time

func get_delivery_progress() -> float:
	if not has_active_delivery():
		return 0.0
	if delivery_in_progress:
		return 1.0

	var duration := maxf(0.001, order_arrival_time - order_start_time)
	return clampf((Global.time_now - order_start_time) / duration, 0.0, 1.0)

func get_delivery_status_text() -> String:
	if not has_active_delivery():
		return ""
	if delivery_in_progress:
		return "Trader arriving..."
	var remaining := maxi(0, ceili(order_arrival_time - Global.time_now))
	return "Arrival in %ss" % remaining

func get_order_duration_for(order_amounts: Dictionary) -> float:
	return ORDER_BASE_DURATION + ORDER_PER_ITEM_DURATION * float(_count_total_items(order_amounts))

func get_drop_position() -> Vector2:
	if not Building.floors.has(0):
		return Vector2(get_center_floor_position().x, 0.0)

	var min_x := INF
	for x in Building.floors[0]:
		var room := Building.floors[0][x] as RoomBase
		if room != null and room is not RoomEmpty:
			min_x = minf(min_x, float(x))

	if min_x == INF:
		return Vector2(get_center_floor_position().x, 0.0)

	var left_edge_x: float = Building.global_position_from_room_index(Vector2i(int(min_x), 0)).x - 24.0
	return Vector2(left_edge_x - 12.0, 0.0)

func register_delivery_crate(crate: Item) -> void:
	if crate == null:
		return
	if crate not in tracked_crates:
		tracked_crates.append(crate)

func unregister_delivery_crate(crate: Item) -> void:
	tracked_crates.erase(crate)

func get_owned_crates() -> Array[Item]:
	_prune_tracked_crates()
	return tracked_crates.duplicate()

func _process(_delta: float) -> void:
	_prune_tracked_crates()
	_refresh_progress_bar()

	if not has_active_delivery() or delivery_in_progress:
		return
	if Global.time_now < order_arrival_time:
		return

	_start_trader_arrival()

func on_trader_arrival_complete() -> void:
	_clear_active_order()

func destroy():
	for crate in get_owned_crates():
		if not is_instance_valid(crate):
			continue
		var holder = crate.get_parent()
		if holder is RoomStorageBase:
			(holder as RoomStorageBase).remove_item(crate)
		crate.destroy()

	tracked_crates.clear()
	pending_order.clear()
	_clear_active_order()
	super.destroy()

func _start_trader_arrival() -> void:
	if pending_order.is_empty():
		_clear_active_order()
		return

	delivery_in_progress = true
	var trader = TRADER_WAGON_SCENE.instantiate()
	trader.target_room = self
	trader.order_items = pending_order.duplicate(true)
	var parent = Global.NPCSpawner if Global.NPCSpawner != null else Building
	parent.add_child(trader)

func _clear_active_order() -> void:
	order_start_time = -1.0
	order_arrival_time = -1.0
	delivery_in_progress = false
	pending_order.clear()
	_refresh_progress_bar()

func _count_total_items(order_amounts: Dictionary) -> int:
	var total := 0
	for amount in order_amounts.values():
		total += maxi(0, int(amount))
	return total

func _normalize_order(order_amounts: Dictionary) -> Dictionary:
	var normalized := {}
	for item_type in order_amounts.keys():
		var amount := maxi(0, int(order_amounts[item_type]))
		if amount <= 0:
			continue
		normalized[int(item_type)] = amount
	return normalized

func _prune_tracked_crates() -> void:
	for i in range(tracked_crates.size() - 1, -1, -1):
		var crate := tracked_crates[i] as Item
		if crate == null or not is_instance_valid(crate) or not crate.is_trade_crate() or not crate.is_owned_by_trade_office(self):
			tracked_crates.remove_at(i)

func _refresh_progress_bar() -> void:
	if progress_bar == null:
		return

	progress_bar.max_value = 100.0
	progress_bar.value = get_delivery_progress() * 100.0
	progress_bar.visible = has_active_delivery()
