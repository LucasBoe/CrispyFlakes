extends NeedBehaviour
class_name ArestedBehaviour

var is_in_cell = false
var notification_instance

func loop():
	npc.Animator.handcuffs.show()
	notification_instance = UiNotifications.create_npc_notification(npc, UiNotifications.ICON_HANDCUFFS, true)
	
	while not is_in_cell:
		await pause(1)
		
	UiNotifications.try_kill(notification_instance)
	var room = Global.Building.get_closest_room_of_type(RoomBase, npc.global_position)
	while true:
		await move(room.get_random_floor_position())

func stop_loop():
	npc.Animator.handcuffs.hide()
	UiNotifications.try_kill(notification_instance)
	return super.stop_loop()
