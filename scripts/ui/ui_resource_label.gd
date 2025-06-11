extends Control

@onready var label: Label = $Label
@onready var change_label: Label = $Label/ChangeLabel
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	change_label.visible = false
	# Ensure this node starts at default scale
	scale = Vector2.ONE

func update_amount(new_amount: int, change: int) -> void:
	# 1) Update the main label
	label.text = str(new_amount)

	# 2) Clone the popup label template
	var change_clone: Label = change_label.duplicate()
	add_child(change_clone)
	change_clone.visible = true

	# 3) Set text & color
	var is_increase := change > 0
	change_clone.text = ("+" if is_increase else "") + str(change)
	change_clone.add_theme_color_override(
		"font_color",
		Color(0, 1, 0) if is_increase else Color(1, 0, 0)
	)

	# 4) Randomize start offset & tilt & reset opacity
	change_clone.position.x += rng.randi_range(-10, 20)
	change_clone.rotation_degrees = rng.randi_range(-15, 15)
	change_clone.modulate.a = 1.0

	# 5) Build a SceneTreeTween with default easing
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	# 6) Randomize final offset and durations
	var y_offset := rng.randi_range(40, 56)  # random final rise between 40-56 px
	var move_dur := randf_range(1.2, 1.8)
	var rotate_dur := randf_range(1.2, 1.8)
	var fade_dur := randf_range(0.8, 1.2)
	var fade_delay := randf_range(0.3, 0.7)

	# 7) Animate popup label in parallel: position, rotation, fade
	tween.parallel().tween_property(
		change_clone, "position:y",
		change_clone.position.y + y_offset,
		move_dur
	)
	tween.parallel().tween_property(
		change_clone, "rotation_degrees",
		change_clone.rotation_degrees + rng.randi_range(-10, 10),
		rotate_dur
	)
	tween.parallel().tween_property(
		change_clone, "modulate:a",
		0.0,
		fade_dur
	).set_delay(fade_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# 8) Animate this Control node scale pop in parallel
	tween.parallel().tween_property(
		self, "scale",
		Vector2(1.05, 1.05),
		0.05
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		self, "scale",
		Vector2.ONE,
		0.05
	).set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	# 9) Cleanup popup label when done
	tween.tween_callback(Callable(change_clone, "queue_free"))
