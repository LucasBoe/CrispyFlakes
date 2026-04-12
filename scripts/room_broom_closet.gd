extends RoomBase
class_name RoomBroomCloset

const MAX_CLEANERS := 5
const BROOM_TEX := preload("res://assets/sprites/item_broom.png")
const _SHELF_BROOM_POSITIONS := [
	Vector2(10, -12),
	Vector2(17, -12),
	Vector2(24, -12),
	Vector2(31, -12),
	Vector2(38, -12),
]

var assigned_cleaners: Array[NPCWorker] = []
var issued_broom_count := 0
var _shelf_brooms: Array[Sprite2D] = []

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.BROOM_CLEANER
	_ensure_shelf_brooms()
	_refresh_shelf_brooms()

func get_job_capacity(job = null) -> int:
	if job == null:
		job = associated_job
	if job != Enum.Jobs.BROOM_CLEANER:
		return 0
	return MAX_CLEANERS

func get_assigned_worker_count(job = null) -> int:
	if job == null:
		job = associated_job
	if job != Enum.Jobs.BROOM_CLEANER:
		return 0
	_cleanup_assigned_cleaners()
	return assigned_cleaners.size()

func register_cleaner(cleaner: NPCWorker) -> bool:
	_cleanup_assigned_cleaners()
	if assigned_cleaners.has(cleaner):
		_refresh_primary_worker()
		return true

	if assigned_cleaners.size() >= MAX_CLEANERS:
		return false

	assigned_cleaners.append(cleaner)
	_refresh_primary_worker()
	return true

func unregister_cleaner(cleaner: NPCWorker) -> void:
	assigned_cleaners.erase(cleaner)
	_refresh_primary_worker()

func issue_broom() -> Item:
	if issued_broom_count >= MAX_CLEANERS:
		return null

	issued_broom_count += 1
	_refresh_shelf_brooms()
	return Global.ItemSpawner.create(Enum.Items.BROOM, get_broom_pickup_position())

func get_broom_pickup_position() -> Vector2:
	return get_center_floor_position() + Vector2(2, 0)

func _cleanup_assigned_cleaners() -> void:
	for i in range(assigned_cleaners.size() - 1, -1, -1):
		if not is_instance_valid(assigned_cleaners[i]):
			assigned_cleaners.remove_at(i)
	_refresh_primary_worker()

func _refresh_primary_worker() -> void:
	worker = assigned_cleaners[0] if not assigned_cleaners.is_empty() else null

func _ensure_shelf_brooms() -> void:
	if not _shelf_brooms.is_empty():
		return

	var root = get_node_or_null("ShelfBrooms")
	if root == null:
		root = Node2D.new()
		root.name = "ShelfBrooms"
		add_child(root)

	for pos in _SHELF_BROOM_POSITIONS:
		var broom := Sprite2D.new()
		broom.texture = BROOM_TEX
		broom.position = pos
		broom.z_index = -90
		root.add_child(broom)
		_shelf_brooms.append(broom)

func _refresh_shelf_brooms() -> void:
	var available := maxi(0, MAX_CLEANERS - issued_broom_count)
	for i in _shelf_brooms.size():
		_shelf_brooms[i].visible = i < available
