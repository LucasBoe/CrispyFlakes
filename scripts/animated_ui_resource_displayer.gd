extends Node2D

const PHASE_1_DURATION := 0.3
const PHASE_2_DURATION := 0.7
const SCATTER_X := 24.0
const SCATTER_Y := 10.0

const PRESSURE_THRESHOLD := 50.0
const PRESSURE_DURATION_SCALE := 0.65
const PRESSURE_DELAY_MAX := 0.1
const PRESSURE_DELAY_MIN := 0.025

const PITCH_BATCH_THRESHOLD := 20.0
const PITCH_START_SMALL := 0.8
const PITCH_START_LARGE := 0.25
const PITCH_TARGET_SMALL := 1.0
const PITCH_TARGET_LARGE := 1.4
const PITCH_RISE_SPEED := 0.5

@onready var coin_dummy = $Coin

var actively_animated: Array = []
var coin_queue: Array = []
var coin_pitch: float = PITCH_START_LARGE
var coin_pitch_target: float = PITCH_TARGET_LARGE
var coins_played_in_session: int = 0

func _ready():
	coin_dummy.visible = false
	ResourceHandler.on_animate_resource_add.connect(animate_resource_add)
	ResourceHandler.on_animate_resource_spend.connect(animate_resource_spend)
	coin_anim_routine()

func animate_resource_add(resource, amount, global_pos, duration):
	for i in amount:
		var anim = ActiveAnimation.new()
		anim.Origin = global_pos
		anim.Duration = duration * PHASE_2_DURATION

		var instance = coin_dummy.duplicate()
		add_child(instance)
		instance.global_position = global_pos
		instance.visible = true
		instance.play()
		instance.frame = randi_range(0, 3)
		anim.Sprite = instance

		var offset_target = global_pos + Vector2(randf_range(-SCATTER_X, SCATTER_X), randf_range(-SCATTER_Y, SCATTER_Y))
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(instance, "global_position", offset_target, duration * PHASE_1_DURATION)
		tween.tween_callback(set_ready.bind(anim))

		coin_queue.append(anim)


func set_ready(animation: ActiveAnimation):
	animation.ReadyToBeAnimated = true

func coin_anim_routine():
	while true:
		var to_start: Array = []
		for coin in coin_queue:
			if coin.ReadyToBeAnimated:
				to_start.append(coin)

		for coin in to_start:
			coin_queue.erase(coin)
			var remaining = actively_animated.size() + coin_queue.size()
			var pressure = clampf(float(remaining) / PRESSURE_THRESHOLD, 0.0, 1.0)
			coin.Duration *= lerp(1.0, PRESSURE_DURATION_SCALE, pressure)
			create_animation(coin)
			await get_tree().create_timer(lerp(PRESSURE_DELAY_MAX, PRESSURE_DELAY_MIN, pressure)).timeout

		await get_tree().process_frame


func animate_resource_spend(amount: int, world_target: Vector2, duration: float) -> void:
	var camera := Camera
	var label_pos = Global.UI.money.get_label_relative_position(camera)
	for i in mini(amount, 5):
		var instance = coin_dummy.duplicate()
		add_child(instance)
		instance.global_position = label_pos
		instance.visible = true
		instance.play()
		instance.frame = randi_range(0, 3)

		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)

		var offset_target = world_target + Vector2(randf_range(-24, 24), randf_range(-10, 10))
		tween.tween_property(instance, "global_position", offset_target, duration)
		#tween.tween_property(instance, "modulate:a", 0.0, duration * 0.2)
		tween.tween_callback(instance.queue_free)

func _process(_delta):
	var camera := Camera
	var target = Global.UI.money.get_label_relative_position(camera)
	var finished: Array = []

	for a in actively_animated:
		var t = Time.get_ticks_usec() / 1000000.0
		var l = (t - a.TimeStart) / a.Duration
		var lll = l * l * l * l * l * l

		a.Sprite.global_position = lerp(a.Sprite.global_position, target, lll)

		if l >= 1.0:
			finished.append(a)

	for a in finished:
		actively_animated.erase(a)
		a.Sprite.queue_free()
		var remaining = actively_animated.size() + coin_queue.size()
		var t = clampf(float(remaining) / PITCH_BATCH_THRESHOLD, 0.0, 1.0)
		coin_pitch_target = maxf(coin_pitch_target, lerp(PITCH_TARGET_SMALL, PITCH_TARGET_LARGE, t))
		if coins_played_in_session == 0:
			coin_pitch = lerp(PITCH_START_SMALL, PITCH_START_LARGE, t)
		print("coin pitch: ", coin_pitch, " remaining: ", remaining)
		SoundPlayer.play_coin(coin_pitch)
		if remaining == 0:
			coin_pitch = PITCH_START_LARGE
			coin_pitch_target = PITCH_TARGET_SMALL
			coins_played_in_session = 0
		else:
			coins_played_in_session += 1
			coin_pitch = lerp(coin_pitch, coin_pitch_target, PITCH_RISE_SPEED / float(remaining))

func create_animation(anim: ActiveAnimation):
	anim.TimeStart = Time.get_ticks_usec() / 1000000.0
	anim.TimeEnd = anim.TimeStart + anim.Duration
	actively_animated.append(anim)

func kill_animation(instance):
	var to_remove = -1
	for i in actively_animated.size():
		if actively_animated[i].Sprite == instance:
			to_remove = i
	if to_remove >= 0:
		actively_animated[to_remove].Sprite.queue_free()
		actively_animated.remove_at(to_remove)

class ActiveAnimation:
	var Sprite: AnimatedSprite2D
	var Origin: Vector2
	var ReadyToBeAnimated: bool = false
	var TimeStart: float
	var TimeEnd: float
	var Duration: float
