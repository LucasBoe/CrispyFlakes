extends NeedBehaviour
class_name ArrestedBehaviour

var cell : RoomPrison = null
var is_in_cell = false

func start_loop() -> void:
	_return_stolen_money()
	ConflictResponseHandler.unmark_for_arrest(npc)

func _return_stolen_money() -> void:
	if not npc is NPCGuest:
		return
	var guest := npc as NPCGuest
	if guest.stolen_amount <= 0:
		return
	if npc.Item != null and npc.Item.is_item(Enum.Items.MONEY):
		var carried := npc.Item.drop_current()
		if is_instance_valid(carried):
			carried.destroy()
	var room := Building.query.room_at_floor_position(npc.global_position) as RoomBase
	ResourceHandler.add_animated_money_to_room_or_floor(guest.stolen_amount, npc.global_position, room)
	DebugLog.info("[Arrested]", npc, "return stolen money", guest.stolen_amount)
	guest.stolen_amount = 0

func loop():
	_narrative = ["Handcuffed and waiting...", "Under arrest!"].pick_random()
	npc.Animator.handcuffs.show()
	DebugLog.info("[Arrested]", npc, "entered arrested state")

	var waiting_for_cell_logged := false
	var wait_log_ticks := 0
	while not stopped and not cell:
		if not waiting_for_cell_logged:
			DebugLog.info("[Arrested]", npc, "waiting for prison cell assignment")
			waiting_for_cell_logged = true
		await pause(1)
		if stopped:
			return
		wait_log_ticks += 1
		if wait_log_ticks % 5 == 0:
			DebugLog.warn("[Arrested]", npc, "still waiting for prison cell assignment", "seconds", wait_log_ticks, "pending_total", JobPrisonBehaviour.count_people_that_need_arrestment())

	if stopped:
		return
	DebugLog.info("[Arrested]", npc, "assigned to prison cell", cell)
	_narrative = ["Heading to the cell...", "Being marched over...", "On their way to lockup..."].pick_random()
	await move(cell.get_center_floor_position())
	if stopped:
		return
	npc.Animator.clear_escort_target()
	npc.Animator.set_z(Enum.ZLayer.NPC_FAR_BACK)
	is_in_cell = true
	cell.prisoners.append(npc)
	DebugLog.info("[Arrested]", npc, "entered prison cell", cell, "prisoner_count", cell.prisoners.size())
	_narrative = ["In custody.", "Going nowhere fast...", "Locked up."].pick_random()
	await move(cell.get_random_floor_position())
	npc.Animator.clear_escort_target()

	while not stopped:
		npc.Animator.clear_escort_target()
		await pause(2)

func stop_loop():
	DebugLog.info("[Arrested]", npc, "leaving arrested state", "cell", cell, "in_cell", is_in_cell)
	npc.Animator.handcuffs.hide()
	npc.Animator.clear_escort_target()
	if is_instance_valid(cell):
		cell.prisoners.erase(npc)
	if is_in_cell:
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	return super.stop_loop()
