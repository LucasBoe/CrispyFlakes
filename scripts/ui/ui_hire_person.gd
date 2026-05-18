extends Button

var hire_ui
var _hire_traits: Array = []

func _ready():
	_hire_traits = TraitLibrary.roll_traits(TraitModule.MAX_RANDOM_TRAIT_COUNT)
	_update_label()
	pressed.connect(try_hire)
	GlobalEventHandler.on_room_created_signal.connect(_on_worker_capacity_changed)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_worker_capacity_changed)
	Global.NPCSpawner.worker_count_changed_signal.connect(_on_worker_count_changed)

func _get_cost() -> int:
	const BASE := 25
	const PER_POSITIVE := 15
	const PER_NEGATIVE := -5
	var cost := BASE
	for t in _hire_traits:
		cost += PER_POSITIVE if t.is_positive() else PER_NEGATIVE
	return cost

func _update_label() -> void:
	var names := _hire_traits.map(func(t): return t.trait_name)
	var trait_text := ", ".join(names) if not names.is_empty() else "No traits"
	var block_reason := Global.NPCSpawner.get_worker_hire_block_reason()
	disabled = block_reason != ""
	text = "%s  |  %s" % [block_reason, trait_text] if block_reason != "" else "$%d  |  %s" % [_get_cost(), trait_text]

func try_hire():
	var block_reason := Global.NPCSpawner.get_worker_hire_block_reason()
	if block_reason != "":
		Global.UI.confirm.show_dialogue("%s. Build more rooms with jobs first." % block_reason, null)
		_update_label()
		return

	var cost := _get_cost()
	if MoneyHandler.total_stored() < cost:
		Global.UI.confirm.show_dialogue("Not enough money! Hiring costs $%d." % cost, null)
		return
	Global.UI.confirm.show_dialogue("Hire for $%d? They will also cost you daily wages." % cost, hire)

func hire():
	var block_reason := Global.NPCSpawner.get_worker_hire_block_reason()
	if block_reason != "":
		Global.UI.confirm.show_dialogue("%s. Build more rooms with jobs first." % block_reason, null)
		_update_label()
		return

	var cost := _get_cost()
	var worker := Global.NPCSpawner.spawn_new_worker() as NPCWorker
	if worker == null:
		_update_label()
		return

	MoneyHandler.spend(cost)
	worker.Traits.traits = _hire_traits.duplicate()
	worker.apply_trait_conflict_preference()
	queue_free()
	hire_ui.hide()

func _on_worker_capacity_changed(_room: RoomBase) -> void:
	_update_label()

func _on_worker_count_changed() -> void:
	_update_label()
