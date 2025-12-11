extends Node

var workers : Dictionary[Enum.Jobs, Array]

var payment_total = 0
var payment_cycle_progression = 0.0

signal on_jobs_changed_signal

func on_job_changed(npc : NPCWorker, previous_job, new_job):
	
	if npc is not NPCWorker:
		return
		
	if previous_job == null:
		for job in workers.keys():
			for worker in workers[job]:
				if npc == worker:
					previous_job = job
		
	print_debug("npc ", npc.get_script().get_global_name(), " changed job from ",previous_job ," to ", new_job)
	
	if workers.has(previous_job):
		workers[previous_job].erase(npc)
		if workers[previous_job].size() == 0:
			workers.erase(previous_job)
		
	if not workers.has(new_job):
		workers[new_job] = []
		
	workers[new_job].append(npc)
	
	payment_total = 0
	for w in workers.values():
		for worker in w:
			payment_total += worker.salary

	on_jobs_changed_signal.emit()
	
func _process(delta):
	payment_cycle_progression += delta / Global.DAY_DURATION
	if payment_cycle_progression >= 1.0:
		payment_cycle_progression = 0.0
		execute_payments()

func execute_payments():			
	ResourceHandler.change_money(-payment_total)
