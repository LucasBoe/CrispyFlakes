extends Control
class_name UIEncounter

signal choice_selected(choice: Dictionary)

const _PANEL_SCREEN_MARGIN := 8.0
const _NPC_LINE_OFFSET := Vector2(0, -24)
const _FOCUS_ZOOM := 4.0
const _FOCUS_OFFSET := Vector2(0, -16)
const _FOCUS_ZOOM_EPSILON := 0.05
const _TYPE_CHARACTER_DELAY := 0.016
const _TYPE_PUNCTUATION_DELAY := 0.045
const _BUTTON_REVEAL_DURATION := 0.12
const _FULLSCREEN_DARKEN_FADE_IN_DURATION := 0.28
const _FULLSCREEN_DARKEN_FADE_OUT_DURATION := 0.18
const _CHOICE_BRACKET_BLUE := "#5890f6"
const _CHOICE_MONEY_YELLOW := "#ffe432"
const _CHOICE_MONEY_RED := "#e64a4a"

@onready var root: MarginContainer = $MarginContainer
@onready var dialogue_label: RichTextLabel = %Container.get_node("RichTextLabel")
@onready var buttons: VBoxContainer = %Buttons
@onready var _button_template: Button = %Buttons.get_node("Button")
@onready var line: PixelLine = $MarginContainer/Control/LineAnchor/Line

var _target: Node2D = null
var _active := false
var _selected_choice: Dictionary = {}
var _front_npc: NPC = null
var _front_npc_previous_z_layer: int = Enum.ZLayer.NPC_DEFAULT

func _ready() -> void:
	hide()
	_button_template.hide()
	_clear_buttons()

func start_encounter(target: Node2D, encounter: Dictionary) -> Dictionary:
	if _active:
		return {}

	_active = true
	_target = target
	_selected_choice = {}

	_begin_encounter_presentation(target)
	if is_instance_valid(Camera) and Camera.has_method("push_focus_lock"):
		Camera.push_focus_lock(self, target, _FOCUS_ZOOM, _FOCUS_OFFSET)
	TimeHandler.push_pause_lock(self)
	await _await_focus_zoom()
	if not _active:
		return {}
	_update_position()
	show()
	await _display_text_and_choices(str(encounter.get("line", "")), encounter.get("choices", []))

	await choice_selected
	return _selected_choice

func show_outcome(target: Node2D, text: String) -> void:
	if not _active:
		_active = true
		_target = target
		_selected_choice = {}
		_begin_encounter_presentation(target)
		if is_instance_valid(Camera) and Camera.has_method("push_focus_lock"):
			Camera.push_focus_lock(self, target, _FOCUS_ZOOM, _FOCUS_OFFSET)
		TimeHandler.push_pause_lock(self)
	else:
		_target = target
		_promote_target_to_front(target)
	if not _active:
		return
	if visible:
		_update_position()
		show()
	else:
		await _await_focus_zoom()
		if not _active:
			return
		_update_position()
		show()
	await _display_text_and_choices(text, [{
		"text": "OK",
		"money_delta": 0,
	}])

	await choice_selected
	_close()


func close_encounter() -> void:
	if not _active:
		return
	_close()


func _await_focus_zoom() -> void:
	if not is_instance_valid(Camera):
		return
	while _active and absf(Camera.zoom.x - _FOCUS_ZOOM) > _FOCUS_ZOOM_EPSILON:
		await get_tree().process_frame

func is_active() -> bool:
	return _active

func _process(_delta: float) -> void:
	if _active:
		_update_position()
		_refresh_choice_button_margins()


func _display_text_and_choices(text: String, choices: Array) -> void:
	dialogue_label.text = text
	dialogue_label.visible_characters = 0
	_rebuild_buttons(choices)
	_set_buttons_revealed(false)
	await _play_typewriter_animation()
	if not _active:
		return
	await _reveal_buttons()

func _rebuild_buttons(choices: Array) -> void:
	_clear_buttons()
	for choice in choices:
		var button := _button_template.duplicate() as Button
		var plain_text := _get_choice_display_text(choice)
		button.show()
		button.text = plain_text
		_set_button_text_hidden(button)
		_set_choice_button_label(button, choice, plain_text)
		button.set_meta("choice_affordable", _is_choice_affordable(choice))
		button.pressed.connect(_on_choice_pressed.bind(choice))
		buttons.add_child(button)
		_refresh_choice_button_margin(button)

func _clear_buttons() -> void:
	if buttons == null:
		return
	for child in buttons.get_children():
		if child == _button_template:
			continue
		child.queue_free()

func _on_choice_pressed(choice: Dictionary) -> void:
	if not _is_choice_affordable(choice):
		return
	_apply_choice_money_delta(choice)
	_selected_choice = choice
	choice_selected.emit(choice)


