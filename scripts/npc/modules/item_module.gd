extends Node2D

class_name ItemModule

var npc : NPC
var current_item : Item

func _ready():
	npc =  $"../.."
	if npc:
		pass

	npc.Item = self

func is_item(item_type : Enum.Items):
	if current_item == null:
		return false

	return current_item.itemType == item_type

func pick_up(item):
	if current_item:
		drop_current()

	current_item = item
	current_item.reparent(self, false)
	LooseItemHandler.unregister_loose_item_instance(item)
	current_item.position = Vector2.ZERO
	current_item.z_index = 0

func try_put_to(storage) -> bool:
	if storage.try_receive(current_item):
		current_item = null
		return true
	else:
		return false

func drop_current() -> Item:

	if not current_item:
		return null

	var item = current_item
	current_item.reparent(Global.ItemSpawner)
	LooseItemHandler.register_loose_item_instance(item)
	current_item.global_position = npc.global_position
	current_item = null
	return item
