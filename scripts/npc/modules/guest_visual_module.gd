extends AnimationModule

@onready var handcuffs = $Handcuffs

func _ready():
	super._ready()
	handcuffs.hide()
