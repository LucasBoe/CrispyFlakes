extends RoomBase
class_name RoomTable

@onready var stools = [$Stool,$Stool2,$Stool3]
var guests = {}

const MAX_GUEST_COUNT = 3

func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
	for i in range(0,MAX_GUEST_COUNT):
		guests[i] = null

func is_free():
	return get_free_count() > 0
	
func get_free_count():
	var c = 0
	for x in MAX_GUEST_COUNT:
		if guests[x] == null:
			c+= 1
	return c
	
func sit(guest : NPC):
	var index = 0
	
	for i in MAX_GUEST_COUNT:
		if guests[i] == null:
			index = i
			guests[i] = guest
			break
	
	var stool = stools[index]
	guest.Animator.z_index = -50
	
	show_guest_count_notification()
	
	return stool.global_position
	
func stand_up(guest : NPC):
	guest.Animator.z_index = 0
	for i in MAX_GUEST_COUNT:
		if guests[i] == guest:
			guests[i] = null
	
	show_guest_count_notification()

func show_guest_count_notification():
	var free = get_free_count()
	var max = MAX_GUEST_COUNT
	var txt = str(max - free, "/", max)
	UiNotifications.create_notification_static(txt, get_center_position(), null, Color.BLACK if free > 0 else Color.RED)
