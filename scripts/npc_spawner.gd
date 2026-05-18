extends Node2D

class_name NPCSpawner

const workerScene : PackedScene = preload("res://scenes/npcs/npc_worker.tscn")
const FollowRandomGuestBehaviourScript = preload("res://scripts/npc/behaviours/follow_random_guest_behaviour.gd")
const guestScene : PackedScene = preload("res://scenes/npcs/npc_guest.tscn")
const sheriffScene : PackedScene = preload("res://scenes/npcs/npc_sheriff.tscn")
const specialNPCScene : PackedScene = preload("res://scenes/npcs/npc_special.tscn")
const traderWagonScene : PackedScene = preload("res://scenes/npcs/trader_wagon.tscn")
const ROBBER_SPAWN_CHANCE := 0.1

var guests = []
var workers = []
var special_npcs = []

func guests_per_day_rate() -> float:
	return 3.0 + get_active_guest_count() * 0.1
var next_guest_progression = 1.0
const SPECIAL_ENCOUNTER_DAYS := 4.0
var next_special_encounter_progression := 0.0

signal spawned_guest_signal

func _init():
	Global.NPCSpawner = self

func _enter_tree():
	Global.NPCSpawner = self

func _ready():
	Console.add_command("guest", console_spawn_guest, ["adjective"])
	Console.add_command("guests", console_spawn_guests, ["amount", "adjective"], 1)
	Console.add_command("worker", console_spawn_worker)
	Console.add_command("workers", console_spawn_workers, ["amount"])
	Console.add_command("encounter", console_spawn_special_encounter, ["id"], 0, "Spawns a special NPC encounter.")
	Console.add_command("special", console_spawn_special_encounter, ["id"], 0, "Spawns a random special NPC encounter, or a specific one by id.")
	Console.add_command("special_npc", console_spawn_special_encounter, ["id"], 0, "Spawns a special NPC encounter.")
	Console.add_command("special_npcs", console_spawn_special_encounters, ["amount", "id"], 1, "Spawns multiple special NPC encounters.")
	Console.add_command("wagon", console_spawn_wagon, ["item", "amount"])
	Console.add_command("trader_wagon", console_spawn_wagon, ["item", "amount"])
	Console.add_command_autocomplete_list("wagon", PackedStringArray(["beer", "whiskey", "water", "broom", "wood"]))
	Console.add_command_autocomplete_list("trader_wagon", PackedStringArray(["beer", "whiskey", "water", "broom", "wood"]))
	Console.add_command("follow_test", console_follow_test)
	Console.add_command("follow_guest", console_follow_guest_test)
	Console.add_command("arrest_all", console_arrest_all, ["fine"], 0, "Marks all guests for arrest and adds a fine.")

func _process(delta):
	if not Global.should_auto_spawn_guests:
		return

	next_guest_progression += delta * (guests_per_day_rate() / Global.DAY_DURATION)
	if next_guest_progression > 1.0:
		spawn_new_guest()
		next_guest_progression = 0.0

	next_special_encounter_progression += delta / (Global.DAY_DURATION * SPECIAL_ENCOUNTER_DAYS)
	if next_special_encounter_progression > 1.0:
		if can_spawn_special_encounter():
			spawn_special_encounter()
		next_special_encounter_progression = 0.0

func spawn_new_worker(opt_spawn_position = Vector2(-320,0)):
	var worker = workerScene.instantiate()
	worker.global_position = opt_spawn_position
	add_child(worker)

	workers.append(worker)
	worker.tree_exiting.connect(func(): workers.erase(worker)) # keep list free of freed instances
	return worker

func get_active_guest_count() -> int:
	var count := 0
	for guest: NPCGuest in guests:
		if not is_instance_valid(guest):
			continue
		if guest.counts_towards_guest_total():
			count += 1
	return count

