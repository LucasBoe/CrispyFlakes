extends Control

const GUEST_TYPE_FALLBACK_ICON := preload("res://assets/sprites/cowboy_raw_stand.png")

@onready var label_workers: Label = %Label_Workers
@onready var label_idles: Label = %Label_Idles
@onready var button_idles: Button = %Button_Idles
@onready var button_highlight: Button = %Button_Highlight
@onready var label_guest_amount: Label = %Label_GuestAmount
@onready var progression_bar: ProgressBar = %ProgressBar_GuestProgression
@onready var label_guest_rate: Label = %Label_GuestRate
@onready var label_avg_mood: Label = %Label_AvgMood
@onready var button_mood_foldout: Button = %Button_MoodFoldout
@onready var mood_affector_container : MarginContainer = $VBoxContainer/MarginContainer2
@onready var mood_affectors: VBoxContainer = %MoodAffectors
@onready var guest_type_row_container: HBoxContainer = %HBoxContainer_GuestTypes
@onready var guest_type_template_row: VBoxContainer = %GuestType_VBoxContainer
@onready var button_spawn_chance_foldout: Button = %Button_SpawnChanceFoldout
@onready var spawn_chance_panel: MarginContainer = $VBoxContainer/MarginContainer3
@onready var spawn_chance_row_container: VBoxContainer = %SpawnChanceRows
@onready var spawn_chance_template_row: HBoxContainer = %SpawnChanceRow_HBoxContainer

var _highlights_active: bool = false
var _is_mood_breakdown_expanded := false
var _mood_affectors_signature := ""
var _guest_type_signature: Array = []
var _is_spawn_chance_expanded := false
var _spawn_chance_signature: Array = []

func _ready() -> void:
	JobHandler.on_jobs_changed_signal.connect(_on_jobs_changed)
	GlobalEventHandler.on_room_created_signal.connect(_on_worker_capacity_changed)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_worker_capacity_changed)
	Global.NPCSpawner.worker_count_changed_signal.connect(_on_jobs_changed)
	NPCEventHandler.on_destroy_npc_signal.connect(_on_destroy_npc)
	HoverHandler.click_hovered_node_signal.connect(_on_click_hovered_node)
	visibility_changed.connect(_on_visibility_changed)
	button_idles.pressed.connect(_select_next_idle)
	button_highlight.pressed.connect(_enable_worker_highlights)
	button_mood_foldout.pressed.connect(_on_mood_foldout_pressed)
	button_spawn_chance_foldout.pressed.connect(_on_spawn_chance_foldout_pressed)
	FeatureGateHandler.feature_changed_signal.connect(_on_feature_changed)
	visible = FeatureGateHandler.is_enabled(FeatureGateHandler.Feature.GUEST_AUTO_SPAWN)
	guest_type_template_row.hide()
	spawn_chance_template_row.hide()
	_on_jobs_changed()
	_update_mood_breakdown_visibility()
	_update_spawn_chance_visibility()

func _on_feature_changed(feature: FeatureGateHandler.Feature, enabled: bool) -> void:
	if feature == FeatureGateHandler.Feature.GUEST_AUTO_SPAWN:
		visible = enabled

func _on_visibility_changed() -> void:
	if visible:
		_on_jobs_changed()

func _on_jobs_changed() -> void:
	var idle_count: int = JobHandler.count_workers_in(Enum.Jobs.IDLE)
	var worker_count := Global.NPCSpawner.get_worker_count()
	label_workers.text = "Workers: %d" % worker_count
	label_workers.remove_theme_color_override("font_color")

	if idle_count > 0:
		label_idles.text = "Idles"
		label_idles.add_theme_color_override("font_color", Color(1, 0.65, 0, 1))
		button_idles.text = str(idle_count)
		button_idles.visible = true
	else:
		label_idles.text = "No Idle Workers"
		label_idles.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		button_idles.visible = false

	if _highlights_active:
		_apply_highlights()

func _on_worker_capacity_changed(_room: RoomBase) -> void:
	_on_jobs_changed()

func _on_destroy_npc(npc) -> void:
	if npc is not NPCWorker:
		return
	_on_jobs_changed()

func _on_click_hovered_node(node) -> void:
	if _highlights_active and node is NPCWorker:
		_clear_highlights()

func _enable_worker_highlights() -> void:
	_highlights_active = true
	_apply_highlights()

func _apply_highlights() -> void:
	for worker in Global.NPCSpawner.workers:
		if is_instance_valid(worker):
			worker.Tint.add_outline(Color.YELLOW, 5, self)

func _clear_highlights() -> void:
	for worker in Global.NPCSpawner.workers:
		if is_instance_valid(worker):
			worker.Tint.remove_outline_for(self)
	_highlights_active = false

func _select_next_idle() -> void:
	var idle_workers: Array = Global.NPCSpawner.workers.filter(func(w: NPCWorker): return w.current_job == Enum.Jobs.IDLE)
	if idle_workers.is_empty():
		_on_jobs_changed()
		return

	var idle: NPCWorker = idle_workers.pick_random()
	Camera.zoomTarget = 2.0
	Camera.zoom_in_out(true, 0.1)
	Camera.set_camera_target_position(idle.global_position)
	await Camera.tween_offset_to_zero().finished
	Global.UI.selection.manually_select(idle)

