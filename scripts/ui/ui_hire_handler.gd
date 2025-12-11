extends FullscreenDragable

@onready var hire_dummy = $MarginContainer/MarginContainer/VBoxContainer/VBoxContainer/Button

func _ready():
	super._ready()
	visibility_changed.connect(_on_visibility_changed)
	hire_dummy.hide()
	hide()
	
func _on_visibility_changed():
	if visible:
		while hire_dummy.get_parent().get_child_count() < 3:
			var instance = hire_dummy.duplicate()
			instance.hire_ui = self
			hire_dummy.get_parent().add_child(instance)
			instance.show()
