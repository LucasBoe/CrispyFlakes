extends Node

var active_fights = []

func get_or_create_fight(npc : NPC) -> Fight:
	
	var fight = null
	
	if active_fights.size() > 0:
		fight = active_fights[0]
	else:	
		var room = Global.Building.query.closest_room_of_type(RoomBase, npc.global_position)
		fight = Fight.new()
		active_fights.append(fight)
		fight.start_fight(room)
	
	fight.participants.append(npc)
	return fight
	
func get_fight_for_room(room : RoomBase):			
	for a in active_fights:
		if a.room == room:
			return a
			
	return null

func _process(delta):
	for f : Fight in active_fights:
		f.energy -= delta / Fight.MAX_DURATION_IN_SECONDS
		
		if f.energy <= 0:
			f.end_fight()
			active_fights.erase(f)
