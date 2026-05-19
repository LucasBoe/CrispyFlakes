extends Node

# Dict of NPCLookInfo -> int (bounty amount in $) — official sheriff bounties
var npc_bounties : Dictionary = {}
# Dict of NPCGuest -> int — outstanding fines such as fight or robbery fines
var npc_fight_fines : Dictionary = {}
var npc_fine_reasons: Dictionary = {}
var active_looks : Array = []

const DEFAULT_FINE_REASON := "Fine"

func _ready():
	NPCEventHandler.on_destroy_npc_signal.connect(_on_npc_destroyed)

func create_bounty(look: NPCLookInfo, amount: int):
	npc_bounties[look] = amount

func create_fight_fine(npc: NPCGuest, amount: int, reason: String = "Brawling"):
	add_fine(npc, amount, reason)

func add_fine(npc: NPCGuest, amount: int, reason: String = DEFAULT_FINE_REASON) -> void:
	if not is_instance_valid(npc) or amount <= 0:
		return
	npc_fight_fines[npc] = int(npc_fight_fines.get(npc, 0)) + amount
	_add_fine_reason(npc, amount, reason)

func get_fine_reason_entries_for(npc: NPC) -> Array:
	if npc_fine_reasons.has(npc):
		return npc_fine_reasons[npc].duplicate(true)
	var fine = get_fight_fine_for(npc)
	if fine != null:
		return [{amount = int(fine), reason = DEFAULT_FINE_REASON}]
	return []

func get_fine_summary_for(npc: NPC) -> String:
	var entries := get_fine_reason_entries_for(npc)
	if entries.is_empty():
		return ""
	var parts := PackedStringArray()
	for entry: Dictionary in entries:
		parts.append("%s ($%d)" % [str(entry.get("reason", DEFAULT_FINE_REASON)), int(entry.get("amount", 0))])
	return ", ".join(parts)

func clear_fine(npc: NPC) -> void:
	npc_fight_fines.erase(npc)
	npc_fine_reasons.erase(npc)

func _add_fine_reason(npc: NPCGuest, amount: int, reason: String) -> void:
	var clean_reason := reason.strip_edges()
	if clean_reason == "":
		clean_reason = DEFAULT_FINE_REASON
	var entries: Array = npc_fine_reasons.get(npc, [])
	for entry: Dictionary in entries:
		if str(entry.get("reason", "")) == clean_reason:
			entry["amount"] = int(entry.get("amount", 0)) + amount
			npc_fine_reasons[npc] = entries
			return
	entries.append({amount = amount, reason = clean_reason})
	npc_fine_reasons[npc] = entries

func activate(look: NPCLookInfo):
	active_looks.append(look)

func deactivate(look: NPCLookInfo):
	active_looks.erase(look)

func get_all_bounties() -> Array:
	var result = []
	for look in npc_bounties:
		result.append({"look": look, "bounty": npc_bounties[look]})
	return result

func get_official_bounty_for(npc: NPC):
	if npc != null and npc_bounties.has(npc.look_info):
		return npc_bounties[npc.look_info]
	return null

func get_fight_fine_for(npc: NPC):
	if npc_fight_fines.has(npc):
		return npc_fight_fines[npc]
	return null

func get_bounty_for(npc : NPC):
	var fine = get_fight_fine_for(npc)
	if fine != null:
		return fine
	var official_bounty = get_official_bounty_for(npc)
	if official_bounty != null:
		return official_bounty
	else:
		return null

func get_total_arrested_payout() -> int:
	if Global.NPCSpawner == null:
		return 0
	var total := 0
	for guest: NPCGuest in Global.NPCSpawner.guests:
		if not is_instance_valid(guest) or guest.Behaviour == null:
			continue
		if not (guest.Behaviour.behaviour_instance is ArrestedBehaviour):
			continue
		var bounty: int = npc_bounties.get(guest.look_info, 0) if guest.look_info != null else 0
		var fine: int = npc_fight_fines.get(guest, 0)
		total += bounty + fine
	return total

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
	clear_fine(npc)
