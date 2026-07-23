extends RefCounted
class_name BuildingNavigationHelperQuery

# fixed size for debug arrowheads - DebugDraw2D.arrow's default scales the
# head with shaft length, which looks huge on short markers and can even
# overlap into a blob when drawing both directions on the same short segment
const DEBUG_ARROW_HEAD_SIZE := 5.0
const DEBUG_OPACITY := 0.5
# actual nav positions sit at feet/floor level (y=0 within a room) - lift the
# visualization up to roughly body height so it doesn't trace the ground.
# Draw-time only: never applied to the underlying stored/returned positions.
const DEBUG_Y_OFFSET := Vector2(0.0, -12.0)

func _v(pos: Vector2) -> Vector2:
	return pos + DEBUG_Y_OFFSET

var _building : Building

# dict with:
# key:		floor level (0/1/2)
# value:		list of:
# 					all floors[]
var _floors = {}

# dict with: 
# key:		stair or elevator
# value:		list of:
#					levels reachable from there (0,1,2)
var _connectors = {}


func _init(_b: Building) -> void:
	_building = _b
	
	GlobalEventHandler.on_room_created_signal.connect(_force_data_model_rebuild)
	GlobalEventHandler.on_room_deleted_signal.connect(_force_data_model_rebuild)
	# elevator shafts are (re)computed on a deferred call (see ElevatorHandler),
	# so reachable floors for a just-placed elevator can be stale by the time
	# _force_data_model_rebuild runs synchronously off the same room signals -
	# re-sync once the shaft rebuild has actually completed
	ElevatorHandler.shafts_rebuilt.connect(_on_elevator_shafts_rebuilt)


func _force_data_model_rebuild(room):
	if room.y == null:
		await room.get_tree().process_frame
	var floor = room.y
	DebugLog.info("[NavConnectors]", "rebuild triggered by", room, "floor", floor)
	_rebuild_row(floor)
	_rebuild_row(floor - 1)
	_rebuild_row(floor + 1)
	_mirror_all_connectors()
	return
	
func _rebuild_row(floor):
	if not _building.floors.has(floor):
		return
		
	var floors_on_level = []
	var is_outside = true
	
	var all_rooms = []
	var connectors = []
	
	var all_positions = []
	
	var f = _building.floors[floor]
	
	var x_start_index = INF
	var x_end_index = -INF
	for i in f.keys():
		x_start_index = min(x_start_index, i)
		x_end_index = max(x_end_index, i)
		
	for x in range(x_start_index - 10, x_end_index + 10):
		all_positions.append(Building.global_position_from_room_index(Vector2i(x,0)).x - 48)
		# a room taller than 1 cell is also registered at floors[y+row][x] for
		# every row it spans - f[x].y == floor excludes those upper-section
		# cells here, since they aren't a walkable floor of their own
		if f.has(x) and not f[x].is_outside_room and f[x].y == floor:
			if is_outside:
				# submit empty floor
				# outside space only exists at ground level (street) - a gap on
				# any floor above is void, not walkable, since there's nothing
				# holding it up
				if floor == 0:
					var info = floorInfo.new()
					info.is_outside = true
					info.y_level = floor
					info.x_size = all_positions.size()
					info.x_center = _sum(all_positions) / (float)(all_positions.size())
					floors_on_level.append(info)
				all_positions.clear()
				is_outside = false
			
			var r = f[x]
			all_rooms.append(r)
			if r is RoomBouncer or r is RoomStairs or r is RoomElevator:
				connectors.append(r)
			if r is RoomStairs or r is RoomElevator:
				_connectors[r] = _get_reachable_floors(r)
		else:
			if not is_outside:
				# submit real floor
				var info = floorInfo.new()
				info.is_outside = false
				info.y_level = floor
				info.all_rooms.append_array(all_rooms)
				all_rooms.clear()
				info.connectors.append_array(connectors)
				connectors.clear()
				info.x_center = _sum(all_positions) / (float)(all_positions.size())
				all_positions.clear()
				floors_on_level.append(info)
				is_outside = true

	# the loop only submits an outside segment when it transitions back into
	# an indoor cell - if the row ends while still outside (e.g. the street
	# past the last room), that trailing segment never gets a closing
	# transition, so it has to be submitted here explicitly
	if is_outside and floor == 0 and not all_positions.is_empty():
		var info = floorInfo.new()
		info.is_outside = true
		info.y_level = floor
		info.x_size = all_positions.size()
		info.x_center = _sum(all_positions) / (float)(all_positions.size())
		floors_on_level.append(info)

	# outside segments only ever exist on the ground floor (see above), so
	# this is the only floor where indoor/outside linking applies
	if floor == 0:
		_link_indoor_outside_neighbors(floors_on_level)
		_link_outside_segments_directly(floors_on_level)

	_floors[floor] = floors_on_level

