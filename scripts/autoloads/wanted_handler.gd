extends Node

# Dict of NPCLookInfo -> int (bounty amount in $)
var npc_bounties : Dictionary = {}
var active_looks : Array = []

func _ready():
	NPCEventHandler.on_destroy_npc_signal.connect(_on_npc_destroyed)

func create_bounty(look: NPCLookInfo, amount: int):
	npc_bounties[look] = amount

func activate(look: NPCLookInfo):
	active_looks.append(look)

func deactivate(look: NPCLookInfo):
	active_looks.erase(look)

func get_all_wanted_npcs() -> Array:
	var result = []
	for look in npc_bounties:
		result.append({"look": look, "bounty": npc_bounties[look]})
	return result

func get_available_wanted_npcs() -> Array:
	var result = []
	for look in npc_bounties:
		if look not in active_looks:
			result.append({"look": look, "bounty": npc_bounties[look]})
	return result

func is_look_similar_to_any_wanted(look: NPCLookInfo) -> bool:
	for wanted_look in npc_bounties:
		if _hue_distance(look.color_offsets.x, wanted_look.color_offsets.x) < 0.15:
			return true
	return false

func _hue_distance(a: float, b: float) -> float:
	var diff = abs(a - b)
	return min(diff, 1.0 - diff)

func _on_npc_destroyed(npc: NPC):
	if npc.look_info != null:
		deactivate(npc.look_info)
