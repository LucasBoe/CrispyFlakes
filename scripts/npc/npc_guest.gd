extends NPC
class_name NPCGuest

var Needs : NeedsModule

func _process(delta):
		
	if Behaviour.has_behaviour:
		return
		
	var newBehaviour = Needs.get_behaviour_from_needs()
	Behaviour.set_behaviour(newBehaviour)
	
