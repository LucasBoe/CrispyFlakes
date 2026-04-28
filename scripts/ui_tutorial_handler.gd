extends Control
class_name UITutorial

const FOLDOUT_ARROW = preload("res://assets/sprites/ui/2x/Arrow_11px_down.png")
const FOLDOUT_ARROW_HOVER_TINT = Color(0.98, 0.84, 0.35, 1.0)
const NAV_PILL_DEFAULT_TINT = Color(0.48, 0.48, 0.48, 1.0)
const NAV_PILL_CURRENT_TINT = Color(0.91, 0.57, 0.22, 1.0)
const TODO_CHECKED = preload("res://assets/sprites/ui/tutorial_todo_checked.png")
const TODO_UNCHECKED = preload("res://assets/sprites/ui/tutorial_todo_unchecked.png")
const NAV_BIG_CHECKED = preload("res://assets/sprites/ui/2x/Tutorial_nav_big_checkmark.png")
const NAV_BIG_FILLED = preload("res://assets/sprites/ui/2x/Tutorial_nav_big_filled.png")
const NAV_BIG_OUTLINE = preload("res://assets/sprites/ui/2x/Tutorial_nav_big_outline.png")
const NAV_SMALL_FILLED = preload("res://assets/sprites/ui/2x/Tutorial_nav_small_filled.png")
const NAV_SMALL_OUTLINE = preload("res://assets/sprites/ui/2x/Tutorial_nav_small_outline.png")

@onready var header_container = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer_Header
@onready var header_label = %Title
@onready var divider_top = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer_Divider
@onready var steps_container = $MarginContainer/MarginContainer/VBoxContainer/VBoxContainer_Step
@onready var step_dummy = $MarginContainer/MarginContainer/VBoxContainer/VBoxContainer_Step/HBoxContainer
@onready var divider_bottom = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer_Divider2
@onready var navbar_big = $MarginContainer/MarginContainer/VBoxContainer/TutorialNavBig
@onready var big_pill_dummy = $MarginContainer/MarginContainer/VBoxContainer/TutorialNavBig/HBoxContainer/PillDummy
@onready var navbar_small = $MarginContainer/MarginContainer/VBoxContainer/TutorialNavSmall
@onready var small_pill_dummy = $MarginContainer/MarginContainer/VBoxContainer/TutorialNavSmall/HBoxContainer/PillDummy
@onready var foldout_button = %ButtonFoldout

var step_instances = []
var big_pills = []
var small_pills = []
var is_big = true

func _ready():
	step_dummy.hide()
	big_pill_dummy.hide()
	small_pill_dummy.hide()
	var refresh_callable := Callable(self, "refresh_ui")
	if not TutorialHandler.tasks_changed.is_connected(refresh_callable):
		TutorialHandler.tasks_changed.connect(refresh_callable)
	refresh_ui()



func refresh_ui():
	_clear_instances(step_instances)
	_clear_instances(big_pills)
	_clear_instances(small_pills)

	var section_title := TutorialHandler.get_current_section_title()
	if section_title.is_empty():
		hide()
		return

	var section_tasks = TutorialHandler.get_section_tasks(section_title)
	var visible_tasks = _get_visible_tasks(section_tasks)
	if visible_tasks.is_empty():
		hide()
		return

	header_label.text = section_title
	_rebuild_steps(visible_tasks)
	_rebuild_nav(section_tasks)
	_apply_layout()
	show()

func toggle_big_small():
	is_big = not is_big
	refresh_ui()

func _rebuild_steps(visible_tasks: Array) -> void:
	var display_tasks = visible_tasks if is_big else [_get_primary_task(visible_tasks)]
	var is_first_task := true

	for task in display_tasks:
		var wrapper := VBoxContainer.new()
		wrapper.add_theme_constant_override("separation", 2)

		var row := step_dummy.duplicate() as HBoxContainer
		row.show()
		wrapper.add_child(row)

		var label := row.get_node("Label") as Label
		var icon := row.get_node("TextureRect") as TextureRect

		foldout_button.disabled = not is_first_task
		foldout_button.self_modulate = Color.WHITE if is_first_task else Color(1.0, 1.0, 1.0, 0.0)
		_configure_foldout_button(foldout_button, is_big)
		if is_first_task:
			foldout_button.pressed.connect(Callable(self, "toggle_big_small"))

		label.text = task.text
		label.self_modulate = Color.WHITE if not task.is_done else Color(1.0, 1.0, 1.0, 0.7)
		icon.texture = TODO_CHECKED if task.is_done else TODO_UNCHECKED

		if is_big and not task.is_done:
			for hint in task.hints:
				wrapper.add_child(_create_hint_label(label, hint))

		steps_container.add_child(wrapper)
		step_instances.append(wrapper)
		is_first_task = false

