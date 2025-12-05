extends Node

var workers : Dictionary[Enum.Jobs, Array]
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
	on_jobs_changed_signal.emit()

func _process(delta):
	print_debug(workers)
