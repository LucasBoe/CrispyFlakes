extends NeedBehaviour
class_name NeedLeaveBehaviour

static func get_probability_by_needs(needs : NeedsModule):
	return (1.0 - needs.Money.Strength) * (1.0 - needs.Mood.Strength)
	
func loop():
	if npc is NPCGuest:
		Global.NPCSpawner.on_guest_destroy(npc)
	
	while isRunning:
		await move(Vector2(-256,0))
		npc.queue_free()
