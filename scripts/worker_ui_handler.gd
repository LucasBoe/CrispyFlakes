extends MenuUITab

@onready var container_label = $MarginContainer/MarginContainer/GridContainer/Label
@onready var hire_button = $MarginContainer/MarginContainer/GridContainer/Button
@onready var payment_progress_bar = $MarginContainer/MarginContainer/GridContainer/HBoxContainer/ProgressBar
@onready var payment_height_label = $MarginContainer/MarginContainer/GridContainer/HBoxContainer/Label

func _ready():
	JobHandler.on_jobs_changed_signal.connect(_on_jobs_changed)
	hire_button.pressed.connect(%UIHire.show)

func _on_jobs_changed():
	var str = ""
	
	for job in JobHandler.workers.keys():
		for worker in JobHandler.workers[job]:
			str += str(Enum.Jobs.keys()[job], " - ", worker.salary, "$\n")
	
	container_label.text = str;
	payment_height_label.text = str(JobHandler.payment_total, "$")

func _process(delta):
	payment_progress_bar.value = JobHandler.payment_cycle_progression
