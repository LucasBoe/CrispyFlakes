extends Node2D

class_name ItemModule

var npc : NPC
var currentItem : Item

func _ready():
	npc =  $"../.."
	if npc:
		pass
		
	npc.Item = self

func PickUp(item):
	if currentItem:
		DropCurrent()
		
	currentItem = item
	currentItem.reparent(self)
	currentItem.position = Vector2.ZERO

func TryPutTo(storage) -> bool:
	if storage.TryReceive(currentItem):
		currentItem = null
		return true
	else:
		return false
	
func DropCurrent():
	currentItem.reparent(Global.ItemSpawner)
	currentItem.global_position = npc.global_position
	currentItem = null
