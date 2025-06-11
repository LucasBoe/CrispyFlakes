extends Control

class_name UIRessourceHandler

const labelScene : PackedScene = preload("res://scenes/ui/ui_resource_label.tscn")

var labelResourceDict : Dictionary = {}

func _ready():
	for resourceType in Enum.Resources.values():
		var instance = labelScene.instantiate()
		($HBoxContainer).add_child(instance)
		labelResourceDict[resourceType] = instance
		
	ResourceHandler.on_resource_changed.connect(on_resource_changed)
	
func on_resource_changed(resourceType, newAmount, change):
	print(str("on resource changed", resourceType))
	labelResourceDict[resourceType].update_amount(newAmount, change)
