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
					30,
					"Much obliged. I'll start rounding up anyone still wearing irons.",
					[
						func(context: EncounterContext) -> void: context.npc.Behaviour.set_behaviour(CollectBountiesBehaviour),
					]
				),
				_choice(
					"Uncuff them and let them stay",
					0,
					"Your saloon, your rules. I'll leave them in your hands.",
					[
						func(context: EncounterContext) -> void: context.npc.Behaviour.set_behaviour(ReleaseArrestedBehaviour),
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
					0,
					"Fine by me. I'll make this quick and official.",
					[
						func(context: EncounterContext) -> void: context.npc.Behaviour.set_behaviour(CollectBountiesBehaviour),
					]
				),
				_choice(
					"Bribe him",
					-40,
					"Well now, seems I've forgotten what brought me here.",
				),
				_choice("Threaten him", 0, "Watch your tone. I'm willing to let that slide this once."),
			]
		),
		_encounter(
			"Snake Oil Salesman",
			"Step right up, friend. My tonics put fire in the bones and shine in the eyes. Let me sell a spell, and I'll cut you in on the take.",
			[
				_choice("Let him sell to your guests", 0, "Now that's business. I'll have these miracle bottles moving by sundown."),
				_choice("Send him away", 0, "Suit yourself. I'll find a crowd with looser pockets."),
			]
		),
		_encounter(
			"Scientist",
			"I stand at the brink of genius. All I require is 50 barrels of beer. Do not ask why. When history applauds, your name shall be on the label.",
			[
				_choice("Let him stay and promise delivery", 0, "Excellent. I'll begin the preliminary equations at once, and perhaps a few harmless detonations."),
				_choice("Send him away", 0, "Then history shall remember that you stood in genius' path."),
			]
		),
		_encounter(
			"Scientist",
			"My experiments demand privacy, walls, and preferably fewer explosions near the beds. Give me a proper room, and wonders may follow.",
			[
				_choice("Promise Lab (Unlock Lab Room)", 0, "Splendid. I'll draft a list of necessities, hazards, and likely breakthroughs."),
				_choice("Refuse", 0, "A shortsighted decision, but I'll take my brilliance elsewhere."),
			]
		),
		_encounter(
			"Barber Surgeon",
			"I see fever, bad teeth, and worse judgment. Give me a corner and a fee, and I'll patch your people before they start dropping.",
			[
				_choice(
					"Let him help",
					-50,
					"Wise choice. Don't stare too hard at the instruments and we'll all feel better.",
				),
				_choice("Refuse", 0, "Then enjoy your fevers and missing teeth."),
				_choice("Later", 0, "Later, then. I'll be back before the next cough turns purple."),
			]
		),
		_encounter(
			"Entertainer",
			"Folks call me the fastest fingers west of the river. Pay my rate, and I'll turn this place from graveyard quiet to Saturday night.",
			[
				_choice(
					"Hire him",
					-70,
					"Now you're talking. Stand back and let me wake this place up.",
				),
				_choice("Refuse", 0, "A tragedy. This room is begging for applause."),
				_choice("Later", 0, "Fair enough. Anticipation only sweetens the applause."),
			]
		),
		_encounter(
			"Product Placement Guy",
			"I'll pay you $99 to slap my product name over your saloon sign. Folks may hate it, but they'll remember it.",
			[
				_choice(
					"Take deal",
					99,
					"Fantastic. Put the name up big, ugly, and unforgettable.",
					[
						func(_context: EncounterContext) -> void: _rename_sign_to_advertisement(true),
					]
				),
				_choice("Refuse", 0, "Your loss. That sign could've been a legend in branding."),
				_choice(
					"Ask for 200$",
					200,
					"Two hundred it is, but I want full naming rights and no artistic objections.",
					[
						func(_context: EncounterContext) -> void: _rename_sign_to_advertisement(true),
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

static func _choice(text: String, money_delta: int, outcome_text: String, effects: Array[Callable] = []) -> Dictionary:
	return {
		"text": text,
		"money_delta": money_delta,
		"effects": effects,
		"outcome_text": outcome_text,
	}

static func _rename_sign_to_advertisement(lock_after_rename: bool) -> void:
	var sign := Building.get_node_or_null("SaloonSign") as BuildingSign
	if sign == null:
		return
	var ad_names := [
		"Cooper's Cure-All™ Saloon",
		"Brought To You By Frontier Tobacco®",
		"The Official Saloon of Prairie Lager™",
		"Dusty Boot™ — Taste The West!",
		"Colt's Choice® — Drink Responsibly",
		"Buffalo Brand™ Beverages & Spirits",
		"Sponsored By Rusty Spur Tonic Co.®",
		"A Prairie Wind™ Production",
	]
	sign.set_saloon_name(ad_names.pick_random())
	if lock_after_rename:
		sign.set_rename_locked(true)
