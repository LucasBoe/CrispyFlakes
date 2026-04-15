extends Area2D

class_name NPC

const STATE_LABEL_FIGHT := "Fighting"

var Animator : AnimationModule;
var Tint : TintModule
var Navigation : NavigationModule
var Behaviour : BehaviourModule
var Item : ItemModule


var look_info : NPCLookInfo
var strength: float = 0.5
var agility: float = 0.5
var intelligence: float = 0.5
var stamina: float = 1.0
var health: float = 1.0

var _status_icon_instance = null
var _status_icon_texture = null

const STAMINA_DRAIN = 0.08
const STAMINA_REGEN = 0.05

func _init():
	Tint = TintModule.new(self)

func _ready():
	strength = randf_range(0.3, 1.0)
	agility = randf_range(0.3, 1.0)
	intelligence = randf_range(0.3, 1.0)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
		
func _on_mouse_entered():
	HoverHandler.notify_hover_enter(self)
	
func _on_mouse_exited():
	HoverHandler.notify_hover_exit(self)
		
func _process(delta):
	var in_fight = is_in_fight_state()
	if in_fight:
		stamina = max(0.0, stamina - STAMINA_DRAIN * delta)
	else:
		stamina = min(1.0, stamina + STAMINA_REGEN * delta)
	_refresh_status_icon()

func _exit_tree():
	UiNotifications.try_kill(_status_icon_instance)
	_status_icon_instance = null
	_status_icon_texture = null

func is_in_fight_state() -> bool:
	return Behaviour != null and (Behaviour.behaviour_instance is FightBehaviour or Behaviour.behaviour_instance is StopFightBehaviour)

func get_state_icon_entries() -> Array:
	var entries := []
	var b = Behaviour.behaviour_instance

	if b is KnockedOutBehaviour:
		var secs = int((b as KnockedOutBehaviour).time_remaining)
		entries.append({icon = UiNotifications.ICON_KNOCKED_OUT, label = "Knocked out (%ds)" % secs})

	if is_in_fight_state():
		entries.append({icon = UiNotifications.ICON_FIGHT, label = STATE_LABEL_FIGHT})

	_append_state_icon_entries(entries)
	return entries

func get_primary_state_icon():
	for entry in get_state_icon_entries():
		if entry.has("icon"):
			return entry.icon
	return null

func _append_state_icon_entries(_entries: Array) -> void:
	pass

func _refresh_status_icon():
	var icon = get_primary_state_icon()

	if icon == _status_icon_texture:
		return

	UiNotifications.try_kill(_status_icon_instance)
	_status_icon_instance = null
	_status_icon_texture = icon

	if icon != null:
		_status_icon_instance = UiNotifications.create_npc_notification(self, icon, true)

func click_on():
	print("npc click")
	
func force_behaviour(new_behaviour): 
	return Behaviour.set_behaviour(new_behaviour)

func destroy():
	NPCEventHandler.on_destroy_npc_signal.emit(self)
	queue_free()
