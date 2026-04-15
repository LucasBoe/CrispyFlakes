extends Control
class_name MenuUIHandler

@onready var worker_tab = $MarginContainer/UIWorkers
@onready var build_tab = $MarginContainer/UIBuild
@onready var settings_tab = $MarginContainer/UISettings

@onready var worker_button = $HBoxContainer/Button_Workers
@onready var build_button = $HBoxContainer/Button_Build
@onready var settings_button = $HBoxContainer/Button_Settings

var visible_tab = null
var all_tabs : Array

func _ready():
	bind_slot(worker_button, worker_tab)
	bind_slot(build_button, build_tab)
	bind_slot(settings_button, settings_tab)
	set_tab(null)
	


func _on_ui_close():
	set_tab(null)
	
func bind_slot(button, tab):
	all_tabs.append(tab)
	button.pressed.connect(set_tab.bind(tab))

func set_tab(tab):
	if visible:
		SoundPlayer.play_ui_click_down()
	else:
		SoundPlayer.play_ui_click_up()
	
	if tab != null and tab == visible_tab:
		tab.visible = not tab.visible
	else:
		for t in all_tabs:
			t.visible = t == tab
			
	visible_tab = tab
