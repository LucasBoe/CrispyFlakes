extends RoomBase
class_name RoomBath

const SERVICE_PRICE := 6

var customers = []
var has_customer
signal customer_arrive

var wash_requests = []

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.BATH

func uses_infrastructure_layer(layer_name: StringName) -> bool:
	return layer_name == &"water" and Building.infrastructure.room_has_service(self, &"water")

func wants_infrastructure_layer(layer_name: StringName) -> bool:
	return layer_name == &"water"

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