func _get_visible_tasks(section_tasks: Array) -> Array:
	var active_tasks = section_tasks.filter(func(task): return task.is_started and not task.is_done)
	if not active_tasks.is_empty():
		return active_tasks

	return []

func _rebuild_nav(section_tasks: Array) -> void:
	for task in section_tasks:
		var big_pill := big_pill_dummy.duplicate() as TextureRect
		big_pill.show()
		big_pill.texture = _get_big_nav_texture(task)
		big_pill.self_modulate = _get_nav_tint(task)
		big_pill_dummy.get_parent().add_child(big_pill)
		big_pills.append(big_pill)

		var small_pill := small_pill_dummy.duplicate() as TextureRect
		small_pill.show()
		small_pill.texture = NAV_SMALL_FILLED if (task.is_started or task.is_done) else NAV_SMALL_OUTLINE
		small_pill.self_modulate = _get_nav_tint(task)
		small_pill_dummy.get_parent().add_child(small_pill)
		small_pills.append(small_pill)

func _apply_layout() -> void:
	header_container.visible = is_big
	divider_top.visible = is_big
	divider_bottom.visible = is_big
	navbar_big.visible = is_big
	navbar_small.visible = not is_big

func _get_primary_task(visible_tasks: Array):
	for task in visible_tasks:
		if not task.is_done:
			return task
	return visible_tasks.back()

func _configure_foldout_button(button: Button, expanded: bool) -> void:
	button.flat = true
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	button.add_theme_stylebox_override("disabled", empty_style)

	var arrow := button.get_node_or_null("Arrow") as TextureRect
	if arrow == null:
		arrow = TextureRect.new()
		arrow.name = "Arrow"
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.texture = FOLDOUT_ARROW
		arrow.anchor_right = 1.0
		arrow.anchor_bottom = 1.0
		arrow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		button.add_child(arrow)

	arrow.pivot_offset = button.custom_minimum_size * 0.5
	arrow.rotation_degrees = 0.0 if expanded else -90.0
	arrow.self_modulate = Color.WHITE

	button.mouse_entered.connect(Callable(self, "_on_foldout_button_hovered").bind(button, true))
	button.mouse_exited.connect(Callable(self, "_on_foldout_button_hovered").bind(button, false))

func _on_foldout_button_hovered(button: Button, hovered: bool) -> void:
	var arrow := button.get_node_or_null("Arrow") as TextureRect
	if arrow == null:
		return
	arrow.self_modulate = FOLDOUT_ARROW_HOVER_TINT if hovered else Color.WHITE

func _get_big_nav_texture(task) -> Texture2D:
	if task.is_done:
		return NAV_BIG_CHECKED
	if task.is_started:
		return NAV_BIG_FILLED
	return NAV_BIG_OUTLINE

func _get_nav_tint(task) -> Color:
	if task.is_done:
		return Color.WHITE
	if task.is_started:
		return NAV_PILL_CURRENT_TINT
	return NAV_PILL_DEFAULT_TINT

func _create_hint_label(reference_label: Label, hint: String) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)

	var hint_label := Label.new()
	hint_label.text = str("- ", hint)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.self_modulate = Color(0.78, 0.75, 0.70, 1.0)

	var font = reference_label.get_theme_font("font")
	if font != null:
		hint_label.add_theme_font_override("font", font)
	hint_label.add_theme_font_size_override("font_size", 13)

	margin.add_child(hint_label)
	return margin

func _clear_instances(instances: Array) -> void:
	for instance in instances:
		instance.queue_free()
	instances.clear()
