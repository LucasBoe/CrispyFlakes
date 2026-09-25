extends Button
signal activated(save_path: String)

@onready var preview: TextureRect = %Preview
@onready var card_mode: Label = %CardMode
@onready var card_name: Label = %CardName
@onready var card_date: Label = %CardDate
@onready var empty_label: Label = %EmptyLabel
@onready var details: VBoxContainer = %Details
@onready var months_label: Label = %Months
@onready var cash_label: Label = %Cash
@onready var workers_label: Label = %Workers
@onready var no_preview: Label = %NoPreview
@onready var slot_number: Label = %SlotNumber

var save_path := ""

func _ready() -> void:
	pressed.connect(func() -> void:
		if not save_path.is_empty():
			activated.emit(save_path)
	)
	mouse_entered.connect(SoundPlayer.play_ui_hover)
	focus_entered.connect(SoundPlayer.play_ui_hover)
	button_down.connect(SoundPlayer.play_ui_click_down)
	button_up.connect(SoundPlayer.play_ui_click_up)

func configure(info: Dictionary, path: String) -> void:
	save_path = path
	disabled = false
	slot_number.text = "SAVE %d" % SaveHandler.get_save_number(path)
	slot_number.show()
	preview.show()
	$PreviewBackground.show()
	details.show()
	preview.texture = null
	var preview_path := str(info.get("preview_path", ""))
	if not preview_path.is_empty() and FileAccess.file_exists(preview_path):
		var screenshot := Image.load_from_file(preview_path)
		if screenshot != null and not screenshot.is_empty():
			preview.texture = ImageTexture.create_from_image(screenshot)
	no_preview.visible = preview.texture == null
	card_mode.text = str(info.get("game_mode", ""))
	var scenario_name := str(info.get("scenario_name", ""))
	if not scenario_name.is_empty():
		card_mode.text += ": " + scenario_name
	card_name.text = str(info.get("saloon_name", ""))
	if card_name.text.is_empty():
		card_name.text = "Unnamed Saloon"
	card_date.text = str(info.get("timestamp", info.get("date", "")))
	var months := int(info.get("months_played", -1))
	months_label.text = "%d months" % months if months >= 0 else "Months: —"
	cash_label.text = "$%s" % _format_number(roundi(float(info.get("cash_owned", 0.0))))
	workers_label.text = "%d workers" % int(info.get("worker_count", 0))
	tooltip_text = "%s\n%s\n%s · %s · %s\n%s" % [card_name.text, card_mode.text, months_label.text, cash_label.text, workers_label.text, card_date.text]
	card_mode.show()
	card_name.show()
	card_date.show()
	empty_label.hide()

func configure_empty() -> void:
	save_path = ""
	disabled = true
	slot_number.hide()
	preview.hide()
	$PreviewBackground.hide()
	preview.texture = null
	details.hide()
	no_preview.hide()
	tooltip_text = ""
	card_mode.hide()
	card_name.hide()
	card_date.hide()
	empty_label.show()

func configure_new(path: String) -> void:
	configure_empty()
	save_path = path
	disabled = false
	empty_label.text = "+\nNEW SAVE\nSave %d" % SaveHandler.get_save_number(path)
	tooltip_text = "Create a new numbered save"

func _format_number(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			grouped += ","
		grouped += digits[index]
	return ("-" if value < 0 else "") + grouped
