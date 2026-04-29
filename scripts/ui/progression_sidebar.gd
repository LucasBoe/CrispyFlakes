extends Control

signal buy_feedback_requested(item: ProgressionItem, reason: String)

@onready var _item_name:    Label        = $Margin/VBox/ItemName
@onready var _item_cost:    Label        = $Margin/VBox/ItemCost
@onready var _room_section:  VBoxContainer    = $Margin/VBox/RoomSection
@onready var _room_preview:  TextureRect      = $Margin/VBox/RoomSection/RoomPreview
@onready var _room_name:     Label            = $Margin/VBox/RoomSection/RoomName
@onready var _room_desc:     Label            = $Margin/VBox/RoomSection/RoomDesc
@onready var _room_recipe = $Margin/VBox/RoomSection/RoomRecipeDisplay
@onready var _panel_content: Control    = $Margin
@onready var _buy_button = $Margin/VBox/BuyButton
@onready var _buy_content: Control      = $Margin/VBox/BuyButton/MarginContainer
@onready var _buy_label:    Label        = $Margin/VBox/BuyButton/MarginContainer/MarginContainer/Label

var _current_item: ProgressionItem = null
var _content_tween: Tween
var _buy_feedback_tween: Tween
var _buy_content_rest_position := Vector2.ZERO

func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_pressed)
	ProgressionHandler.item_unlocked.connect(func(_i): _refresh_buy_button())
	ProgressionHandler.points_changed.connect(func(_p): _refresh_buy_button())
	_buy_content_rest_position = _buy_content.position
	hide()

func on_item_selected(item: ProgressionItem) -> void:
	var was_visible := visible
	var switching_items := was_visible and _current_item != null and item != null and _current_item != item
	_current_item = item
	if item == null:
		hide()
		return

	show()
	_apply_item_content(item)
	_refresh_buy_button()
	if not was_visible or switching_items:
		_play_content_transition()

func _apply_item_content(item: ProgressionItem) -> void:
	_item_name.text = item.display_name
	_item_cost.text = "%d pts" % item.cost

	var preview_data = null
	if item.unlocks_room != null:
		preview_data = item.unlocks_room
	elif item.unlocks_infrastructure != null:
		preview_data = item.unlocks_infrastructure

	if preview_data != null:
		_room_section.show()
		_room_preview.texture = preview_data.room_preview
		_room_name.text = preview_data.room_name
		_room_desc.text = preview_data.room_desc
		if item.unlocks_room != null:
			_room_recipe.show_for_data(item.unlocks_room)
		else:
			_room_recipe.hide()
	else:
		_room_section.hide()

func _refresh_buy_button() -> void:
	if _current_item == null:
		return
	var owned := ProgressionHandler.is_item_unlocked(_current_item)
	var dep_met := _current_item.depends_on == null or ProgressionHandler.is_item_unlocked(_current_item.depends_on)
	var can_afford := ProgressionHandler.get_points() >= _current_item.cost
	var label_text: String
	if owned:
		label_text = "Owned"
	elif not dep_met:
		label_text = "Missing prereq"
	elif not can_afford:
		label_text = "Need %d pts" % (_current_item.cost - ProgressionHandler.get_points())
	else:
		label_text = "Buy (%d pts)" % _current_item.cost

	_buy_button.disabled = owned
	_buy_content.visible = true
	_buy_button.text = ""
	_buy_label.text = label_text
	_buy_button.fit_to_content()
	_buy_button.call_deferred("fit_to_content")

func _on_buy_pressed() -> void:
	if _current_item == null:
		return
	var dep_met := _current_item.depends_on == null or ProgressionHandler.is_item_unlocked(_current_item.depends_on)
	if not dep_met:
		_play_buy_feedback(Color(1.0, 0.75, 0.75, 1.0))
		buy_feedback_requested.emit(_current_item, "dependency")
		return
	if ProgressionHandler.get_points() < _current_item.cost:
		_play_buy_feedback(Color(1.0, 0.65, 0.65, 1.0))
		buy_feedback_requested.emit(_current_item, "points")
		return

	_play_buy_press()
	ProgressionHandler.try_unlock(_current_item)

func _play_content_transition() -> void:
	if _content_tween != null:
		_content_tween.kill()
	_panel_content.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(_panel_content, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_content_tween = tween

func _play_buy_press() -> void:
	if _buy_feedback_tween != null:
		_buy_feedback_tween.kill()
	_buy_content.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(_buy_content, "scale", Vector2(1.06, 0.94), 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_buy_content, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_buy_feedback_tween = tween

func _play_buy_feedback(tint: Color) -> void:
	if _buy_feedback_tween != null:
		_buy_feedback_tween.kill()
	_buy_content.position = _buy_content_rest_position
	_buy_content.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_buy_content, "position:x", _buy_content_rest_position.x - 2.0, 0.03)
	tween.parallel().tween_property(_buy_content, "modulate", tint, 0.05)
	tween.tween_property(_buy_content, "position:x", _buy_content_rest_position.x + 2.0, 0.03)
	tween.tween_property(_buy_content, "position:x", _buy_content_rest_position.x - 1.0, 0.02)
	tween.tween_property(_buy_content, "position:x", _buy_content_rest_position.x, 0.02)
	tween.tween_property(_buy_content, "modulate", Color.WHITE, 0.08)
	_buy_feedback_tween = tween
