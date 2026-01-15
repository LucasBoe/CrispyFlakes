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