# Indoor and outside segments strictly alternate along a row, so an indoor
# segment can only ever border the outside segments immediately before/after
# it in this list. Any such boundary is walkable from the side by default -
# a bouncer (if present among the indoor segment's connectors) doesn't gate
# this basic reachability, it just marks a supervised/frisked crossing point
# for the concrete NPC movement layer to route through.
func _link_indoor_outside_neighbors(floors_on_level: Array) -> void:
	for i in range(floors_on_level.size() - 1):
		var a : floorInfo = floors_on_level[i]
		var b : floorInfo = floors_on_level[i + 1]
		if a.is_outside == b.is_outside:
			continue
		a.neighbors.append(b)
		b.neighbors.append(a)

# The street is one contiguous space - walking from one outside segment to
# another (passing several buildings along the way) shouldn't require
# detouring through every building in between, which would also wrongly
# trigger an entering/frisking transition at each one along the way. Link
# every outside segment on this row directly to every other, so the search
# can always take the direct along-the-street route instead.
func _link_outside_segments_directly(floors_on_level: Array) -> void:
	var outside_segments : Array = []
	for f : floorInfo in floors_on_level:
		if f.is_outside:
			outside_segments.append(f)
	for i in range(outside_segments.size()):
		for j in range(i + 1, outside_segments.size()):
			outside_segments[i].neighbors.append(outside_segments[j])
			outside_segments[j].neighbors.append(outside_segments[i])

# _connectors is only ever added to (see _rebuild_row) and never pruned when
# a room is freed - a bulk teardown (e.g. loading a save clears the whole
# building via room.destroy(), which never fires on_room_deleted_signal) can
# leave freed instances as keys. Purge those before anything touches them.
func _prune_invalid_connectors() -> void:
	for connector in _connectors.keys():
		if not is_instance_valid(connector):
			_connectors.erase(connector)

# floorInfo.connectors is a separate per-object list (populated by direct row
# scan + _mirror_all_connectors) that has the exact same staleness problem as
# _connectors above, and a floorInfo can go a long time between rebuilds -
# prune it in place before any read so a freed room never gets touched.
func _valid_connectors_of(floor_info: floorInfo) -> Array:
	var i := floor_info.connectors.size() - 1
	while i >= 0:
		if not is_instance_valid(floor_info.connectors[i]):
			floor_info.connectors.remove_at(i)
		i -= 1
	return floor_info.connectors

# ElevatorHandler's shaft rebuild is deferred, so the elevator connectors we
# picked up during the room-placement rebuild can be stale (e.g. a brand new
# elevator not merged into its shaft yet). Recompute reachable floors for
# every known elevator connector now that shafts are actually up to date.
func _on_elevator_shafts_rebuilt() -> void:
	_prune_invalid_connectors()
	for connector in _connectors.keys():
		if connector is RoomElevator:
			_connectors[connector] = _get_reachable_floors(connector)
	_mirror_all_connectors()

