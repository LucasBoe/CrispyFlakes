extends Node2D

var loose_items = {}

func register_loose_item_instance(item : Item):
	
	if not loose_items.has(item.itemType):
		loose_items[item.itemType] = []
		
	if not loose_items[item.itemType].has(item):
		loose_items[item.itemType].append(item)
	
func unregister_loose_item_instance(item : Item):
		
	if not loose_items.has(item.itemType):
		return
		
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
		var it: Item = arr[i]

		if not is_instance_valid(it):
			arr.remove_at(i)
			continue
			
		var d := it.global_position.distance_squared_to(global_pos)
		if d < best_dist:
			best_dist = d
			closest = it

	return closest
