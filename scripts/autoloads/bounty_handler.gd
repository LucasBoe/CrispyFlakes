extends Node

# Dict of NPCLookInfo -> int (bounty amount in $) — official sheriff bounties
var npc_bounties : Dictionary = {}
# Dict of NPCGuest -> int — fines issued after a drunk fight arrest
var npc_fight_fines : Dictionary = {}
var active_looks : Array = []

func _ready():
	NPCEventHandler.on_destroy_npc_signal.connect(_on_npc_destroyed)

func create_bounty(look: NPCLookInfo, amount: int):
	npc_bounties[look] = amount

func create_fight_fine(npc: NPCGuest, amount: int):
	npc_fight_fines[npc] = amount

func activate(look: NPCLookInfo):
	active_looks.append(look)

func deactivate(look: NPCLookInfo):
	active_looks.erase(look)

func get_all_bounties() -> Array:
	var result = []
	for look in npc_bounties:
		result.append({"look": look, "bounty": npc_bounties[look]})
	return result
	
func get_bounty_for(npc : NPC):
	if npc_fight_fines.has(npc):
		return npc_fight_fines[npc]
	elif npc_bounties.has(npc.look_info):
		return npc_bounties[npc.look_info]
	else:
		return null

func get_available_bounties() -> Array:
	var result = []
	for look in npc_bounties:
		if look not in active_looks:
			result.append({"look": look, "bounty": npc_bounties[look]})
	return result

func is_look_similar_to_any_bounty(look: NPCLookInfo) -> bool:
	for bounty_look in npc_bounties:
		if _hue_distance(look.color_offsets.x, bounty_look.color_offsets.x) < 0.15:
			return true
	return false

func _hue_distance(a: float, b: float) -> float:
	var diff = abs(a - b)
	return min(diff, 1.0 - diff)

func _on_npc_destroyed(npc: NPC):
	if npc.look_info != null:
		deactivate(npc.look_info)
