extends RoomBase
class_name RoomBath

var customers = []
var has_customer
signal customer_arrive

var wash_requests = []
var has_faucet: bool = false
var faucet_module = null

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.BATH

	var modules_root = get_node_or_null("ModulesRoot")
	if modules_root:
		for group in modules_root.get_children():
			for module in group.get_children():
				module.bought_changed.connect(_on_module_bought)
				if module.bought:
					_on_module_bought(module)

func _on_module_bought(module) -> void:
	if not module.bought:
		return
	if module.name == "Faucet":
		has_faucet = true
		faucet_module = module

func clean_customer():

	if customers.size() == 0:
		return

	var customer = customers[0]
	if is_instance_valid(customer):
		customer.npc.clean()
	unregister_as_customer(customer)

func register_as_customer(customer):
	customers.append(customer)
	has_customer = true
	customer_arrive.emit()

func unregister_as_customer(customer):
	customers.erase(customer)
	has_customer = customers.size() > 0
