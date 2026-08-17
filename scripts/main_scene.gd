extends Node

func _ready() -> void:
	Building.visible = true
	if SaveHandler.has_pending_load():
		SaveHandler.load_pending()
	else:
		StartupCoordinator.begin()
