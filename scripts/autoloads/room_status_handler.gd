extends Node

var rooms = []
var enabled: bool = true

const REFRESH_RATE = 1.0
const _NO_WATER_ICON := preload("res://assets/sprites/ui/icon_no_water.png")
const _NO_ELECTRICITY_ICON := preload("res://assets/sprites/ui/no-electricity_icon_small.png")

func _init():
	GlobalEventHandler.on_room_created_signal.connect(_on_room_created)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_room_deleted)
	
func _ready():
	notification_loop()
	
func _on_room_created(room : RoomBase):
	var should_track := false
	
	await get_tree().process_frame

	if room is RoomWell: #not mandatory
		return

	if room is RoomJunk and (room as RoomJunk).suppress_no_worker_warning:
		return

	if room is RoomWaterTower or room is RoomToilet:
		should_track = true

	if room.get_electricity_consumption_amount() > 0 \
	or room.wants_infrastructure_layer(&"electricity") \
	or room.requires_infrastructure_layer(&"electricity"):
		should_track = true

	if room.associated_job:
		should_track = true

	#only when people need to be arested
	if room is RoomPrison\
	and JobPrisonBehaviour.count_people_that_need_arrestment() == 0:
		return

	if should_track and not rooms.has(room):
		rooms.append(room)
	
func _on_room_deleted(room : RoomBase):
	if rooms.has(room):
		rooms.erase(room)
		
func notification_loop():
	while true:
		if not enabled or rooms.size() == 0:
			await pause(1)
		else:
			for r : RoomBase in rooms:
				var water_alert := _get_water_shortage_color(r)
				var electricity_alert := _get_electricity_shortage_color(r)
				if water_alert != Color.TRANSPARENT:
					var is_critical := r.requires_infrastructure_layer(&"water")
					notify(r, "no water" if is_critical else "", water_alert, _NO_WATER_ICON if is_critical else null, is_critical)
					await pause(REFRESH_RATE / rooms.size() - .01)
				elif electricity_alert != Color.TRANSPARENT:
					var needs_power := r.requires_infrastructure_layer(&"electricity")
					notify(r, "no electricity" if needs_power else "", electricity_alert, _NO_ELECTRICITY_ICON if needs_power else null, needs_power)
					await pause(REFRESH_RATE / rooms.size() - .01)
				elif r is RoomWaterTower:
					if not (r as RoomWaterTower).has_water() and not r.worker:
						notify(r, "needs pumping", Color.ORANGE)
						await pause(REFRESH_RATE / rooms.size() - .01)
				elif r is RoomToilet:
					var toilet := r as RoomToilet
					if not toilet.has_working_water_supply():
						notify(toilet, toilet.get_unusable_status_text(), Color.ORANGE, toilet.get_unusable_status_icon())
						await pause(REFRESH_RATE / rooms.size() - .01)
				elif r is RoomOuthouse:
					if (r as RoomOuthouse).is_full() and not r.worker:
						var has_cleaners = JobHandler.count_workers_in(Enum.Jobs.BROOM_CLEANER) > 0
						notify(r, "awaiting cleaner" if has_cleaners else "no cleaner", Color.DARK_GOLDENROD if has_cleaners else Color.ORANGE)
						await pause(REFRESH_RATE / rooms.size() - .01)
				elif r is RoomGambling:
					var gambling := r as RoomGambling
					if gambling.should_warn_waiting_for_round():
						notify(r, gambling.get_waiting_round_warning_text(), Color.ORANGE)
						await pause(REFRESH_RATE / rooms.size() - .01)
					elif gambling.should_warn_no_jackpot():
						notify(r, "no jackpot", Color.YELLOW, null, false)
						await pause(REFRESH_RATE / rooms.size() - .01)
					elif gambling.should_warn_start_requirements():
						notify(r, gambling.get_requirement_warning_text(), Color.YELLOW, null, false)
						await pause(REFRESH_RATE / rooms.size() - .01)
				elif r is RoomBed:
					if (r as RoomBed).needs_cleaning and not r.worker:
						var has_cleaners = JobHandler.count_workers_in(Enum.Jobs.BROOM_CLEANER) > 0
						notify(r, "awaiting cleaner" if has_cleaners else "no cleaner", Color.DARK_GOLDENROD if has_cleaners else Color.ORANGE)
						await pause(REFRESH_RATE / rooms.size() - .01)
				elif r is RoomSafe:
					var safe := r as RoomSafe
					if not safe.worker:
						notify(safe, "no worker", Color.ORANGE)
						await pause(REFRESH_RATE / rooms.size() - .01)
					elif safe.should_warn_cannot_store_more_money():
						notify(safe, safe.get_full_warning_text(), Color.ORANGE)
						await pause(REFRESH_RATE / rooms.size() - .01)
				elif r is RoomStove:
					if not (r as RoomStove).is_heating() and not r.worker:
						notify(r, "no worker", Color.ORANGE)
						await pause(REFRESH_RATE / rooms.size() - .01)
				elif r.associated_job != null and not r.worker:
					notify(r, "no worker", Color.ORANGE)
					await pause(REFRESH_RATE / rooms.size() - .01)
				await pause(0)

func _get_water_shortage_color(room: RoomBase) -> Color:
	if not room.wants_infrastructure_layer(&"water"):
		return Color.TRANSPARENT
	var tower := Building.infrastructure.get_connected_provider(room, &"water") as RoomWaterTower
	if tower == null or tower.has_water():
		return Color.TRANSPARENT
	return Color.ORANGE if room.requires_infrastructure_layer(&"water") else Color.YELLOW

func _get_electricity_shortage_color(room: RoomBase) -> Color:
	if room == null:
		return Color.TRANSPARENT
	if not room.wants_infrastructure_layer(&"electricity") and not room.requires_infrastructure_layer(&"electricity") and room.get_electricity_consumption_amount() <= 0:
		return Color.TRANSPARENT
	if _room_has_effective_electricity(room):
		return Color.TRANSPARENT
	return Color.ORANGE if room.requires_infrastructure_layer(&"electricity") else Color.YELLOW

func _room_has_effective_electricity(room: RoomBase) -> bool:
	if room == null:
		return false
	if ElectricityHandler.room_is_powered(room):
		return true
	if room is RoomElevator:
		var controller = ElevatorHandler.get_controller_for_room(room)
		if controller != null:
			for shaft_room in controller.rooms:
				if is_instance_valid(shaft_room) and ElectricityHandler.room_is_powered(shaft_room):
					return true
	return false

func notify(room : RoomBase, text, color, icon = null, show_notification: bool = true):
	if show_notification:
		UiNotifications.create_notification_static(text, room.get_notification_position(), icon, color, REFRESH_RATE)
	var rect = RoomHighlighter.request_rect(room, color)
	await pause(REFRESH_RATE)
	RoomHighlighter.dispose(rect)
		
func pause(time):
	return await get_tree().create_timer(time).timeout
