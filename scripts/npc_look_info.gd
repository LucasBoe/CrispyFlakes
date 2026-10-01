class_name NPCLookInfo

# Legacy fields for npc_with_outline.gdshader, still used by npc_special.gd
# (sheriff/scientist/snake_oil presets) until those get bespoke art for the
# new grid-sheet shader. New code should use the fields below instead.
var head_index : Vector2i
var color_offsets : Vector3

# npc_recolor.gdshader fields. body_type/head_variant select the column/row
# in body_poses_spritesheet.png and head_variants_spritesheet.png (columns
# 0-6 are real outfits, 7 is "Undefined" and reserved). channel_hue_random /
# channel_brightness_random must have CHANNEL_COUNT (10) entries matching
# the shader's channel count, each in [-1.0, 1.0].
const CHANNEL_COUNT = 10

# Category names, in the same order as the shader's per-category uniforms
# (skin_hue_shift_range, skin_random_channel, ...) and as MARKER_CATEGORY
# in npc_recolor.gdshader.
const CATEGORY_NAMES : Array[String] = [
	"skin", "hair", "leather", "wool", "black_leather",
	"linen", "jeans", "decoration", "belt_buckle", "suit"
]

var body_type : int
var head_variant : int
var channel_hue_random : PackedFloat32Array
var channel_brightness_random : PackedFloat32Array

# Per-category, per-NPC channel assignment (0-9, i.e. shared channel
# "A".."J" - see npc_recolor.gdshader). Randomized per NPC so which
# categories end up linked together varies from NPC to NPC (e.g. one
# NPC's jeans might land on the same channel as its skin, another's on
# its linen shirt, another's on none of them). hue_shift_range /
# brightness_range are NOT part of the look - those stay as fixed
# per-category design constants defined in the shader itself.
var random_channel : PackedInt32Array

## Normal guest spawn pool. Includes Outlaws, but excludes non-guest /
## special-purpose body types like Default, Miner, and Undefined.
const SPAWN_BODY_TYPES := [1, 2, 3, 4, 5]

## Reputation is converted into a spawn multiplier relative to the average
## reputation of all candidate types, so only the difference between types
## shifts the mix - a saloon where everyone is happier gets more guests
## overall (NPCSpawner.guests_per_day_rate()), not a different mix. Every
## 0.125 of reputation above/below the average doubles/halves a type's weight.
const REPUTATION_WEIGHT_EXPONENT := 8.0

## Bounds on a single type's spawn chance. Deliberately wide so badly served
## types can all but vanish and well served ones can dominate the crowd; the
## floor keeps a trickle of visits so a type can still win back its reputation.
const MIN_SPAWN_CHANCE := 0.01
const MAX_SPAWN_CHANCE := 0.75

static func new_random() -> NPCLookInfo:
	return _new_random_with_body_type(_pick_reputation_weighted_spawn_body_type())

## Freshly spawned guests skew toward whichever type has been leaving the
## saloon happiest ("word gets around") - see NPCSpawner.type_reputation.
static func _pick_reputation_weighted_spawn_body_type() -> int:
	var chances := get_spawn_chances()
	var roll := randf()
	for candidate_type: int in chances.keys():
		roll -= chances[candidate_type]
		if roll <= 0.0:
			return candidate_type

	return chances.keys().back()

## Raw, un-normalized spawn weight per candidate body_type, before the
## per-type chance bounds are applied (see get_spawn_chances()).
static func get_spawn_weights() -> Dictionary:
	var allowed_types := SPAWN_BODY_TYPES.filter(func(t): return ScenarioHandler.is_archetype_allowed(t))
	if allowed_types.is_empty():
		allowed_types = SPAWN_BODY_TYPES

	var reputations: Dictionary = {}
	var average_reputation := 0.0
	for candidate_type in allowed_types:
		reputations[candidate_type] = Global.NPCSpawner.get_type_reputation(candidate_type) if Global.NPCSpawner != null else NPCSpawner.NEUTRAL_REPUTATION
		average_reputation += reputations[candidate_type]
	average_reputation /= allowed_types.size()

	var weights: Dictionary = {}
	for candidate_type in allowed_types:
		weights[candidate_type] = pow(2.0, (reputations[candidate_type] - average_reputation) * REPUTATION_WEIGHT_EXPONENT)
	return weights

