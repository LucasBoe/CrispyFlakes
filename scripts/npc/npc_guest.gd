extends NPC
class_name NPCGuest

var Needs : NeedsModule
var is_dirty = true

@onready var sprite = $AnimationModule
@onready var dirt = $AnimationModule/Dirt

func _ready():
	super._ready()
	sprite.modulate = Color.GRAY
	while is_dirty:
		try_drop_dirt()
		await get_tree().create_timer(1).timeout

func _process(delta):
	
	dirt.get_child(0).visible = is_dirty and Navigation.is_moving
		
	if Behaviour.has_behaviour:
		return
		
	var newBehaviour = Needs.get_behaviour_from_needs()
	print_debug("set behaviour to ", newBehaviour.get_global_name())
	Behaviour.set_behaviour(newBehaviour)
	
func try_drop_dirt():
	if not dirt.get_child(0).visible:
		return
		
	if randf() < .8:
		return
		
	DirtHandler.create_dirt_at(global_position)

func clean():
	is_dirty = false
	sprite.modulate = Color.WHITE
