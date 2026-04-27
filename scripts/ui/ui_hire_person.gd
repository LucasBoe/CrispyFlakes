extends Button

var hire_ui
var _hire_traits: Array = []

func _ready():
	_hire_traits = TraitLibrary.roll_traits(TraitModule.MAX_RANDOM_TRAIT_COUNT)
	_update_label()
	pressed.connect(try_hire)

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
	text = "$%d  |  %s" % [_get_cost(), ", ".join(names) if not names.is_empty() else "No traits"]

func try_hire():
	var cost := _get_cost()
	if MoneyHandler.total_stored() < cost:
		Global.UI.confirm.show_dialogue("Not enough money! Hiring costs $%d." % cost, null)
		return
	Global.UI.confirm.show_dialogue("Hire for $%d? They will also cost you daily wages." % cost, hire)

func hire():
	var cost := _get_cost()
	MoneyHandler.spend(cost)
	var worker := Global.NPCSpawner.spawn_new_worker() as NPCWorker
	worker.Traits.traits = _hire_traits.duplicate()
	worker.apply_trait_conflict_preference()
	queue_free()
	hire_ui.hide()
