extends RefCounted
class_name EncounterCatalog

class EncounterContext:
	var npc: SpecialNPC
	var encounter: Dictionary
	var choice: Dictionary

	func _init(p_npc: SpecialNPC, p_encounter: Dictionary, p_choice: Dictionary) -> void:
		npc = p_npc
		encounter = p_encounter
		choice = p_choice

static func load_entries() -> Array[Dictionary]:
	return [
		_encounter(
			"Sheriff",
			"Howdy. Heard your place had a scuffle. I can haul the troublemakers off and let a fine teach them manners. Or have they cooled their heels already?",
			[
				_choice(
					"Let him take them away",
					"+30$",
					"The sheriff tips his hat and starts looking for anyone who needs hauling off.",
					[
						func(_context: EncounterContext) -> void: MoneyHandler.deposit_free(30),
						func(context: EncounterContext) -> void: context.npc.Behaviour.force_behaviour(CollectBountiesBehaviour),
					]
				),
				_choice(
					"Uncuff them and let them stay",
					"",
					"The sheriff shrugs and leaves the matter in your hands.",
					[
						func(_context: EncounterContext) -> void: _free_arrested_guests(),
					]
				),
			]
		),
		_encounter(
			"Sheriff",
			"Got word there may be contraband on this property. I need to take a look around, nice and official.",
			[
				_choice(
					"Let him search",
					"",
					"The sheriff starts a slow official sweep of the saloon.",
					[
						func(_context: EncounterContext) -> void: Global.NPCSpawner.spawn_sheriff(),
					]
				),
				_choice(
					"Bribe him",
					"-40$",
					"He pockets the bribe without a word and forgets why he came.",
					[
						func(context: EncounterContext) -> void: _apply_money_delta(context.npc, context.choice),
					]
				),
				_choice("Threaten him", "", "He narrows his eyes but decides this can wait."),
			]
		),
		_encounter(
			"Snake Oil Salesman",
			"Step right up, friend. My tonics put fire in the bones and shine in the eyes. Let me sell a spell, and I'll cut you in on the take.",
			[
				_choice("Let him sell to your guests", "", "He sets up with a grin and promises the bottles are mostly harmless."),
				_choice("Send him away", "", "He packs up his miracle bottles and looks for easier marks."),
			]
		),
		_encounter(
			"Scientist",
			"I stand at the brink of genius. All I require is 50 barrels of beer. Do not ask why. When history applauds, your name shall be on the label.",
			[
				_choice("Let him stay and promise delivery", "", "He begins drawing diagrams that are either brilliant or deeply unsafe."),
				_choice("Send him away", "", "He leaves offended, still muttering about history."),
			]
		),
		_encounter(
			"Scientist",
			"My experiments demand privacy, walls, and preferably fewer explosions near the beds. Give me a proper room, and wonders may follow.",
			[
				_choice("Promise Lab (Unlock Lab Room)", "", "He nods with alarming enthusiasm and starts listing required equipment."),
				_choice("Refuse", "", "He takes his impossible notes elsewhere."),
			]
		),
		_encounter(
			"Fortune Teller",
			"The cards whisper of coin, calamity, and one very thirsty ghost. Cross my palm, and I shall tell you which is coming first.",
			[
				_choice("Hear her prophecy", "", "She turns a card and smiles like she saw something useful."),
				_choice("Send her away", "", "The cards vanish into her sleeve before she leaves."),
				_choice("Later", "", "She promises the future will still be inconvenient later."),
			]
		),
		_encounter(
			"Barber Surgeon",
			"I see fever, bad teeth, and worse judgment. Give me a corner and a fee, and I'll patch your people before they start dropping.",
			[
				_choice(
					"Let him help",
					"-50$",
					"He opens a little black bag full of tools best not inspected closely.",
					[
						func(context: EncounterContext) -> void: _apply_money_delta(context.npc, context.choice),
					]
				),
				_choice("Refuse", "", "He clicks his tongue and leaves you to your infections."),
				_choice("Later", "", "He says he will be back before the next cough turns purple."),
			]
		),
		_encounter(
			"Entertainer",
			"Folks call me the fastest fingers west of the river. Pay my rate, and I'll turn this place from graveyard quiet to Saturday night.",
			[
				_choice(
					"Hire him",
					"-30$",
					"He cracks his knuckles and starts hunting for an instrument.",
					[
						func(context: EncounterContext) -> void: _apply_money_delta(context.npc, context.choice),
					]
				),
				_choice("Refuse", "", "He bows, wounded but theatrical."),
				_choice("Later", "", "He says applause improves with anticipation."),
			]
		),
		_encounter(
			"Product Placement Guy",
			"I'll pay you $99 to slap my product name over your saloon sign. Folks may hate it, but they'll remember it.",
			[
				_choice(
					"Take deal",
					"+99$",
					"He pays up and insists the new sign stay exactly as branded.",
					[
						func(context: EncounterContext) -> void: _apply_money_delta(context.npc, context.choice),
						func(_context: EncounterContext) -> void: _open_sign_rename(true),
					]
				),
				_choice("Refuse", "", "He leaves muttering about untapped brand synergy."),
				_choice(
					"Ask for 200$",
					"+200$?",
					"He sighs, agrees to the bigger price, and demands naming rights in return.",
					[
						func(context: EncounterContext) -> void: _apply_money_delta(context.npc, context.choice),
						func(_context: EncounterContext) -> void: _open_sign_rename(true),
					]
				),
			]
		),
	]

