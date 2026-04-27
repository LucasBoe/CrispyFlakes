extends Control

@onready var esc_overlay = $ESCOverlay
@onready var paused_icon = $PausePlayIconOverlay/Paused
@onready var play_icon = $PausePlayIconOverlay/Play

var _play_tween: Tween

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep processing input even when paused
	esc_overlay.visible = false
	get_tree().paused = false
	paused_icon.hide()
	play_icon.hide()
	TimeHandler.on_time_changed_signal.connect(on_time_changed)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause():
	var paused = not get_tree().paused
	get_tree().paused = paused
	esc_overlay.visible = paused
	
func on_time_changed(speed: int):
	if speed == 0:
		play_icon.hide()
		paused_icon.modulate.a = 1.0
		paused_icon.show()
	else:
		paused_icon.hide()
		play_icon.modulate.a = 1.0
		play_icon.show()
		if _play_tween:
			_play_tween.kill()
		_play_tween = create_tween()
		_play_tween.tween_property(play_icon, "modulate:a", 0.0, 1.2).set_delay(0.3)
		_play_tween.tween_callback(play_icon.hide)
