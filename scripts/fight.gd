class_name Fight

var bar: float = 0.5
var participants = []
var room : RoomBase
var highlight

# Optionally set when this fight is an arrest confrontation
var is_arrest_fight: bool = false

const MAX_DURATION_IN_SECONDS = 30

func start_fight(_room):
	room = _room
	highlight = RoomHighlighter.request_rect(room, Color.RED)

func worker_won() -> bool:
	return bar >= 1.0

func npc_won() -> bool:
	return bar <= 0.0

func end_fight():
	print("[FIGHT] end_fight called. bar:", bar, " worker_won:", worker_won(), " npc_won:", npc_won(), " participants:", participants.size())
	if worker_won():
		for p in participants:
			if p is NPCGuest:
				if is_arrest_fight:
					p.pending_arrest = false
				p.force_behaviour(ArrestedBehaviour)
	else:
		for p in participants:
			if p is NPCGuest and is_arrest_fight:
				p.pending_arrest = false

	RoomHighlighter.dispose(highlight)