# Stairs/elevators are only discovered while scanning the row they physically
# sit on, so a floorInfo one level up never sees the connector that would let
# an NPC use it to go back down. This mirrors every known connector into every
# floorInfo on every level it can reach, so the graph is bidirectional.
func _mirror_all_connectors() -> void:
	_prune_invalid_connectors()
	for connector in _connectors.keys():
		var levels : Array = _connectors[connector]
		DebugLog.info("[NavConnectors]", "mirroring", connector, "levels", levels)
		for level in levels:
			var info := _query_floor_info(level, connector.x)
			if info == null:
				DebugLog.warn("[NavConnectors]", "no floorInfo to mirror into", connector, "level", level, "x", connector.x)
				continue
			if not info.connectors.has(connector):
				info.connectors.append(connector)
				DebugLog.info("[NavConnectors]", "mirrored", connector, "into level", level)

func _get_reachable_floors(connector) -> Array:
	if connector is RoomStairs:
		var levels := [connector.y]
		if Building.get_room_from_index(Vector2i(connector.x, connector.y + 1)) != null:
			levels.append(connector.y + 1)
		DebugLog.info("[NavConnectors]", "stairs reachable floors", connector, "levels", levels)
		return levels
	if connector is RoomElevator:
		var levels = ElevatorHandler.get_reachable_floors(connector)
		DebugLog.info("[NavConnectors]", "elevator reachable floors", connector, "levels", levels)
		return levels
	return [connector.y]

func _sum(array):
	var v = 0
	for i in array:
		v+= i
	return v

func refresh_target_path(current_phase : NavigationModule.navigationPhase, current_position : Vector2, target_position : Vector2, requires_bouncer : bool = true) -> Array[NavigationModule.navigationPhase]:
	# finish current stairs movement before planning a new path, so the BFS
	# starts from the stairs' exit rather than the in-between y the NPC
	# currently occupies
	var resuming_stairs : bool = current_phase is NavigationModule.useStairsPhase and not current_phase.is_done()
	if resuming_stairs:
		current_position = current_phase.last_waypoint()

	var current_floor : floorInfo = query_floor_at_position(current_position)
	var target_floor : floorInfo = query_floor_at_position(target_position)

	if current_floor == null or target_floor == null:
		return []

	var hops : Array[NavigationModule.navigationPhase] = []
	if current_floor != target_floor:
		hops = _find_path(current_floor, target_floor, current_position, requires_bouncer)
		if hops.is_empty():
			return []

	var path : Array[NavigationModule.navigationPhase] = []
	if resuming_stairs:
		path.append(current_phase)
	path.append_array(hops)
	path.append(NavigationModule.walkPhase.new(target_position))
	return path
	
func query_floor_at_position(position : Vector2):
	# is position part of room?
	var room = _building.query.room_at_position(position) as RoomBase
	if room and _floors.has(room.y):
		for floor : floorInfo in _floors[room.y]:
			if floor.all_rooms.has(room):
				return floor

	# treat outside
	var index = _building.round_room_index_from_global_position(position)

	if not _floors.has(index.y):
		return null

	var closest_distance = INF
	var closest_floor = null

	for floor : floorInfo in _floors[index.y]:
		if floor.is_outside:
			var distance = abs(position.x - floor.x_center)
			if distance < closest_distance:
				closest_distance = distance
				closest_floor = floor
	
	return closest_floor

func _debug_floor_label(floor_info: floorInfo) -> String:
	return "y=%d x=%.0f outside=%s" % [floor_info.y_level, floor_info.x_center, floor_info.is_outside]

# The bouncer that gates crossings for this indoor segment, if any - if a
# bouncer exists anywhere on the floor, guests are meant to be forced through
# it regardless of which side of the segment they're actually crossing
# (there's only one legitimate door once the building has one at all).
func _bouncer_gating(indoor : floorInfo, _outside : floorInfo):
	for connector in _valid_connectors_of(indoor):
		if connector is RoomBouncer:
			return connector
	return null

