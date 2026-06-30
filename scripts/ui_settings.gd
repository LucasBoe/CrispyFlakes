extends MenuUITab

@onready var music_slider: HSlider = $MarginContainer/MarginContainer/GridContainer/HSlider
@onready var sfx_slider: HSlider = $MarginContainer/MarginContainer/GridContainer/HSlider2
@onready var skip_tutorial_container: Control = $MarginContainer/MarginContainer/GridContainer/SkipTutorialContainer
@onready var skip_tutorial_button: Button = $MarginContainer/MarginContainer/GridContainer/SkipTutorialContainer/SkipTutorialButton


const MUSIC_BUS_NAME := "Music"
const SFX_BUS_NAME := "SFX"

signal started_game_signal

func _ready() -> void:
	# Connect slider signals (if not already connected in the editor)
	music_slider.value_changed.connect(_on_music_slider_value_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_value_changed)
	skip_tutorial_button.pressed.connect(_on_skip_tutorial_button_pressed)
	
	music_slider.drag_started.connect(SoundPlayer.play_ui_click_down)
	music_slider.drag_ended.connect(SoundPlayer.play_ui_click_up)
		
	sfx_slider.drag_started.connect(SoundPlayer.play_ui_click_down)
	sfx_slider.drag_ended.connect(SoundPlayer.play_ui_click_up)

	# Initialize sliders from current bus volumes
	var music_bus := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	var sfx_bus := AudioServer.get_bus_index(SFX_BUS_NAME)

	music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus))
	sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))
	set_skip_tutorial_available(false)

func _on_music_slider_value_changed(value: float) -> void:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

func _on_sfx_slider_value_changed(value: float) -> void:
	var bus_index := AudioServer.get_bus_index(SFX_BUS_NAME)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

func set_skip_tutorial_available(available: bool) -> void:
	skip_tutorial_container.visible = available
	skip_tutorial_button.disabled = not available

func _on_skip_tutorial_button_pressed() -> void:
	StartupCoordinator.request_skip_tutorial()
