extends Node2D

const STOVE_INFRASTRUCTURE_SCRIPT = preload("res://scripts/infrastructure/stove_infrastructure.gd")

var previously_hovered = null
var currently_hovered = null

var worker_ui_active: bool = false

signal click_hovered_node_signal

func _process(_delta):
	var mouse_pos = get_global_mouse_position()

	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hits = get_world_2d().direct_space_state.intersect_point(query)

	var precise: Array = []
	var buffer: Array = []
	var stoves: Array = []
	for hit in hits:
		var collider = hit.collider
		if collider is NPC:
			buffer.append(collider)
		elif collider.name == "PreciseHover" and collider.get_parent() is NPC:
			precise.append(collider.get_parent())
		elif collider is Area2D and collider.get_parent() != null and collider.get_parent().get_script() == STOVE_INFRASTRUCTURE_SCRIPT:
			stoves.append(collider.get_parent())

	var candidates: Array = precise if not precise.is_empty() else buffer

	var best_worker: NPCWorker = null
	var best_guest: NPCGuest = null
	for npc in candidates:
		if npc is NPCWorker:
			if best_worker == null or npc.global_position.distance_squared_to(mouse_pos) < best_worker.global_position.distance_squared_to(mouse_pos):
				best_worker = npc
		elif npc is NPCGuest and not worker_ui_active:
			if best_guest == null or npc.global_position.distance_squared_to(mouse_pos) < best_guest.global_position.distance_squared_to(mouse_pos):
				best_guest = npc

	if best_guest != null and best_worker == null:
		change_hover(best_guest)
	elif best_worker != null:
		change_hover(best_worker)
	elif not stoves.is_empty():
		change_hover(_get_closest_stove(stoves, mouse_pos))
	else:
		change_hover(Building.query.room_at_position(mouse_pos))

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
	if node is NPC:
		var npc = node as NPC
		if state:
			npc.Tint.add_outline(Color.LIGHT_GRAY if currently_hovered is NPCGuest else Color.WHITE, 10, self)
		else:
			npc.Tint.remove_outline_for(self)
		return

	if node != null and node.has_method("set_outline"):
		node.set_outline(state)

func _unhandled_input(event):
	if event.is_action_pressed("click"):
		if currently_hovered is NPC:
			currently_hovered.click_on()

		# For NPCWorker: defer selection to release so we can tell if it was a drag
		if not (currently_hovered is NPCWorker) and NPCWorker.picked_up_npc == null:
			click_hovered_node_signal.emit(currently_hovered)

	elif event.is_action_released("click"):
		if currently_hovered is NPCWorker and not NPCWorker.was_dragging:
			click_hovered_node_signal.emit(currently_hovered)

func _get_closest_stove(stoves: Array, mouse_pos: Vector2):
	var best = null
	var best_distance := INF
	for stove_ref in stoves:
		var stove = stove_ref
		if not is_instance_valid(stove):
			continue
		var distance: float = stove.global_position.distance_squared_to(mouse_pos)
		if best == null or distance < best_distance:
			best = stove
			best_distance = distance
	return best
