extends Node2D

@onready var sky = $Sky
@onready var clouds = $CloudHandler
@onready var mountains = [$Montains, $Montains2]

var mointain_lerp = .33

var mountains_default_posisitions = []

func _ready():
	for i in mountains:
		mountains_default_posisitions.append(i.global_position)
	_setup_world_tint()

func _setup_world_tint() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 1
	add_child(layer)

	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/world_tint.gdshader")
	rect.material = mat
	layer.add_child(rect)

func _process(delta):
	var tod: float = fmod(Global.time_now, Global.DAY_DURATION) / Global.DAY_DURATION * 24.0
	$NewSky.material.set_shader_parameter("time_of_day", tod)
	RenderingServer.global_shader_parameter_set("sky_time_of_day", tod)

	var cam_pos = Camera.global_position
	var inv_zoom: Vector2 = Vector2.ONE / Camera.zoom
	sky.global_position = cam_pos
	sky.scale = Vector2(1000.0, inv_zoom.y)
	clouds.global_position = cam_pos
	clouds.scale = inv_zoom

	for i in mountains.size():
		var mountain = mountains[i]
		var default_position = mountains_default_posisitions[i]
		mountain.global_position = lerp(default_position, cam_pos, mointain_lerp)
		mountain.scale = lerp(Vector2.ONE, inv_zoom, mointain_lerp)
