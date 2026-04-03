extends NPC
class_name NPCGuest

var manual_behaviour = false
var pending_arrest: bool = false:
	set(value):
		pending_arrest = value
		if value:
			_pending_arrest_notification = UiNotifications.create_npc_notification(self, UiNotifications.ICON_HANDCUFFS, true)
		else:
			UiNotifications.try_kill(_pending_arrest_notification)
			_pending_arrest_notification = null

var _pending_arrest_notification = null

var Needs : NeedsModule
var is_dirty = true

@onready var dirt = $AnimationModule/Dirt

func init(custom_look = null):
	apply_look(custom_look)
	while is_dirty:
		try_drop_dirt()
		await get_tree().create_timer(1).timeout

func _ready():
	super._ready()

func apply_look(custom_look = null):
	var mat := Animator.material as ShaderMaterial
	if mat == null:
		return

	if custom_look:
		look_info = custom_look
	else:
		look_info = NPCLookInfo.new_random()

	mat.set_shader_parameter("base_hue_offset", look_info.color_offsets)
	mat.set_shader_parameter("sprite_index", Vector2(look_info.head_index.x, look_info.head_index.y))

func _process(_delta):

	dirt.get_child(0).visible = is_dirty and Navigation.is_moving

	if Behaviour.has_behaviour:
		return

	var new_behaviour = IdleBehaviour

	if not manual_behaviour:
		new_behaviour = get_next_behaviour()

	Behaviour.set_behaviour(new_behaviour)

func get_next_behaviour():

	if pending_arrest:
		return IdleBehaviour

	if Needs.satisfaction.strength <= 0.0 or Needs.stay_duration.strength > 10.0:
		return NeedLeaveBehaviour

	var f = randf()
	var s = Needs.drunkenness.strength

	if s > f:
		return FightBehaviour

	return Behaviour.get_behaviour_from_available_rooms(Global.Building.query.all_rooms_of_type(RoomBase))

func try_drop_dirt():
	if not dirt.get_child(0).visible:
		return

	if randf() < .8:
		return

	DirtHandler.create_dirt_at(global_position)

func clean():
	is_dirty = false
	Tint.remove_tint_for(self)
	Needs.satisfaction.strength += 0.3
	notify(UiNotifications.ICON_PLUS_2)

func notify(tex):
	UiNotifications.create_npc_notification(self, tex)
