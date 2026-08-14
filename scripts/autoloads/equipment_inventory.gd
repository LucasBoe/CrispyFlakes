extends Node

var instances: Array[EquipmentInstance] = []

const CATALOG_DIR: String = "res://assets/resources/equipment/"

func _ready() -> void:
	Console.add_command("random_equipment", console_acquire_random_equipment, 0, 0, "Debug: acquires a random equipment item, bypassing Wardrobe capacity.")

func console_acquire_random_equipment() -> void:
	var catalog := get_catalog()
	if catalog.is_empty():
		Console.print_line("no equipment catalog entries found")
		return
	var data: EquipmentData = catalog[randi() % catalog.size()]
	var inst := EquipmentInstance.new()
	inst.data = data
	instances.append(inst)
	Console.print_line("acquired: %s" % data.equipment_name)

func get_catalog() -> Array[EquipmentData]:
	var catalog: Array[EquipmentData] = []
	var dir: DirAccess = DirAccess.open(CATALOG_DIR)
	if dir == null:
		return catalog
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var data = load(CATALOG_DIR + file_name)
			if data is EquipmentData:
				catalog.append(data)
		file_name = dir.get_next()
	dir.list_dir_end()
	return catalog

func get_capacity() -> int:
	if not is_instance_valid(Building) or Building.query == null:
		return 0
	return Building.query.all_rooms_of_type(RoomWardrobe).size()

func can_acquire() -> bool:
	return instances.size() < get_capacity()

func try_acquire(data: EquipmentData) -> EquipmentInstance:
	if not can_acquire():
		return null
	var inst := EquipmentInstance.new()
	inst.data = data
	instances.append(inst)
	return inst

func get_equipped_by(worker) -> EquipmentInstance:
	for inst: EquipmentInstance in instances:
		if inst.equipped_by == worker:
			return inst
	return null

func equip(worker, inst: EquipmentInstance) -> bool:
	if inst == null:
		unequip(worker)
		return true

	if not instances.has(inst):
		return false

	var current: EquipmentInstance = get_equipped_by(worker)
	if current == inst:
		return true

	if current != null:
		current.equipped_by = null

	# If another worker already has this instance, take it from them
	if not inst.is_available():
		inst.equipped_by = null

	inst.equipped_by = worker
	return true

func unequip(worker) -> void:
	var current: EquipmentInstance = get_equipped_by(worker)
	if current != null:
		current.equipped_by = null