func _process(_delta: float) -> void:
	var guest_count := Global.NPCSpawner.get_active_guest_count()
	label_guest_amount.text = str("Guests: ", guest_count)
	if FeatureGateHandler.is_enabled(FeatureGateHandler.Feature.GUEST_AUTO_SPAWN):
		progression_bar.value = Global.NPCSpawner.next_guest_progression
		label_guest_rate.text = "+%.2f/M" % Global.NPCSpawner.guests_per_day_rate()
	else:
		label_guest_rate.text = ""
	_update_avg_mood(guest_count)
	_update_mood_breakdown(guest_count)
	_update_guest_type_breakdown(guest_count)
	_update_spawn_chance_breakdown()

func _update_avg_mood(guest_count: int) -> void:
	if guest_count == 0:
		label_avg_mood.text = "Avg. Mood: -"
		label_avg_mood.remove_theme_color_override("font_color")
		return
	var avg := Global.NPCSpawner.get_average_mood()
	label_avg_mood.text = "Avg. Mood: %d%%" % roundi(avg * 100)
	label_avg_mood.add_theme_color_override("font_color", Color.GREEN.lerp(Color.RED, 1.0 - avg))

func _update_mood_breakdown(guest_count: int) -> void:
	if guest_count == 0:
		_mood_affectors_signature = ""
		button_mood_foldout.hide()
		_clear_mood_affectors()
		_update_mood_breakdown_visibility()
		return

	var summary := Global.NPCSpawner.get_mood_affector_summary()
	if summary.is_empty():
		_mood_affectors_signature = ""
		button_mood_foldout.hide()
		_clear_mood_affectors()
		_update_mood_breakdown_visibility()
		return

	button_mood_foldout.show()
	var signature := _build_mood_affector_signature(summary, guest_count)
	if signature != _mood_affectors_signature:
		_rebuild_mood_affectors(summary, guest_count)
		_mood_affectors_signature = signature

	_update_mood_breakdown_visibility()

func _build_mood_affector_signature(summary: Array[Dictionary], guest_count: int) -> String:
	var parts := PackedStringArray([str(guest_count)])
	for entry in summary:
		parts.append("%s|%.3f|%d|%d" % [
			entry.reason,
			entry.amount,
			entry.guest_count,
			entry.event_count,
		])
	return "|".join(parts)

func _rebuild_mood_affectors(summary: Array[Dictionary], guest_count: int) -> void:
	_clear_mood_affectors()

	var max_abs := 0.0
	for entry in summary:
		max_abs = maxf(max_abs, absf(entry.amount))

	for entry in summary:
		var lbl := Label.new()
		lbl.theme = label_avg_mood.theme
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.text = "%s  %s (%d guest%s)" % [
			_build_impact_marker(entry.amount, max_abs),
			entry.reason,
			entry.guest_count,
			"" if entry.guest_count == 1 else "s",
		]
		lbl.add_theme_color_override("font_color", _get_affector_color(entry.amount, max_abs))
		mood_affectors.add_child(lbl)

func _clear_mood_affectors() -> void:
	for child in mood_affectors.get_children():
		mood_affectors.remove_child(child)
		child.queue_free()

func _build_impact_marker(amount: float, max_abs: float) -> String:
	if is_zero_approx(max_abs):
		return ""
	var normalized := clampf(absf(amount) / max_abs, 0.0, 1.0)
	var level := maxi(1, ceili(normalized * 4.0))
	var marker := "+" if amount >= 0.0 else "-"
	return marker.repeat(level)

func _get_affector_color(amount: float, max_abs: float) -> Color:
	var neutral := Color(0.88, 0.84, 0.75, 1.0)
	var strong := Color(0.72, 0.95, 0.45, 1.0) if amount >= 0.0 else Color(1.0, 0.55, 0.52, 1.0)
	var intensity := 1.0 if is_zero_approx(max_abs) else clampf(absf(amount) / max_abs, 0.25, 1.0)
	return neutral.lerp(strong, intensity)

func _update_mood_breakdown_visibility() -> void:
	var has_entries := mood_affectors.get_child_count() > 0
	var show_breakdown := has_entries and _is_mood_breakdown_expanded
	button_mood_foldout.visible = has_entries
	button_mood_foldout.text = "v" if _is_mood_breakdown_expanded else ">"
	mood_affector_container.visible = show_breakdown
	mood_affectors.visible = show_breakdown

func _on_mood_foldout_pressed() -> void:
	if mood_affectors.get_child_count() == 0:
		return
	_is_mood_breakdown_expanded = not _is_mood_breakdown_expanded
	_update_mood_breakdown_visibility()

## Static row of icon+count+mood per guest body_type, always visible (no
## foldout) - mirrors UIItemsController's template-row-duplication
## pattern (scripts/ui/ui_items_controller.gd).
func _update_guest_type_breakdown(guest_count: int) -> void:
	if guest_count == 0:
		_guest_type_signature = []
		_apply_guest_type_stats({})
		return

	var stats := Global.NPCSpawner.get_guest_type_stats()
	var signature := _build_guest_type_signature(stats)
	if signature == _guest_type_signature:
		return
	_guest_type_signature = signature
	_apply_guest_type_stats(stats)

