extends Node

var instances: Array = []

const WEAPONS_DIR: String = "res://assets/resources/weapons/"

func _ready() -> void:
	var dir: DirAccess = DirAccess.open(WEAPONS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var data = load(WEAPONS_DIR + file_name)
			if data != null:
				add_instance(data)
		file_name = dir.get_next()
	dir.list_dir_end()

func add_instance(data) -> void:
	var inst := WeaponInstance.new()
	inst.data = data
	instances.append(inst)

func get_equipped_by(worker) -> WeaponInstance:
	for inst: WeaponInstance in instances:
		if inst.equipped_by == worker:
			return inst
	return null

func equip(worker, inst) -> void:
	# Drop whatever this worker currently holds
	var current: WeaponInstance = get_equipped_by(worker)
	if current != null:
		current.equipped_by = null

	if inst == null:
		return

	# If another worker already has this instance, take it from them
	if not inst.is_available():
		inst.equipped_by = null

	inst.equipped_by = worker

func unequip(worker) -> void:
	var current: WeaponInstance = get_equipped_by(worker)
	if current != null:
		current.equipped_by = null
