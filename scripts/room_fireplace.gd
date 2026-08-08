extends RoomStove
class_name RoomFireplace

const _FIREPLACE_TEXTURE := preload("res://assets/sprites/fireplace.png")
const FIREPLACE_HEAT_RANGE := 72.0
const STOCKPILE_TARGET_FUEL := 2
const STOCKPILE_RADIUS := 18.0
const POKED_FIRE_DURATION := 18.0
const POKED_BURN_MULTIPLIER := 0.35
const REPOKE_THRESHOLD := 4.0
const STOCKPILE_DROP_OFFSETS: Array[Vector2] = [
	Vector2(-6.0, 0.0),
	Vector2(-1.0, 0.0),
	Vector2(4.0, 0.0),
	Vector2(9.0, 0.0),
]

var _poked_fire_remaining := 0.0


func init_room(_x: int, _y: int) -> void:
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.FIREPLACE_KEEPER


func get_heat_source_debug_name() -> String:
	return "fireplace"


func get_temperature_range() -> float:
	return FIREPLACE_HEAT_RANGE


func get_heat_band_temperatures() -> Array[float]:
	return [
		TemperatureHandler.PRIMARY_HEAT_TEMPERATURE,
		TemperatureHandler.SECONDARY_HEAT_TEMPERATURE,
	]


func get_stockpile_anchor_position() -> Vector2:
	return global_position + Vector2(35.0, 0.0)


func get_stockpile_drop_position() -> Vector2:
	var stockpiled := get_stockpiled_fuel_count()
	var offset_index := mini(stockpiled, STOCKPILE_DROP_OFFSETS.size() - 1)
	return get_stockpile_anchor_position() + STOCKPILE_DROP_OFFSETS[offset_index]


func get_stockpiled_fuel_count() -> int:
	return _get_stockpiled_fuel_items().size()


func get_stockpiled_wood_count() -> int:
	return get_stockpiled_fuel_count()


func has_stockpiled_fuel() -> bool:
	return get_stockpiled_fuel_count() > 0


func has_stockpiled_wood() -> bool:
	return has_stockpiled_fuel()


func needs_stockpile() -> bool:
	return get_stockpiled_fuel_count() < STOCKPILE_TARGET_FUEL


func consume_stockpiled_fuel_type() -> int:
	var stockpiled_fuel := _get_stockpiled_fuel_items()
	if stockpiled_fuel.is_empty():
		return -1

	var item := stockpiled_fuel[0] as Item
	if item == null or not is_instance_valid(item):
		return -1

	var fuel_item_type := item.itemType
	item.destroy()
	return fuel_item_type


func consume_stockpiled_fuel() -> bool:
	return consume_stockpiled_fuel_type() >= 0


func consume_stockpiled_wood() -> bool:
	return consume_stockpiled_fuel()


func is_loose_fuel_stockpiled(item: Item) -> bool:
	return item != null \
	and is_instance_valid(item) \
	and Item.is_fuel_item(item.itemType) \
	and item.global_position.distance_squared_to(get_stockpile_anchor_position()) <= STOCKPILE_RADIUS * STOCKPILE_RADIUS


func is_loose_wood_stockpiled(item: Item) -> bool:
	return is_loose_fuel_stockpiled(item)


func poke_fire() -> void:
	if not is_heating():
		return
	_poked_fire_remaining = POKED_FIRE_DURATION


func needs_poking() -> bool:
	return is_heating() and _poked_fire_remaining <= REPOKE_THRESHOLD


func is_fire_poked() -> bool:
	return _poked_fire_remaining > 0.0


func get_poked_seconds_remaining() -> float:
	return _poked_fire_remaining


func _before_heat_update(delta: float) -> void:
	_poked_fire_remaining = maxf(0.0, _poked_fire_remaining - delta)


func _get_fuel_burn_multiplier() -> float:
	return POKED_BURN_MULTIPLIER if is_fire_poked() else 1.0


func _get_ember_burn_multiplier() -> float:
	return POKED_BURN_MULTIPLIER if is_fire_poked() else 1.0


func _get_active_texture() -> Texture2D:
	return _FIREPLACE_TEXTURE


func _get_inactive_texture() -> Texture2D:
	return _FIREPLACE_TEXTURE


func _get_stockpiled_fuel_items() -> Array[Item]:
	var items: Array[Item] = []
	for fuel_type in [Enum.Items.WOOD, Enum.Items.COAL]:
		var loose_fuel_items := LooseItemHandler.loose_items.get(fuel_type, []) as Array
		if loose_fuel_items == null:
			continue

		for candidate in loose_fuel_items:
			var item := candidate as Item
			if item == null or not is_instance_valid(item):
				continue
			if not is_loose_fuel_stockpiled(item):
				continue
			items.append(item)

	items.sort_custom(func(a: Item, b: Item): return a.global_position.x < b.global_position.x)
	return items


func _get_stockpiled_wood_items() -> Array[Item]:
	return _get_stockpiled_fuel_items()
