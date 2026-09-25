extends Control
class_name LoadGameMenu

signal back_requested
signal load_requested(save_path: String)
signal save_completed(save_path: String)

enum Mode { LOAD, SAVE }
@export var mode: Mode = Mode.LOAD

const SAVE_CARD_SCENE := preload("res://scenes/ui/load_game_card.tscn")

@onready var panel: Control = $Panel
@onready var save_scroll: ScrollContainer = %SaveScroll
@onready var save_grid: GridContainer = %SaveGrid
@onready var save_cards: Array = save_grid.get_children()
@onready var back_button: Button = %BackButton
@onready var title: Label = $Panel/Margin/Layout/Title
@onready var status_label: Label = %StatusLabel
@onready var overwrite_dialog: Control = %OverwriteDialog
@onready var overwrite_message: Label = %OverwriteMessage
@onready var overwrite_button: Button = %OverwriteButton
@onready var cancel_overwrite_button: Button = %CancelOverwriteButton
var _busy := false
var _pending_overwrite_path := ""

func _ready() -> void:
	overwrite_button.pressed.connect(_confirm_overwrite)
	cancel_overwrite_button.pressed.connect(_cancel_overwrite)
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(SoundPlayer.play_ui_hover)
	back_button.focus_entered.connect(SoundPlayer.play_ui_hover)
	back_button.button_down.connect(SoundPlayer.play_ui_click_down)
	back_button.button_up.connect(SoundPlayer.play_ui_click_up)
	for card in save_cards:
		card.activated.connect(_on_card_activated)
	title.text = "SAVE GAME" if mode == Mode.SAVE else "LOAD GAME"
	_refresh_save_cards()

func _on_back_pressed() -> void:
	if _busy:
		return
	if not _pending_overwrite_path.is_empty():
		_cancel_overwrite()
		return
	if mode == Mode.SAVE:
		hide()
		TimeHandler.pop_pause_lock(self)
	back_requested.emit()

func open_for_saving() -> void:
	mode = Mode.SAVE
	title.text = "SAVE GAME"
	status_label.hide()
	_refresh_save_cards()
	position = Vector2.ZERO
	save_scroll.scroll_vertical = 0
	show()
	TimeHandler.push_pause_lock(self)
	focus_first_available_card()

func _exit_tree() -> void:
	if mode == Mode.SAVE:
		TimeHandler.pop_pause_lock(self)

func _input(event: InputEvent) -> void:
	if mode == Mode.SAVE and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _on_card_activated(path: String) -> void:
	if _busy or not _pending_overwrite_path.is_empty():
		return
	if mode == Mode.LOAD:
		load_requested.emit(path)
		return
	if FileAccess.file_exists(path):
		_pending_overwrite_path = path
		overwrite_message.text = "Overwrite Save %d?\nThe existing saved progress will be replaced." % SaveHandler.get_save_number(path)
		back_button.disabled = true
		for card in save_cards:
			card.disabled = true
		overwrite_dialog.show()
		cancel_overwrite_button.grab_focus()
		return
	await _save_to_path(path)

func _confirm_overwrite() -> void:
	if _pending_overwrite_path.is_empty():
		return
	var path := _pending_overwrite_path
	_pending_overwrite_path = ""
	overwrite_dialog.hide()
	await _save_to_path(path)

func _cancel_overwrite() -> void:
	var path := _pending_overwrite_path
	_pending_overwrite_path = ""
	overwrite_dialog.hide()
	back_button.disabled = false
	_refresh_save_cards()
	for card in save_cards:
		if card.visible and card.save_path == path:
			card.grab_focus()
			break

func _save_to_path(path: String) -> void:
	_busy = true
	back_button.disabled = true
	for card in save_cards:
		card.disabled = true
	status_label.text = "Saving…"
	status_label.show()
	var error := await SaveHandler.save_game(path)
	_busy = false
	back_button.disabled = false
	_refresh_save_cards()
	status_label.text = "Save %d saved." % SaveHandler.get_save_number(path) if error == OK else "Save failed: %s. Please try again." % error_string(error)
	if error == OK:
		save_completed.emit(path)
	for card in save_cards:
		if card.visible and card.save_path == path:
			card.grab_focus()
			break

func _refresh_save_cards() -> void:
	_populate_cards(SaveHandler.get_save_paths())

func _populate_cards(paths: Array[String]) -> void:
	var card_count := paths.size() + (1 if mode == Mode.SAVE else 0)
	while save_cards.size() < card_count:
		var card = SAVE_CARD_SCENE.instantiate()
		save_grid.add_child(card)
		card.activated.connect(_on_card_activated)
		save_cards.append(card)
	for index in save_cards.size():
		var card = save_cards[index]
		if index < paths.size():
			card.configure(SaveHandler.get_save_info(paths[index]), paths[index])
			if mode == Mode.SAVE:
				card.tooltip_text = "Overwrite Save %d\n%s" % [SaveHandler.get_save_number(paths[index]), card.tooltip_text]
			card.show()
		elif mode == Mode.SAVE and index == paths.size():
			card.configure_new(SaveHandler.get_new_save_path())
			card.show()
		else:
			card.configure_empty()
			card.hide()

func has_available_save() -> bool:
	return not SaveHandler.get_save_paths().is_empty()

func focus_first_available_card() -> void:
	for card in save_cards:
		if not card.disabled:
			card.grab_focus()
			return
	back_button.grab_focus()

func prepare_for_entry() -> void:
	_refresh_save_cards()
	save_scroll.scroll_vertical = 0
	position.y = get_viewport_rect().size.y
	show()

func prepare_for_exit() -> void:
	position.y = 0.0

func set_panel_y(value: float) -> void:
	position.y = value
