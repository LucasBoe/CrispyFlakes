extends Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep processing input even when paused
	self.visible = false
	get_tree().paused = false

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause():
	var paused = not get_tree().paused
	get_tree().paused = paused
	self.visible = paused