# Point (world x) where an indoor segment and its outside neighbor connect -
# the bouncer's position if one gates the crossing, otherwise the segment
# edge facing the other side. Shared by cost calculation and phase creation
# so both agree on exactly where a same-level hop actually crosses.
func _indoor_outside_crossing_x(a : floorInfo, b : floorInfo, requires_bouncer : bool = true) -> float:
	var indoor : floorInfo = a if not a.is_outside else b
	var outside : floorInfo = b if indoor == a else a
	if requires_bouncer:
		var bouncer = _bouncer_gating(indoor, outside)
		if bouncer != null:
			return bouncer.get_center_position().x
	return _segment_edge_facing(indoor, outside.x_center)

# Same-level (indoor/outside) hops are a real walk, so a longer one should
# cost more than a short one. Vertical hops (stairs/elevator) also have to be
# walked to first - a connector on the far side of the building isn't free
# just because it's still "one hop" - so charge the horizontal approach
# distance too, plus a small flat cost for the climb/ride itself (not scaled
# by distance, since using stairs/an elevator is roughly equally effortful
# regardless of where in the building it sits). `from_x` is the actual
# arrival position on `current` along the best path found so far - not
# current.x_center, which can be far from where you actually are on a wide
# floor and would otherwise make a distant connector look artificially cheap.
const VERTICAL_HOP_BASE_COST := 48.0

func _edge_cost(current: floorInfo, neighbor: floorInfo, from_x: float, requires_bouncer : bool = true) -> Dictionary:
	if current.y_level == neighbor.y_level:
		var crossing_x := _indoor_outside_crossing_x(current, neighbor, requires_bouncer)
		return {"cost": absf(from_x - crossing_x), "arrival_x": crossing_x}
	var connector = _find_connecting_connector(current, neighbor, from_x)
	if connector == null:
		return {"cost": INF, "arrival_x": from_x}
	var connector_x : float = connector.get_center_position().x
	return {"cost": absf(from_x - connector_x) + VERTICAL_HOP_BASE_COST, "arrival_x": connector_x}

func _find_path(start_floor: floorInfo, goal_floor: floorInfo, start_pos: Vector2, requires_bouncer : bool = true) -> Array[NavigationModule.navigationPhase]:
	if start_floor == goal_floor:
		return []

	var open: Array[floorInfo] = [start_floor]
	var came_from := {}
	var cost_so_far := {start_floor: 0.0}
	var arrival_x := {start_floor: start_pos.x}

	while open.size() > 0:
		var best_index := 0
		for i in range(1, open.size()):
			if cost_so_far[open[i]] < cost_so_far[open[best_index]]:
				best_index = i
		var current : floorInfo = open[best_index]
		open.remove_at(best_index)

		if current == goal_floor:
			DebugLog.info("[NavPath]", "found path", "cost", cost_so_far[current], "nodes_visited", cost_so_far.size())
			return _reconstruct_path(came_from, goal_floor, arrival_x, requires_bouncer)

		for neighbor in _get_connected_floors(current):
			if neighbor == null:
				continue
			var hop : Dictionary = _edge_cost(current, neighbor, arrival_x[current], requires_bouncer)
			if hop.cost == INF:
				continue
			var new_cost : float = cost_so_far[current] + hop.cost
			if not cost_so_far.has(neighbor) or new_cost < cost_so_far[neighbor]:
				cost_so_far[neighbor] = new_cost
				came_from[neighbor] = current
				arrival_x[neighbor] = hop.arrival_x
				open.append(neighbor)
				DebugLog.info("[NavPath]", "discovered", _debug_floor_label(neighbor), "cost", new_cost, "via", _debug_floor_label(current))

	DebugLog.warn("[NavPath]", "no path found", "start", _debug_floor_label(start_floor), "goal", _debug_floor_label(goal_floor))
	return []
	
func _get_connected_floors(current_floor: floorInfo) -> Array:
	var result: Array = []
	result.append_array(current_floor.neighbors)
	for connector in _valid_connectors_of(current_floor):
		if not _connectors.has(connector):
			continue
		for level in _connectors[connector]:
			if level == current_floor.y_level:
				continue
			var neighbor := _query_floor_info(level, connector.x)
			if neighbor != null:
				result.append(neighbor)
	return result

