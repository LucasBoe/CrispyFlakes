extends AnimationModule

@onready var handcuffs = $Handcuffs
@onready var escort_chain: EscortChain = $"../EscortChain"

func _ready():
	super._ready()
	handcuffs.hide()
	if is_instance_valid(escort_chain):
		escort_chain.subject = npc
		escort_chain.handcuffs = handcuffs

func set_escort_target(target: NPC) -> void:
	if is_instance_valid(escort_chain):
		escort_chain.set_target(target)

func clear_escort_target() -> void:
	if is_instance_valid(escort_chain):
		escort_chain.clear_target()
