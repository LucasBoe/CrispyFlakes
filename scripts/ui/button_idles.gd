extends Button

func _ready():
	JobHandler.on_jobs_changed_signal.connect(_on_jobs_changed)
	pressed.connect(_select_next_idle)
	
func _on_jobs_changed():
	var idles = JobHandler.count_workers_in(Enum.Jobs.IDLE)
	text = str(idles)
	visible = idles > 0

func _select_next_idle():
	var idle = Global.NPCSpawner.workers.filter(func(w:NPCWorker):return w.current_job == Enum.Jobs.IDLE).pick_random()
	%Camera.zoomTarget = 2.0
	%Camera.zoom_in_out(true, 0.1)
	%Camera.position = idle.position
	await %Camera.tween_offset_to_zero().finished
	Global.UI.selection.manually_select(idle)