func _query_floor_info(y_level: int, x: int) -> floorInfo:
	if not _floors.has(y_level):
		return null
	var position = Building.global_position_from_room_index(Vector2i(x, y_level))
	return query_floor_at_position(position)


func _reconstruct_path(came_from: Dictionary, goal_floor: floorInfo, arrival_x: Dictionary, requires_bouncer : bool = true) -> Array[NavigationModule.navigationPhase]:
	var path: Array[NavigationModule.navigationPhase] = []
	var current = goal_floor
	while came_from.has(current):
		var predecessor = came_from[current]
		path.push_front(create_phase(predecessor, current, arrival_x[predecessor], requires_bouncer))
		current = predecessor
	return path

# Builds the concrete phase an NPC executes to get from `from` to `to`,
# given they're adjacent in the floorInfo graph (see _get_connected_floors).
# `from_x` is the actual arrival position on `from` (see _find_path) - passing
# it through keeps the connector chosen here consistent with whichever one
# the search actually costed for this hop. `requires_bouncer` false lets an
# indoor/outside crossing skip the door and use the open side instead, even
# when a bouncer is present (e.g. workers, who aren't gated by it).
func create_phase(from : floorInfo, to : floorInfo, from_x : float = INF, requires_bouncer : bool = true) -> NavigationModule.navigationPhase:
	if from.y_level != to.y_level:
		return _create_vertical_phase(from, to, from_x)
	return _create_indoor_outside_phase(from, to, requires_bouncer)

func _create_vertical_phase(from : floorInfo, to : floorInfo, from_x : float) -> NavigationModule.navigationPhase:
	var connector = _find_connecting_connector(from, to, from_x)
	if connector is RoomStairs:
		var phase := NavigationModule.useStairsPhase.new()
		phase.waypoints = NavigationModule.compute_stairs_waypoints(connector.global_position, to.y_level < from.y_level)
		return phase
	if connector is RoomElevator:
		var from_room : RoomElevator = Building.get_room_from_index(Vector2i(connector.x, from.y_level))
		var to_room : RoomElevator = Building.get_room_from_index(Vector2i(connector.x, to.y_level))
		return NavigationModule.useElevatorPhase.new(from_room, to_room)
	return null

# A vertical connector (stairs/elevator) gets mirrored into every floorInfo it
# reaches (see _mirror_all_connectors), so any connector linking two adjacent
# floors appears in both of their connector lists - and there can be more
# than one (e.g. two separate staircases both spanning the same two floors).
# Among ties, prefer whichever sits physically closest to `reference_x` (the
# actual position on `a`, if known) instead of just the first one found in
# list order or floor a's aggregate center, which can be misleading on a wide
# floor where the true position sits far from the average.
func _find_connecting_connector(a : floorInfo, b : floorInfo, reference_x : float = INF):
	var best = null
	var best_distance := INF
	var ref : float = reference_x if reference_x != INF else a.x_center
	var b_connectors := _valid_connectors_of(b)
	for connector in _valid_connectors_of(a):
		if not b_connectors.has(connector):
			continue
		var distance : float = abs(connector.get_center_position().x - ref)
		if distance < best_distance:
			best_distance = distance
			best = connector
	return best

func _create_indoor_outside_phase(from : floorInfo, to : floorInfo, requires_bouncer : bool = true) -> NavigationModule.navigationPhase:
	var indoor : floorInfo = from if not from.is_outside else to
	var outside : floorInfo = to if indoor == from else from
	var entering : bool = indoor == to

	if requires_bouncer:
		var bouncer = _bouncer_gating(indoor, outside)
		if bouncer != null:
			return NavigationModule.useDoorSwapPhase.new(bouncer, entering)

	var crossing_x : float = _segment_edge_facing(indoor, outside.x_center)
	var crossing_y : float = indoor.y_level * -48.0
	return NavigationModule.swapInOutSidewaysPhase.new(Vector2(crossing_x, crossing_y), entering)

