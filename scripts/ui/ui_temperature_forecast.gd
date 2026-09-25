extends Control
class_name UITemperatureForecast

signal tutorial_forecast_opened

const COLOR_NORMAL := Color(0.99607843, 0.80784315, 0.23921569, 1.0)
const COLOR_COLD := Color(0.55, 0.85, 1.0, 1.0)
## How much brighter the segment(s) under the arrow read compared to the rest
## of the strip.
const TODAY_HIGHLIGHT := 0.35

## Segments are drawn edge-to-edge (no gap) and full-height, so the whole row
## reads as a continuous color strip rather than a row of floating dots.
## One slot beyond this is kept off the visible edge as a scroll buffer (see
## TemperatureHandler.FORECAST_DAYS_AFTER) — spacing is stretched at runtime
## so those VISIBLE_SLOT_COUNT slots fill the row's actual width exactly,
## whatever that ends up being, instead of a fixed guess that could leave
## dead space on either side.
const VISIBLE_SLOT_COUNT := 12

## Horizontal center of the pointer graphic (temperature_scale_pointer.png,
## 15px wide) in MarkersRow's local space: it sits in a sibling container
## with a 4px left margin, so its center is 4 + 15/2 = 11.5. Hardcoded to
## match the pointer's current placement in the scene — if the pointer gets
## moved again later, update this to match.
const POINTER_ANCHOR_X := 11.5
const ICON_WARM := preload("res://assets/sprites/ui/icon_sun.png")
const ICON_COLD := preload("res://assets/sprites/ui/icon_snowflake.png")
const TUTORIAL_ARROW_TEXTURE := preload("res://assets/sprites/ui/2x/arrow_red_left.png")
const GOLDEN_GLOW_SHADER := preload("res://assets/shaders/golden_glow_red_replace.gdshader")
const TUTORIAL_ARROW_OFFSET := Vector2(24.0, -5.0)
const TUTORIAL_ARROW_HOVER_WIDTH := 3.0
const TUTORIAL_ARROW_HOVER_DURATION := 0.5

const SEASON_WARM := "Summer"
const SEASON_COLD := "Winter"
const ACTION_WARM := "No fires needed"
const ACTION_COLD := "Light up fires"

@onready var _foldout_button: Button = %Button_ForecastFoldout
@onready var _panel: Control = $MarginContainer2
@onready var _markers_row: Control = %MarkersRow
@onready var _weather_icon: TextureRect = %Weather_Icon_TextureRect
@onready var _season_and_temperature_label: Label = %SeasonAndTemp_Label
@onready var _action_required_label: Label = %ActionRequired_Label

var _markers: Array[ColorRect] = []

## Cached so the summary labels/icon only get touched when something about
## them actually changed, instead of reassigning Label.text every frame.
var _summary_initialized := false
var _last_displayed_temperature := 0
var _last_displayed_is_cold := false
var _is_expanded := false
var _forecast_unlocked := false
var _tutorial_prompt_active := false
var _tutorial_arrow: TextureRect
var _tutorial_arrow_hover_tween: Tween
var _tutorial_arrow_material: ShaderMaterial

func _ready() -> void:
	_forecast_unlocked = FeatureGateHandler.is_enabled(FeatureGateHandler.Feature.TEMPERATURE_SYSTEM)
	_is_expanded = _forecast_unlocked
	_foldout_button.pressed.connect(_on_foldout_pressed)

	# Same dummy-template pattern as CloudHandler: the scene only has one
	# real ColorRect (MarkerDummy, including its Header cap); it stays
	# hidden and every visible segment is a duplicate of it, so there's a
	# single place to restyle the look of "one day" in the editor.
	var dummy := _markers_row.get_node("MarkerDummy") as ColorRect
	dummy.visible = false

	var slot_count := TemperatureHandler.get_forecast_temperatures().size()
	for i in slot_count:
		var marker := dummy.duplicate() as ColorRect
		marker.visible = true
		_markers_row.add_child(marker)
		_markers.append(marker)

	_update_marker_colors()
	_update_marker_positions()
	_update_summary()
	_update_visibility_state()

func _process(_delta: float) -> void:
	# a scenario can enable the feature after _ready(), so expand on the unlock transition too
	if not _forecast_unlocked and FeatureGateHandler.is_enabled(FeatureGateHandler.Feature.TEMPERATURE_SYSTEM):
		_forecast_unlocked = true
		_is_expanded = true
		_tutorial_prompt_active = false
		_destroy_tutorial_arrow()

	_update_visibility_state()
	if not visible or not (_forecast_unlocked and _is_expanded):
		return

	# Both pull from TemperatureHandler every frame, which also serves to
	# detect a day rollover promptly even if nothing else touches it that
	# frame — the strip drifts left continuously with the time of day and the
	# highlight cross-fades at the same rate, so nothing ever visibly jumps.
	_update_marker_colors()
	_update_marker_positions()
	_update_summary()

func request_tutorial_foldout_prompt() -> void:
	if _forecast_unlocked:
		_is_expanded = true
		_tutorial_prompt_active = false
		_destroy_tutorial_arrow()
		_update_visibility_state()
		return

	_tutorial_prompt_active = true
	_is_expanded = false
	_show_tutorial_arrow()
	_update_visibility_state()

func clear_tutorial_foldout_prompt() -> void:
	_tutorial_prompt_active = false
	_destroy_tutorial_arrow()
	_update_visibility_state()

func has_unlocked_forecast() -> bool:
	return _forecast_unlocked

func is_expanded() -> bool:
	return _is_expanded

