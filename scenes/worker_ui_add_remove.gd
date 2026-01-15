extends HBoxContainer

@onready var job_name_label = $Label
@onready var worker_amount_label = $Label2
@onready var remove_button = $Button
@onready var add_button = $Button2

var associated_job : Enum.Jobs

func init(job):
	associated_job = Enum.Jobs[job]
	
	job_name_label.text = str(job)
	
	if associated_job == Enum.Jobs.IDLE:
		add_button.disabled = true
		remove_button.disabled = true
	else:
		add_button.pressed.connect(_try_add_worker)
		remove_button.pressed.connect(_try_remove_worker)
	
	refresh_amount()
	JobHandler.on_jobs_changed_signal.connect(_on_jobs_changed)
	
func _try_add_worker():
	SoundPlayer.mouse_click_down.play()
	JobHandler.add_more_people_to_job(associated_job)
	
func _try_remove_worker():
	SoundPlayer.mouse_click_down.play()
	JobHandler.remove_people_from_job(associated_job)

func _on_jobs_changed():
	refresh_amount()
	
func refresh_amount():
	var amount = JobHandler.count_workers_in(associated_job)
	worker_amount_label.text = str(amount)
	
	if associated_job == Enum.Jobs.IDLE:
		return
	
	add_button.disabled = JobHandler.count_workers_in(Enum.Jobs.IDLE) <= 0
	remove_button.disabled = amount <= 0
