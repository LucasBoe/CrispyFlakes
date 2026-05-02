extends Control
class_name UITutorial

const TUTORIAL_DOT_OFF = preload("res://assets/sprites/ui/2x/tutorial_dot_off.png")
const TUTORIAL_DOT_SELECTED = preload("res://assets/sprites/ui/2x/tutorial_dot_selected.png")
const TUTORIAL_DOT_GLOW = preload("res://assets/sprites/ui/2x/tutorial_dot_glow.png")
const TODO_CHECKED = preload("res://assets/sprites/ui/tutorial_todo_checked.png")
const TODO_UNCHECKED = preload("res://assets/sprites/ui/tutorial_todo_unchecked.png")
const REVEALED_MARKER_TEXTURE = preload("res://assets/sprites/ui/exclamation_mark.png")
const GOLDEN_GLOW_SHADER = preload("res://assets/shaders/golden_glow_red_replace.gdshader")
const REWARD_TINT = Color(1.0, 0.92, 0.25, 1.0)
const HINT_TINT = Color(0.92, 0.92, 0.92, 1.0)
const CONNECTOR_HEIGHT := 2.0
const REVEAL_FLY_DURATION := 0.35
const REVEAL_FLY_SCALE := Vector2(0.6, 0.6)
const SUMMARY_LABEL_GAP := 8.0

@export var reward_text := "30 $ Reward"
@export var start_expanded := true

@onready var _bubble_sidebar: VFlowContainer = %BubbleSidebar
@onready var _bubble_template: Button = %BubbleTemplate
@onready var _quest_window: Control = %QuestWindow
@onready var _section_label: Label = %SectionLabel
@onready var _task_icon: TextureRect = %TaskIcon
@onready var _task_label: Label = %TaskLabel
@onready var _hints_container: VBoxContainer = %HintsContainer
@onready var _reward_label: Label = %RewardLabel
@onready var _claim_reward_button: Button = %ClaimRewardButton

var _hint_rows: Array[Control] = []
var _bubble_instances: Array[Button] = []
var _selected_section_title := ""
var _sidebar_quests: Array = []
var _is_expanded := true
var _revealed_marker_instances := {}
var _hovered_section_title := ""
var _glowing_active_sections := {}
var _sections_animating_into_sidebar := {}
var _shared_golden_glow_material: ShaderMaterial
var _bubble_base_minimum_size := Vector2.ZERO


func _ready() -> void:
	_shared_golden_glow_material = ShaderMaterial.new()
	_shared_golden_glow_material.shader = GOLDEN_GLOW_SHADER
	_is_expanded = start_expanded
	_reward_label.self_modulate = REWARD_TINT
	_bubble_base_minimum_size = _bubble_template.custom_minimum_size
	_bubble_template.hide()
	_claim_reward_button.pressed.connect(_on_claim_reward_pressed)
	resized.connect(_update_layout)

	var refresh_callable := Callable(self, "refresh_ui")
	if not TutorialHandler.quests_changed.is_connected(refresh_callable):
		TutorialHandler.quests_changed.connect(refresh_callable)

	refresh_ui()
	call_deferred("_update_layout")

func _exit_tree() -> void:
	_clear_revealed_markers()


func refresh_ui() -> void:
	_prune_bubble_state()
	_rebuild_revealed_markers()
	_sidebar_quests = TutorialHandler.get_sidebar_quests()
	_rebuild_bubbles()

	if _sidebar_quests.is_empty():
		_selected_section_title = ""
		_clear_hint_rows()
		hide()
		return

	show()
	_ensure_selected_section()
	_refresh_selected_section_content()
	_apply_bubble_states()
	_apply_expanded_state()
	call_deferred("_update_layout")


func _ensure_selected_section() -> void:
	for quest in _sidebar_quests:
		if quest.section_title == _selected_section_title:
			return

	var preferred_quest = TutorialHandler.get_current_quest()
	if preferred_quest != null:
		for quest in _sidebar_quests:
			if quest == preferred_quest:
				_selected_section_title = preferred_quest.section_title
				return

	_selected_section_title = _sidebar_quests[0].section_title