# Debug visualization for the abstracted floor model. Encodes:
#   box style    -> outside (gray outline) vs real floor (filled green)
#   box width    -> room count on that floor segment
#   magenta dot  -> computed x_center
#   colored ring -> connector, color keyed by type
#   label        -> y_level, is_outside, room count, x_center
# duration 0.0 draws for a single frame (call every _process); pass a
# positive duration for a one-off call from e.g. a console command.
func debug_draw_floor_infos(duration: float = 0.0) -> void:
	for y_level : int in _floors.keys():
		var world_y : float = y_level * -48.0
		for floor_info : floorInfo in _floors[y_level]:
			_debug_draw_floor_info(floor_info, world_y, duration)
	_debug_draw_vertical_connectors(duration)

# One pair of arrows per level-to-level hop of each stairs/elevator connector,
# instead of per-floorInfo circles - a connector can be mirrored into many
# floorInfos (see _mirror_all_connectors), so drawing from the global
# _connectors registry avoids drawing the same hop over and over.
func _debug_draw_vertical_connectors(duration: float) -> void:
	_prune_invalid_connectors()
	for connector in _connectors.keys():
		var marker_color := Color.ORANGE if connector is RoomStairs else Color.CYAN
		var levels : Array = _connectors[connector].duplicate()
		levels.sort()
		var x : float = connector.get_center_position().x
		for i in range(levels.size() - 1):
			var from := _v(Vector2(x, levels[i] * -48.0))
			var to := _v(Vector2(x, levels[i + 1] * -48.0))
			DebugDraw2D.arrow(from, to, Color(marker_color, DEBUG_OPACITY), 2.0, duration, DEBUG_ARROW_HEAD_SIZE)
			DebugDraw2D.arrow(to, from, Color(marker_color, DEBUG_OPACITY), 2.0, duration, DEBUG_ARROW_HEAD_SIZE)

func _debug_draw_floor_info(floor_info: floorInfo, world_y: float, duration: float, ghost: bool = false) -> void:
	var cell_width := 48.0
	var box_width : float = floor_info.x_size * cell_width if floor_info.is_outside else max(floor_info.all_rooms.size() * cell_width, cell_width)
	var box_center := _v(Vector2(floor_info.x_center, world_y - 16.0))
	var box_size := Vector2(box_width - 8, 32.0)
	var alpha := 0.3 * DEBUG_OPACITY if ghost else DEBUG_OPACITY

	if floor_info.is_outside:
		DebugDraw2D.rect(box_center, box_size, Color(Color.DIM_GRAY, alpha), 2.0, duration)
	else:
		DebugDraw2D.rect_filled(box_center, box_size, Color(0.0, 1.0, 0.0, 0.25 * alpha), duration)
		DebugDraw2D.rect(box_center, box_size, Color(Color.GREEN, alpha), 2.0, duration)

	DebugDraw2D.circle_filled(_v(Vector2(floor_info.x_center, world_y)), 3.0, 8, Color(Color.MAGENTA, alpha), duration)

	for connector in _valid_connectors_of(floor_info):
		if connector is RoomBouncer:
			DebugDraw2D.circle(_v(Vector2(connector.get_center_position().x, world_y)), 6.0, 12, Color(Color.RED, alpha), 2.0, duration)

	if not floor_info.is_outside:
		for neighbor : floorInfo in floor_info.neighbors:
			_debug_draw_indoor_outside_crossing(floor_info, neighbor, world_y, duration, alpha)

# A bidirectional arrow spanning the actual locations that connect: from the
# bouncer's exact position to the outside segment's near edge when a bouncer
# gates the crossing, or from the indoor segment's near edge to the outside
# segment's near edge when it's just an open side - so the arrow always shows
# where you actually end up, not just an arbitrary point on the boundary.
const CROSSING_ARROW_MIN_LEN := 14.0
const CROSSING_ARROW_MAX_LEN := 40.0

