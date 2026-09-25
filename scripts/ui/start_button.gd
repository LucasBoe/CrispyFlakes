extends Button

@onready var _gold_plate: NinePatchRect = $GoldPlate
@onready var _gold_material: ShaderMaterial = _gold_plate.material

var _visual_state := -2
var _feedback_tween: Tween

func _ready() -> void:
	mouse_entered.connect(_on_hovered)
	focus_entered.connect(_on_focused)
	button_down.connect(SoundPlayer.play_ui_click_down)
	button_up.connect(SoundPlayer.play_ui_click_up)
	visibility_changed.connect(_reset_feedback)
	resized.connect(_update_pivot)
	_update_pivot()
	_refresh_feedback()

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_gold_material.set_shader_parameter("ui_time", float(Time.get_ticks_msec()) / 1000.0)
	_refresh_feedback()

func _refresh_feedback() -> void:
	var state := 0
	if disabled:
		state = -1
	elif is_pressed():
		state = 2
	elif is_hovered() or has_focus():
		state = 1
	if state == _visual_state:
		return
	_visual_state = state
	_gold_material.set_shader_parameter("is_unlocked", not disabled)
	_gold_material.set_shader_parameter("is_active", state > 0)
	if _feedback_tween != null:
		_feedback_tween.kill()
	var target_scale := 0.96 if state == 2 else 1.0
	_feedback_tween = create_tween().set_ignore_time_scale(true)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE * target_scale, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_pivot() -> void:
	pivot_offset = size * 0.5

func _reset_feedback() -> void:
	if _feedback_tween != null:
		_feedback_tween.kill()
	scale = Vector2.ONE
	_visual_state = -2

func _on_hovered() -> void:
	if not disabled:
		SoundPlayer.play_ui_hover()

func _on_focused() -> void:
	if not disabled and not is_hovered():
		SoundPlayer.play_ui_hover()
