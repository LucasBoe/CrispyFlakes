extends Behaviour
class_name FollowRandomGuestBehaviour

func loop():
	_narrative = "Tailing someone..."
	while not stopped:
		var target := _pick_target()
		if target == null:
			break
		while is_instance_valid(target) and not stopped:
			await move(target)
			if stopped:
				return

func _pick_target() -> NPC:
	var candidates: Array[NPC] = []
	for child in Global.NPCSpawner.get_children():
		if child is NPC and is_instance_valid(child) and child != npc:
			candidates.append(child as NPC)
	return candidates.pick_random() if not candidates.is_empty() else null
