extends Control

@onready var buttonToggle : Button = $Button
@onready var container = $MarginContainer
@onready var container_label = $MarginContainer/MarginContainer/GridContainer/Label

func _ready():
	toggle_button_visibility()
	buttonToggle.pressed.connect(toggle_button_visibility)
	JobHandler.on_jobs_changed_signal.connect(_on_jobs_changed)
	
func toggle_button_visibility():
	container.visible = !container.visible
	(SoundPlayer.mouse_click_down if container.visible else SoundPlayer.mouse_click_up).play()

func _on_jobs_changed():
	var str = ""
	
	for job in JobHandler.workers.keys():
		str = str(str, Enum.Jobs.keys()[job], " (",JobHandler.workers[job].size(),")\n")
	
	container_label.text = str;
