extends RoomBase
class_name RoomKitchen

const TIMEOUT_DURATION_IN_MSEC := 10000
const LOAD_DURATION := 2.5
const COOK_DURATION := 6.0
const SOUP_BATCH_SIZE := 5
const SERVICE_PRICE := 7

var soup_requests: Array[SoupRequest] = []
var soups_available: int = 0

var water_loaded := false
var fuel_loaded := false

func init_room(_x: int, _y: int) -> void:
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.KITCHEN

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func uses_infrastructure_layer(layer_name: StringName) -> bool:
	return layer_name == &"water" and Building.infrastructure.room_has_service(self, &"water")

func wants_infrastructure_layer(layer_name: StringName) -> bool:
	return layer_name == &"water"

func request_soup(_requestor) -> SoupRequest:
	var request := SoupRequest.new()
	request.status = Enum.RequestStatus.OPEN
	request.time = Time.get_ticks_msec()
	soup_requests.append(request)
	return request

func fulfill_next_request() -> void:
	if soup_requests.is_empty() or soups_available <= 0:
		return
	var req := soup_requests[0] as SoupRequest
	req.status = Enum.RequestStatus.FULFILLED
	soup_requests.erase(req)
	soups_available -= 1

func has_pending_requests() -> bool:
	return not soup_requests.is_empty()

func has_available_soup() -> bool:
	return soups_available > 0

func load_water() -> void:
	water_loaded = true

func load_fuel() -> void:
	fuel_loaded = true

## One water and one fuel cook a full batch; the next batch starts once the pot is empty.
func can_cook_batch() -> bool:
	return water_loaded and fuel_loaded and soups_available == 0

func cook_batch() -> void:
	water_loaded = false
	fuel_loaded = false
	soups_available += SOUP_BATCH_SIZE

func get_sale_price() -> int:
	return SERVICE_PRICE

func _process_requests_timeout() -> void:
	var now := Time.get_ticks_msec()
	var expired: Array[SoupRequest] = []
	for request in soup_requests:
		if now - request.time > TIMEOUT_DURATION_IN_MSEC:
			expired.append(request)
	for request in expired:
		request.status = Enum.RequestStatus.TIMEOUT
		soup_requests.erase(request)

func _physics_process(_delta: float) -> void:
	_process_requests_timeout()

class SoupRequest:
	var time: float
	var status: Enum.RequestStatus
