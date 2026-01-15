extends RoomEmpty
class_name RoomBath

@onready var progressBar : TextureProgressBar = $ProgressBar

var customers = []
var has_customer
signal customer_arrive

func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
	progressBar.visible = false
	associatedJob = Enum.Jobs.BATH

func clean_customer():
	var customer = customers[0]
	customer.npc.clean()
	customers.erase(customer)
	has_customer = customers.size() > 0

func register_as_customer(customer):
	customers.append(customer)
	has_customer = true
	customer_arrive.emit()