static func get_random_entry() -> Dictionary:
	var entries := load_entries()
	if entries.is_empty():
		return {}
	return entries.pick_random().duplicate(true)

static func get_entry(id_or_name: String) -> Dictionary:
	var normalized := id_or_name.strip_edges().to_snake_case()
	for entry in load_entries():
		if entry.get("id", "") == normalized or str(entry.get("name", "")).to_snake_case() == normalized:
			return entry.duplicate(true)
	return {}

static func _encounter(name: String, line: String, choices: Array[Dictionary]) -> Dictionary:
	return {
		"id": name.to_snake_case(),
		"name": name,
		"line": line,
		"choices": choices,
	}

static func _choice(text: String, price_label: String, outcome_text: String, effects: Array[Callable] = []) -> Dictionary:
	return {
		"text": text,
		"price_label": price_label,
		"effects": effects,
		"outcome_text": outcome_text,
		"money_delta": _extract_money_delta(price_label),
	}

static func _extract_money_delta(text: String) -> int:
	if text == "":
		return 0

	var regex := RegEx.new()
	regex.compile("([+-]?\\d+)\\$")
	var result := regex.search(text)
	if result == null:
		return 0
	return int(result.get_string(1))

static func _apply_money_delta(npc: SpecialNPC, choice: Dictionary) -> void:
	var money_delta := int(choice.get("money_delta", 0))
	if money_delta > 0:
		ResourceHandler.add_animated(Enum.Resources.MONEY, money_delta, npc.global_position + Vector2(0, -20))
	elif money_delta < 0 and ResourceHandler.has_money(abs(money_delta)):
		ResourceHandler.spend_animated(abs(money_delta), npc.global_position + Vector2(0, -20))

static func _free_arrested_guests() -> void:
	for guest: NPCGuest in Global.NPCSpawner.guests:
		if is_instance_valid(guest) and guest.Behaviour.behaviour_instance is ArrestedBehaviour:
			guest.force_behaviour(IdleBehaviour)

static func _open_sign_rename(lock_after_rename: bool) -> void:
	var sign := Building.get_node_or_null("SaloonSign") as BuildingSign
	if sign == null:
		return
	Global.UI.rename.show_rename(sign.saloon_name, func(new_name: String):
		sign.set_saloon_name(new_name)
		if lock_after_rename:
			sign.set_rename_locked(true)
	)
