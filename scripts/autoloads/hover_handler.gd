extends Node2D

var previously_hovered_room = null
var currently_hovered_room = null

signal click_room_signal

func _process(delta):
	
	var mouse_position = get_global_mouse_position()
	previously_hovered_room = currently_hovered_room
	currently_hovered_room = Global.Building.get_current_room_from_global_position(mouse_position)

	if NPCWorker.picked_up_npc:
		currently_hovered_room = null
		
	if previously_hovered_room == currently_hovered_room:
		return

	#if previously_hovered_room != null:
		#RoomHighlighter.end_request(previously_hovered_room)
		#
	#if currently_hovered_room != null:
		#RoomHighlighter.request_rect(currently_hovered_room, Color(1,0,0,.3))


func _unhandled_input(event):
	
	if event.is_action_pressed("click"):
		click_room_signal.emit(currently_hovered_room)
