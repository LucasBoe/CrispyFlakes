extends PanelContainer
class_name UIRename

@onready var _line_edit: LineEdit = $MarginContainer/MarginContainer/VBoxContainer/LineEdit
@onready var button_ok: Button = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/ButtonOk
@onready var button_cancel: Button = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/ButtonCancel

var _callback: Callable

func _ready():
	button_ok.pressed.connect(_click_ok)
	button_cancel.pressed.connect(_click_cancel)
	_line_edit.text_submitted.connect(func(_s): _click_ok())
	hide()

func show_rename(current_name: String, callback: Callable):
	_line_edit.text = current_name
	_callback = callback
	show()
	_line_edit.grab_focus()
	_line_edit.select_all()

func _click_ok():
	SoundPlayer.play_ui_click_up()
	var new_name: String = _line_edit.text.strip_edges()
	if not new_name.is_empty():
		_callback.call(new_name)
	hide()

func _click_cancel():
	SoundPlayer.play_ui_click_up()
	hide()
