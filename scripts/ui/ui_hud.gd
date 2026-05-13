extends Control

@onready var label_workers: Label = %Label_Workers
@onready var label_idles: Label = %Label_Idles
@onready var button_idles: Button = %Button_Idles
@onready var button_highlight: Button = $MarginContainer/MarginContainer_Content/HBoxContainer/VBoxContainer_Workers/HBoxContainer/Button
@onready var label_guest_amount: Label = %Label_GuestAmount
@onready var progression_bar: ProgressBar = %ProgressBar_GuestProgression
@onready var label_guest_rate: Label = %Label_GuestRate

var _highlights_active: bool = false

func _ready() -> void:
	JobHandler.on_jobs_changed_signal.connect(_on_jobs_changed)
	NPCEventHandler.on_destroy_npc_signal.connect(_on_destroy_npc)
	HoverHandler.click_hovered_node_signal.connect(_on_click_hovered_node)
	visibility_changed.connect(_on_visibility_changed)
	button_idles.pressed.connect(_select_next_idle)
	button_highlight.pressed.connect(_enable_worker_highlights)
	_on_jobs_changed()

func _on_visibility_changed() -> void:
	if visible:
		_on_jobs_changed()

func _on_jobs_changed() -> void:
	var idle_count: int = JobHandler.count_workers_in(Enum.Jobs.IDLE)
	label_workers.text = str("Workers: ", Global.NPCSpawner.workers.size())
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
	Camera.position = idle.position
	await Camera.tween_offset_to_zero().finished
	Global.UI.selection.manually_select(idle)

func _process(_delta: float) -> void:
	label_guest_amount.text = str("Guests: ", Global.NPCSpawner.get_active_guest_count())
	if Global.should_auto_spawn_guests:
		progression_bar.value = Global.NPCSpawner.next_guest_progression
		label_guest_rate.text = str("+", Global.NPCSpawner.guests_per_day_rate(), "/M")
	else:
		label_guest_rate.text = ""
