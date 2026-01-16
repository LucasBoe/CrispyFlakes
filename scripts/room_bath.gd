extends RoomEmpty
class_name RoomBath

@onready var progressBar : TextureProgressBar = $ProgressBar

var customers = []
var has_customer
signal customer_arrive

var wash_requests = []

func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
	progressBar.visible = false
	associatedJob = Enum.Jobs.BATH

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
