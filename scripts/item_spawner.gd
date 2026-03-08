extends Node2D

class_name ItemSpawner

@onready var itemScene : PackedScene = preload("res://scenes/item.tscn")

var items : Array

func _ready():
	Global.ItemSpawner = self

func Create(itemIndentifier : Enum.Items, pos : Vector2) -> Item:
	var instance = itemScene.instantiate().init(itemIndentifier)
	items.append(instance)
	add_child(instance)
	instance.position = pos
	return instance
