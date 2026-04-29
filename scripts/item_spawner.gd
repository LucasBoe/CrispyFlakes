extends Node2D

class_name ItemSpawner

@onready var itemScene : PackedScene = preload("res://scenes/item.tscn")

var items : Array

func _init():
	Global.ItemSpawner = self

func _enter_tree():
	Global.ItemSpawner = self
	
func create(itemIndentifier : Enum.Items, pos : Vector2) -> Item:
	var instance = itemScene.instantiate().init(itemIndentifier)
	items.append(instance)
	add_child(instance)
	instance.position = pos
	instance.play_spawn_sound()
	LooseItemHandler.register_loose_item_instance(instance)
	return instance
