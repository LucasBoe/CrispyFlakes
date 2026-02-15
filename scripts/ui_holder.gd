extends CanvasLayer
class_name UIHolder

@onready var tutorial: UITutorial = $UITutorial
#@onready var room: UIRoom = $UIRoom
@onready var resources: UIRessourceHandler = $UIResources
@onready var dialogue: UIDialogueHandler = $UIDialogue
#@onready var time: UITime = $UITime
@onready var menu: MenuUIHandler = $UIMenu
#@onready var fullscreen: UIFullscreen = $UIFullscreen
@onready var hire : UIHire = $UIFullscreen/UIHire
@onready var confirm : UIConfirm = $UIFullscreen/UIConfirm
@onready var close_handler : UICloseHandler = $UICloseHandler
#@onready var pause: UIPause = $UIPause

func _ready():
	Global.UI = self