func _rebuild_bubbles() -> void:
	_clear_bubbles()

	for tutorial_index in range(_sidebar_quests.size()):
		var quest = _sidebar_quests[tutorial_index]
		var bubble := _bubble_template.duplicate() as Button
		bubble.name = "Bubble_%d" % tutorial_index
		bubble.show()
		bubble.tooltip_text = quest.section_title

		var icon := bubble.get_node("BubbleIcon") as TextureRect
		var state_icon := bubble.get_node("BubbleStateIcon") as TextureRect
		var connector := bubble.get_node_or_null("BubbleConnector") as ColorRect
		var summary_label := _ensure_bubble_summary_label(bubble)

		icon.visible = true
		icon.texture = TUTORIAL_DOT_OFF
		icon.self_modulate = Color.WHITE
		icon.material = _shared_golden_glow_material
		state_icon.visible = true
		_layout_bubble_visuals(icon, state_icon, summary_label)
		if connector != null:
			connector.visible = false

		bubble.mouse_entered.connect(_on_bubble_mouse_entered.bind(quest.section_title))
		bubble.mouse_exited.connect(_on_bubble_mouse_exited.bind(quest.section_title))
		bubble.pressed.connect(_on_bubble_pressed.bind(quest.section_title))
		_bubble_sidebar.add_child(bubble)
		_bubble_instances.append(bubble)

func _rebuild_revealed_markers() -> void:
	_clear_revealed_markers()

	for quest in TutorialHandler.get_revealed_quests():
		var marker = UiNotifications.create_npc_action_button(
			quest.reveal_target,
			REVEALED_MARKER_TEXTURE,
			Callable(self, "_on_revealed_marker_pressed").bind(quest.section_title),
			true,
			Vector2(0, -30)
		)
		if marker != null and marker.instance is CanvasItem:
			(marker.instance as CanvasItem).material = _shared_golden_glow_material
		_revealed_marker_instances[quest.section_title] = marker

func _clear_revealed_markers() -> void:
	for section_title in _revealed_marker_instances.keys().duplicate():
		if _sections_animating_into_sidebar.has(section_title):
			continue
		UiNotifications.try_kill(_revealed_marker_instances[section_title])
		_revealed_marker_instances.erase(section_title)


func _clear_bubbles() -> void:
	for bubble in _bubble_instances:
		bubble.queue_free()
	_bubble_instances.clear()


func _on_bubble_pressed(section_title: String) -> void:
	var quest = TutorialHandler.get_quest(section_title)
	if quest == null:
		return

	var will_reveal_details := _selected_section_title != section_title or not _is_expanded
	if will_reveal_details:
		_glowing_active_sections.erase(section_title)

	if _selected_section_title == section_title:
		_is_expanded = not _is_expanded
	else:
		_selected_section_title = section_title
		_is_expanded = true

	_refresh_selected_section_content()
	_apply_bubble_states()
	_apply_expanded_state()
	call_deferred("_update_layout")

