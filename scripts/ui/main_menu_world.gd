extends Node2D

@export var reference_viewport_size := Vector2(960, 540)
@export var fit_camera_to_viewport := true
@export_range(1.0, 120.0, 0.5, "or_greater") var day_cycle_seconds := 20.0

@onready var camera: Camera2D = $Camera2D
@onready var sky: Sprite2D = $Environment/NewSky
@onready var montain_builder = $Environment/MontainBuilder
@onready var campaign_selection: Control = %CampaignSelection
@onready var preview_guests: HBoxContainer = $CampaignPreview/HBoxContainerGuests
@onready var preview_sign: BuildingSign = $CampaignPreview/Saloon/SaloonSign

# winter strengths are the ones authored on the sky material, scaled by _winter_amount
const WINTER_FADE_SECONDS := 1.5
const HORSE_TEXTURE := preload("res://assets/sprites/horse.png")
# matches AnimationModule.RIDE_BODY_OFFSET: riders sit 8px above the ground
const PREVIEW_RIDER_LIFT := 8

var _camera_zoom: Vector2
var _gameplay_camera_process_mode: ProcessMode
var _gameplay_camera_enabled: bool
var _sky_material: ShaderMaterial
var _starting_time_of_day: float
var _day_cycle_start_usec: int
var _max_tint_before: float
var _max_tint_after: float
var _max_snow_amount: float
var _selected_scenario_is_cold := false
var _winter_amount := 0.0
var _guest_preview_template: TextureRect
var _mounted_icon_cache: Dictionary = {}

func _ready() -> void:
	_sky_material = sky.material.duplicate() as ShaderMaterial
	sky.material = _sky_material
	_starting_time_of_day = _sky_material.get_shader_parameter("time_of_day")
	_day_cycle_start_usec = Time.get_ticks_usec()
	_max_tint_before = _sky_material.get_shader_parameter("weather_tint_strength_before")
	_max_tint_after = _sky_material.get_shader_parameter("weather_tint_strength_after")
	_max_snow_amount = _sky_material.get_shader_parameter("snow_amount")
	campaign_selection.scenario_selected.connect(_on_campaign_scenario_selected)
	# clicking the sign would open the in-game rename UI, which the menu does not have
	preview_sign.set_rename_locked(true)
	# the authored Guest node is only a template to clone per preview guest
	_guest_preview_template = preview_guests.get_node("Guest") as TextureRect
	preview_guests.remove_child(_guest_preview_template)
	# the selection screen's _ready ran first, so its default selection was already emitted
	_on_campaign_scenario_selected(campaign_selection.get_selected_scenario())
	_gameplay_camera_process_mode = Camera.process_mode
	_gameplay_camera_enabled = Camera.enabled
	Camera.process_mode = Node.PROCESS_MODE_DISABLED
	Camera.enabled = false
	camera.make_current()
	_camera_zoom = camera.zoom
	get_viewport().size_changed.connect(_frame_saloon)
	_frame_saloon()

func _exit_tree() -> void:
	if is_instance_valid(_guest_preview_template):
		_guest_preview_template.free()
	Camera.process_mode = _gameplay_camera_process_mode
	Camera.enabled = _gameplay_camera_enabled

func _on_campaign_scenario_selected(scenario: ScenarioData) -> void:
	_populate_guest_preview(scenario)
	if scenario != null:
		preview_sign.set_saloon_name(scenario.display_name)
	var feature := FeatureGateHandler.Feature.TEMPERATURE_SYSTEM
	_selected_scenario_is_cold = scenario != null and bool(scenario.feature_overrides.get(feature, FeatureGateHandler.is_enabled(feature)))

