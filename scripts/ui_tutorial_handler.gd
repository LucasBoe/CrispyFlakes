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
var _sidebar_tutorials: Array = []
var _is_expanded := true
var _revealed_marker_instances := {}
var _hovered_section_title := ""
var _glowing_active_sections := {}
var _shared_golden_glow_material: ShaderMaterial


func _ready() -> void:
	_shared_golden_glow_material = ShaderMaterial.new()
	_shared_golden_glow_material.shader = GOLDEN_GLOW_SHADER
	_is_expanded = start_expanded
	_reward_label.self_modulate = REWARD_TINT
	_bubble_template.hide()
	_claim_reward_button.pressed.connect(_on_claim_reward_pressed)
	resized.connect(_update_layout)

	var refresh_callable := Callable(self, "refresh_ui")
	if not TutorialHandler.tasks_changed.is_connected(refresh_callable):
		TutorialHandler.tasks_changed.connect(refresh_callable)

	refresh_ui()
	call_deferred("_update_layout")

func _exit_tree() -> void:
	_clear_revealed_markers()


func refresh_ui() -> void:
	_prune_bubble_state()
	_rebuild_revealed_markers()
	_sidebar_tutorials = TutorialHandler.get_sidebar_tutorials()
	_rebuild_bubbles()

	if _sidebar_tutorials.is_empty():
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
	for tutorial in _sidebar_tutorials:
		if tutorial.section_title == _selected_section_title:
			return

	var preferred_section := TutorialHandler.get_current_section_title()
	for tutorial in _sidebar_tutorials:
		if tutorial.section_title == preferred_section:
			_selected_section_title = preferred_section
			return

	_selected_section_title = _sidebar_tutorials[0].section_title


func _rebuild_bubbles() -> void:
	_clear_bubbles()

	for tutorial_index in range(_sidebar_tutorials.size()):
		var tutorial = _sidebar_tutorials[tutorial_index]
		var bubble := _bubble_template.duplicate() as Button
		bubble.name = "Bubble_%d" % tutorial_index
		bubble.show()
		bubble.tooltip_text = tutorial.section_title

		var icon := bubble.get_node("BubbleIcon") as TextureRect
		var state_icon := bubble.get_node("BubbleStateIcon") as TextureRect
		var connector := bubble.get_node_or_null("BubbleConnector") as ColorRect

		icon.visible = true
		icon.texture = TUTORIAL_DOT_OFF
		icon.self_modulate = Color.WHITE
		icon.material = _shared_golden_glow_material
		state_icon.visible = true
		if connector != null:
			connector.visible = false

		bubble.mouse_entered.connect(_on_bubble_mouse_entered.bind(tutorial.section_title))
		bubble.mouse_exited.connect(_on_bubble_mouse_exited.bind(tutorial.section_title))
		bubble.pressed.connect(_on_bubble_pressed.bind(tutorial.section_title))
		_bubble_sidebar.add_child(bubble)
		_bubble_instances.append(bubble)

func _rebuild_revealed_markers() -> void:
	_clear_revealed_markers()

	for tutorial in TutorialHandler.get_revealed_tutorials():
		var marker = UiNotifications.create_npc_action_button(
			tutorial.reveal_target,
			REVEALED_MARKER_TEXTURE,
			Callable(self, "_on_revealed_marker_pressed").bind(tutorial.section_title),
			true,
			Vector2(0, -30)
		)
		if marker != null and marker.instance is CanvasItem:
			(marker.instance as CanvasItem).material = _shared_golden_glow_material
		_revealed_marker_instances[tutorial.section_title] = marker

func _clear_revealed_markers() -> void:
	for marker in _revealed_marker_instances.values():
		UiNotifications.try_kill(marker)
	_revealed_marker_instances.clear()


func _clear_bubbles() -> void:
	for bubble in _bubble_instances:
		bubble.queue_free()
	_bubble_instances.clear()


func _on_bubble_pressed(section_title: String) -> void:
	var tutorial = TutorialHandler.get_tutorial(section_title)
	if tutorial == null:
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
	_selected_section_title = section_title
	_is_expanded = false
	_glowing_active_sections[section_title] = true
	TutorialHandler._activate_tutorial(section_title)

func _on_bubble_mouse_entered(section_title: String) -> void:
	_hovered_section_title = section_title
	_apply_bubble_states()

func _on_bubble_mouse_exited(section_title: String) -> void:
	if _hovered_section_title == section_title:
		_hovered_section_title = ""
	_apply_bubble_states()


func _refresh_selected_section_content() -> void:
	_clear_hint_rows()

	var tutorial = TutorialHandler.get_tutorial(_selected_section_title)
	if tutorial == null:
		return

	var display_tasks := _get_display_tasks(tutorial.section_title)
	var primary_task = _get_primary_display_task(display_tasks)

	_section_label.text = "\"%s\"" % tutorial.section_title
	_task_label.text = "" if primary_task == null else primary_task.text
	_task_icon.texture = _get_task_icon_texture(tutorial, primary_task)

	var display_hints := _get_display_hints(primary_task, display_tasks)
	_hints_container.visible = not display_hints.is_empty()
	for hint_index in range(display_hints.size()):
		var row := _create_hint_row(hint_index + 1, display_hints[hint_index])
		_hints_container.add_child(row)
		_hint_rows.append(row)

	var tutorial_reward_text := TutorialHandler.get_tutorial_reward_text(tutorial.section_title)
	if tutorial_reward_text.is_empty():
		tutorial_reward_text = reward_text

	_reward_label.visible = not tutorial_reward_text.is_empty()
	_reward_label.text = tutorial_reward_text
	_claim_reward_button.visible = tutorial.phase == TutorialHandler.TutorialPhase.COMPLETED


