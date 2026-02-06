extends MenuUITab

@onready var hire_button = $MarginContainer/MarginContainer/GridContainer/Button
@onready var payment_progress_bar = $MarginContainer/MarginContainer/GridContainer/HBoxContainer/ProgressBar
@onready var payment_height_label = $MarginContainer/MarginContainer/GridContainer/HBoxContainer/Label

@onready var worker_info_dummy : WorkerUIInfo = $MarginContainer/MarginContainer/GridContainer/VBoxContainer/HBoxContainer
@onready var worker_ui_add_remove_dummy : WorkerUIAddRemove = $MarginContainer/MarginContainer/GridContainer/WorkerUIAddRemove

func _ready():
	JobHandler.on_jobs_changed_signal.connect(_on_jobs_changed)
	
	for key in Enum.Jobs.keys():
		var instance = worker_ui_add_remove_dummy.duplicate()
		worker_ui_add_remove_dummy.get_parent().add_child(instance)
		instance.init(key) 
		
	worker_info_dummy.hide()
	worker_ui_add_remove_dummy.hide()
	
	await get_tree().process_frame
	
	hire_button.pressed.connect(Global.UI.hire.show)
	visibility_changed.connect(_on_visibility_changed)
		
func _on_visibility_changed():
	if not visible:
		return

func _on_jobs_changed():
	var p = worker_info_dummy.get_parent()
	Util.delete_all_children_execept_index_0(p)
	
	for job_type in JobHandler.workers.keys():
		for worker in JobHandler.workers[job_type]:
			var job = Enum.Jobs.keys()[job_type]
			var name = worker.character_name
			var cost = worker.salary
			var clone = worker_info_dummy.duplicate()
			p.add_child(clone)
			clone.name_label.text = str(job, " - ", name, " - ", cost)
			clone.button_fire.pressed.connect(JobHandler.fire_worker.bind(worker))
			clone.show()
	
	payment_height_label.text = str("-", JobHandler.payment_total, "$ / D")

func _process(delta):
	payment_progress_bar.value = JobHandler.payment_cycle_progression
