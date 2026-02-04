extends HBoxContainer
class_name TutorialUIItem

@onready var text_label = $Label
@onready var texture_rect = $TextureRect

var is_done = false

var done_icon = preload("res://assets/sprites/ui/tutorial_todo_checked.png")

func set_text(text):
	text_label.text = str("- ", text)

func set_done():
	is_done = true
	texture_rect.texture = done_icon
