extends RoomEmpty
class_name RoomBar

@onready var progressBar : TextureProgressBar = $ProgressBar
var drinkRequests = []

@export var drink_type : Enum.Items

const TIMEOUT_DURATION_IN_MSEC = 5000

func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
	associatedJob = Enum.Jobs.BAR
	progressBar.visible = false

func TryReceive(item) -> bool:
	item.Destroy()
	return true

func request_drink(requestor):
	var request = drink_request.new()
	request.status = Enum.RequestStatus.OPEN
	request.time = Time.get_ticks_msec()
	drinkRequests.append(request)
	return request
	
func fullfill_next_request():
	var req = drinkRequests[0]
	
	req.status = Enum.RequestStatus.FULFILLED
	drinkRequests.erase(req)
	
func _process(delta):
	var t = Time.get_ticks_msec()
	
	var done = []
	
	for request in drinkRequests:
		var dif = t - request.time
		print(dif)
		if dif > TIMEOUT_DURATION_IN_MSEC:
			done.append(request)
			
	for d in done:
		d.status = Enum.RequestStatus.TIMEOUT
		drinkRequests.erase(d)

class drink_request:	
	var time : float 
	var status : Enum.RequestStatus
