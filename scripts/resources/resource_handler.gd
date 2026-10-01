extends Node2D

## Non-money resource counters. Money lives entirely in MoneyHandler.

var resources : Dictionary = {}
signal on_resource_changed_signal

func _ready():
	for r in Enum.Resources.values():
		resources[r] = 0

func change_resource(resource, change):
	var r = resource as Enum.Resources
	resources[r] += change
	on_resource_changed_signal.emit(r, resources[r], change)

func has(resource, amount):
	if not resources.has(resource):
		return false

	if resources[resource] < amount:
		return false

	return true

func _process(_delta):
	if Input.is_key_pressed(KEY_5):
		MoneyHandler.earn_animated(4, get_global_mouse_position(), MoneyHandler.NO_LOCATION, "Debug Add Money")
