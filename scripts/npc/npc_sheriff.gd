extends NPC
class_name NPCSheriff

func _ready():
	super._ready()

func _process(_delta):
	if Behaviour != null and not Behaviour.has_behaviour:
		Behaviour.set_behaviour(CollectBountiesBehaviour)
