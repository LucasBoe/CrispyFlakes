extends RoomBase
class_name RoomBar

var drink_requests = []
var drink_type : Enum.Items = Enum.Items.WATER_BUCKET
var current_module = null
var has_faucet: bool = false

const TIMEOUT_DURATION_IN_MSEC = 5000

const _MODULE_DRINK_MAP = {
	"Water": Enum.Items.WATER_BUCKET,
	"Beer": Enum.Items.BEER_BARREL,
	"Whiskey": Enum.Items.WISKEY_BOX,
}

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.BAR

	var modules_root = get_node_or_null("ModulesRoot")
	if modules_root:
		for group in modules_root.get_children():
			for module in group.get_children():
				module.bought_changed.connect(_on_module_bought)
				if module.bought:
					if module.name == "Faucet":
						has_faucet = true
					else:
						current_module = module
						drink_type = _MODULE_DRINK_MAP.get(module.name, drink_type)

func _on_module_bought(module) -> void:
	if not module.bought:
		return
	if module.name == "Faucet":
		has_faucet = true
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
