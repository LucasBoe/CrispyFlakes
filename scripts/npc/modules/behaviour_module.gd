extends Node

class_name BehaviourModule

@onready var behaviourHost = $Host;
const script_idle = preload("res://scripts/npc/behaviours/idle_behaviour.gd")
const script_brewery = preload("res://scripts/npc/behaviours/brewery_behaviour.gd")
const script_bar = preload("res://scripts/npc/behaviours/bar_behaviour.gd")

var npc;
var has_behaviour = false

func _ready():
	npc = get_parent() as NPC
	if npc:
		pass
		
	npc.Behaviour = self

func set_behaviour_from_job(job : Enum.Jobs):
	var script
	
	if has_behaviour:
		script = behaviourHost.get_script()
		if script is Behaviour:
			script.isRunning = false
	
	match job:
		
		Enum.Jobs.IDLE:
			script = script_idle
		
		Enum.Jobs.BREWERY:
			script = script_brewery
			
		Enum.Jobs.BAR:
			script = script_bar
	
	if script:
		pass
	
	behaviourHost.set_script(script)
	(behaviourHost as Behaviour).npc = npc
	behaviourHost.set_process(true)
	has_behaviour = true
	
