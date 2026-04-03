extends NeedBehaviour
class_name ArrestedBehaviour

var cell : RoomPrison = null
var is_in_cell = false
var notification_instance

func loop():
	npc.Animator.handcuffs.show()
	notification_instance = UiNotifications.create_npc_notification(npc, UiNotifications.ICON_HANDCUFFS, true)

	while not cell:
		await pause(1)

	await move(cell.get_center_floor_position())
	npc.Animator.set_z(-150)
	is_in_cell = true
	cell.prisoners.append(npc)
	await move(cell.get_random_floor_position())

	UiNotifications.try_kill(notification_instance)
	while true:
		await pause(2)

func stop_loop():
	npc.Animator.handcuffs.hide()
	cell.prisoners.erase(npc)
	npc.Animator.set_z(0)
	UiNotifications.try_kill(notification_instance)
	return super.stop_loop()
