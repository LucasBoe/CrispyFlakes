extends MenuUITab

@onready var container_label = $MarginContainer/MarginContainer/GridContainer/Label

func _ready():
	JobHandler.on_jobs_changed_signal.connect(_on_jobs_changed)

func _on_jobs_changed():
	var str = ""
	
	for job in JobHandler.workers.keys():
		str = str(str, Enum.Jobs.keys()[job], " (",JobHandler.workers[job].size(),")\n")
	
	container_label.text = str;
