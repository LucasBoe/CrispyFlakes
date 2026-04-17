extends Control
class_name UIMoney

@onready var root = $MarginContainer
@onready var count_label = $MarginContainer/CountLabel
@onready var plus_label = $MarginContainer/PlusLabel
@onready var minus_label = $MarginContainer/MinusLabel

func _ready():
	JobHandler.on_jobs_changed_signal.connect(_on_jobs_changed)
	ResourceHandler.on_money_changed.connect(_on_money_changed)
	GlobalEventHandler.on_room_created_signal.connect(_on_room_changed)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_room_changed)

func _on_room_changed(_room = null):
	_on_money_changed()
	
func _on_jobs_changed():
	var worker_payments_daily = JobHandler.payment_total
	minus_label.text = str("-",roundi(worker_payments_daily), "/M")
	
func _on_money_changed():
	var total_money = ResourceHandler.resources[Enum.Resources.MONEY]

	var added_money = 0.0
	for change in ResourceHandler.money_transaction_history.values():
		if change < 0:
			continue
		added_money += change

	plus_label.text = str("+", roundi(added_money), "/M")
	var cap = MoneyHandler.total_capacity()
	count_label.text = str(roundi(total_money), "/", roundi(cap))
	
func get_label_relative_position(camera : Camera2D):
	
	var ui_pos = (root.global_position + root.size / 2)
	return 	Util.ui_to_world_position(ui_pos, self, camera)
