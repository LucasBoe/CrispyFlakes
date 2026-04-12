extends Node

var rooms = []

const REFRESH_RATE = 1.0

func _init():
	GlobalEventHandler.on_room_created_signal.connect(_on_room_created)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_room_deleted)
	
func _ready():
	notification_loop()
	
func _on_room_created(room : RoomBase):
	
	await get_tree().process_frame
	
	if not room.associated_job:
		return
	
	if room is RoomWell: #not mandatory
		return

	if room is RoomWaterTower:
		rooms.append(room)
		return

	#only when people need to be arested
	if room is RoomPrison\
	and JobPrisonBehaviour.count_people_that_need_arrestment() == 0:
		return
		
	rooms.append(room)
	
func _on_room_deleted(room : RoomBase):
	if rooms.has(room):
		rooms.erase(room)
		
func notification_loop():
	while true:
		if rooms.size() == 0:
			await pause(1)
		else:
			for r : RoomBase in rooms:
				if r is RoomWaterTower:
					if not (r as RoomWaterTower).has_water() and not r.worker:
						notify(r, "needs pumping", Color.ORANGE)
						await pause(REFRESH_RATE / rooms.size() - .01)
				elif r is RoomOuthouse:
					if (r as RoomOuthouse).is_full() and not r.worker:
						var has_cleaners = JobHandler.count_workers_in(Enum.Jobs.BROOM_CLEANER) > 0
						notify(r, "awaiting cleaner" if has_cleaners else "no cleaner", Color.DARK_GOLDENROD if has_cleaners else Color.ORANGE)
						await pause(REFRESH_RATE / rooms.size() - .01)
				elif r is RoomBed:
					if (r as RoomBed).needs_cleaning and not r.worker:
						var has_cleaners = JobHandler.count_workers_in(Enum.Jobs.BROOM_CLEANER) > 0
						notify(r, "awaiting cleaner" if has_cleaners else "no cleaner", Color.DARK_GOLDENROD if has_cleaners else Color.ORANGE)
						await pause(REFRESH_RATE / rooms.size() - .01)
				elif not r.worker:
					notify(r, "no worker", Color.ORANGE)
					await pause(REFRESH_RATE / rooms.size() - .01)
				await pause(0)
				
func notify(room : RoomBase, text, color, icon = null):
	UiNotifications.create_notification_static(text, room.get_notification_position(), icon, color, REFRESH_RATE)
	var rect = RoomHighlighter.request_rect(room, color)
	await pause(REFRESH_RATE)
	RoomHighlighter.dispose(rect)
		
func pause(time):
	return await get_tree().create_timer(time).timeout
