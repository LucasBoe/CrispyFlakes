extends NPC
class_name NPCGuest

const NeedSleepBehaviourScript = preload("res://scripts/npc/behaviours/need_sleep_behaviour.gd")

var manual_behaviour = false
var pending_arrest: bool = false
var is_known_fugitive: bool = false

var needs_to_pee: float = 0.0
const PEE_RATE: float = 0.01

var _arrest_highlight = null
var _arrest_highlight_room = null

var Needs : NeedsModule
var is_dirty = true

@onready var dirt = $AnimationModule/Dirt

func init(custom_look = null):
	needs_to_pee = randf()
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

func _exit_tree():
	super._exit_tree()
	_clear_arrest_highlight()

func _process(_delta):
	super._process(_delta)

	needs_to_pee = minf(needs_to_pee + PEE_RATE * _delta, 1.0)
	dirt.get_child(0).visible = is_dirty and Navigation.is_moving
	_refresh_arrest_highlight()

	if Behaviour.has_behaviour:
		return

	var new_behaviour = IdleBehaviour

	if not manual_behaviour:
		new_behaviour = get_next_behaviour()

	Behaviour.set_behaviour(new_behaviour)

func _append_state_icon_entries(entries: Array) -> void:
	var b = Behaviour.behaviour_instance
	var bounty = BountyHandler.get_bounty_for(self)
	var bounty_info = " 0$" if bounty == null else str(" ", bounty, "$")
	var is_arrested = b is ArrestedBehaviour
	var has_bounty = bounty != null

	if pending_arrest:
		entries.append({icon = UiNotifications.ICON_HANDCUFFS, label = "Marked for Arrest (Drop Worker)"})
	if is_arrested:
		entries.append({icon = UiNotifications.ICON_HANDCUFFED, label = "Arrested (Call Sherrif)"})
	if has_bounty or is_known_fugitive:
		var bounty_label = str("Has Bounty (", bounty_info, ")") if has_bounty else "Known Fugitive"
		entries.append({icon = UiNotifications.ICON_FUGITIVE, label = bounty_label})
	elif pending_arrest or is_arrested:
		entries.append({label = "Has No Bounty or Fine"})

func counts_towards_guest_total() -> bool:
	var behaviour = Behaviour.behaviour_instance
	return not (behaviour is ArrestedBehaviour or behaviour is FollowSheriffBehaviour)

func get_next_behaviour():

	if pending_arrest:
		return IdleBehaviour

	if Needs.satisfaction.strength <= 0.0 or Needs.stay_duration.strength > 10.0:
		return NeedLeaveBehaviour

	if Needs.drunkenness.strength > randf():
		return PukeBehaviour

	if Needs.drunkenness.strength > randf():
		return FightBehaviour

	if (1.0 - Needs.Energy.strength) > randf():
		return NeedSleepBehaviourScript

	if needs_to_pee > randf():
		return UseOuthouseBehaviour

	return Behaviour.get_behaviour_from_available_rooms(Building.query.all_rooms_of_type(RoomBase))

func _refresh_arrest_highlight():
	var in_fight = is_in_fight_state()
	if pending_arrest and not in_fight:
		var current_room = Building.query.room_at_position(global_position)
		if current_room != _arrest_highlight_room:
			_clear_arrest_highlight()
			_arrest_highlight_room = current_room
			if current_room != null:
				_arrest_highlight = RoomHighlighter.request_rect(current_room, Color.YELLOW, 2, RoomHighlighter.Priority.ARREST)
	else:
		_clear_arrest_highlight()

func _clear_arrest_highlight():
	if _arrest_highlight != null:
		RoomHighlighter.dispose(_arrest_highlight)
		_arrest_highlight = null
		_arrest_highlight_room = null

func try_drop_dirt():
	if not dirt.get_child(0).visible:
		return

	if randf() < .8:
		return

	DirtHandler.create_dirt_at(global_position)

func clean():
	is_dirty = false
	Tint.remove_tint_for(self)
	add_satisfaction(0.3)

func add_satisfaction(amount: float):
	Needs.satisfaction.strength += amount
	if amount > 0.5:
		notify(UiNotifications.ICON_PLUS_3)
	elif amount > 0.25:
		notify(UiNotifications.ICON_PLUS_2)
	else:
		notify(UiNotifications.ICON_PLUS_1)

func notify(tex):
	UiNotifications.create_npc_notification(self, tex)
