extends Control
class_name UITemperatureForecast

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

@onready var _markers_row: Control = %MarkersRow
@onready var _weather_icon: TextureRect = %Weather_Icon_TextureRect
@onready var _season_and_temperature_label: Label = %SeasonAndTemp_Label
@onready var _action_required_label: Label = %ActionRequired_Label

const ICON_WARM := preload("res://assets/sprites/ui/icon_sun.png")
const ICON_COLD := preload("res://assets/sprites/ui/icon_snowflake.png")

const SEASON_WARM := "Summer"
const SEASON_COLD := "Winter"
const ACTION_WARM := "No fires needed"
const ACTION_COLD := "Light up fires"

var _markers: Array[ColorRect] = []

## Cached so the summary labels/icon only get touched when something about
## them actually changed, instead of reassigning Label.text every frame.
var _summary_initialized := false
var _last_displayed_temperature := 0
var _last_displayed_is_cold := false

func _ready() -> void:
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

func _process(_delta: float) -> void:
	# Both pull from TemperatureHandler every frame, which also serves to
	# detect a day rollover promptly even if nothing else touches it that
	# frame — the strip drifts left continuously with the time of day and the
	# highlight cross-fades at the same rate, so nothing ever visibly jumps.
	_update_marker_colors()
	_update_marker_positions()
	_update_summary()

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
