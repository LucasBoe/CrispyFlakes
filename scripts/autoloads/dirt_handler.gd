extends Node

var dirt_instances = []
var dirt_sprite = preload("res://assets/sprites/floor-dirt.png")

func create_dirt_at(position_in_global_space):
	
	var new_dirt_instance := Sprite2D.new() # create new
	new_dirt_instance.global_position = position_in_global_space - Vector2(0,1) # place new
	new_dirt_instance.texture = dirt_sprite # assign sprite
	new_dirt_instance.region_enabled = true
	new_dirt_instance.region_rect = Rect2i(0 if randf() < .5 else 8, 0, 8, 2)
	add_child(new_dirt_instance)
	dirt_instances.append(new_dirt_instance) # add to list

func get_closest_to(global_pos: Vector2) -> Sprite2D:
	var closest: Sprite2D = null
	var best_dist := INF

	for i in range(dirt_instances.size() - 1, -1, -1):
		var dirt = dirt_instances[i]
		if not is_instance_valid(dirt):
			dirt_instances.remove_at(i)
			continue

		var d = dirt.global_position.distance_squared_to(global_pos)
		if d < best_dist:
			best_dist = d
			closest = dirt

	return closest

func get_all_in_range(global_pos: Vector2, range: float) -> Array[Sprite2D]:
	var dirt_in_range: Array[Sprite2D] = []
	var range_squared := range * range

	for i in range(dirt_instances.size() - 1, -1, -1):
		var dirt := dirt_instances[i] as Sprite2D
		if not is_instance_valid(dirt):
			dirt_instances.remove_at(i)
			continue

		if dirt.global_position.distance_squared_to(global_pos) <= range_squared:
			dirt_in_range.append(dirt)

	return dirt_in_range

func clean_dirt(dirt: Sprite2D) -> void:
	if dirt_instances.has(dirt):
		dirt_instances.erase(dirt)
	if is_instance_valid(dirt):
		dirt.queue_free()