func _build_guest_type_signature(stats: Dictionary) -> Array:
	var body_types: Array = stats.keys()
	body_types.sort()
	var signature: Array = []
	for body_type in body_types:
		var entry: Dictionary = stats[body_type]
		signature.append("%d:%d:%.2f" % [body_type, entry.count, entry.avg_mood])
	return signature

func _apply_guest_type_stats(stats: Dictionary) -> void:
	_clear_guest_type_rows()

	var body_types: Array = stats.keys()
	body_types.sort()

	if body_types.is_empty():
		guest_type_template_row.hide()
		return

	for i in body_types.size():
		var row := guest_type_template_row if i == 0 else guest_type_template_row.duplicate() as VBoxContainer
		if i > 0:
			guest_type_row_container.add_child(row)

		var body_type: int = body_types[i]
		var entry: Dictionary = stats[body_type]
		var amount: int = entry.count
		var avg_mood: float = entry.avg_mood
		var archetype = NPCArchetypeLibrary.get_archetype(body_type)

		var amount_label := row.get_node("Amount_Label") as Label
		var icon_rect := row.get_node("Icon_TextureRect") as TextureRect
		var mood_label := row.get_node("Mood_Label") as Label
		amount_label.text = str(amount)
		icon_rect.texture = archetype.icon if archetype.icon != null else GUEST_TYPE_FALLBACK_ICON
		mood_label.text = "%d%%" % roundi(avg_mood * 100)
		mood_label.add_theme_color_override("font_color", Color.GREEN.lerp(Color.RED, 1.0 - avg_mood))
		row.tooltip_text = "%s x%d, Mood %d%%" % [archetype.display_name, amount, roundi(avg_mood * 100)]
		row.show()

func _clear_guest_type_rows() -> void:
	for i in range(guest_type_row_container.get_child_count() - 1, -1, -1):
		var child := guest_type_row_container.get_child(i)
		if child == guest_type_template_row:
			continue
		guest_type_row_container.remove_child(child)
		child.queue_free()

## Foldout showing each guest archetype's current chance to be picked for
## the next spawn (see NPCLookInfo.get_spawn_chance_percentages()) - unlike
## the guest-type breakdown above, this reflects odds, not live guest
## counts, so it's shown even with zero guests on the floor.
func _update_spawn_chance_breakdown() -> void:
	var percentages := NPCLookInfo.get_spawn_chance_percentages()
	var signature := _build_spawn_chance_signature(percentages)
	if signature != _spawn_chance_signature:
		_spawn_chance_signature = signature
		_apply_spawn_chance_percentages(percentages)
	_update_spawn_chance_visibility()

func _build_spawn_chance_signature(percentages: Dictionary) -> Array:
	var body_types: Array = percentages.keys()
	body_types.sort()
	var signature: Array = []
	for body_type in body_types:
		signature.append("%d:%.1f" % [body_type, percentages[body_type]])
	return signature

func _apply_spawn_chance_percentages(percentages: Dictionary) -> void:
	_clear_spawn_chance_rows()

	var body_types: Array = percentages.keys()
	body_types.sort()

	for i in body_types.size():
		var row := spawn_chance_template_row if i == 0 else spawn_chance_template_row.duplicate() as HBoxContainer
		if i > 0:
			spawn_chance_row_container.add_child(row)

		var body_type: int = body_types[i]
		var percent: float = percentages[body_type]
		var archetype = NPCArchetypeLibrary.get_archetype(body_type)

		var icon_rect := row.get_node("Icon_TextureRect") as TextureRect
		var name_label := row.get_node("Name_Label") as Label
		var percent_label := row.get_node("Percent_Label") as Label
		icon_rect.texture = archetype.icon if archetype.icon != null else GUEST_TYPE_FALLBACK_ICON
		name_label.text = archetype.display_name
		percent_label.text = "%d%%" % roundi(percent)
		row.show()

func _clear_spawn_chance_rows() -> void:
	for i in range(spawn_chance_row_container.get_child_count() - 1, -1, -1):
		var child := spawn_chance_row_container.get_child(i)
		if child == spawn_chance_template_row:
			continue
		spawn_chance_row_container.remove_child(child)
		child.queue_free()

func _update_spawn_chance_visibility() -> void:
	var has_rows := spawn_chance_row_container.get_child_count() > 0
	button_spawn_chance_foldout.visible = has_rows
	button_spawn_chance_foldout.text = "v" if _is_spawn_chance_expanded else ">"
	var show_breakdown := has_rows and _is_spawn_chance_expanded
	spawn_chance_panel.visible = show_breakdown
	spawn_chance_row_container.visible = show_breakdown

func _on_spawn_chance_foldout_pressed() -> void:
	if spawn_chance_row_container.get_child_count() == 0:
		return
	_is_spawn_chance_expanded = not _is_spawn_chance_expanded
	_update_spawn_chance_visibility()
