extends Node2D

var previously_hovered = null
var currently_hovered = null

signal click_hovered_node_signal

func notify_hover_enter(npc):
	if currently_hovered is NPCWorker and npc is NPCGuest:
		return
		
	change_hover(npc)
	
func notify_hover_exit(npc):
	if currently_hovered == npc:
		change_hover(null)
	
func _process(delta):
	
	if not currently_hovered or currently_hovered is not NPC:
		var mouse_position = get_global_mouse_position()
		change_hover(Global.Building.query.room_at_position(mouse_position))

func change_hover(new_hover):
	previously_hovered = currently_hovered
	currently_hovered = new_hover
		
	if previously_hovered == currently_hovered:
		return
		
	if previously_hovered:
		_set_outline(previously_hovered, false)
			
	if currently_hovered:
		_set_outline(currently_hovered, true)

func _set_outline(node, state) -> void:
		
	if node is RoomBase:
		node.set_outline(state)
	
	if node is NPC:
		var npc = node as NPC
		if state:
			npc.Tint.add_outline(Color.LIGHT_GRAY if currently_hovered is NPCGuest else Color.WHITE, 10, self)
		else:
			npc.Tint.remove_outline_for(self)

func _unhandled_input(event):
	if event.is_action_pressed("click"):
		
		click_hovered_node_signal.emit(currently_hovered)
		
		if currently_hovered is NPC:
			currently_hovered.click_on()	