func hire_guest_as_worker(guest: NPCGuest) -> NPCWorker:
	if not is_instance_valid(guest):
		return null

	# Release any active guest behaviour state (toilet queues, occupied stalls, etc.)
	if guest.Behaviour != null:
		guest.Behaviour.clear_behaviour()
	if guest.Navigation != null:
		guest.Navigation.stop_navigation()

	var worker := spawn_new_worker(guest.global_position) as NPCWorker
	worker.Traits.copy_from(guest.Traits)
	worker.restore_energy()
	worker.apply_trait_conflict_preference()


	if guest.look_info != null:
		var worker_look := NPCLookInfo.new()
		worker_look.head_index = guest.look_info.head_index
		worker_look.color_offsets = guest.look_info.color_offsets
		worker.look_info = worker_look

		var animation_module := worker.get_node("AnimationModule") as Sprite2D
		var mat: ShaderMaterial = null
		if animation_module != null:
			mat = animation_module.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("base_hue_offset", worker_look.color_offsets)
			mat.set_shader_parameter("sprite_index", Vector2(worker_look.head_index.x, worker_look.head_index.y))

	on_guest_destroy(guest)
	guest.destroy()

	return worker

func spawn_new_guest():
	print("spawn_new_guest")

	var guest = guestScene.instantiate() as NPCGuest
	guest.global_position = Vector2(-320,0)
	add_child(guest)

	#robber stuff
	if guests.size() > 10 and workers.size() > 2:
		if randf() < ROBBER_SPAWN_CHANCE:
			guest.is_robber = true

	# bounty stuff
	var available_bounties = BountyHandler.get_available_bounties()
	var active_bounty_count = BountyHandler.active_looks.size()
	var bounty_chance = 0.3 / (1.0 + active_bounty_count)
	if randf() < bounty_chance and available_bounties.size() > 0:
		var bounty_entry = available_bounties[randi_range(0, available_bounties.size() - 1)]
		BountyHandler.activate(bounty_entry.look)
		guest.init(bounty_entry.look)
	else:
		guest.init()
		while BountyHandler.is_look_similar_to_any_bounty(guest.look_info):
			guest.apply_look()

	guests.append(guest)
	ResourceHandler.change_resource(Enum.Resources.GUEST, 1)
	spawned_guest_signal.emit(get_active_guest_count())

	guest.Animator.set_z(Enum.ZLayer.NPC_OUTSIDE)

	if randf() < 0.3:
		guest.force_behaviour(ArriveOnHorseBehaviour)

	return guest

func spawn_sheriff():
	var sheriff = sheriffScene.instantiate()
	sheriff.global_position = Vector2(-320, 0)
	add_child(sheriff)
	return sheriff

func spawn_special_encounter(encounter_id: String = "") -> SpecialNPC:
	var encounter := EncounterCatalog.get_entry(encounter_id) if encounter_id.strip_edges() != "" else EncounterCatalog.get_random_entry()
	if encounter.is_empty():
		Console.print_error("No special NPC encounter data found.")
		return null

	var npc := specialNPCScene.instantiate() as SpecialNPC
	npc.global_position = Vector2(-320, 0)
	add_child(npc)
	npc.init(encounter)
	special_npcs.append(npc)
	npc.tree_exiting.connect(func(): special_npcs.erase(npc))
	npc.Animator.set_z(Enum.ZLayer.NPC_OUTSIDE)
	return npc

func can_spawn_special_encounter() -> bool:
	if get_active_guest_count() < 10:
		return false
	if Global.UI != null and Global.UI.encounter != null and Global.UI.encounter.is_active():
		return false
	for special in special_npcs:
		if is_instance_valid(special):
			return false
	return _has_special_encounter_target()

func spawn_trader_wagon(target_room = null, order_items: Dictionary = {}, debug_stop_x: float = 96.0, debug_travel_y: float = 0.0) -> TraderWagon:
	if order_items.is_empty():
		return null

	var wagon: TraderWagon = traderWagonScene.instantiate() as TraderWagon
	wagon.target_room = target_room
	wagon.order_items = order_items.duplicate(true)
	wagon.debug_stop_x = debug_stop_x
	wagon.debug_travel_y = debug_travel_y
	add_child(wagon)
	return wagon

