class_name Fight

var participants = []
var room : RoomBase
var highlight
var time_elapsed: float = 0.0
var is_over: bool = false

# Optionally set when this fight is an arrest confrontation
var is_arrest_fight: bool = false

const MAX_DURATION_IN_SECONDS = 30
const DRUNK_FIGHT_BOUNTY: int = 10

func start_fight(_room):
	room = _room
	highlight = RoomHighlighter.request_rect(room, Color.RED, 2, RoomHighlighter.Priority.FIGHT)

func worker_won() -> bool:
	var has_guests = false
	var has_workers = false
	for p in participants:
		if p is NPCGuest:
			has_guests = true
			if p.health > 0.0:
				return false
		elif p is NPCWorker:
			has_workers = true
	return has_guests and has_workers

func npc_won() -> bool:
	var has_workers = false
	for p in participants:
		if p is NPCWorker:
			has_workers = true
			if p.health > 0.0:
				return false
	return has_workers

func guests_all_down() -> bool:
	var has_guests = false
	for p in participants:
		if p is NPCGuest:
			has_guests = true
			if p.health > 0.0:
				return false
	var has_workers = false
	for p in participants:
		if p is NPCWorker:
			has_workers = true
	return has_guests and not has_workers

func end_fight():
	if worker_won():
		for p in participants:
			if p is NPCGuest:
				if is_arrest_fight:
					p.pending_arrest = false
				elif p.look_info != null:
					BountyHandler.create_fight_fine(p, DRUNK_FIGHT_BOUNTY)
				p.force_behaviour(ArrestedBehaviour)
	elif guests_all_down():
		for p in participants:
			if p is NPCGuest:
				p.force_behaviour(KnockedOutBehaviour)

	RoomHighlighter.dispose(highlight)
