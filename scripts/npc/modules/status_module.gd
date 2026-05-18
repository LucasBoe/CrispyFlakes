extends Node
class_name StatusModule

var npc: NPC
var _statuses: Array[Enum.NpcStatus] = []

signal status_changed

func _ready() -> void:
	npc = get_parent() as NPC
	if npc:
		npc.Status = self

func has_status(status: Enum.NpcStatus) -> bool:
	return _statuses.has(status)

func set_status(status: Enum.NpcStatus) -> void:
	if _statuses.has(status):
		return
	_statuses.append(status)
	status_changed.emit()

func clear_status(status: Enum.NpcStatus) -> void:
	if not _statuses.has(status):
		return
	_statuses.erase(status)
	status_changed.emit()

func get_entries() -> Array:
	_refresh_dynamic_guest_statuses()
	var entries: Array = []

	if has_status(Enum.NpcStatus.INJURED):
		entries.append({icon = UiNotifications.ICON_INJURED, label = "Injured"})
	if has_status(Enum.NpcStatus.WELL_TREATED):
		entries.append({icon = UiNotifications.ICON_TREATED, label = "Well Treated — Resting"})
	if has_status(Enum.NpcStatus.BADLY_TREATED):
		entries.append({icon = UiNotifications.ICON_TREATED, label = "Badly Treated — Resting"})

	if has_status(Enum.NpcStatus.MARKED_FOR_ARREST):
		entries.append({icon = UiNotifications.ICON_HANDCUFFS, label = "Marked for Arrest (Drop Worker)"})
	if has_status(Enum.NpcStatus.ARRESTED):
		entries.append({icon = UiNotifications.ICON_HANDCUFFED, label = "Arrested (Call Sherrif)"})
	if has_status(Enum.NpcStatus.KNOWN_FUGITIVE):
		var guest: NPCGuest = npc as NPCGuest
		var bounty = BountyHandler.get_official_bounty_for(guest)
		entries.append({icon = UiNotifications.ICON_FUGITIVE, label = str("Known Fugitive (", bounty, "$)")})
	if has_status(Enum.NpcStatus.CARRYING_LOOT):
		var guest: NPCGuest = npc as NPCGuest
		entries.append({icon = UiNotifications.ICON_ROBBER, label = str("Carrying stolen loot ($", guest.stolen_amount, ")")})
	if has_status(Enum.NpcStatus.HAS_OUTSTANDING_FINE):
		var guest: NPCGuest = npc as NPCGuest
		var fine = BountyHandler.get_fight_fine_for(guest)
		var reason := BountyHandler.get_fine_summary_for(guest)
		var fine_text := reason
		if fine_text == "":
			fine_text = str(fine, "$")
		entries.append({label = str("Outstanding Fine: ", fine_text)})
	elif has_status(Enum.NpcStatus.MARKED_FOR_ARREST) or has_status(Enum.NpcStatus.ARRESTED):
		if not has_status(Enum.NpcStatus.KNOWN_FUGITIVE):
			entries.append({label = "Has No Bounty or Fine"})

	return entries

func _refresh_dynamic_guest_statuses() -> void:
	var guest: NPCGuest = npc as NPCGuest
	if guest == null or guest.Behaviour == null:
		return
	var b: Behaviour = guest.Behaviour.behaviour_instance
	var bounty = BountyHandler.get_official_bounty_for(guest)
	var fine = BountyHandler.get_fight_fine_for(guest)
	_sync(Enum.NpcStatus.MARKED_FOR_ARREST, ConflictResponseHandler.is_marked_for_arrest(guest))
	_sync(Enum.NpcStatus.ARRESTED, b is ArrestedBehaviour)
	_sync(Enum.NpcStatus.KNOWN_FUGITIVE, bounty != null and guest.is_known_fugitive)
	_sync(Enum.NpcStatus.CARRYING_LOOT, guest.stolen_amount > 0)
	_sync(Enum.NpcStatus.HAS_OUTSTANDING_FINE, fine != null)

func _sync(status: Enum.NpcStatus, condition: bool) -> void:
	if condition:
		set_status(status)
	else:
		clear_status(status)
