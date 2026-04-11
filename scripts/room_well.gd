extends RoomOutsideBase
class_name RoomWell

@onready var progressBar: TextureProgressBar = $ProgressBar
@onready var underground_bg: NinePatchRect = $Underground/Background
@onready var underground_fg: NinePatchRect = $Underground/Foreground
@onready var water_rect: ColorRect = $Underground/WaterLevelRect

const BASE_DEPTH := 48.0
const DEPTH_INCREMENT := 8.0
const WATER_BOTTOM_MARGIN := 6.0
const WATER_TOP_START := 8.0
const WATER_PER_DEPTH := 32
const BASE_DIG_COST := 25
const REFILL_RATE := 0.025

var depth := 1
var max_water := 48.0
var current_water := 32.0

var current_user
var registered_users = []

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	progressBar.visible = false
	associated_job = Enum.Jobs.WELL
	_update_visuals()

func _process(delta):
	if current_water < max_water:
		current_water = minf(current_water + REFILL_RATE * delta, max_water)
		_update_visuals()

func register(npc: NPC):
	registered_users.append(npc)
	check_next()

func unregister(npc: NPC):
	registered_users.erase(npc)
	check_next()

func check_next():
	if registered_users.size() > 0:
		current_user = registered_users[0]
	else:
		current_user = null

func has_water() -> bool:
	return current_water >= 1.0

func consume_water():
	current_water = maxf(0.0, current_water - 1.0)
	_update_visuals()

func get_dig_cost() -> int:
	return BASE_DIG_COST * depth

func dig_deeper() -> bool:
	var cost = get_dig_cost()
	if not ResourceHandler.has_money(cost):
		return false
	ResourceHandler.change_resource(Enum.Resources.MONEY, -cost)
	depth += 1
	max_water += WATER_PER_DEPTH
	current_water = minf(current_water + WATER_PER_DEPTH, max_water)
	_update_visuals()
	return true

func _update_visuals():
	var shaft_height = BASE_DEPTH + (depth - 1) * DEPTH_INCREMENT
	underground_bg.offset_bottom = shaft_height
	underground_fg.offset_bottom = shaft_height

	var water_bottom = shaft_height - WATER_BOTTOM_MARGIN
	var max_water_height = water_bottom - WATER_TOP_START
	var water_ratio = current_water / max_water if max_water > 0 else 0.0
	var water_height = max_water_height * water_ratio

	water_rect.offset_bottom = water_bottom
	water_rect.offset_top = water_bottom - water_height
