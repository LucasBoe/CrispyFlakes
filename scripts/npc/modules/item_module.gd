extends Node2D

class_name ItemModule

var npc : NPC
var currentItem : Item

func _ready():
	npc =  $"../.."
	if npc:
		pass
		
	npc.Item = self
	
func is_item(item_type : Enum.Items):
	if currentItem == null:
		return false
		
	return currentItem.itemType == item_type

func PickUp(item):
	if currentItem:
		DropCurrent()
		
	currentItem = item
	currentItem.reparent(self, false)
	LooseItemHandler.unregister_loose_item_instance(item)
	currentItem.position = Vector2.ZERO
	currentItem.z_index = 0

func TryPutTo(storage) -> bool:
	if storage.TryReceive(currentItem):
		currentItem = null
		return true
	else:
		return false
	
func DropCurrent() -> Item:
	
	if not currentItem:
		return null
	
	var item = currentItem
	currentItem.reparent(Global.ItemSpawner)
	LooseItemHandler.register_loose_item_instance(item)
	currentItem.global_position = npc.global_position
	currentItem = null
	return item
