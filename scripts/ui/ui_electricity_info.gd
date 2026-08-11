extends Control
class_name UIElectricityInfo

const NORMAL_FILL := 0.55
const MAX_PERCENT := 300.0

@onready var display_texture: TextureRect = $MarginContainer/HBoxContainer/ElectricityDisplayTexture
@onready var summary_label: Label = $MarginContainer/HBoxContainer/Labels/SummaryLabel
@onready var producers_label: Label = $MarginContainer/HBoxContainer/Labels/ProducersLabel
@onready var consumers_label: Label = $MarginContainer/HBoxContainer/Labels/ConsumersLabel

var _meter_material: ShaderMaterial

func _ready() -> void:
	_meter_material = display_texture.material as ShaderMaterial
	if _meter_material == null:
		push_warning("UIElectricityInfo expects a ShaderMaterial on ElectricityDisplayTexture in the scene.")
		return
	ElectricityHandler.state_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var stats := ElectricityHandler.get_stats()
	var production := int(stats["production"])
	var percent := float(stats["percent"])
	var demand := int(stats["demand"])
	var fill_ratio := 1.0 - pow(1.0 - (1.0 if demand <= 0 and production > 0 else _meter_fill_ratio(percent)), 1.5)
	var fill_color_ratio = 0 if percent < 75.0 else (.5 if percent < 100.0 else 1.0)
	var is_stable := demand > 0 and percent >= 100.0

	_meter_material.set_shader_parameter("fill_ratio", fill_ratio)
	_meter_material.set_shader_parameter("fill_color_ratio", fill_color_ratio)
	_meter_material.set_shader_parameter("blink_enabled", demand > 0 and not is_stable)

	summary_label.text = _summary_text(percent, demand)
	producers_label.text = _signed_count_text("+", int(stats["active_producers"]), "producer")
	consumers_label.text = _signed_count_text("-", int(stats["consumers"]), "consumer")

func _meter_fill_ratio(percent: float) -> float:
	var clamped_percent := clampf(percent, 0.0, MAX_PERCENT)
	if clamped_percent <= 100.0:
		return (clamped_percent / 100.0) * NORMAL_FILL
	return NORMAL_FILL + ((clamped_percent - 100.0) / 200.0) * (1.0 - NORMAL_FILL)

func _summary_text(percent: float, demand: int) -> String:
	var shown_percent := roundi(percent)
	if demand <= 0:
		return "%d%% - no consumers" % shown_percent
	return "%d%% - %s" % [shown_percent, "production stable" if percent >= 100.0 else "production unstable"]

func _signed_count_text(prefix: String, count: int, noun: String) -> String:
	return "%s %d %s%s" % [prefix, count, noun, "" if count == 1 else "s"]
