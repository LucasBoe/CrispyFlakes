extends Behaviour
class_name StartupWaitBehaviour


func start_loop() -> void:
	_narrative = "Waiting for instructions..."


func loop() -> void:
	while not stopped and is_instance_valid(npc):
		if npc is NPCWorker and (npc as NPCWorker).current_job != Enum.Jobs.IDLE:
			return
		await end_of_frame()
