extends Control
class_name UITutorial

@onready var item_dummy : TutorialUIItem = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer

var instances = []

func _ready():
	hide()
	item_dummy.hide()
	
func add_task(text):
	var item_instance = item_dummy.duplicate() as TutorialUIItem
	item_dummy.get_parent().add_child(item_instance)
	item_instance.text_label.text = text
	item_instance.show()
	instances.append(item_instance)
	show()
	return item_instance

func clear_tasks():
	for i in instances:
		i.queue_free()
		
	instances.clear()
	hide()
