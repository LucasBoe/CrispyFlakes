extends Node2D

var previously_hovered = null
var currently_hovered = null

var worker_ui_active: bool = false

signal click_hovered_node_signal

var _click_interceptors: Array[Callable] = []

func add_click_interceptor(interceptor: Callable) -> void:
	_click_interceptors.append(interceptor)

func remove_click_interceptor(interceptor: Callable) -> void:
	_click_interceptors.erase(interceptor)

func _run_interceptors(node) -> bool:
	for interceptor in _click_interceptors:
		if interceptor.call(node):
			return true
	return false

func _process(_delta):
	var mouse_pos = get_global_mouse_position()

	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hits = get_world_2d().direct_space_state.intersect_point(query)

	var precise: Array = []
	var buffer: Array = []
	var picked_up = NPCWorker.picked_up_npc
	for hit in hits:
		var collider = hit.collider
		if collider is NPC:
			if collider != picked_up:
				buffer.append(collider)
		elif collider.name == "PreciseHover" and collider.get_parent() is NPC:
			if collider.get_parent() != picked_up:
				precise.append(collider.get_parent())

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
	else:
		change_hover(Building.query.room_at_position(mouse_pos))

func change_hover(new_hover):
	previously_hovered = currently_hovered
	currently_hovered = new_hover
		
	if previously_hovered == currently_hovered:
		return

	if is_instance_valid(previously_hovered) and previously_hovered is RoomWaterTower:
		Building.infrastructure.hide_water_info()

	if is_instance_valid(previously_hovered):
		_set_outline(previously_hovered, false)

	if is_instance_valid(currently_hovered) and currently_hovered is RoomWaterTower:
		Building.infrastructure.show_water_info()

	if is_instance_valid(currently_hovered):
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
		if is_instance_valid(currently_hovered) and currently_hovered is NPC:
			currently_hovered.click_on()

		if _run_interceptors(currently_hovered):
			return

		# For NPCWorker: defer selection to release so we can tell if it was a drag
		if not (is_instance_valid(currently_hovered) and currently_hovered is NPCWorker) and NPCWorker.picked_up_npc == null:
			click_hovered_node_signal.emit(currently_hovered)

	elif event.is_action_released("click"):
		if is_instance_valid(currently_hovered) and currently_hovered is NPCWorker and not NPCWorker.was_dragging:
			if not _run_interceptors(currently_hovered):
				click_hovered_node_signal.emit(currently_hovered)
