extends MenuUITab

@onready var music_slider: HSlider = $MarginContainer/MarginContainer/GridContainer/HSlider
@onready var sfx_slider: HSlider = $MarginContainer/MarginContainer/GridContainer/HSlider2


const MUSIC_BUS_NAME := "Music"
const SFX_BUS_NAME := "SFX"

signal started_game_signal

func _ready() -> void:
	# Connect slider signals (if not already connected in the editor)
	music_slider.value_changed.connect(_on_music_slider_value_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_value_changed)
	
	music_slider.drag_started.connect(SoundPlayer.mouse_click_down.play)
	music_slider.drag_ended.connect(SoundPlayer.mouse_click_up.play)
		
	sfx_slider.drag_started.connect(SoundPlayer.mouse_click_down.play)
	sfx_slider.drag_ended.connect(SoundPlayer.mouse_click_up.play)

	# Initialize sliders from current bus volumes
	var music_bus := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	var sfx_bus := AudioServer.get_bus_index(SFX_BUS_NAME)

	music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus))
	sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))

func _on_music_slider_value_changed(value: float) -> void:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

func _on_sfx_slider_value_changed(value: float) -> void:
	var bus_index := AudioServer.get_bus_index(SFX_BUS_NAME)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
