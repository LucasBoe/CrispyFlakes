extends RoomBase
class_name RoomBrewery

var faucet_module = null
var has_faucet: bool = false

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.BREWERY
	GlobalEventHandler.on_room_created_signal.connect(_on_room_created)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_room_deleted)
	_refresh_faucet_state()

func _on_module_bought(module) -> void:
	if module.name == "Faucet":
		faucet_module = module
		_refresh_faucet_state()
		return
	if module.bought:
		current_module = module

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