func _update_visibility_state() -> void:
	visible = _tutorial_prompt_active or _forecast_unlocked
	_foldout_button.visible = visible
	_foldout_button.text = "v" if _is_expanded and _forecast_unlocked else ">"
	_panel.visible = _forecast_unlocked and _is_expanded

func _on_foldout_pressed() -> void:
	if not _forecast_unlocked:
		if not _tutorial_prompt_active:
			return
		TemperatureHandler.activate_tutorial_summer_start()
		_forecast_unlocked = true
		_tutorial_prompt_active = false
		_is_expanded = true
		_destroy_tutorial_arrow()
		tutorial_forecast_opened.emit()
		_update_visibility_state()
		return

	_is_expanded = not _is_expanded
	_update_visibility_state()

func _show_tutorial_arrow() -> void:
	if is_instance_valid(_tutorial_arrow):
		return

	if _tutorial_arrow_material == null:
		_tutorial_arrow_material = ShaderMaterial.new()
		_tutorial_arrow_material.shader = GOLDEN_GLOW_SHADER

	var arrow := TextureRect.new()
	arrow.name = "TutorialForecastArrow"
	arrow.texture = TUTORIAL_ARROW_TEXTURE
	arrow.material = _tutorial_arrow_material
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP
	arrow.size = TUTORIAL_ARROW_TEXTURE.get_size()
	arrow.position = TUTORIAL_ARROW_OFFSET
	_foldout_button.add_child(arrow)
	_tutorial_arrow = arrow

	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(arrow, "position:x", TUTORIAL_ARROW_OFFSET.x + TUTORIAL_ARROW_HOVER_WIDTH, TUTORIAL_ARROW_HOVER_DURATION)
	tween.tween_property(arrow, "position:x", TUTORIAL_ARROW_OFFSET.x, TUTORIAL_ARROW_HOVER_DURATION)
	_tutorial_arrow_hover_tween = tween

func _destroy_tutorial_arrow() -> void:
	if _tutorial_arrow_hover_tween != null:
		_tutorial_arrow_hover_tween.kill()
		_tutorial_arrow_hover_tween = null

	if _tutorial_arrow != null and is_instance_valid(_tutorial_arrow):
		_tutorial_arrow.queue_free()
	_tutorial_arrow = null

## Weather icon, "Season (temp°C)" label, and the fires-needed hint — all
## driven by the same live get_outdoor_temperature()/is_cold() the rest of
## this widget already uses, so they always agree with what the strip shows.
func _update_summary() -> void:
	var temperature := TemperatureHandler.get_outdoor_temperature()
	var rounded := roundi(temperature)
	var cold := TemperatureHandler.is_cold(temperature)

	if _summary_initialized and rounded == _last_displayed_temperature and cold == _last_displayed_is_cold:
		return
	_summary_initialized = true
	_last_displayed_temperature = rounded
	_last_displayed_is_cold = cold

	_weather_icon.texture = ICON_COLD if cold else ICON_WARM
	var season := SEASON_COLD if cold else SEASON_WARM
	_season_and_temperature_label.text = "%s (%d°C)" % [season, rounded]
	_action_required_label.text = ACTION_COLD if cold else ACTION_WARM

## today and tomorrow's segments cross-fade brightness as the day
## progresses — this is the same continuous blend get_outdoor_temperature()
## uses, so whichever color is actually under the arrow at any instant is
## exactly the temperature currently in effect, with no discrete jump.
func _update_marker_colors() -> void:
	var forecast := TemperatureHandler.get_forecast_temperatures()
	var center_index := TemperatureHandler.get_forecast_center_index()
	var day_fraction := TemperatureHandler.get_time_of_day_hours() / 24.0
	for i in mini(forecast.size(), _markers.size()):
		var marker := _markers[i]
		if marker == null:
			continue
		var base_color := COLOR_COLD if TemperatureHandler.is_cold(forecast[i]) else COLOR_NORMAL
		var highlight := 0.0
		if i == center_index:
			highlight = 1.0 - day_fraction
		elif i == center_index + 1:
			highlight = day_fraction
		marker.color = base_color.lightened(TODAY_HIGHLIGHT * highlight)

func _update_marker_positions() -> void:
	if _markers.is_empty():
		return

	var center_index := TemperatureHandler.get_forecast_center_index()
	var day_fraction := TemperatureHandler.get_time_of_day_hours() / 24.0
	# Anchored under the pointer graphic (now near the left edge) rather than
	# the row's horizontal center.
	var center_x := POINTER_ANCHOR_X
	# Stretched so VISIBLE_SLOT_COUNT segments exactly fill the row's actual
	# width — the whole available space is used left to right, whatever size
	# MarkersRow ends up being, instead of a fixed pixel guess.
	var slot_spacing := _markers_row.size.x / float(VISIBLE_SLOT_COUNT)
	var row_height := _markers_row.size.y

	for i in _markers.size():
		var marker := _markers[i]
		if marker == null:
			continue
		var slot_offset := float(i - center_index) - day_fraction
		# Round each segment's shared boundary with its neighbor, not its
		# center — rounding position and size independently could land
		# neighboring edges on different pixels (a 1px gap letting whatever's
		# behind the strip show through as a thin line). Both segments derive
		# their touching edge from the exact same formula, so it always rounds
		# to the same pixel on both sides.
		var left_edge := roundf(center_x + (slot_offset - 0.5) * slot_spacing)
		var right_edge := roundf(center_x + (slot_offset + 0.5) * slot_spacing)
		marker.position = Vector2(left_edge, 0.0)
		marker.size = Vector2(right_edge - left_edge, row_height)
