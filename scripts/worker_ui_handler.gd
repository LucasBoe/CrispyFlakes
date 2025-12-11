extends MenuUITab

@onready var container_label = $MarginContainer/MarginContainer/GridContainer/Label
@onready var hire_button = $MarginContainer/MarginContainer/GridContainer/Button

func _ready():
	JobHandler.on_jobs_changed_signal.connect(_on_jobs_changed)
	hire_button.pressed.connect(%UIHire.show)

func _on_jobs_changed():
	var str = ""
	
	for job in JobHandler.workers.keys():
		str = str(str, Enum.Jobs.keys()[job], " (",JobHandler.workers[job].size(),")\n")
	
	container_label.text = str;
