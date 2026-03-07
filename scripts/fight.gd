class_name Fight

var energy = 1.0
var participants = []
var room : RoomBase
var highlight

const MAX_DURATION_IN_SECONDS = 30

func start_fight(_room):
	room = _room
	highlight = RoomHighlighter.request_rect(room, Color.RED)

func end_fight():
	var was_smoothed = false
	
	for p in participants:
		if p is NPCWorker:
			was_smoothed = true
			
	for p in participants:
		if p is NPCGuest:
			p.force_behaviour(ArestedBehaviour)
	
	RoomHighlighter.dispose(highlight)
