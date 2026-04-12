extends RoomBase
class_name RoomBrewery

var current_module = null

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.BREWERY

	var modules_root = get_node_or_null("ModulesRoot")
	if modules_root:
		for group in modules_root.get_children():
			for module in group.get_children():
				module.bought_changed.connect(_on_module_bought)
				if module.bought:
					current_module = module

func _on_module_bought(module) -> void:
	if module.bought:
		current_module = module
