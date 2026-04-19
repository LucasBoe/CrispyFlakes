extends Node

var instances: Array = []

func _ready() -> void:
	# Pre-populate with one of each weapon type.
	# Replace this with proper acquisition logic when ready.
	for data in WeaponData.get_definitions():
		add_instance(data)

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
