extends RoomBase
class_name RoomBar

@onready var progressBar : TextureProgressBar = $ProgressBar
@onready var bar_sprite : Sprite2D = $Bar
@onready var bar_texture_water = preload("res://assets/sprites/bar_water.png")
@onready var bar_texture_beer = preload("res://assets/sprites/bar_beer.png")
@onready var bar_texture_wiskey = preload("res://assets/sprites/bar_wiskey.png")
var drink_requests = []

var current_upgrade = null
@onready var upgrades = [preload("res://assets/resources/room_bar_water.tres"), preload("res://assets/resources/room_bar_beer.tres"), preload("res://assets/resources/room_bar_wiskey.tres")]
@export var drink_type : Enum.Items

const TIMEOUT_DURATION_IN_MSEC = 5000

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	has_upgrades = true
	associated_job = Enum.Jobs.BAR
	progressBar.visible = false
	try_set_upgrade(upgrades[0])

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

	# tutorial stuff
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
		var dif = t - request.time
		if dif > TIMEOUT_DURATION_IN_MSEC:
			done.append(request)

	for d in done:
		d.status = Enum.RequestStatus.TIMEOUT
		drink_requests.erase(d)

func try_set_upgrade(upgrade : RoomUpgrade):

	if upgrade == current_upgrade:
		return

	if not ResourceHandler.has_money(upgrade.upgrade_price):
		return

	ResourceHandler.change_money(-upgrade.upgrade_price)
	current_upgrade = upgrade
	drink_type = upgrade.opt_associated_item

	if drink_type == Enum.Items.WATER_BUCKET:
		bar_sprite.texture = bar_texture_water
	elif drink_type == Enum.Items.BEER_BARREL:
		bar_sprite.texture = bar_texture_beer
	else:
		bar_sprite.texture = bar_texture_wiskey

	if Global.NPCSpawner:
		for worker : NPCWorker in Global.NPCSpawner.workers:
			var behaviour = worker.Behaviour as BehaviourModule
			if behaviour.behaviour_instance is not JobBarBehaviour:
				continue

			var bar_job = (behaviour.behaviour_instance as JobBarBehaviour)
			if bar_job.bar == self:
				bar_job.drinks_available = 0.0

class drink_request:
	var time : float
	var status : Enum.RequestStatus