func _set_buttons_revealed(revealed: bool) -> void:
	buttons.modulate = Color(1.0, 1.0, 1.0, 1.0 if revealed else 0.0)
	buttons.mouse_filter = Control.MOUSE_FILTER_PASS if revealed else Control.MOUSE_FILTER_IGNORE
	for child in buttons.get_children():
		if child == _button_template:
			continue
		if child is Button:
			var button := child as Button
			var affordable := bool(button.get_meta("choice_affordable", true))
			button.disabled = not revealed or not affordable


func _reveal_buttons() -> void:
	_set_buttons_revealed(false)
	var start_usec := Time.get_ticks_usec()
	while _active:
		var elapsed := maxf((Time.get_ticks_usec() - start_usec) / 1000000.0, 0.0)
		var progress := clampf(elapsed / _BUTTON_REVEAL_DURATION, 0.0, 1.0)
		buttons.modulate.a = progress
		if progress >= 1.0:
			break
		await get_tree().process_frame
	if _active:
		buttons.mouse_filter = Control.MOUSE_FILTER_PASS
		for child in buttons.get_children():
			if child == _button_template:
				continue
			if child is Button:
				var button := child as Button
				var affordable := bool(button.get_meta("choice_affordable", true))
				button.disabled = not affordable


func _play_typewriter_animation() -> void:
	var total_characters := dialogue_label.get_total_character_count()
	if total_characters <= 0:
		dialogue_label.visible_characters = -1
		return

	for char_index in range(1, total_characters + 1):
		if not _active:
			return
		dialogue_label.visible_characters = char_index
		var char_delay := _TYPE_CHARACTER_DELAY
		var revealed_text := dialogue_label.text
		if char_index - 1 < revealed_text.length():
			var current_char := revealed_text[char_index - 1]
			if current_char == "." or current_char == "!" or current_char == "?" or current_char == ",":
				char_delay += _TYPE_PUNCTUATION_DELAY
		await get_tree().create_timer(char_delay, true, false, true).timeout

	dialogue_label.visible_characters = -1

func _close() -> void:
	TimeHandler.pop_pause_lock(self)
	if is_instance_valid(Camera) and Camera.has_method("pop_focus_lock"):
		Camera.pop_focus_lock(self)
	_end_encounter_presentation()
	hide()
	buttons.modulate = Color.WHITE
	_clear_buttons()
	_target = null
	_active = false

func _update_position() -> void:
	if not is_instance_valid(_target):
		return

	var target_ui_position: Vector2 = Util.world_to_ui_position(_target.global_position + _NPC_LINE_OFFSET, self, Camera)
	var panel_size := root.size
	var viewport_size := get_viewport().get_visible_rect().size
	var desired_position: Vector2 = target_ui_position - Vector2(panel_size.x * 0.5, panel_size.y + 34.0)
	desired_position.x = clampf(desired_position.x, _PANEL_SCREEN_MARGIN, viewport_size.x - panel_size.x - _PANEL_SCREEN_MARGIN)
	desired_position.y = clampf(desired_position.y, _PANEL_SCREEN_MARGIN, viewport_size.y - panel_size.y - _PANEL_SCREEN_MARGIN)
	root.global_position = desired_position

	line.global_position = Vector2(
		clampf(target_ui_position.x, root.global_position.x + 8.0, root.global_position.x + panel_size.x - 8.0),
		root.global_position.y + panel_size.y
	)
	line.target_position = target_ui_position

func _begin_encounter_presentation(target: Node2D) -> void:
	_promote_target_to_front(target)
	var environment: Node = _get_environment_handler()
	if environment != null and environment.has_method("fade_fullscreen_darken_in"):
		environment.fade_fullscreen_darken_in(_FULLSCREEN_DARKEN_FADE_IN_DURATION)

func _end_encounter_presentation() -> void:
	var environment: Node = _get_environment_handler()
	if environment != null and environment.has_method("fade_fullscreen_darken_out"):
		environment.fade_fullscreen_darken_out(_FULLSCREEN_DARKEN_FADE_OUT_DURATION)
	_restore_target_z_layer()

func _promote_target_to_front(target: Node2D) -> void:
	if target == _front_npc:
		return
	_restore_target_z_layer()
	var npc_target := target as NPC
	if npc_target == null or npc_target.Animator == null:
		return
	_front_npc = npc_target
	_front_npc_previous_z_layer = npc_target.Animator.z_index
	npc_target.Animator.set_z(Enum.ZLayer.NPC_DRAGGED)

func _restore_target_z_layer() -> void:
	if is_instance_valid(_front_npc) and _front_npc.Animator != null:
		_front_npc.Animator.set_z(_front_npc_previous_z_layer)
	_front_npc = null
	_front_npc_previous_z_layer = Enum.ZLayer.NPC_DEFAULT

func _get_environment_handler() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	return current_scene.get_node_or_null("Environment")