## Normalized 0-1 spawn chance per candidate body_type, each held within
## MIN/MAX_SPAWN_CHANCE. Types pinned at a bound are fixed there and the
## remaining probability is redistributed among the others by weight.
static func get_spawn_chances() -> Dictionary:
	var weights := get_spawn_weights()
	var min_chance := minf(MIN_SPAWN_CHANCE, 1.0 / weights.size())
	var max_chance := maxf(MAX_SPAWN_CHANCE, 1.0 / weights.size())
	var chances: Dictionary = {}
	var free_types: Array = weights.keys()
	var free_probability := 1.0

	while not free_types.is_empty():
		var free_weight := 0.0
		for candidate_type in free_types:
			free_weight += weights[candidate_type]

		var free_chances: Dictionary = {}
		for candidate_type in free_types:
			free_chances[candidate_type] = free_probability * weights[candidate_type] / free_weight

		# Pin one side per pass - capping a dominant type frees probability
		# that may lift others back above the floor, and vice versa.
		var over_max: Array = free_types.filter(func(t): return free_chances[t] > max_chance)
		var to_pin: Array = over_max if not over_max.is_empty() else free_types.filter(func(t): return free_chances[t] < min_chance)
		if to_pin.is_empty():
			chances.merge(free_chances)
			break

		for candidate_type in to_pin:
			chances[candidate_type] = clampf(free_chances[candidate_type], min_chance, max_chance)
			free_probability -= chances[candidate_type]
			free_types.erase(candidate_type)

	return chances

## Normalized 0-100 spawn chance per candidate body_type, for UI display
## (see UIHUD's spawn-odds foldout). Mirrors get_spawn_chances() without
## rolling, so it reflects the current odds without consuming randomness.
static func get_spawn_chance_percentages() -> Dictionary:
	var chances := get_spawn_chances()
	for candidate_type in chances.keys():
		chances[candidate_type] *= 100.0
	return chances

## Body type is picked weighted by each archetype's bounty_weight (see
## NPCArchetype.bounty_weight) instead of the uniform range new_random()
## uses, so bounties skew toward whichever types are configured as more
## "wanted" (e.g. mostly outlaws) rather than any of the 4 common types
## equally.
static func new_random_bounty() -> NPCLookInfo:
	return _new_random_with_body_type(_pick_weighted_bounty_body_type())

static func _pick_weighted_bounty_body_type() -> int:
	var candidate_count: int = NPCArchetypeLibrary.PATHS.size()
	var total_weight := 0.0
	var weights: Array[float] = []
	for candidate_type in candidate_count:
		var archetype = NPCArchetypeLibrary.get_archetype(candidate_type)
		var weight: float = archetype.bounty_weight if ScenarioHandler.is_archetype_allowed(candidate_type) else 0.0
		weights.append(weight)
		total_weight += weight

	if total_weight <= 0.0:
		return randi_range(0, candidate_count - 1)

	var roll := randf() * total_weight
	for candidate_type in weights.size():
		roll -= weights[candidate_type]
		if roll <= 0.0:
			return candidate_type

	return weights.size() - 1

static func _new_random_with_body_type(new_body_type: int) -> NPCLookInfo:
	var look = NPCLookInfo.new()
	look.head_index = Vector2i(randi_range(0, 16), randi_range(0, 9))
	look.color_offsets = Vector3(randf(), randf_range(0.5, 0.833333), randf_range(-0.2, 0.5))

	look.body_type = new_body_type
	look.head_variant = randi_range(0, 7)
	look.channel_hue_random = PackedFloat32Array()
	look.channel_brightness_random = PackedFloat32Array()
	for i in CHANNEL_COUNT:
		look.channel_hue_random.append(randf_range(-1.0, 1.0))
		look.channel_brightness_random.append(randf_range(-1.0, 1.0))

	look.random_channel = PackedInt32Array()
	for i in CATEGORY_NAMES.size():
		look.random_channel.append(randi_range(0, CHANNEL_COUNT - 1))

	return look

func apply_to_material(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("body_type", body_type)
	mat.set_shader_parameter("head_variant", head_variant)
	mat.set_shader_parameter("channel_hue_random", channel_hue_random)
	mat.set_shader_parameter("channel_brightness_random", channel_brightness_random)

	for i in CATEGORY_NAMES.size():
		var category: String = CATEGORY_NAMES[i]
		mat.set_shader_parameter(category + "_random_channel", random_channel[i])
