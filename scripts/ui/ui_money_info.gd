extends Control
class_name UIMoney

const TICK_PUNCH_SCALE := 1.2
const TICK_PUNCH_DURATION := 0.15

@onready var root = $MarginContainer
@onready var count_label = $MarginContainer/CountLabel
@onready var plus_label = $MarginContainer/PlusLabel
@onready var minus_label = $MarginContainer/MinusLabel

var _last_total_money: float = 0.0
var _tick_tween: Tween

func _ready():
	#JobHandler.on_jobs_changed_signal.connect(_on_jobs_changed)
	count_label.pivot_offset = count_label.size / 2.0
	_last_total_money = ResourceHandler.resources[Enum.Resources.MONEY]
	ResourceHandler.on_money_changed_signal.connect(_on_money_changed)
	GlobalEventHandler.on_room_created_signal.connect(_on_room_changed)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_room_changed)

func _on_room_changed(_room = null):
	_on_money_changed()
	
#func _on_jobs_changed():
	#var worker_payments_daily = JobHandler.payment_total
	#minus_label.text = str("-",roundi(worker_payments_daily), "/M")
	
func _on_money_changed():
	var total_money = ResourceHandler.resources[Enum.Resources.MONEY]

	var added_money = 0.0
	for entry in ResourceHandler.money_transaction_history:
		var change := float(entry.get("change", 0.0))
		if change < 0:
			continue
		added_money += change

	plus_label.text = str("+", roundi(added_money), "/M")
	var cap = MoneyHandler.total_capacity()
	count_label.text = str(roundi(total_money), "/", roundi(cap))

	if total_money > _last_total_money:
		_play_tick_punch()
	_last_total_money = total_money

func _play_tick_punch() -> void:
	if _tick_tween:
		_tick_tween.kill()
	count_label.scale = Vector2.ONE * TICK_PUNCH_SCALE
	_tick_tween = create_tween()
	_tick_tween.set_trans(Tween.TRANS_QUAD)
	_tick_tween.set_ease(Tween.EASE_OUT)
	_tick_tween.tween_property(count_label, "scale", Vector2.ONE, TICK_PUNCH_DURATION)

func get_label_relative_position(camera : Camera2D):
	
	var ui_pos = (root.global_position + root.size / 2)
	return 	Util.ui_to_world_position(ui_pos, self, camera)