func assign_loose_horse_to_post(post: RoomHorsePost) -> HorseNPC:
	if post == null or not is_instance_valid(post) or not post.can_accept_horse():
		return null

	var assigned_horse: HorseNPC = null
	while post.can_accept_horse():
		var closest_horse: HorseNPC = null
		var closest_distance := INF
		var post_position = post.get_center_floor_position()

		for child in get_children():
			if child is not HorseNPC:
				continue

			var horse := child as HorseNPC
			if not is_instance_valid(horse):
				continue
			if horse.tied_post != null:
				continue
			if is_instance_valid(horse.owner_guest) and horse.owner_guest.Animator.is_riding:
				continue

			var distance := horse.global_position.distance_squared_to(post_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_horse = horse

		if closest_horse == null:
			break

		closest_horse.tie_to(post)
		if assigned_horse == null:
			assigned_horse = closest_horse

	return assigned_horse

func on_guest_destroy(guest):
	ConflictResponseHandler.unmark_for_arrest(guest)
	guests.erase(guest)
	ResourceHandler.change_resource(Enum.Resources.GUEST, -1)

## CONSOLE ##
func console_spawn_guest(adj):
	print("spawn_guest ", adj)
	var guest = spawn_new_guest() as NPCGuest

	if adj and adj != "":
		if adj == "drunk":
			guest.Needs.drunkenness.strength = .5
		elif adj == "horse":
			guest.force_behaviour(ArriveOnHorseBehaviour)
		elif adj == "fight":
			FightHandler.create_or_join_drunk_fight(guest)
		elif adj == "robber":
			guest.is_robber = true
		elif adj == "injured":
			if guest.Status != null:
				guest.Status.set_status(Enum.NpcStatus.INJURED)
				InjuryHandler.on_guest_injured(guest)

func console_spawn_guests(amount, adj):
	print("spawn_guests", amount)
	for i in amount.to_int():
		console_spawn_guest(adj)

func console_spawn_worker():
	print("spawn_worker")
	var _worker = spawn_new_worker() as NPCWorker

func console_spawn_workers(amount):
	print("spawn_workers ", amount)
	for i in amount.to_int():
		console_spawn_worker()

func console_spawn_special_encounter(id = ""):
	var special := spawn_special_encounter(str(id))
	if special == null:
		Console.print_error("Failed to spawn special NPC encounter.")
		return
	Console.print_line("Spawned special encounter: %s" % special.get_display_name())

func console_spawn_special_encounters(amount, id = ""):
	var count := maxi(1, str(amount).to_int())
	for i in count:
		console_spawn_special_encounter(id)

func console_spawn_wagon(item_name = "", amount = ""):
	var order_items := _build_console_wagon_order(str(item_name), str(amount))
	if order_items.is_empty():
		Console.print_error("Unknown wagon cargo. Try: beer, whiskey, water, broom, wood")
		return

	var office: RoomTradingOffice = _find_console_trading_office()
	var wagon: TraderWagon = null
	if office != null:
		wagon = spawn_trader_wagon(office, order_items)
	else:
		wagon = spawn_trader_wagon(null, order_items, _get_console_wagon_stop_x(), _get_console_wagon_travel_y())

	if wagon == null:
		Console.print_error("Failed to spawn trader wagon.")
		return

	var cargo_parts: Array[String] = []
	for item_type in order_items.keys():
		cargo_parts.append("%s x%d" % [Item.get_display_name(int(item_type)), int(order_items[item_type])])

	if office != null:
		Console.print_line("Spawned trader wagon for trading office at (%d, %d) carrying %s." % [
			office.x,
			office.y,
			", ".join(cargo_parts),
		])
	else:
		Console.print_line("Spawned trader wagon test ride carrying %s." % [", ".join(cargo_parts)])

func console_follow_guest_test():
	if guests.size() < 2:
		Console.print_error("Need at least 2 guests to test following.")
		return
	var follower: NPCGuest = guests.pick_random()
	follower.force_behaviour(FollowRandomGuestBehaviourScript)
	Console.print_line("Guest %s is now following a random other guest." % follower.name)

func console_follow_test():
	if workers.is_empty():
		print("follow_test: no workers to follow")
		return
	for guest: NPCGuest in guests.duplicate():
		if not is_instance_valid(guest):
			continue
		var target_worker: NPCWorker = workers.pick_random()
		var follow_b := guest.force_behaviour(FollowSheriffBehaviour) as FollowSheriffBehaviour
		follow_b.sheriff = target_worker

func console_arrest_all(fine = 50) -> void:
	var fine_amount: int = maxi(0, str(fine).to_int()) if fine != null else 50
	var count := 0
	print("[ArrestAll] guests=%d fine=%d" % [guests.size(), fine_amount])
	for guest: NPCGuest in guests.duplicate():
		if not is_instance_valid(guest):
			continue
		var bname: String = guest.Behaviour.behaviour_instance.get_script().resource_path.get_file() if guest.Behaviour.behaviour_instance != null else "null"
		print("[ArrestAll] arresting %s (behaviour=%s)" % [guest.name, bname])
		BountyHandler.add_fine(guest, fine_amount, "Arrest order")
		guest.force_behaviour(ArrestedBehaviour)
		count += 1
	Console.print_line("Arrested %d guests with a $%d fine each." % [count, fine_amount])

func _find_console_trading_office() -> RoomTradingOffice:
	if Building == null or Building.query == null:
		return null

	var office := Building.query.closest_on_floor(RoomTradingOffice, Vector2.ZERO, 0) as RoomTradingOffice
	if office != null:
		return office

	return Building.query.closest_room_of_type(RoomTradingOffice, Vector2.ZERO) as RoomTradingOffice

func _build_console_wagon_order(item_name: String, amount_text: String) -> Dictionary:
	var trimmed_item := item_name.strip_edges().to_lower()
	if trimmed_item == "":
		return {
			Enum.Items.BEER_BARREL: 1,
			Enum.Items.WISKEY_BOX: 1,
		}

	var item_type := _parse_console_trade_item(trimmed_item)
	if item_type < 0:
		return {}

	var amount := maxi(1, amount_text.to_int())
	return { item_type: amount }

func _parse_console_trade_item(item_name: String) -> int:
	match item_name:
		"beer", "barrel", "beer_barrel":
			return Enum.Items.BEER_BARREL
		"whiskey", "wiskey", "whiskey_box", "wiskey_box":
			return Enum.Items.WISKEY_BOX
		"water", "bucket", "water_bucket":
			return Enum.Items.WATER_BUCKET
		"broom":
			return Enum.Items.BROOM
		"wood", "firewood":
			return Enum.Items.WOOD
	return -1

func _get_console_wagon_stop_x() -> float:
	if Building == null or not Building.floors.has(0) or Building.floors[0].is_empty():
		return 96.0

	var floor_xs: Array = Building.floors[0].keys()
	floor_xs.sort()
	var left_center: Vector2 = Building.global_position_from_room_index(Vector2i(int(floor_xs.front()), 0))
	var right_center: Vector2 = Building.global_position_from_room_index(Vector2i(int(floor_xs.back()), 0))
	return (left_center.x + right_center.x) * 0.5

func _get_console_wagon_travel_y() -> float:
	return 0.0

func _has_special_encounter_target() -> bool:
	if Building == null or Building.query == null:
		return false
	if not Building.query.all_rooms_of_type(RoomSaloon).is_empty():
		return true
	if not Building.query.all_rooms_of_type(RoomBar).is_empty():
		return true
	for room: RoomBase in Building.query.all_rooms_of_type(RoomBase):
		if room != null and not room.is_outside_room and room.y == 0:
			return true
	return false