func _get_display_tasks(section_title: String) -> Array:
	var active_tasks := TutorialHandler.get_section_tasks(section_title).filter(
		func(task): return task.is_started and not task.is_done
	)
	if not active_tasks.is_empty():
		return active_tasks
	return TutorialHandler.get_section_tasks(section_title)


func _get_primary_display_task(display_tasks: Array):
	if display_tasks.is_empty():
		return null

	for task in display_tasks:
		if not task.is_done:
			return task

	return display_tasks[0]


func _get_task_icon_texture(tutorial, primary_task) -> Texture2D:
	if tutorial.phase == TutorialHandler.TutorialPhase.COMPLETED:
		return TODO_CHECKED
	if primary_task != null and primary_task.is_done:
		return TODO_CHECKED
	return TODO_UNCHECKED


func _get_display_hints(primary_task, display_tasks: Array) -> Array[String]:
	if primary_task == null:
		return []

	if not primary_task.hints.is_empty():
		return primary_task.hints.duplicate()

	var fallback_hints: Array[String] = []
	for task in display_tasks:
		if task == primary_task:
			continue
		fallback_hints.append(task.text)
	return fallback_hints


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


func _apply_bubble_states() -> void:
	for bubble_index in range(_bubble_instances.size()):
		var bubble := _bubble_instances[bubble_index]
		var tutorial = _sidebar_tutorials[bubble_index]
		var background_icon := bubble.get_node("BubbleIcon") as TextureRect
		var state_icon := bubble.get_node("BubbleStateIcon") as TextureRect
		background_icon.texture = _get_bubble_dot_texture(tutorial.section_title, tutorial)
		state_icon.texture = _get_bubble_state_icon_texture(tutorial)
		state_icon.self_modulate = _get_bubble_state_icon_modulate(tutorial.section_title, tutorial)
		bubble.modulate = Color.WHITE

func _get_bubble_dot_texture(section_title: String, tutorial) -> Texture2D:
	if _should_glow_bubble(section_title, tutorial):
		return TUTORIAL_DOT_GLOW
	if _is_bubble_highlighted(section_title):
		return TUTORIAL_DOT_SELECTED
	return TUTORIAL_DOT_OFF

func _get_bubble_state_icon_texture(tutorial) -> Texture2D:
	if tutorial.phase == TutorialHandler.TutorialPhase.COMPLETED:
		return TODO_CHECKED
	return TODO_UNCHECKED

func _get_bubble_state_icon_modulate(section_title: String, tutorial) -> Color:
	if _should_glow_bubble(section_title, tutorial):
		return Color.BLACK
	if _is_bubble_highlighted(section_title):
		return Color.BLACK
	return Color.WHITE

func _should_glow_bubble(section_title: String, tutorial) -> bool:
	if tutorial.phase == TutorialHandler.TutorialPhase.COMPLETED:
		return true
	return _glowing_active_sections.has(section_title)

func _is_bubble_highlighted(section_title: String) -> bool:
	if _hovered_section_title == section_title:
		return true
	return _selected_section_title == section_title and _quest_window.visible and _is_expanded

func _prune_bubble_state() -> void:
	if not _hovered_section_title.is_empty() and TutorialHandler.get_tutorial(_hovered_section_title) == null:
		_hovered_section_title = ""

	var valid_section_titles := {}
	for section_title in TutorialHandler.tutorial_order:
		valid_section_titles[section_title] = true

	for section_title in _glowing_active_sections.keys():
		if not valid_section_titles.has(section_title):
			_glowing_active_sections.erase(section_title)


func _apply_expanded_state() -> void:
	var tutorial = TutorialHandler.get_tutorial(_selected_section_title)
	var can_show_details: bool = tutorial != null and tutorial.phase != TutorialHandler.TutorialPhase.REVEALED
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

	var bubble_rect := selected_bubble.get_global_rect()
	var quest_window_rect := _quest_window.get_global_rect()
	var bubble_size := selected_bubble.size if selected_bubble.size != Vector2.ZERO else selected_bubble.custom_minimum_size

	connector.visible = true
	connector.position = Vector2(
		bubble_size.x,
		(bubble_size.y - CONNECTOR_HEIGHT) * 0.5
	)
	connector.size = Vector2(
		max(quest_window_rect.position.x - bubble_rect.end.x, 0.0),
		CONNECTOR_HEIGHT
	)


func _get_selected_bubble() -> Button:
	for bubble_index in range(_sidebar_tutorials.size()):
		if _sidebar_tutorials[bubble_index].section_title == _selected_section_title:
			return _bubble_instances[bubble_index]
	return null


func _get_bubble_connector(bubble: Button) -> ColorRect:
	return bubble.get_node_or_null("BubbleConnector") as ColorRect


func _hide_all_bubble_connectors() -> void:
	for bubble in _bubble_instances:
		var connector := _get_bubble_connector(bubble)
		if connector != null:
			connector.visible = false


func _on_claim_reward_pressed() -> void:
	if _selected_section_title.is_empty():
		return
	TutorialHandler.claim_tutorial_reward(_selected_section_title)

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
