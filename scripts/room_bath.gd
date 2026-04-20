extends RoomBase
class_name RoomBath

const SERVICE_PRICE := 6

var customers = []
var has_customer
signal customer_arrive

var wash_requests = []
var has_faucet: bool = false
var faucet_module = null

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.BATH
	GlobalEventHandler.on_room_created_signal.connect(_on_room_created)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_room_deleted)
	_refresh_faucet_state()

func _on_module_bought(module) -> void:
	if module.name == "Faucet":
		faucet_module = module
		_refresh_faucet_state()
		return
	if not module.bought:
		return

func _on_room_created(room: RoomBase) -> void:
	if room is not RoomWaterTower:
		return
	_refresh_faucet_state()

func _on_room_deleted(room: RoomBase) -> void:
	if room is not RoomWaterTower:
		return
	call_deferred("_refresh_faucet_state")

func _refresh_faucet_state() -> void:
	has_faucet = faucet_module != null and faucet_module.bought and faucet_module.is_dependency_met()

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

func get_service_price() -> int:
	return SERVICE_PRICE
