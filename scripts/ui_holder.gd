extends CanvasLayer
class_name UIHolder

@onready var tutorial: UITutorial = $UITutorial
#@onready var room: UIRoom = $UIRoom
@onready var resources: UIRessourceHandler = $UIResources
@onready var money : UIMoney = $UIMoney
@onready var dialogue: UIDialogueHandler = $UIDialogue
#@onready var time: UITime = $UITime
@onready var menu: MenuUIHandler = $UIMenu
#@onready var fullscreen: UIFullscreen = $UIFullscreen
@onready var selection :  = $UISelectionPanel
@onready var hire : UIHire = $UIFullscreen/UIHire
@onready var confirm : UIConfirm = $UIFullscreen/UIConfirm
@onready var rename: UIRename = $UIFullscreen/UIRename
#@onready var pause: UIPause = $UIPause


func _init():
	Global.UI = self

func _unhandled_input(event):
	if not event.is_action_pressed("click"):
		return

	if get_viewport().gui_get_hovered_control() != null:
		return

	if PlacementHandler.is_placing:
		return

	menu._on_ui_close()
