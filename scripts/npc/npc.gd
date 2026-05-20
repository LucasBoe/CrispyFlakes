extends Area2D

class_name NPC

const STATE_LABEL_FIGHT := "Fighting"
const NAMETAG_SCENE := preload("res://scenes/npcs/npc_nametag.tscn")
const NAMETAG_LABEL_PATH := ^"MarginContainer/MarginContainer/LabelName"
const NAMETAG_SHOW_ZOOM_THRESHOLD := 3.0

var Animator : AnimationModule;
var Tint : TintModule
var Navigation : NavigationModule
var Behaviour : BehaviourModule
var Item : ItemModule


var Equipment: EquipmentModule
var Traits: TraitModule
var Status: StatusModule

var look_info : NPCLookInfo
var energy: float = 1.0

var _status_icon_instance = null
var _status_icon_texture = null
var _nametag_instance: Control = null
var _nametag_label: Label = null
var _last_nametag_text := ""
var _last_nametag_visible := false

func _init():
	Tint = TintModule.new(self)
	Equipment = EquipmentModule.new(self)
	Traits = TraitModule.new(self)

func _ready():
	Traits.ensure_traits()
	restore_energy()
	_ensure_nametag()
	_refresh_nametag()

func _process(_delta):
	_refresh_status_icon()
	_refresh_nametag()

func _exit_tree():
	UiNotifications.try_kill(_status_icon_instance)
	_status_icon_instance = null
	_status_icon_texture = null
	_nametag_instance = null
	_nametag_label = null

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

	if Status != null:
		entries.append_array(Status.get_entries())
	else:
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

func get_display_name() -> String:
	var script: Script = get_script()
	if script != null:
		var global_name := String(script.get_global_name())
		if global_name.begins_with("NPC"):
			global_name = global_name.substr(3)
		if not global_name.is_empty():
			return global_name
	return name

func get_debug_display_name() -> String:
	return "%s #%d" % [get_display_name(), abs(get_instance_id()) % 1000000]

func get_max_energy() -> float:
	if Traits == null:
		return 1.0
	return Traits.get_max_energy_multiplier()

func get_move_speed_multiplier() -> float:
	if Traits == null:
		return 1.0
	return Traits.get_move_speed_multiplier()

func get_work_duration_multiplier() -> float:
	if Traits == null:
		return 1.0
	return Traits.get_work_duration_multiplier()

func restore_energy() -> void:
	energy = get_max_energy()

func clamp_energy() -> void:
	energy = clampf(energy, 0.0, get_max_energy())

func destroy():
	NPCEventHandler.on_destroy_npc_signal.emit(self)
	if Behaviour != null:
		Behaviour.clear_behaviour()
	queue_free()

func _ensure_nametag() -> void:
	if is_instance_valid(_nametag_instance):
		return
	_nametag_instance = null
	_nametag_label = null

	_nametag_instance = NAMETAG_SCENE.instantiate() as Control
	if _nametag_instance == null:
		return

	add_child(_nametag_instance)
	_set_mouse_filter_ignore_recursive(_nametag_instance)
	_nametag_label = _nametag_instance.get_node_or_null(NAMETAG_LABEL_PATH) as Label
	_nametag_instance.visible = false
	call_deferred("_refresh_nametag_layout")

func _refresh_nametag() -> void:
	if not is_instance_valid(_nametag_instance):
		_ensure_nametag()
	if not is_instance_valid(_nametag_instance):
		return

	var display_name: String = get_display_name().strip_edges()
	if _nametag_label != null and display_name != _last_nametag_text:
		_nametag_label.text = display_name
		_last_nametag_text = display_name
		call_deferred("_refresh_nametag_layout")

	var should_show: bool = not display_name.is_empty() and is_instance_valid(Camera) and Camera.zoom.x >= NAMETAG_SHOW_ZOOM_THRESHOLD
	if should_show == _last_nametag_visible:
		return

	_nametag_instance.visible = should_show
	_last_nametag_visible = should_show

func _refresh_nametag_layout() -> void:
	if not is_instance_valid(_nametag_instance):
		return

	_nametag_instance.reset_size()
	var scaled_width := _nametag_instance.size.x * _nametag_instance.scale.x
	var nametag_position := _nametag_instance.position
	nametag_position.x = -scaled_width * 0.5
	_nametag_instance.position = nametag_position

func _set_mouse_filter_ignore_recursive(root: Node) -> void:
	if root is Control:
		(root as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child in root.get_children():
		_set_mouse_filter_ignore_recursive(child)
