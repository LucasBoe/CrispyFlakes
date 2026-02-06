extends Node
class_name NeedsModule

var Money : Need
var Mood : Need
var Drunkenness : Need
var Energy : Need

var needs = []

var npc

func _ready():
	Money = new_need(Enum.Need.MONEY)
	Mood = new_need(Enum.Need.HAPPY)
	Drunkenness = new_need(Enum.Need.DRUNK)
	Energy = new_need(Enum.Need.ENERGY)
	
	Money.strength = randf_range(0.2, 1.0)
	Mood.strength = randf_range(0.3, 1.0)
	Drunkenness.strength = randf_range(0.0, 0.2)
	Energy.strength = randf_range(0.5, 1.0)
	
	npc = get_parent() as NPCGuest
	if npc:
		pass
		
	npc.Needs = self
	
func new_need(type):
	var instance = Need.new()
	instance.type = type
	needs.append(instance)
	add_child(instance)
	return instance

func get_behaviour_from_needs():
	var all = []
	#try_add(all, IdleBehaviour, "Idle")
	try_add(all, NeedLeaveBehaviour, "Leave")
	try_add(all, NeedDrinkingBehaviour, "Drinking")
	try_add(all, NeedCleaningBehaviour, "Cleaning")
	var pick = all.pick_random();
	return pick;

func try_add(all, type, name):
	var probability : int = type.get_probability_by_needs(self) * 100
	var str = type_string(typeof(type));
	
	print(name, " probabilit: ", probability, "%")
	
	for i in probability:
		all.append(type)
