extends RoomEmpty
class_name RoomBar

@onready var progressBar : TextureProgressBar = $ProgressBar
var drinkRequests : Dictionary

func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
	associatedJob = Enum.Jobs.BAR
	progressBar.visible = false

func TryReceive(item) -> bool:
	item.Destroy()
	return true

func request_drink(requestor):
	drinkRequests[requestor] = null
	
func has_drink(requestor):
	return drinkRequests.has(requestor) && drinkRequests[requestor] != null
	
func pick_up_drink(requestor) -> Item:
	var item = drinkRequests[requestor]
	drinkRequests.erase(requestor)
	return item
