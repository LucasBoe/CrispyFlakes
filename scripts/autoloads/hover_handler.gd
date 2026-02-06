extends Node2D

var previously_hovered = null
var currently_hovered = null

signal click_hovered_node_signal

func notify_hover_enter(npc):
	change_hover(npc)
	
func notify_hover_exit(npc):
	if currently_hovered == npc:
		change_hover(null)
	
func _process(delta):
	
	if not currently_hovered or currently_hovered is not NPC:
		var mouse_position = get_global_mouse_position()
		change_hover(Global.Building.get_current_room_from_global_position(mouse_position))

func change_hover(new_hover):
	previously_hovered = currently_hovered
	currently_hovered = new_hover
		
	if previously_hovered == currently_hovered:
		return
		
	if previously_hovered:
		_set_outline(previously_hovered, Color.BLACK)
			
	if currently_hovered:
		_set_outline(currently_hovered, Color.WHITE)

func _set_outline(node, color: Color) -> void:
	
	var sprite: CanvasItem = null
	
	sprite = node.get_child(1) as CanvasItem
	
	if not sprite:
		return
		
	if node is RoomBase:
		sprite.visible = color == Color.WHITE	
	
	if node is NPC:
		if sprite.material == null:
			return
	
		var mat := sprite.material as ShaderMaterial
		if mat == null:
			return
		
		mat.set_shader_parameter("outline_color", color)

func _unhandled_input(event):
	if event.is_action_pressed("click"):
		
		click_hovered_node_signal.emit(currently_hovered)
		
		if currently_hovered is NPC:
			currently_hovered.click_on()	
