extends NPC
class_name NPCGuest

var manual_behaviour = false

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
		
	var newBehaviour = IdleBehaviour
		
	if not manual_behaviour:
		newBehaviour = get_next_behaviour()
		
	Behaviour.set_behaviour(newBehaviour)
	
func get_next_behaviour():
	
	if Needs.satisfaction.strength <= 0.0 or Needs.stay_duration.strength > 3.0:
		return NeedLeaveBehaviour
	
	return Behaviour.get_behaviour_from_available_rooms(Global.Building.get_all_rooms_of_type(RoomBase))
	
func try_drop_dirt():
	if not dirt.get_child(0).visible:
		return
		
	if randf() < .8:
		return
		
	DirtHandler.create_dirt_at(global_position)

func clean():
	is_dirty = false
	sprite.modulate = Color.WHITE
	Needs.satisfaction.strength += 0.3
