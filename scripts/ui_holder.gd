extends CanvasLayer
class_name UIHolder

const UI_ITEMS_CONTROLLER := preload("res://scripts/ui/ui_items_controller.gd")

@onready var tutorial: UITutorial = %UITutorial
#@onready var room: UIRoom = $UIRoom
@onready var money : UIMoney = %UIMoney
@onready var dialogue: UIDialogueHandler = %UIDialogue
@onready var encounter: UIEncounter = %UIEncounter
#@onready var time: UITime = $UITime
@onready var menu: MenuUIHandler = %UIMenu
#@onready var fullscreen: UIFullscreen = $UIFullscreen
@onready var selection :  = %UISelectionPanel
@onready var hud: Control = $UIHUD
@onready var controls: Control = $UIControls
@onready var hire : UIHire = %UIFullscreen.get_node("UIHire") as UIHire
@onready var confirm : UIConfirm = %UIFullscreen.get_node("UIConfirm") as UIConfirm
@onready var rename: UIRename = %UIFullscreen.get_node("UIRename") as UIRename
@onready var ui_items: Control = $UIItems
#@onready var pause: UIPause = $UIPause


func _init():
	Global.UI = self

func _ready() -> void:
	ui_items.hide()

	if ui_items.get_node_or_null("UIItemsController") != null:
		return

	var controller := UI_ITEMS_CONTROLLER.new()
	controller.name = "UIItemsController"
	ui_items.add_child(controller)

func _unhandled_input(event):
	if not event.is_action_pressed("click"):
		return

	if get_viewport().gui_get_hovered_control() != null:
		return

	if PlacementHandler.is_placing:
		return

	tutorial._on_ui_close()
	menu._on_ui_close()
