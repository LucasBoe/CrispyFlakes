extends RoomOutsideBase
class_name RoomWaterTower

const MAX_WATER := 96.0
const PUMP_AMOUNT := 8.0
const PUMP_DURATION := 3.0

@onready var fill_rect: ColorRect = $ModulesRoot/Tower/Basic/WaterTower/ColorRectFill

var current_water := 0.0

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.WATER_TOWER
	_update_visual()

func is_full() -> bool:
	return current_water >= MAX_WATER

func has_water() -> bool:
	return current_water >= 1.0

func pump():
	current_water = minf(current_water + PUMP_AMOUNT, MAX_WATER)
	_update_visual()

func consume_water():
	current_water = maxf(0.0, current_water - 1.0)
	_update_visual()

func _update_visual():
	if not is_instance_valid(fill_rect):
		return
	var ratio = current_water / MAX_WATER
	# offset_bottom fixed at -58 (bottom of tank), offset_top slides up as water fills
	fill_rect.offset_top = -58.0 - 26.0 * ratio
