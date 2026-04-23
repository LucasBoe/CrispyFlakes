extends Behaviour
class_name KnockedOutBehaviour

const DURATION = 60.0
const ENERGY_RECOVERY_PER_SECOND := 1.0 / DURATION
const DRUNKENNESS_RECOVERY_PER_SECOND := 0.75 / DURATION

var notification_instance
var time_remaining: float = DURATION

func start_loop():
	_narrative = ["Down for the count...", "Out cold...", "Seeing stars..."].pick_random()
	notification_instance = UiNotifications.create_npc_notification(npc, UiNotifications.ICON_KNOCKED_OUT, true)
	_set_collision_rotation(PI / 2.0)

func loop():
	time_remaining = DURATION
	while time_remaining > 0.0:
		var delta := npc.get_process_delta_time()
		time_remaining -= delta
		npc.energy = minf(1.0, npc.energy + ENERGY_RECOVERY_PER_SECOND * delta)
		if npc is NPCGuest:
			var guest := npc as NPCGuest
			guest.Needs.drunkenness.strength = maxf(0.0, guest.Needs.drunkenness.strength - DRUNKENNESS_RECOVERY_PER_SECOND * delta)
		await end_of_frame()
	npc.energy = 1.0

func stop_loop() -> BehaviourSaveData:
	UiNotifications.try_kill(notification_instance)
	_set_collision_rotation(0.0)
	return super.stop_loop()

func _set_collision_rotation(angle: float) -> void:
	var shape := npc.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.rotation = angle
	var precise_shape := npc.get_node_or_null("PreciseHover/CollisionShape2D") as CollisionShape2D
	if precise_shape:
		precise_shape.rotation = angle