func _get_choice_display_text(choice: Dictionary) -> String:
	var text := str(choice.get("text", ""))
	var money_delta := int(choice.get("money_delta", 0))
	if money_delta == 0:
		return text
	if text.contains("$"):
		return text
	return "%s (%s)" % [text, _format_money_delta_label(money_delta)]

func _set_button_text_hidden(button: Button) -> void:
	var invisible := Color(1.0, 1.0, 1.0, 0.0)
	button.add_theme_color_override("font_color", invisible)
	button.add_theme_color_override("font_focus_color", invisible)
	button.add_theme_color_override("font_hover_color", invisible)
	button.add_theme_color_override("font_hover_pressed_color", invisible)
	button.add_theme_color_override("font_pressed_color", invisible)
	button.add_theme_color_override("font_disabled_color", invisible)

func _set_choice_button_label(button: Button, choice: Dictionary, plain_text: String) -> void:
	var label := button.get_node_or_null("ContentMargin/ChoiceLabel") as RichTextLabel
	if label == null:
		return
	label.text = "[center]%s[/center]" % _format_choice_label_text(choice, plain_text)
	label.tooltip_text = plain_text

func _refresh_choice_button_margins() -> void:
	for child in buttons.get_children():
		if child == _button_template:
			continue
		if child is Button:
			_refresh_choice_button_margin(child as Button)

func _refresh_choice_button_margin(button: Button) -> void:
	var content_margin := button.get_node_or_null("ContentMargin") as MarginContainer
	if content_margin == null:
		return
	var style_name := _get_button_margin_style_name(button)
	var stylebox := button.get_theme_stylebox(style_name)
	if stylebox == null and style_name != "normal":
		stylebox = button.get_theme_stylebox("normal")
	if stylebox == null:
		return
	content_margin.add_theme_constant_override("margin_left", int(stylebox.get_content_margin(SIDE_LEFT)))
	content_margin.add_theme_constant_override("margin_top", int(stylebox.get_content_margin(SIDE_TOP)))
	content_margin.add_theme_constant_override("margin_right", int(stylebox.get_content_margin(SIDE_RIGHT)))
	content_margin.add_theme_constant_override("margin_bottom", int(stylebox.get_content_margin(SIDE_BOTTOM)))

func _get_button_margin_style_name(button: Button) -> String:
	match button.get_draw_mode():
		BaseButton.DRAW_HOVER:
			return "hover"
		BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED:
			return "pressed"
		BaseButton.DRAW_DISABLED:
			return "disabled"
		_:
			return "normal"

func _format_choice_label_text(choice: Dictionary, text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\(([^)]*)\\)")
	var result := ""
	var last_end := 0
	var money_color := _get_choice_money_color(choice)
	for match in regex.search_all(text):
		var start := match.get_start()
		var end := match.get_end()
		result += _format_inline_money_tokens(text.substr(last_end, start - last_end), money_color)
		var bracket_content := match.get_string(1)
		var color := money_color if _is_money_bracket_content(bracket_content) else _CHOICE_BRACKET_BLUE
		result += "[color=%s](%s)[/color]" % [color, bracket_content]
		last_end = end
	result += _format_inline_money_tokens(text.substr(last_end), money_color)
	return result

func _is_money_bracket_content(text: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[-+]?\\d+\\$\\??$")
	return regex.search(text.strip_edges()) != null

func _format_inline_money_tokens(text: String, money_color: String) -> String:
	var regex := RegEx.new()
	regex.compile("[-+]?\\d+\\$\\??")
	var result := ""
	var last_end := 0
	for match in regex.search_all(text):
		var start := match.get_start()
		var end := match.get_end()
		result += text.substr(last_end, start - last_end)
		result += "[color=%s]%s[/color]" % [money_color, match.get_string()]
		last_end = end
	result += text.substr(last_end)
	return result

func _format_money_delta_label(money_delta: int) -> String:
	return "%+d$" % money_delta

func _is_choice_affordable(choice: Dictionary) -> bool:
	var money_delta := int(choice.get("money_delta", 0))
	if money_delta >= 0:
		return true
	return ResourceHandler.has_money(abs(money_delta))

func _get_choice_money_color(choice: Dictionary) -> String:
	return _CHOICE_MONEY_YELLOW if _is_choice_affordable(choice) else _CHOICE_MONEY_RED

func _apply_choice_money_delta(choice: Dictionary) -> void:
	var money_delta := int(choice.get("money_delta", 0))
	if money_delta == 0 or not is_instance_valid(_target):
		return
	var effect_position := _target.global_position + Vector2(0, -20)
	if money_delta > 0:
		ResourceHandler.add_animated(Enum.Resources.MONEY, money_delta, effect_position)
	else:
		ResourceHandler.spend_animated(abs(money_delta), effect_position)
