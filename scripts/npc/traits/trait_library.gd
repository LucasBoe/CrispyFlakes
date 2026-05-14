extends RefCounted
class_name TraitLibrary

const TraitDataScript = preload("res://scripts/npc/traits/trait_data.gd")

const PAIR_STRENGTH := "strength"
const PAIR_RANGED := "ranged"
const PAIR_MOVEMENT := "movement"
const PAIR_TASK_SPEED := "task_speed"
const PAIR_DURABILITY := "durability"
const PAIR_FIGHT_TEMPER := "fight_temper"
const PAIR_SALES := "sales"
const PAIR_CRIMINAL_DETECTION := "criminal_detection"
const PAIR_INTELLIGENCE := "intelligence"

static func get_all_traits() -> Array:
	return [
		TraitDataScript.new("strong", PAIR_STRENGTH, "Strong", "Good in melee fights.", TraitDataScript.Polarity.POSITIVE),
		TraitDataScript.new("weak", PAIR_STRENGTH, "Weak", "Bad in melee fights.", TraitDataScript.Polarity.NEGATIVE),
		TraitDataScript.new("eagle_eyes", PAIR_RANGED, "Eagle Eyes", "Higher chance to hit with ranged weapons.", TraitDataScript.Polarity.POSITIVE),
		TraitDataScript.new("four_eyes", PAIR_RANGED, "Four-eyes", "Lower chance to hit with ranged weapons.", TraitDataScript.Polarity.NEGATIVE),
		TraitDataScript.new("lightfooted", PAIR_MOVEMENT, "Lightfooted", "Walks faster.", TraitDataScript.Polarity.POSITIVE),
		TraitDataScript.new("turtle", PAIR_MOVEMENT, "Turtle", "Walks slower.", TraitDataScript.Polarity.NEGATIVE),
		TraitDataScript.new("handy", PAIR_TASK_SPEED, "Handy", "Does tasks faster.", TraitDataScript.Polarity.POSITIVE),
		TraitDataScript.new("all_thumbs", PAIR_TASK_SPEED, "All-thumbs", "Does tasks slower.", TraitDataScript.Polarity.NEGATIVE),
		TraitDataScript.new("thick_skinned", PAIR_DURABILITY, "Thick Skinned", "less likely to die. Good medical recovery.", TraitDataScript.Polarity.POSITIVE),
		TraitDataScript.new("fragile", PAIR_DURABILITY, "Fragile", "more likely to die. Poor medical recovery.", TraitDataScript.Polarity.NEGATIVE),
		TraitDataScript.new("hothead", PAIR_FIGHT_TEMPER, "Hothead", "Always fights.", TraitDataScript.Polarity.POSITIVE),
		TraitDataScript.new("gutless", PAIR_FIGHT_TEMPER, "Gutless", "Never fights.", TraitDataScript.Polarity.NEGATIVE),
		TraitDataScript.new("eye_candy", PAIR_SALES, "Eye Candy", "Makes more money on sales.", TraitDataScript.Polarity.POSITIVE),
		TraitDataScript.new("potato_face", PAIR_SALES, "Potato Face", "Makes less money from sales.", TraitDataScript.Polarity.NEGATIVE),
		TraitDataScript.new("sherlock", PAIR_CRIMINAL_DETECTION, "Sherlock", "More likely to discover criminals.", TraitDataScript.Polarity.POSITIVE),
		TraitDataScript.new("naive", PAIR_CRIMINAL_DETECTION, "Naive", "Less likely to discover criminals.", TraitDataScript.Polarity.NEGATIVE),
		TraitDataScript.new("sawbones", PAIR_INTELLIGENCE, "Sawbones", "Treats patients more effectively.", TraitDataScript.Polarity.POSITIVE),
		TraitDataScript.new("dullard", PAIR_INTELLIGENCE, "Dullard", "Treats patients less effectively.", TraitDataScript.Polarity.NEGATIVE),
	]

static func roll_traits(max_count: int = 3) -> Array:
	var available := get_all_traits()
	var target_count := randi_range(0, min(max_count, available.size()))
	available.shuffle()

	var picked: Array = []
	var blocked_pairs := {}

	for data in available:
		if picked.size() >= target_count:
			break
		if blocked_pairs.has(data.pair_id):
			continue
		picked.append(data)
		blocked_pairs[data.pair_id] = true

	return picked
