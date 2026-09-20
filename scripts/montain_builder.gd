extends Node2D

const SKY_TINT_SHADER := preload("res://assets/shaders/sky_tint.gdshader")

# sky_colors.gdshaderinc uniforms are not global, so every material needs the scene's tuned palette copied onto it
const SKY_PALETTE_PARAMS := [
	"dawn_top", "dawn_bottom",
	"sunrise_top", "sunrise_bottom",
	"morning_top", "morning_bottom",
	"midday_top", "midday_bottom",
	"afternoon_top", "afternoon_bottom",
	"golden_top", "golden_bottom",
	"sunset_top", "sunset_bottom",
	"dusk_top", "dusk_bottom",
	"night_blue_top", "night_blue_bottom",
	"night_teal_top", "night_teal_bottom",
]

const MOUNTAIN_PIECE_PATHS := [
	"res://assets/sprites/background_assets/mountain_range_1.png",
	"res://assets/sprites/background_assets/mountain_range_2.png",
	"res://assets/sprites/background_assets/mountain_range_3.png",
	"res://assets/sprites/background_assets/mountain_range_4.png",
	"res://assets/sprites/background_assets/mountain_range_5.png",
	"res://assets/sprites/background_assets/mountain_range_6.png",
	"res://assets/sprites/background_assets/mountain_range_7.png",
	"res://assets/sprites/background_assets/mountain_range_8.png",
	"res://assets/sprites/background_assets/mountain_range_9.png",
]

const MOUNTAIN_AMBIENT_MIX := 1.0
const DESERT_AMBIENT_MIX := 0.5

const FAR_TINT_STRENGTH := 1.0
const FAR_TINT_STRENGTH_2 := 0.85
const MEDIUM_TINT_STRENGTH := 0.7
const CLOSE_TINT_STRENGTH := 0.5
const DESERT_TINT_STRENGTH := 0.4

const MONTAIN_RANGE_TARGET_WIDTH := 4096.0

# a region_rect wider than the texture tiles it via texture_repeat; wide enough for parallax drift
const REPEATING_LAYER_REGION_WIDTH := 4096.0

# per-layer lerp weight from its authored position toward the camera: 0 stays put, 1 tracks the camera
const PARALLAX_FACTORS := {
	"FarMontainRange": Vector2(0.80, 0.5),
	"FarMontainRange2": Vector2(0.70, 0.35),
	"MediumMontainRange": Vector2(0.60, 0.25),
	"CloseMontainRange": Vector2(0.30, 0.15),
	"DesertRange": Vector2(0.20, 0.1),
	"DesertRange2": Vector2(0.10, 0.05),
}

@onready var far_montain_range: Sprite2D = $FarMontainRange
@onready var far_montain_range_2: Sprite2D = $FarMontainRange2
@onready var medium_montain_range: Node2D = $MediumMontainRange
@onready var close_montain_range: Node2D = $CloseMontainRange
@onready var desert_range: Sprite2D = $DesertRange
@onready var desert_range_2: Sprite2D = $DesertRange2

var _default_layer_positions: Dictionary = {}
var _sky_palette: Dictionary = {}

func _ready() -> void:
	_sky_palette = _read_sky_palette()
	far_montain_range.material = _make_sky_tint_material(FAR_TINT_STRENGTH, MOUNTAIN_AMBIENT_MIX)
	far_montain_range_2.material = _make_sky_tint_material(FAR_TINT_STRENGTH_2, MOUNTAIN_AMBIENT_MIX)
	desert_range.material = _make_sky_tint_material(CLOSE_TINT_STRENGTH, lerp(DESERT_AMBIENT_MIX, MOUNTAIN_AMBIENT_MIX, .66))
	desert_range_2.material = _make_sky_tint_material(DESERT_TINT_STRENGTH, lerp(DESERT_AMBIENT_MIX, MOUNTAIN_AMBIENT_MIX, .33))
	_widen_repeating_layer(far_montain_range)
	_widen_repeating_layer(far_montain_range_2)
	_widen_repeating_layer(desert_range)
	_widen_repeating_layer(desert_range_2)
	_build_random_montain_range(medium_montain_range, MEDIUM_TINT_STRENGTH)
	_build_random_montain_range(close_montain_range, CLOSE_TINT_STRENGTH)

	for layer_name in PARALLAX_FACTORS:
		_default_layer_positions[layer_name] = (get_node(layer_name) as CanvasItem).position

func apply_parallax(cam_global_pos: Vector2, cam_zoom: Vector2) -> void:
	var inv_zoom: Vector2 = Vector2.ONE / cam_zoom
	for layer_name in PARALLAX_FACTORS:
		var layer: CanvasItem = get_node(layer_name)
		var factor: Vector2 = PARALLAX_FACTORS[layer_name]
		var default_position: Vector2 = _default_layer_positions[layer_name]
		layer.position = Vector2(
			lerp(default_position.x, cam_global_pos.x, factor.x),
			lerp(default_position.y, cam_global_pos.y, factor.y)
		)
		layer.scale = Vector2(
			lerp(1.0, inv_zoom.x, factor.x),
			lerp(1.0, inv_zoom.y, factor.y)
		)

func _read_sky_palette() -> Dictionary:
	# NewSky is a sibling of this node in both the gameplay and menu scenes
	var sky_sprite: Sprite2D = get_parent().get_node("NewSky") as Sprite2D
	var sky_material: ShaderMaterial = sky_sprite.material as ShaderMaterial
	var palette: Dictionary = {}
	for param_name in SKY_PALETTE_PARAMS:
		palette[param_name] = sky_material.get_shader_parameter(param_name)
	return palette

func _make_sky_tint_material(tint_strength: float, ambient_mix: float) -> ShaderMaterial:
	var sky_tint_material := ShaderMaterial.new()
	sky_tint_material.shader = SKY_TINT_SHADER
	sky_tint_material.set_shader_parameter("tint_strength", tint_strength)
	sky_tint_material.set_shader_parameter("sky_ambient_mix", ambient_mix)
	for param_name in _sky_palette:
		sky_tint_material.set_shader_parameter(param_name, _sky_palette[param_name])
	return sky_tint_material

func _widen_repeating_layer(sprite: Sprite2D) -> void:
	var rect: Rect2 = sprite.region_rect
	rect.size.x = REPEATING_LAYER_REGION_WIDTH
	sprite.region_rect = rect

func _build_random_montain_range(container: Node2D, tint_strength: float) -> void:
	for child in container.get_children():
		child.free()

	var shared_material := _make_sky_tint_material(tint_strength, MOUNTAIN_AMBIENT_MIX)

	var textures: Array[Texture2D] = []
	var total_width := 0.0
	while total_width < MONTAIN_RANGE_TARGET_WIDTH:
		var texture: Texture2D = load(MOUNTAIN_PIECE_PATHS.pick_random())
		textures.append(texture)
		total_width += texture.get_width()

	# centered on x = 0 so the Node2D's scale pivots at the range's middle
	var cursor_x := -total_width / 2.0
	for texture in textures:
		var piece := Sprite2D.new()
		piece.texture = texture
		piece.material = shared_material
		piece.position.x = cursor_x + texture.get_width() / 2.0
		container.add_child(piece)
		cursor_x += texture.get_width()
