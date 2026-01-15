extends MenuUITab

@onready var container_label = $MarginContainer/MarginContainer/GridContainer/Label
@onready var hire_button = $MarginContainer/MarginContainer/GridContainer/Button
@onready var payment_progress_bar = $MarginContainer/MarginContainer/GridContainer/HBoxContainer/ProgressBar
@onready var payment_height_label = $MarginContainer/MarginContainer/GridContainer/HBoxContainer/Label

@onready var worker_ui_add_remove_dummy = $MarginContainer/MarginContainer/GridContainer/WorkerUIAddRemove

func _ready():
	JobHandler.on_jobs_changed_signal.connect(_on_jobs_changed)
	hire_button.pressed.connect(%UIHire.show)
	
	for key in Enum.Jobs.keys():
		var instance = worker_ui_add_remove_dummy.duplicate()
		worker_ui_add_remove_dummy.get_parent().add_child(instance)
		instance.init(key)
		
	worker_ui_add_remove_dummy.hide()
		

func _on_jobs_changed():
	var str = ""
	
	for job_type in JobHandler.workers.keys():
		for worker in JobHandler.workers[job_type]:
			var job = Enum.Jobs.keys()[job_type]
			var name = worker.character_name
			var cost = worker.salary
			str += str(name, " - ", job , " - ", cost, "$\n")
	
	container_label.text = str;
	payment_height_label.text = str(JobHandler.payment_total, "$ / D")

func _process(delta):
	payment_progress_bar.value = JobHandler.payment_cycle_progression
