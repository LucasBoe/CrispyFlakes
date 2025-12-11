extends Node
class_name NeedsModule

var Money : Need
var Mood : Need
var Drunkenness : Need
var Energy : Need

var npc

func _ready():
	Money = new_need()
	Mood = new_need()
	Drunkenness = new_need()
	Energy = new_need()
	
	Money.Strength = randf_range(0.2, 1.0)
	Mood.Strength = randf_range(0.3, 1.0)
	Drunkenness.Strength = randf_range(0.0, 0.2)
	Energy.Strength = randf_range(0.5, 1.0)
	
	npc = get_parent() as NPCGuest
	if npc:
		pass
		
	npc.Needs = self
	
func new_need():
	var instance = Need.new()
	add_child(instance)
	return instance

func get_behaviour_from_needs():
	var all = []
	try_add(all, IdleBehaviour, "Idle")
	try_add(all, NeedLeaveBehaviour, "Leave")
	try_add(all, NeedDrinkingBehaviour, "Drinking")
	var pick = all.pick_random();
	return pick;

func try_add(all, type, name):
	var probability : int = type.get_probability_by_needs(self) * 100
	var str = type_string(typeof(type));
	
	print(name, " probabilit: ", probability, "%")
	
	for i in probability:
		all.append(type)