func _debug_draw_indoor_outside_crossing(indoor: floorInfo, outside: floorInfo, world_y: float, duration: float, alpha: float) -> void:
	var bouncer = _bouncer_gating(indoor, outside)

	var from_x : float = bouncer.get_center_position().x if bouncer != null else _segment_edge_facing(indoor, outside.x_center)
	var to_x : float = _segment_edge_facing(outside, indoor.x_center)

	# the door can sit far from the boundary inside a wide segment, and truly
	# adjacent segments have ~0 gap between their edges - clamp so the arrow
	# is never huge, and never so short it's invisible/degenerate
	var direction := signf(to_x - from_x)
	if direction == 0.0:
		direction = 1.0 if outside.x_center > indoor.x_center else -1.0
	var length := clampf(abs(to_x - from_x), CROSSING_ARROW_MIN_LEN, CROSSING_ARROW_MAX_LEN)
	to_x = from_x + direction * length

	var y := world_y - 16.0
	var from := _v(Vector2(from_x, y))
	var to := _v(Vector2(to_x, y))
	# red = supervised bouncer door, yellow = open side, no gate - matches the
	# path-phase tool's useDoorSwapPhase/swapInOutSidewaysPhase colors
	var color := Color.RED if bouncer != null else Color.YELLOW
	DebugDraw2D.arrow(from, to, Color(color, alpha), 2.0, duration, DEBUG_ARROW_HEAD_SIZE)
	DebugDraw2D.arrow(to, from, Color(color, alpha), 2.0, duration, DEBUG_ARROW_HEAD_SIZE)

func _segment_edge_facing(segment: floorInfo, other_x_center: float) -> float:
	var cell_width := 48.0
	var width : float = segment.x_size * cell_width if segment.is_outside else max(segment.all_rooms.size() * cell_width, cell_width)
	var half := width / 2.0
	return segment.x_center + half if other_x_center > segment.x_center else segment.x_center - half

# Debug visualization for just the currently hovered floor segment: full
# detail for the hovered floorInfo, plus every floorInfo it's actually
# reachable from/to (same-level via bouncer, vertical via stairs/elevator)
# drawn dimmed ("ghost"), with the specific connectors bridging them
# highlighted - so you can verify exactly what one floor considers connected
# without the whole building's clutter.
func debug_draw_hovered_floor_info(hover_position: Vector2, duration: float = 0.0) -> void:
	var current_floor : floorInfo = query_floor_at_position(hover_position)
	if current_floor == null:
		return

	var world_y : float = current_floor.y_level * -48.0
	_debug_draw_floor_info(current_floor, world_y, duration)

	for neighbor : floorInfo in _get_connected_floors(current_floor):
		_debug_draw_floor_info(neighbor, neighbor.y_level * -48.0, duration, true)

	for connector in _valid_connectors_of(current_floor):
		if not (connector is RoomStairs or connector is RoomElevator):
			continue
		var marker_color := Color.ORANGE if connector is RoomStairs else Color.CYAN
		var x : float = connector.get_center_position().x
		for level in _connectors.get(connector, []):
			if level == current_floor.y_level:
				continue
			var other := _v(Vector2(x, level * -48.0))
			var here := _v(Vector2(x, world_y))
			DebugDraw2D.arrow(here, other, Color(marker_color, DEBUG_OPACITY), 2.0, duration, DEBUG_ARROW_HEAD_SIZE)
			DebugDraw2D.arrow(other, here, Color(marker_color, DEBUG_OPACITY), 2.0, duration, DEBUG_ARROW_HEAD_SIZE)

# Debug visualization of the actual phase-graph pathing between two world
# positions - exercises _find_path/create_phase exactly like a real NPC
# would, drawn as a sequence of colored segments so each phase type is
# distinguishable: white = plain walk, orange = stairs zig-zag (each step
# marked), yellow = open-side indoor/outside crossing, red = bouncer door,
# cyan = elevator ride. Same palette as the floor/connector overview tool.
func debug_draw_path_between(start_pos: Vector2, end_pos: Vector2, duration: float = 0.0) -> void:
	var start_floor : floorInfo = query_floor_at_position(start_pos)
	var goal_floor : floorInfo = query_floor_at_position(end_pos)
	if start_floor == null or goal_floor == null:
		return

	DebugDraw2D.circle_filled(_v(start_pos), 4.0, 8, Color(Color.LIME_GREEN, DEBUG_OPACITY), duration)
	DebugDraw2D.circle_filled(_v(end_pos), 4.0, 8, Color(Color.RED, DEBUG_OPACITY), duration)

	var phases : Array[NavigationModule.navigationPhase] = _find_path(start_floor, goal_floor, start_pos)
	phases.append(NavigationModule.walkPhase.new(end_pos))
	debug_draw_phases(phases, start_pos, duration)

