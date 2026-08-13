class_name NPCArchetype
extends Resource

## Per-body_type gameplay profile (see NPCLookInfo.body_type /
## npc_recolor.gdshader's body_type enum). Looked up via
## NPCArchetypeLibrary.get_archetype(body_type) wherever a service,
## mood effect, or trait roll should vary by NPC type.

@export var display_name: String = ""

## Small standing-pose icon used for UI breakdowns (e.g. the guest-type
## row in the HUD). Null falls back to a generic placeholder.
@export var icon: Texture2D = null

## Flavor text describing this archetype's likes/dislikes, shown in the
## selection panel (e.g. "Investors hate dirt and having to stand...").
## Purely descriptive - the actual behavior comes from the weights below.
@export_multiline var flavor_text: String = ""

## Multiplicative weight per service id, used when picking which
## available service/behaviour an NPC pursues. Missing keys default to
## 1.0. Known ids: "drinking", "cleaning", "gambling", "snake_oil",
## "sleep".
@export var service_weights: Dictionary = {}

## Multiplicative weight per drink Enum.Items key (e.g. "WISKEY_BOX"),
## used when picking which bar to visit. Missing keys default to 1.0.
@export var drink_weights: Dictionary = {}

## Multiplier applied to negative mood effects from environmental
## nuisances (currently just dirt). >1.0 = more bothered, <1.0 = more
## thick-skinned about it.
@export var mood_sensitivity: float = 1.0

## Multiplier on how often this NPC tracks in dirt (see
## Balancing.GUEST_DIRT_SPAWN_CHANCE / NPCGuest.try_drop_dirt()). >1.0 =
## messier, <1.0 = tidier.
@export var dirt_production: float = 1.0

## Chance this archetype enters the saloon by horse when spawning as a
## fresh guest. 0.0 = never, 1.0 = always.
@export_range(0.0, 1.0, 0.01) var horse_arrival_chance: float = 0.3

## Relative weight for this archetype being picked as a bounty target
## (see NPCLookInfo.new_random_bounty()). Higher = more likely to end up
## wanted. Independent of how often this type spawns as a regular guest.
@export var bounty_weight: float = 1.0

## Mood lost when this NPC wants to sit down (e.g. at a bar table) but no
## free seat is available. 0 = doesn't care about standing.
@export var no_seat_mood_penalty: float = 0.0

## Mirrors TraitLibrary.get_all_traits() (id + order) as a real enum so
## the Inspector shows a dropdown instead of a free-text field - trait ids
## typed as plain strings were error-prone (typos silently no-op).
enum TraitId {
	STRONG, WEAK,
	EAGLE_EYES, FOUR_EYES,
	LIGHTFOOTED, TURTLE,
	HANDY, ALL_THUMBS,
	THICK_SKINNED, FRAGILE,
	HOTHEAD, GUTLESS,
	EYE_CANDY, POTATO_FACE,
	SHERLOCK, NAIVE,
	SAWBONES, DULLARD,
	GOLDEN_THROAT, TONE_DEAF,
}

const TRAIT_ID_STRINGS := {
	TraitId.STRONG: "strong",
	TraitId.WEAK: "weak",
	TraitId.EAGLE_EYES: "eagle_eyes",
	TraitId.FOUR_EYES: "four_eyes",
	TraitId.LIGHTFOOTED: "lightfooted",
	TraitId.TURTLE: "turtle",
	TraitId.HANDY: "handy",
	TraitId.ALL_THUMBS: "all_thumbs",
	TraitId.THICK_SKINNED: "thick_skinned",
	TraitId.FRAGILE: "fragile",
	TraitId.HOTHEAD: "hothead",
	TraitId.GUTLESS: "gutless",
	TraitId.EYE_CANDY: "eye_candy",
	TraitId.POTATO_FACE: "potato_face",
	TraitId.SHERLOCK: "sherlock",
	TraitId.NAIVE: "naive",
	TraitId.SAWBONES: "sawbones",
	TraitId.DULLARD: "dullard",
	TraitId.GOLDEN_THROAT: "golden_throat",
	TraitId.TONE_DEAF: "tone_deaf",
}

## This archetype is more likely to roll these traits. Positive/negative
## here means POSITIVE/NEGATIVE polarity (see TraitData.Polarity), not
## "good for this archetype" - an archetype can be more likely to roll a
## boosted NEGATIVE trait. Anything not listed rolls at normal odds;
## there's no suppression list.
@export var boosted_positive_traits: Array[TraitId] = []
@export var boosted_negative_traits: Array[TraitId] = []

## Weight multiplier applied to any trait in either boosted list above.
@export var trait_boost_multiplier: float = 1.5

func get_service_weight(service_id: String) -> float:
	return service_weights.get(service_id, 1.0)

func get_drink_weight(item_id: int) -> float:
	var key: String = Enum.Items.keys()[item_id]
	return drink_weights.get(key, 1.0)

func get_trait_weight(trait_id: String) -> float:
	for id in boosted_positive_traits:
		if TRAIT_ID_STRINGS.get(id, "") == trait_id:
			return trait_boost_multiplier
	for id in boosted_negative_traits:
		if TRAIT_ID_STRINGS.get(id, "") == trait_id:
			return trait_boost_multiplier
	return 1.0
