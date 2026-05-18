extends RoomBase
class_name RoomBar

var drink_requests = []
@export var drink_type: int = Enum.Items.WATER_BUCKET
@export var item_cost: int = 2
@export var drink_icon: Texture2D

const TIMEOUT_DURATION_IN_MSEC = 10000

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.BAR

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func uses_infrastructure_layer(layer_name: StringName) -> bool:
	return layer_name == &"water" and drink_type == Enum.Items.WATER_BUCKET and Building.infrastructure.room_has_service(self, &"water")

func wants_infrastructure_layer(layer_name: StringName) -> bool:
	return layer_name == &"water" and drink_type == Enum.Items.WATER_BUCKET

func try_receive(item) -> bool:
	item.destroy()
	return true

func request_drink(_requestor):
	var request = drink_request.new()
	request.status = Enum.RequestStatus.OPEN
	request.time = Time.get_ticks_msec()
	drink_requests.append(request)
	return request

func fullfill_next_request():
	if drink_requests.size() <= 0:
		return
	var req = drink_requests[0]
	req.status = Enum.RequestStatus.FULFILLED
	drink_requests.erase(req)

func get_sale_price() -> int:
	return ceili(float(item_cost) * 1.5)

func _process(_delta):
	if not Global.should_auto_spawn_guests:
		return
	var t = Time.get_ticks_msec()
	var done = []
	for request in drink_requests:
		if t - request.time > TIMEOUT_DURATION_IN_MSEC:
			done.append(request)
	for d in done:
		d.status = Enum.RequestStatus.TIMEOUT
		drink_requests.erase(d)

class drink_request:
	var time: float
	var status: Enum.RequestStatus
