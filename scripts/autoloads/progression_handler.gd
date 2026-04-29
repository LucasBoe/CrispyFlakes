extends Node

signal flag_unlocked(flag: ProgressionItem.ProgressionFlag)
signal room_unlocked(room: RoomData)
signal points_changed(new_total: int)
signal item_unlocked(item: ProgressionItem)

const ALL_ITEMS := [
	preload("res://assets/resources/progression/prog_empty_room.tres"),
	preload("res://assets/resources/progression/prog_tables.tres"),
	preload("res://assets/resources/progression/prog_stairs.tres"),
	preload("res://assets/resources/progression/prog_outhouse.tres"),
	preload("res://assets/resources/progression/prog_bar.tres"),
	preload("res://assets/resources/progression/prog_broom_room.tres"),
	preload("res://assets/resources/progression/prog_entertainment.tres"),
	preload("res://assets/resources/progression/prog_horsestand.tres"),
	preload("res://assets/resources/progression/prog_water_tower.tres"),
	preload("res://assets/resources/progression/prog_bed_room.tres"),
	preload("res://assets/resources/progression/prog_storage.tres"),
	preload("res://assets/resources/progression/prog_brewery.tres"),
	preload("res://assets/resources/progression/prog_bouncer.tres"),
	preload("res://assets/resources/progression/prog_gambling.tres"),
	preload("res://assets/resources/progression/prog_stables.tres"),
	preload("res://assets/resources/progression/prog_toilets.tres"),
	preload("res://assets/resources/progression/prog_aging_cellar.tres"),
	preload("res://assets/resources/progression/prog_destillery.tres"),
	preload("res://assets/resources/progression/prog_prison.tres"),
	preload("res://assets/resources/progression/prog_safe.tres"),
	preload("res://assets/resources/progression/prog_bath.tres"),
	preload("res://assets/resources/progression/prog_big_brewer.tres"),
	preload("res://assets/resources/progression/prog_big_table.tres"),
	preload("res://assets/resources/progression/prog_stove.tres"),
	preload("res://assets/resources/progression/prog_big_bucket.tres"),
	preload("res://assets/resources/progression/prog_beer_barrel_holder.tres"),
	preload("res://assets/resources/progression/prog_whiskey_shelf.tres"),
	preload("res://assets/resources/progression/prog_triple_bunk_bed.tres"),
	preload("res://assets/resources/progression/prog_trade_office.tres"),
]

@onready var empty_room = preload("res://assets/resources/progression/prog_empty_room.tres")
@onready var table_room = preload("res://assets/resources/progression/prog_tables.tres")
@onready var broom_room = preload("res://assets/resources/progression/prog_broom_room.tres")

var _points: int = 0
var _highest_guest_count_reached: int = 0
var _unlocked_flags: Dictionary = {}
var _unlocked_rooms: Array[RoomData] = []
var _unlocked_items: Array[ProgressionItem] = []
var _items_by_room: Dictionary = {}
var _items_by_infrastructure: Dictionary = {}

func _ready() -> void:
	Global.NPCSpawner.spawned_guest_signal.connect(_on_spawned_guest)
	Console.add_command("tree", console_unlock_all_progression, 0, 0, "Unlocks all progression tree items.")
	for item: ProgressionItem in ALL_ITEMS:
		if item.unlocks_room != null:
			_items_by_room[item.unlocks_room] = item
		if item.unlocks_infrastructure != null:
			_items_by_infrastructure[item.unlocks_infrastructure] = item

func unlock_default_rooms():
	force_unlock(empty_room)

func console_unlock_all_progression() -> void:
	for item: ProgressionItem in ALL_ITEMS:
		force_unlock(item)
	Console.print_line("unlocked all progression tree items")

func force_unlock(item: ProgressionItem) -> void:
	if is_item_unlocked(item):
		return
	if item.unlocks_flag != ProgressionItem.ProgressionFlag.NONE:
		_unlocked_flags[item.unlocks_flag] = true
		flag_unlocked.emit(item.unlocks_flag)
	if item.unlocks_room != null:
		_unlocked_rooms.append(item.unlocks_room)
		room_unlocked.emit(item.unlocks_room)
	_unlocked_items.append(item)
	item_unlocked.emit(item)

func add_points(amount: int) -> void:
	_points += amount
	points_changed.emit(_points)

func get_points() -> int:
	return _points

func is_item_unlocked(item: ProgressionItem) -> bool:
	return item in _unlocked_items

func try_unlock(item: ProgressionItem) -> bool:
	if _points < item.cost:
		return false
	if item.depends_on != null and not is_item_unlocked(item.depends_on):
		return false
	_points -= item.cost
	points_changed.emit(_points)

	if item.unlocks_flag != ProgressionItem.ProgressionFlag.NONE:
		_unlocked_flags[item.unlocks_flag] = true
		flag_unlocked.emit(item.unlocks_flag)

	if item.unlocks_room != null:
		_unlocked_rooms.append(item.unlocks_room)
		room_unlocked.emit(item.unlocks_room)

	_unlocked_items.append(item)
	item_unlocked.emit(item)
	return true

func is_flag_set(flag: ProgressionItem.ProgressionFlag) -> bool:
	return _unlocked_flags.get(flag, false)

func is_room_unlocked(room: RoomData) -> bool:
	return room in _unlocked_rooms

func get_item_for_room(room: RoomData) -> ProgressionItem:
	return _items_by_room.get(room, null)

func is_room_build_unlocked(room: RoomData) -> bool:
	return true if get_item_for_room(room) == null else is_room_unlocked(room)

func get_item_for_infrastructure(data: InfrastructureData) -> ProgressionItem:
	return _items_by_infrastructure.get(data, null)

func is_infrastructure_build_unlocked(data: InfrastructureData) -> bool:
	var item := get_item_for_infrastructure(data)
	return true if item == null else is_item_unlocked(item)

func _on_spawned_guest(guest_count: int) -> void:
	if guest_count <= _highest_guest_count_reached:
		return

	add_points(guest_count - _highest_guest_count_reached)
	_highest_guest_count_reached = guest_count
