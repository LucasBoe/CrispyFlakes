extends RoomBase
class_name RoomBar

var drink_requests = []
var drink_type : Enum.Items = Enum.Items.WATER_BUCKET
var has_faucet: bool = false
var faucet_module = null

const TIMEOUT_DURATION_IN_MSEC = 5000

const _MODULE_DRINK_MAP = {
	"Water": Enum.Items.WATER_BUCKET,
	"Beer": Enum.Items.BEER_BARREL,
	"Whiskey": Enum.Items.WISKEY_BOX,
}

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.BAR
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
	current_module = module
	drink_type = _MODULE_DRINK_MAP.get(module.name, drink_type)

	if Global.NPCSpawner:
		for worker : NPCWorker in Global.NPCSpawner.workers:
			var behaviour = worker.Behaviour as BehaviourModule
			if behaviour.behaviour_instance is not JobBarBehaviour:
				continue
			var bar_job = behaviour.behaviour_instance as JobBarBehaviour
			if bar_job.bar == self:
				bar_job.drinks_available = 0.0

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

func try_receive(item) -> bool:
	item.destroy()
	return true

func request_drink(requestor):
	var request = drink_request.new()
	request.status = Enum.RequestStatus.OPEN
	request.time = Time.get_ticks_msec()
	drink_requests.append(request)
	return request

func fullfill_next_request():
	if drink_requests.size() <= 0:
		return

	var req = drink_requests[0]

	if drink_type == Enum.Items.BEER_BARREL:
		TutorialHandler.try_notify_sold_beer()

	req.status = Enum.RequestStatus.FULFILLED
	drink_requests.erase(req)

func get_sale_price() -> int:
	if current_module == null:
		return 0
	return ceili(float(current_module.item_cost) * 1.5)

func _process(delta):
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
	var time : float
	var status : Enum.RequestStatus
