extends Node

var workers : Dictionary[Enum.Jobs, Array]

var payment_total = 0
var payment_cycle_progression = 0.0
var payment_cycle_duration = 60.0

signal on_jobs_changed_signal

func on_job_changed(npc : NPCWorker, previous_job, new_job):
	
	if npc is not NPCWorker:
		return
	
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
	payment_cycle_progression += delta / payment_cycle_duration
	if payment_cycle_progression >= 1.0:
		payment_cycle_progression = 0.0
		execute_payments()

func execute_payments():			
	ResourceHandler.change_money(-payment_total)
