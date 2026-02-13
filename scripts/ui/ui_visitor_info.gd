extends Control

@onready var count_label = $CountLabel
@onready var progression_label = $ProgressionLabel
@onready var progression_bar = $ProgressBar
@onready var tier_list_dummy = $VBoxContainer/HBoxContainer

var tier_list_instances = []

func _ready():
	for i in TierHandler.max_tier + 1:
		var instance = tier_list_dummy.duplicate()
		tier_list_dummy.get_parent().add_child(instance)
		tier_list_instances.append(instance)
		refresh_tier(i)
		
	tier_list_dummy.hide()
	TierHandler.tier_unlocked_signal.connect(refresh_tier)
	
func refresh_tier(tier_index):
	var item = tier_list_instances[tier_index]
	(item.get_child(0) as TextureRect).texture = TierHandler.tier_icons[tier_index]
	(item.get_child(1) as Label).text = str("Rooms (", TierHandler.tier_visitors_needed[tier_index], "Guests)")
	(item.get_child(2) as TextureRect).texture = load("res://assets/sprites/ui/tutorial_todo_checked.png") if TierHandler.current_tier >= tier_index else load("res://assets/sprites/ui/tutorial_todo_unchecked.png")

func _process(delta):
	
	count_label.text = str(Global.NPCSpawner.guests.size())
	if Global.should_auto_spawn_guests:
		progression_bar.value = Global.NPCSpawner.next_guest_progression
		progression_label.text = str(Global.NPCSpawner.guests_per_day_rate,"/D")
	else:
		progression_label.text = ""
