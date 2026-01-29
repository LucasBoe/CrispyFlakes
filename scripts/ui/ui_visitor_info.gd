extends Control

@onready var count_label = $CountLabel
@onready var progression_label = $ProgressionLabel
@onready var progression_bar = $ProgressBar


func _process(delta):
	
	count_label.text = str(Global.NPCSpawner.guests.size())
	if Global.should_auto_spawn_guests:
		progression_bar.value = Global.NPCSpawner.next_guest_progression
		progression_label.text = str(Global.NPCSpawner.guests_per_day_rate,"/D")
	else:
		progression_label.text = ""
