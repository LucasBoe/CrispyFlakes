extends NeedBehaviour
class_name NeedLeaveBehaviour

static func get_probability_by_needs(needs : NeedsModule):	
	return (1.0 - needs.Money.strength) * (1.0 - needs.Mood.strength)
	
func loop():
	if npc is NPCGuest:
		Global.NPCSpawner.on_guest_destroy(npc)
	
	await move(Vector2(-256,0))
	npc.destroy()
