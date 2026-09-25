extends Node

func _ready() -> void:
	Building.visible = true
	RoomStatusHandler.enabled = true
	if SaveHandler.has_pending_load():
		SaveHandler.load_pending()
	else:
		SaveHandler.played_seconds = 0.0
		SaveHandler.active_save_path = ""
		StartupCoordinator.begin()
