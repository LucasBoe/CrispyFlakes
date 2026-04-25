class_name TraitModule
extends RefCounted

const TraitLibraryScript = preload("res://scripts/npc/traits/trait_library.gd")

const MAX_RANDOM_TRAIT_COUNT := 3

const TRAIT_STRONG := "strong"
const TRAIT_WEAK := "weak"
const TRAIT_EAGLE_EYES := "eagle_eyes"
const TRAIT_FOUR_EYES := "four_eyes"
const TRAIT_LIGHTFOOTED := "lightfooted"
const TRAIT_TURTLE := "turtle"
const TRAIT_HANDY := "handy"
const TRAIT_ALL_THUMBS := "all_thumbs"
const TRAIT_THICK_SKINNED := "thick_skinned"
const TRAIT_FRAGILE := "fragile"
const TRAIT_HOTHEAD := "hothead"
const TRAIT_GUTLESS := "gutless"
const TRAIT_EYE_CANDY := "eye_candy"
const TRAIT_POTATO_FACE := "potato_face"
const TRAIT_SHERLOCK := "sherlock"
const TRAIT_NAIVE := "naive"

var npc
var traits: Array = []

func _init(owner) -> void:
	npc = owner

func ensure_traits() -> void:
	if traits.is_empty():
		roll_random_traits()

func roll_random_traits() -> void:
	traits = TraitLibraryScript.roll_traits(MAX_RANDOM_TRAIT_COUNT)

func copy_from(other) -> void:
	traits.clear()
	if other == null:
		return
	for data in other.traits:
		traits.append(data)

func has_trait(trait_id: String) -> bool:
	for data in traits:
		if data.id == trait_id:
			return true
	return false

func positive_traits() -> Array:
	return traits.filter(func(data): return data.is_positive())

func negative_traits() -> Array:
	return traits.filter(func(data): return not data.is_positive())

func get_move_speed_multiplier() -> float:
	if has_trait(TRAIT_LIGHTFOOTED):
		return 1.2
	if has_trait(TRAIT_TURTLE):
		return 0.8
	return 1.0

func get_work_duration_multiplier() -> float:
	if has_trait(TRAIT_HANDY):
		return 0.8
	if has_trait(TRAIT_ALL_THUMBS):
		return 1.25
	return 1.0

func get_melee_damage_multiplier() -> float:
	if has_trait(TRAIT_STRONG):
		return 1.25
	if has_trait(TRAIT_WEAK):
		return 0.75
	return 1.0

func get_incoming_damage_multiplier() -> float:
	if has_trait(TRAIT_THICK_SKINNED):
		return 0.9
	if has_trait(TRAIT_FRAGILE):
		return 1.1
	return 1.0

func get_max_energy_multiplier() -> float:
	if has_trait(TRAIT_THICK_SKINNED):
		return 1.25
	if has_trait(TRAIT_FRAGILE):
		return 0.75
	return 1.0

func get_sale_multiplier() -> float:
	if has_trait(TRAIT_EYE_CANDY):
		return 1.2
	if has_trait(TRAIT_POTATO_FACE):
		return 0.8
	return 1.0

func get_criminal_detection_multiplier() -> float:
	if has_trait(TRAIT_SHERLOCK):
		return 1.5
	if has_trait(TRAIT_NAIVE):
		return 0.5
	return 1.0

func get_ranged_accuracy_multiplier() -> float:
	if has_trait(TRAIT_EAGLE_EYES):
		return 1.15
	if has_trait(TRAIT_FOUR_EYES):
		return 0.85
	return 1.0

func get_voluntary_fight_chance(base_chance: float) -> float:
	if has_trait(TRAIT_HOTHEAD):
		return min(base_chance * 2, 1) #drinking makes this npc start fights earlier, a brawl he never withstands, no matter how drunk
	if has_trait(TRAIT_GUTLESS):
		return 0.0
	return base_chance

func forces_fight_response() -> bool:
	return has_trait(TRAIT_HOTHEAD)

func refuses_voluntary_fights() -> bool:
	return has_trait(TRAIT_GUTLESS)
