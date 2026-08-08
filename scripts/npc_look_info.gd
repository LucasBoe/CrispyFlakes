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

const SPAWN_BODY_TYPE_MIN := 1
const SPAWN_BODY_TYPE_MAX := 4

## Guest count a type needs before its average mood is fully trusted as a
## spawn-weight signal (see _pick_mood_weighted_spawn_body_type()). Below
## this, the signal is blended toward neutral so one lone happy/miserable
## guest can't swing the whole type's future spawn rate.
const MOOD_WEIGHT_SAMPLE_CONFIDENCE := 8.0

static func new_random() -> NPCLookInfo:
	return _new_random_with_body_type(_pick_mood_weighted_spawn_body_type())

## Freshly spawned guests skew toward whichever type is currently doing
## well ("word gets around") - each candidate type's spawn weight scales
## with its live guests' average mood (see NPCSpawner.get_guest_type_stats()),
## blended toward neutral for types with few guests so a single outlier
## guest can't dominate the weighting.
static func _pick_mood_weighted_spawn_body_type() -> int:
	var stats: Dictionary = {}
	if Global.NPCSpawner != null:
		stats = Global.NPCSpawner.get_guest_type_stats()

	var candidates: Array[int] = []
	var weights: Array[float] = []
	var total_weight := 0.0
	for candidate_type in range(SPAWN_BODY_TYPE_MIN, SPAWN_BODY_TYPE_MAX + 1):
		var blended_mood := 0.5
		if stats.has(candidate_type):
			var entry: Dictionary = stats[candidate_type]
			var confidence: float = clampf(float(entry.count) / MOOD_WEIGHT_SAMPLE_CONFIDENCE, 0.0, 1.0)
			blended_mood = lerpf(0.5, entry.avg_mood, confidence)
		var weight: float = lerpf(0.5, 1.5, blended_mood)
		candidates.append(candidate_type)
		weights.append(weight)
		total_weight += weight

	if total_weight <= 0.0:
		return candidates.pick_random()

	var roll := randf() * total_weight
	for i in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]

	return candidates[candidates.size() - 1]

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
		var weight: float = archetype.bounty_weight
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
