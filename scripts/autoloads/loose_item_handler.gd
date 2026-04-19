extends Node2D

var loose_items = {}

func register_loose_item_instance(item : Item):
	if not is_instance_valid(item):
		return
	
	if not loose_items.has(item.itemType):
		loose_items[item.itemType] = []

	_prune_invalid_for(item.itemType)
		
	if not loose_items[item.itemType].has(item):
		loose_items[item.itemType].append(item)
	
func unregister_loose_item_instance(item : Item):
	if not is_instance_valid(item):
		_prune_all_invalid()
		return
		
	if not loose_items.has(item.itemType):
		return

	_prune_invalid_for(item.itemType)
		
	if not loose_items[item.itemType].has(item):
		return
		
	loose_items[item.itemType].erase(item)

func get_closest_to(global_pos: Vector2, item_type ):
	var closest: Item = null
	var best_dist := INF
	
	if not loose_items.has(item_type):
		return null

	var arr: Array = loose_items[item_type]

	for i in range(arr.size() - 1, -1, -1):
		var candidate = arr[i]
		if not is_instance_valid(candidate):
			arr.remove_at(i)
			continue

		var it := candidate as Item
		if it == null:
			arr.remove_at(i)
			continue
			
		var d := it.global_position.distance_squared_to(global_pos)
		if d < best_dist:
			best_dist = d
			closest = it

	return closest

func _prune_invalid_for(item_type) -> void:
	if not loose_items.has(item_type):
		return

	var arr: Array = loose_items[item_type]
	for i in range(arr.size() - 1, -1, -1):
		if not is_instance_valid(arr[i]):
			arr.remove_at(i)

func _prune_all_invalid() -> void:
	for item_type in loose_items.keys():
		_prune_invalid_for(item_type)
