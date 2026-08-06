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

static func new_random() -> NPCLookInfo:
	var look = NPCLookInfo.new()
	look.head_index = Vector2i(randi_range(0, 16), randi_range(0, 9))
	look.color_offsets = Vector3(randf(), randf_range(0.5, 0.833333), randf_range(-0.2, 0.5))

	look.body_type = randi_range(1, 4)
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
