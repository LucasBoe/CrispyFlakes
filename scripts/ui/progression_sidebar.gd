extends Control

signal dependency_requested_signal(item: ProgressionItem)

@onready var _item_name: Label = $Margin/VBox/ItemName
@onready var _item_cost: Label = $Margin/VBox/ItemCost
@onready var _room_section: VBoxContainer = $Margin/VBox/RoomScroll/RoomSection
@onready var _group_description: Label = $Margin/VBox/RoomScroll/RoomSection/GroupDescription
@onready var _entry_dummy: Control = $Margin/VBox/RoomScroll/RoomSection/EntryDummy
@onready var _panel_content: Control = $Margin
@onready var _status_button = $Margin/VBox/BuyButton
@onready var _status_content: Control = $Margin/VBox/BuyButton/MarginContainer
@onready var _status_label: Label = $Margin/VBox/BuyButton/MarginContainer/MarginContainer/Label

var _current_item: ProgressionItem = null
var _content_tween: Tween
var _entry_sections: Array[Control] = []

func _ready() -> void:
	_status_button.pressed.connect(_on_status_pressed)
	ProgressionHandler.item_unlocked_signal.connect(func(_item): _refresh_status_button())
	ProgressionHandler.item_completed_signal.connect(func(_item): _refresh_status_button())
	_group_description.hide()
	_entry_dummy.hide()
	hide()

func _process(_delta: float) -> void:
	if _current_item == null or not visible:
		return
	_item_cost.text = "%d / %d built" % [
		ProgressionHandler.get_item_completed_content_count(_current_item),
		ProgressionHandler.get_item_total_content_count(_current_item),
	]
	_refresh_status_button()

func on_item_selected(item: ProgressionItem) -> void:
	var was_visible := visible
	var switching_items := was_visible and _current_item != null and item != null and _current_item != item
	_current_item = item
	if item == null or not ProgressionHandler.is_item_revealed(item):
		hide()
		return

	show()
	_apply_item_content(item)
	_refresh_status_button()
	if not was_visible or switching_items:
		_play_content_transition()

func _apply_item_content(item: ProgressionItem) -> void:
	_item_name.text = item.display_name
	_item_cost.text = "%d / %d built" % [
		ProgressionHandler.get_item_completed_content_count(item),
		ProgressionHandler.get_item_total_content_count(item),
	]
	_item_cost.visible = true

	_apply_room_sections(item)
	_room_section.show()

func _apply_room_sections(item: ProgressionItem) -> void:
	_group_description.text = _build_group_description(item)
	_group_description.visible = _group_description.text != ""

	var all_content: Array = []
	for room in item.get_unlocked_rooms():
		all_content.append(room)
	for data in item.get_unlocked_infrastructure():
		all_content.append(data)

	_ensure_entry_count(all_content.size())
	for i in range(_entry_sections.size()):
		if i < all_content.size():
			_apply_data_to_entry(_entry_sections[i], all_content[i], i == all_content.size() - 1)
		else:
			_entry_sections[i].hide()

func _ensure_entry_count(required_count: int) -> void:
	while _entry_sections.size() < required_count:
		var entry := _entry_dummy.duplicate()
		entry.name = "Entry%d" % (_entry_sections.size() + 1)
		entry.visible = true
		_room_section.add_child(entry)
		_room_section.move_child(entry, _group_description.get_index() + 1 + _entry_sections.size())
		_entry_sections.append(entry)

func _apply_data_to_entry(entry: Control, data, is_last: bool) -> void:
	entry.show()
	var info_display := entry.get_node("RoomInfoDisplay") as RoomInfoDisplay
	info_display.show_for(data, true, ProgressionHandler.is_content_built(data))
	entry.get_node("Divider").visible = not is_last

func _refresh_status_button() -> void:
	if _current_item == null:
		return

	var label_text := ""
	var missing_requirements := ProgressionHandler.get_missing_requirements(_current_item)
	var missing_requirement := missing_requirements[0] if not missing_requirements.is_empty() else null
	if ProgressionHandler.is_item_completed(_current_item):
		label_text = "Completed"
		_status_button.disabled = true
	elif ProgressionHandler.is_item_unlocked(_current_item):
		label_text = "Build all rooms in this group"
		_status_button.disabled = true
	elif missing_requirement != null:
		if missing_requirements.size() > 1:
			label_text = "Requires %s +%d" % [missing_requirement.display_name, missing_requirements.size() - 1]
		else:
			label_text = "Requires %s" % missing_requirement.display_name
		_status_button.disabled = false
	else:
		label_text = "Locked"
		_status_button.disabled = true

	_status_content.visible = true
	_status_button.text = ""
	var needs_refit := _status_label.text != label_text
	_status_label.text = label_text
	if needs_refit:
		_status_button.fit_to_content()
		_status_button.call_deferred("fit_to_content")

func _on_status_pressed() -> void:
	if _current_item == null:
		return
	var missing_requirement := ProgressionHandler.get_primary_missing_requirement(_current_item)
	if missing_requirement != null:
		SoundPlayer.play_ui_click_down()
		dependency_requested_signal.emit(missing_requirement)

func _build_group_description(item: ProgressionItem) -> String:
	var lines: Array[String] = []
	if item.description != "":
		lines.append(item.description)

	var requirements := ProgressionHandler.get_missing_requirements(item)
	if not requirements.is_empty():
		var requirement_names: Array[String] = []
		for requirement in requirements:
			requirement_names.append(requirement.display_name)
		lines.append("Needs: %s" % ", ".join(requirement_names))

	return "\n".join(lines)

func _play_content_transition() -> void:
	if _content_tween != null:
		_content_tween.kill()
	_panel_content.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(_panel_content, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_content_tween = tween
