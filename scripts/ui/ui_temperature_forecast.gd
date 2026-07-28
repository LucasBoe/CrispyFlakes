extends Control
class_name UITemperatureForecast

const COLOR_NORMAL := Color(0.05, 0.05, 0.05, 1.0)
const COLOR_COLD := Color(0.55, 0.85, 1.0, 1.0)
## How much brighter the segment(s) under the arrow read compared to the rest
## of the strip.
const TODAY_HIGHLIGHT := 0.35

## Width of one day's segment, in pixels — segments are drawn edge-to-edge
## (no gap) and full-height, so the whole cavity reads as a continuous
## color strip rather than a row of floating dots. Integer: this UI is
## authored at native 1x (the engine's own viewport stretch does the 2x
## display scaling), so fractional pixel offsets would just blur/shimmer.
const SLOT_SPACING := 11.0

@onready var _markers_row: Control = $MarkersRow

var _markers: Array[ColorRect] = []

func _ready() -> void:
	for child in _markers_row.get_children():
		_markers.append(child as ColorRect)

	_update_marker_colors()
	_update_marker_positions()

func _process(_delta: float) -> void:
	# Both pull from TemperatureHandler every frame, which also serves to
	# detect a day rollover promptly even if nothing else touches it that
	# frame — the strip drifts left continuously with the time of day and the
	# highlight cross-fades at the same rate, so nothing ever visibly jumps.
	_update_marker_colors()
	_update_marker_positions()

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
	# Center within MarkersRow's own rect, whatever size/position that ends
	# up being set to in the scene — avoids drifting out of sync (and out of
	# its own clip_contents rect) if that band gets resized later.
	var center_x := _markers_row.size.x * 0.5
	var marker_size := Vector2(SLOT_SPACING, _markers_row.size.y)

	for i in _markers.size():
		var marker := _markers[i]
		if marker == null:
			continue
		var slot_offset := float(i - center_index) - day_fraction
		var target_x := center_x + slot_offset * SLOT_SPACING
		marker.size = marker_size
		# Snap to whole pixels — the underlying day_fraction drift is
		# continuous/fractional, but this UI is pixel art at native 1x scale,
		# so the rendered position needs to stay pixel-aligned regardless.
		marker.position = Vector2(roundf(target_x - marker_size.x * 0.5), 0.0)
