extends Control
class_name MenuUIHandler

@onready var worker_tab = $MarginContainer/UIWorkers
@onready var build_tab = $MarginContainer/UIBuild

@onready var worker_button = $HBoxContainer/Button_Workers
@onready var build_button = $HBoxContainer/Button_Build

var visible_tab = null
var all_tabs : Array

func _ready():
	bind_slot(worker_button, worker_tab)
	bind_slot(build_button, build_tab)
	set_tab(null)
	
func bind_slot(button, tab):
	all_tabs.append(tab)
	button.pressed.connect(set_tab.bind(tab))

func set_tab(tab):
	(SoundPlayer.mouse_click_down if visible else SoundPlayer.mouse_click_up).play()
	
	if tab != null and tab == visible_tab:
		tab.hide()
	else:
		for t in all_tabs:
			t.visible = t == tab
			
	visible_tab = tab