func _on_revealed_marker_pressed(section_title: String) -> void:
	var quest = TutorialHandler.get_quest(section_title)
	if quest == null:
		return
	if _sections_animating_into_sidebar.has(section_title):
		return

	var marker = _revealed_marker_instances.get(section_title)
	if marker != null:
		marker.target_object = null
		if marker.instance is Control:
			(marker.instance as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	_selected_section_title = section_title
	_is_expanded = false
	_glowing_active_sections[section_title] = true
	_sections_animating_into_sidebar[section_title] = true
	TutorialHandler.activate_quest(quest)
	await _play_revealed_marker_flight(section_title)

func _on_bubble_mouse_entered(section_title: String) -> void:
	_hovered_section_title = section_title
	_apply_bubble_states()

func _on_bubble_mouse_exited(section_title: String) -> void:
	if _hovered_section_title == section_title:
		_hovered_section_title = ""
	_apply_bubble_states()


func _refresh_selected_section_content() -> void:
	_clear_hint_rows()

	var quest = TutorialHandler.get_quest(_selected_section_title)
	if quest == null:
		return

	_section_label.text = "\"%s\"" % quest.section_title
	_task_label.text = quest.text
	_task_icon.texture = _get_task_icon_texture(quest)

	var display_hints := _get_display_hints(quest)
	_hints_container.visible = not display_hints.is_empty()
	for hint_index in range(display_hints.size()):
		var row := _create_hint_row(hint_index + 1, display_hints[hint_index])
		_hints_container.add_child(row)
		_hint_rows.append(row)

	var quest_reward_text := TutorialHandler.get_quest_reward_text(quest)
	if quest_reward_text.is_empty():
		quest_reward_text = reward_text

	_reward_label.visible = not quest_reward_text.is_empty()
	_reward_label.text = quest_reward_text
	_claim_reward_button.visible = quest.phase == TutorialHandler.TutorialPhase.COMPLETED


func _get_task_icon_texture(quest) -> Texture2D:
	if quest.phase == TutorialHandler.TutorialPhase.COMPLETED:
		return TODO_CHECKED
	if quest.is_done:
		return TODO_CHECKED
	return TODO_UNCHECKED


func _get_display_hints(quest) -> Array[String]:
	if quest == null:
		return []
	if quest != null and quest.phase == TutorialHandler.TutorialPhase.COMPLETED:
		return []

	return quest.hints.duplicate()


func _create_hint_row(step_number: int, hint: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var number_label := Label.new()
	number_label.text = "%d." % step_number
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	number_label.self_modulate = Color.WHITE
	_copy_label_style(number_label, _task_label, false)
	number_label.add_theme_font_size_override("font_size", int(max(_task_label.get_theme_font_size("font_size") - 1, 10)))
	row.add_child(number_label)

	var hint_label := Label.new()
	hint_label.text = hint
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_label.self_modulate = HINT_TINT
	_copy_label_style(hint_label, _task_label, true)
	hint_label.add_theme_font_size_override("font_size", int(max(_task_label.get_theme_font_size("font_size") - 1, 10)))
	row.add_child(hint_label)

	return row


func _copy_label_style(target: Label, reference: Label, use_theme: bool) -> void:
	if use_theme:
		target.theme = reference.theme

	var font := reference.get_theme_font("font")
	if font != null:
		target.add_theme_font_override("font", font)


func _ensure_bubble_summary_label(bubble: Button) -> Label:
	var summary_label := bubble.get_node_or_null("BubbleSummaryLabel") as Label
	if summary_label != null:
		return summary_label

	summary_label = Label.new()
	summary_label.name = "BubbleSummaryLabel"
	summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	summary_label.clip_text = false
	summary_label.self_modulate = Color.WHITE
	_copy_label_style(summary_label, _task_label, true)
	bubble.add_child(summary_label)
	return summary_label


func _layout_bubble_visuals(background_icon: TextureRect, state_icon: TextureRect, summary_label: Label) -> void:
	background_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	background_icon.position = Vector2.ZERO
	background_icon.size = _bubble_base_minimum_size

	var state_icon_size := state_icon.size
	if state_icon_size == Vector2.ZERO:
		state_icon_size = Vector2(
			state_icon.offset_right - state_icon.offset_left,
			state_icon.offset_bottom - state_icon.offset_top
		)
	if state_icon_size == Vector2.ZERO:
		state_icon_size = TODO_UNCHECKED.get_size()

	state_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	state_icon.size = state_icon_size
	state_icon.position = (_bubble_base_minimum_size - state_icon_size) * 0.5

	summary_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	summary_label.position = Vector2(_bubble_base_minimum_size.x + SUMMARY_LABEL_GAP, 0)
	summary_label.custom_minimum_size = Vector2.ZERO
	summary_label.size = Vector2(220, _bubble_base_minimum_size.y)


func _should_show_collapsed_summary(section_title: String) -> bool:
	return _selected_section_title == section_title and not _is_expanded


func _get_collapsed_summary_text(section_title: String) -> String:
	var quest = TutorialHandler.get_quest(section_title)
	if quest == null:
		return ""
	return quest.text


func _apply_bubble_states() -> void:
	for bubble_index in range(_bubble_instances.size()):
		var bubble := _bubble_instances[bubble_index]
		var quest = _sidebar_quests[bubble_index]
		var background_icon := bubble.get_node("BubbleIcon") as TextureRect
		var state_icon := bubble.get_node("BubbleStateIcon") as TextureRect
		var summary_label := _ensure_bubble_summary_label(bubble)
		var bubble_width := _bubble_base_minimum_size.x

		if _sections_animating_into_sidebar.has(quest.section_title):
			bubble.modulate = Color(1.0, 1.0, 1.0, 0.0)
			bubble.disabled = true
			summary_label.visible = false
			continue

		background_icon.texture = _get_bubble_dot_texture(quest.section_title, quest)
		state_icon.texture = _get_bubble_state_icon_texture(quest)
		state_icon.self_modulate = _get_bubble_state_icon_modulate(quest.section_title, quest)
		summary_label.text = _get_collapsed_summary_text(quest.section_title)
		summary_label.visible = _should_show_collapsed_summary(quest.section_title) and not summary_label.text.is_empty()
		if summary_label.visible:
			bubble_width += SUMMARY_LABEL_GAP + summary_label.get_combined_minimum_size().x

		bubble.custom_minimum_size = Vector2(bubble_width, _bubble_base_minimum_size.y)
		bubble.modulate = Color.WHITE
		bubble.disabled = false

func _get_bubble_dot_texture(section_title: String, quest) -> Texture2D:
	if _should_glow_bubble(section_title, quest):
		return TUTORIAL_DOT_GLOW
	if _is_bubble_highlighted(section_title):
		return TUTORIAL_DOT_SELECTED
	return TUTORIAL_DOT_OFF

func _get_bubble_state_icon_texture(quest) -> Texture2D:
	if quest.phase == TutorialHandler.TutorialPhase.COMPLETED:
		return TODO_CHECKED
	return TODO_UNCHECKED

func _get_bubble_state_icon_modulate(section_title: String, quest) -> Color:
	if _should_glow_bubble(section_title, quest):
		return Color.BLACK
	if _is_bubble_highlighted(section_title):
		return Color.BLACK
	return Color.WHITE

func _should_glow_bubble(section_title: String, quest) -> bool:
	if quest.phase == TutorialHandler.TutorialPhase.COMPLETED:
		return true
	return _glowing_active_sections.has(section_title)

func _is_bubble_highlighted(section_title: String) -> bool:
	if _hovered_section_title == section_title:
		return true
	return _selected_section_title == section_title and _quest_window.visible and _is_expanded

func _prune_bubble_state() -> void:
	if not _hovered_section_title.is_empty() and TutorialHandler.get_quest(_hovered_section_title) == null:
		_hovered_section_title = ""

	var valid_section_titles := {}
	for section_title in TutorialHandler.get_quest_titles():
		valid_section_titles[section_title] = true

	for section_title in _glowing_active_sections.keys():
		if not valid_section_titles.has(section_title):
			_glowing_active_sections.erase(section_title)

	for section_title in _sections_animating_into_sidebar.keys():
		if not valid_section_titles.has(section_title):
			_sections_animating_into_sidebar.erase(section_title)


func _apply_expanded_state() -> void:
	var quest = TutorialHandler.get_quest(_selected_section_title)
	var can_show_details: bool = quest != null and quest.phase != TutorialHandler.TutorialPhase.REVEALED
	_quest_window.visible = can_show_details and _is_expanded
	if not _quest_window.visible:
		_hide_all_bubble_connectors()


func _update_layout() -> void:
	if not is_inside_tree():
		return

	if not _quest_window.visible:
		_hide_all_bubble_connectors()
		return

	var selected_bubble := _get_selected_bubble()
	if selected_bubble == null:
		_hide_all_bubble_connectors()
		return

	var connector := _get_bubble_connector(selected_bubble)
	if connector == null:
		return

	_hide_all_bubble_connectors()

	connector.visible = true


func _get_selected_bubble() -> Button:
	for bubble_index in range(_sidebar_quests.size()):
		if _sidebar_quests[bubble_index].section_title == _selected_section_title:
			return _bubble_instances[bubble_index]
	return null


func _get_bubble_connector(bubble: Button) -> ColorRect:
	return bubble.get_node_or_null("BubbleConnector") as ColorRect


func _hide_all_bubble_connectors() -> void:
	for bubble in _bubble_instances:
		var connector := _get_bubble_connector(bubble)
		if connector != null:
			connector.visible = false


func _get_bubble_for_section(section_title: String) -> Button:
	for bubble_index in range(_sidebar_quests.size()):
		if _sidebar_quests[bubble_index].section_title == section_title:
			return _bubble_instances[bubble_index]
	return null


func _play_revealed_marker_flight(section_title: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var bubble := _get_bubble_for_section(section_title)
	var marker = _revealed_marker_instances.get(section_title)
	if bubble == null or marker == null or not (marker.instance is Control):
		_finish_revealed_marker_flight(section_title)
		return

	var target_center := bubble.get_global_rect().get_center()
	var flying_marker := marker.instance as Control
	var marker_size := flying_marker.size
	if marker_size == Vector2.ZERO:
		marker_size = REVEALED_MARKER_TEXTURE.get_size()
	var target_position_ui := target_center - (marker_size * REVEAL_FLY_SCALE) * 0.5
	var target_position_world := Util.ui_to_world_position(target_position_ui, self, Camera)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		flying_marker,
		"global_position",
		target_position_world,
		REVEAL_FLY_DURATION
	)
	tween.parallel().tween_property(flying_marker, "scale", REVEAL_FLY_SCALE, REVEAL_FLY_DURATION)
	await tween.finished

	_finish_revealed_marker_flight(section_title)


func _finish_revealed_marker_flight(section_title: String) -> void:
	var marker = _revealed_marker_instances.get(section_title)
	if marker != null:
		UiNotifications.try_kill(marker)
		_revealed_marker_instances.erase(section_title)

	_sections_animating_into_sidebar.erase(section_title)
	_apply_bubble_states()
	call_deferred("_update_layout")


func _on_claim_reward_pressed() -> void:
	if _selected_section_title.is_empty():
		return
	var quest = TutorialHandler.get_quest(_selected_section_title)
	if quest == null:
		return
	TutorialHandler.claim_quest_reward(quest)

func _on_ui_close() -> void:
	if not visible or not _quest_window.visible or not _is_expanded:
		return

	_is_expanded = false
	_apply_bubble_states()
	_apply_expanded_state()
	call_deferred("_update_layout")


func _clear_hint_rows() -> void:
	for row in _hint_rows:
		row.queue_free()
	_hint_rows.clear()