func _populate_guest_preview(scenario: ScenarioData) -> void:
	for child in preview_guests.get_children():
		preview_guests.remove_child(child)
		child.queue_free()
	if scenario == null:
		return
	var horse_feature := FeatureGateHandler.Feature.HORSE_ARRIVALS
	var horses_enabled := bool(scenario.feature_overrides.get(horse_feature, FeatureGateHandler.is_enabled(horse_feature)))
	for index in scenario.allowed_npc_archetypes.size():
		var archetype := scenario.allowed_npc_archetypes[index]
		if archetype == null or archetype.icon == null:
			continue
		var amount := scenario.preview_guest_counts[index] if index < scenario.preview_guest_counts.size() else 1
		# mount the share of this type that would arrive by horse, so the lineup hints at it
		var mounted := roundi(amount * archetype.horse_arrival_chance) if horses_enabled else 0
		for i in amount:
			var guest := _guest_preview_template.duplicate() as TextureRect
			guest.texture = _get_mounted_icon(archetype.icon) if i < mounted else archetype.icon
			preview_guests.add_child(guest)

## Rider and horse baked into one texture (horse drawn over the rider's legs so the standing
## icon reads as seated). The texture is as tall as the preview row, so the hooves land on the
## same line as a standing guest's feet when the TextureRect centers it vertically.
func _get_mounted_icon(rider_texture: Texture2D) -> Texture2D:
	if _mounted_icon_cache.has(rider_texture):
		return _mounted_icon_cache[rider_texture]

	var rider := rider_texture.get_image()
	rider.convert(Image.FORMAT_RGBA8)
	var horse := HORSE_TEXTURE.get_image()
	horse.convert(Image.FORMAT_RGBA8)

	var row_height := int(preview_guests.size.y)
	var ground_y := (row_height + rider.get_height()) / 2
	var width := maxi(horse.get_width(), rider.get_width())
	var image := Image.create(width, row_height, false, Image.FORMAT_RGBA8)
	var rider_pos := Vector2i((width - rider.get_width()) / 2, ground_y - PREVIEW_RIDER_LIFT - rider.get_height())
	var horse_pos := Vector2i((width - horse.get_width()) / 2, ground_y - horse.get_height())
	image.blend_rect(rider, Rect2i(Vector2i.ZERO, rider.get_size()), rider_pos)
	image.blend_rect(horse, Rect2i(Vector2i.ZERO, horse.get_size()), horse_pos)

	var texture := ImageTexture.create_from_image(image)
	_mounted_icon_cache[rider_texture] = texture
	return texture

func _update_winter(delta: float) -> void:
	var target := 1.0 if campaign_selection.visible and _selected_scenario_is_cold else 0.0
	_winter_amount = move_toward(_winter_amount, target, delta / WINTER_FADE_SECONDS)
	var active := _winter_amount > 0.0
	_sky_material.set_shader_parameter("weather_tint_enabled", active)
	_sky_material.set_shader_parameter("snow_enabled", active)
	_sky_material.set_shader_parameter("weather_tint_strength_before", _max_tint_before * _winter_amount)
	_sky_material.set_shader_parameter("weather_tint_strength_after", _max_tint_after * _winter_amount)
	_sky_material.set_shader_parameter("snow_amount", _max_snow_amount * _winter_amount)
	# same globals gameplay pushes, so sky_tint.gdshader objects take the cold tint too
	RenderingServer.global_shader_parameter_set("weather_tint_color", _sky_material.get_shader_parameter("weather_tint_color"))
	RenderingServer.global_shader_parameter_set("weather_tint_strength", _max_tint_after * _winter_amount)

func _frame_saloon() -> void:
	if not fit_camera_to_viewport:
		return
	var viewport_size := get_viewport_rect().size
	var fit := minf(viewport_size.x / reference_viewport_size.x,
		viewport_size.y / reference_viewport_size.y)
	camera.zoom = _camera_zoom * fit

func _process(delta: float) -> void:
	# real seconds, independent of gameplay speed or pause
	var elapsed := (Time.get_ticks_usec() - _day_cycle_start_usec) / 1000000.0
	var time_of_day := fposmod(_starting_time_of_day + elapsed * 24.0 / day_cycle_seconds, 24.0)
	_sky_material.set_shader_parameter("time_of_day", time_of_day)
	# sky_tint.gdshader reads this global, so the menu has to push it like the gameplay scene does
	RenderingServer.global_shader_parameter_set("sky_time_of_day", time_of_day)
	montain_builder.apply_parallax(camera.global_position, camera.zoom)
	_update_winter(delta)
