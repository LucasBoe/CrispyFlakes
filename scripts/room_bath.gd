extends RoomBase
class_name RoomBath

const MAX_FUEL_DURATION := 60.0
const REFUEL_THRESHOLD_RATIO := 0.2
const REFUEL_DURATION := 2.5

var customers = []
var has_customer
signal customer_arrive_signal

var wash_requests = []

var _fuel_remaining := 0.0

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.BATH

func _process(delta: float) -> void:
	_fuel_remaining = maxf(0.0, _fuel_remaining - delta)

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func refuel() -> void:
	_fuel_remaining = MAX_FUEL_DURATION

func needs_refuel() -> bool:
	return _fuel_remaining <= MAX_FUEL_DURATION * REFUEL_THRESHOLD_RATIO

func is_heating() -> bool:
	return _fuel_remaining > 0.0

func get_fuel_ratio() -> float:
	return clampf(_fuel_remaining / MAX_FUEL_DURATION, 0.0, 1.0)

func uses_infrastructure_layer(layer_name: StringName) -> bool:
	return layer_name == &"water" and Building.infrastructure.room_has_service(self, &"water")

func wants_infrastructure_layer(layer_name: StringName) -> bool:
	return layer_name == &"water"

func clean_customer():

	if customers.size() == 0:
		return

	var customer = customers[0]
	if is_instance_valid(customer):
		if is_instance_valid(customer.npc):
			customer.npc.clean()
	unregister_as_customer(customer)

func register_as_customer(customer):
	customers.append(customer)
	has_customer = true
	customer_arrive_signal.emit()

func unregister_as_customer(customer):
	customers.erase(customer)
	has_customer = customers.size() > 0

func get_service_price() -> int:
	return Pricing.BATH_SERVICE_PRICE