# Draws an already-computed phase sequence starting from start_pos - shared by
# the hypothetical click-to-cursor tool above and the live selected-NPC path
# viewer below, so both always agree on what each phase type looks like.
func debug_draw_phases(phases: Array[NavigationModule.navigationPhase], start_pos: Vector2, duration: float = 0.0) -> void:
	var current_pos := start_pos
	for phase in phases:
		current_pos = _debug_draw_phase(phase, current_pos, duration)

# Debug visualization of a live NPC's actual in-flight navigation path - same
# palette as debug_draw_path_between, but reads the real target_path instead
# of computing a hypothetical one.
func debug_draw_live_npc_path(npc: NPC, duration: float = 0.0) -> void:
	if npc == null or npc.Navigation == null or not npc.Navigation.has_target:
		return
	DebugDraw2D.circle_filled(_v(npc.global_position), 4.0, 8, Color(Color.LIME_GREEN, DEBUG_OPACITY), duration)
	debug_draw_phases(npc.Navigation.target_path, npc.global_position, duration)

func _debug_draw_phase(phase: NavigationModule.navigationPhase, from_pos: Vector2, duration: float) -> Vector2:
	if phase is NavigationModule.useStairsPhase:
		var color := Color(Color.ORANGE, DEBUG_OPACITY)
		var prev := from_pos
		for waypoint : Vector2 in phase.waypoints:
			DebugDraw2D.arrow(_v(prev), _v(waypoint), color, 2.0, duration, DEBUG_ARROW_HEAD_SIZE)
			DebugDraw2D.circle_filled(_v(waypoint), 3.0, 8, color, duration)
			prev = waypoint
		return phase.last_waypoint()

	if phase is NavigationModule.useDoorSwapPhase:
		var color := Color(Color.RED, DEBUG_OPACITY)
		DebugDraw2D.arrow(_v(from_pos), _v(phase.target_location), color, 2.0, duration, DEBUG_ARROW_HEAD_SIZE)
		DebugDraw2D.circle(_v(phase.target_location), 6.0, 12, color, 2.0, duration)
		return phase.target_location

	if phase is NavigationModule.useElevatorPhase:
		var color := Color(Color.CYAN, DEBUG_OPACITY)
		DebugDraw2D.arrow(_v(from_pos), _v(phase.target_location), color, 2.0, duration, DEBUG_ARROW_HEAD_SIZE)
		var exit_pos : Vector2 = phase.to_room.get_exit_position()
		DebugDraw2D.arrow(_v(phase.target_location), _v(exit_pos), color, 2.0, duration, DEBUG_ARROW_HEAD_SIZE)
		return exit_pos

	if phase is NavigationModule.swapInOutSidewaysPhase:
		var color := Color(Color.YELLOW, DEBUG_OPACITY)
		DebugDraw2D.arrow(_v(from_pos), _v(phase.target_location), color, 2.0, duration, DEBUG_ARROW_HEAD_SIZE)
		return phase.target_location

	# walkPhase, or any other plain navigationPhase
	var color := Color(Color.WHITE, DEBUG_OPACITY)
	DebugDraw2D.arrow(_v(from_pos), _v(phase.target_location), color, 2.0, duration, DEBUG_ARROW_HEAD_SIZE)
	return phase.target_location

class floorInfo:
	var is_outside = false
	var y_level : int
	var x_size : int
	var x_center : float
	var all_rooms = []
	var connectors = [] #stairs, elevators, doors and edges
	var neighbors = [] #adjacent same-level indoor/outside segments, walkable from the side
