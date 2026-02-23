extends Node
class_name NeedsModule

var satisfaction : Need
var stay_duration : Need
var passive_satisfaction_loss : Need
var drunkenness : Need

var needs = []

var npc

func _ready():
	satisfaction = new_need(Enum.Need.SATISFACTION, 0.5)
	stay_duration = new_need(Enum.Need.STAY_DURATION, 0.0)
	passive_satisfaction_loss = new_need(Enum.Need.PASSIVE_SATISFACTION_LOSS, 0.0)
	drunkenness = new_need(Enum.Need.DRUNKENNESS, 0.0)
	
	npc = get_parent() as NPCGuest
	if npc:
		pass
		
	npc.Needs = self
	
func new_need(type, strength):
	var instance = Need.new()
	instance.type = type
	instance.strength = strength
	needs.append(instance)
	add_child(instance)
	return instance

#func get_behaviour_from_needs():
	#var all = []
	##try_add(all, IdleBehaviour, "Idle")
	#try_add(all, NeedLeaveBehaviour, "Leave")
	#try_add(all, NeedDrinkingBehaviour, "Drinking")
	#try_add(all, NeedCleaningBehaviour, "Cleaning")
	#var pick = all.pick_random();
	#return pick;
#
#func try_add(all, type, name):
	#var probability : int = type.get_probability_by_needs(self) * 100
	#var str = type_string(typeof(type));
	#
	#print(name, " probabilit: ", probability, "%")
	#
	#for i in probability:
		#all.append(type)

func _process(delta):
	var delta_minute = delta / 60.0

	stay_duration.strength += delta_minute

	var max_loss := 2.0        # cap (per minute)
	var ramp := 0.25        # how fast it approaches the cap

	# diminishing returns: grows fast at first, then slows as it gets higher
	passive_satisfaction_loss.strength += (max_loss - passive_satisfaction_loss.strength) * ramp * delta_minute

	satisfaction.strength -= passive_satisfaction_loss.strength * delta_minute
