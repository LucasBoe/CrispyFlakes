extends RoomBase
class_name RoomGambling

var guests: Dictionary = {}
var max_guest_count: int = 3

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)

	for i in max_guest_count:
		guests[i] = null

func is_free() -> bool:
	return get_free_count() > 0

func get_free_count() -> int:
	var c: int = 0
	for i in max_guest_count:
		if guests[i] == null:
			c += 1
	return c

func sit(guest: NPC) -> Vector2:
	for i in max_guest_count:
		if guests[i] == null:
			guests[i] = guest
			break

	guest.Animator.set_sitting(true)
	guest.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)

	show_guest_count_notification()

	return get_random_floor_position()

func stand_up(guest: NPC) -> void:
	guest.Animator.set_sitting(false)
	guest.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	for i in max_guest_count:
		if guests[i] == guest:
			guests[i] = null

	show_guest_count_notification()

func show_guest_count_notification() -> void:
	var free: int = get_free_count()
	var txt: String = str(max_guest_count - free, "/", max_guest_count)
	UiNotifications.create_notification_static(txt, get_center_position(), null, Color.BLACK if free > 0 else Color.RED)
