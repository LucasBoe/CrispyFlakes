extends RoomBase
class_name RoomTable

var guests = {}
var max_guest_count = 0
var current_module = null

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)

	var modules_root = get_node_or_null("ModulesRoot")
	if modules_root:
		for group in modules_root.get_children():
			for module in group.get_children():
				if not module.has_method("set_bought"):
					continue
				module.bought_changed.connect(_on_module_bought)
				if module.bought:
					_apply_module(module)

func _on_module_bought(module) -> void:
	if module.bought:
		_apply_module(module)

func _apply_module(module) -> void:
	current_module = module
	max_guest_count = module.max_guests if module.max_guests > 0 else module.seat_positions.size()
	guests.clear()
	for i in max_guest_count:
		guests[i] = null

func is_free():
	return get_free_count() > 0

func get_free_count():
	var c = 0
	for x in max_guest_count:
		if guests[x] == null:
			c += 1
	return c

func sit(guest : NPC):
	var index = 0
	for i in max_guest_count:
		if guests[i] == null:
			index = i
			guests[i] = guest
			break

	guest.Animator.set_sitting(true)
	guest.Animator.set_z(Enums.ZLayer.NPC_BEHIND_ROOM_CONTENT)

	show_guest_count_notification()

	return current_module.to_global(current_module.seat_positions[index])

func stand_up(guest : NPC):
	guest.Animator.set_sitting(false)
	guest.Animator.set_z(Enums.ZLayer.NPC_DEFAULT)
	for i in max_guest_count:
		if guests[i] == guest:
			guests[i] = null

	show_guest_count_notification()

func show_guest_count_notification():
	var free = get_free_count()
	var txt = str(max_guest_count - free, "/", max_guest_count)
	UiNotifications.create_notification_static(txt, get_center_position(), null, Color.BLACK if free > 0 else Color.RED)
