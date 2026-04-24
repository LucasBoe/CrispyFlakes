extends Area2D

class_name NPC

const STATE_LABEL_FIGHT := "Fighting"

var Animator : AnimationModule;
var Tint : TintModule
var Navigation : NavigationModule
var Behaviour : BehaviourModule
var Item : ItemModule


var Equipment: EquipmentModule
var Traits: TraitModule

var look_info : NPCLookInfo
var strength: float = 0.5
var agility: float = 0.5
var intelligence: float = 0.5
var energy: float = 1.0

var _status_icon_instance = null
var _status_icon_texture = null

func _init():
	Tint = TintModule.new(self)
	Equipment = EquipmentModule.new(self)
	Traits = TraitModule.new(self)

func _ready():
	strength = randf_range(0.3, 1.0)
	agility = randf_range(0.3, 1.0)
	intelligence = randf_range(0.3, 1.0)
	Traits.ensure_traits()
	restore_energy()

func _process(_delta):
	_refresh_status_icon()

func _exit_tree():
	UiNotifications.try_kill(_status_icon_instance)
	_status_icon_instance = null
	_status_icon_texture = null

func is_in_fight_state() -> bool:
	if Behaviour == null:
		return false

	var behaviour = Behaviour.behaviour_instance
	if behaviour is FightBehaviour:
		if (behaviour as FightBehaviour).fight:
			return (behaviour as FightBehaviour).fight.has_started
	return false

func get_state_icon_entries() -> Array:
	var entries := []
	var b = Behaviour.behaviour_instance

	if b is KnockedOutBehaviour:
		var secs = int((b as KnockedOutBehaviour).time_remaining)
		entries.append({icon = UiNotifications.ICON_KNOCKED_OUT, label = "Knocked out (%ds)" % secs})

	if b != null and b.get_script().resource_path.ends_with("panic_behaviour.gd"):
		entries.append({label = "Panicking"})

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

func get_max_energy() -> float:
	if Traits == null:
		return 1.0
	return Traits.get_max_energy_multiplier()

func restore_energy() -> void:
	energy = get_max_energy()

func clamp_energy() -> void:
	energy = clampf(energy, 0.0, get_max_energy())

func destroy():
	NPCEventHandler.on_destroy_npc_signal.emit(self)
	queue_free()
