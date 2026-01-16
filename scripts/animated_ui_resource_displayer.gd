extends Node2D

@onready var coin_dummy = $Coin
@onready var ui_resource_handler : UIRessourceHandler = $"../UI/UIResources"
@onready var camera = %Camera
@onready var canvas : CanvasLayer = $"../UI";

var actively_animated = []

func _ready():
	coin_dummy.visible = false
	ResourceHandler.on_animate_resource_add.connect(animate_resource_add)
	
func animate_resource_add(resource, amount, global_pos, duration):
	var dummy = coin_dummy
	
	for i in amount:	
		var instance = dummy.duplicate()
		add_child(instance)
		instance.global_position = global_pos
		instance.visible = true
		instance.play()
		instance.frame = randi_range(0,3)
		
		var target_relative = ui_resource_handler.get_resource_label_relative_position(resource)
		
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		
		var offset_target = global_pos + Vector2(randf_range(-24, 24), randf_range(-10, 10))
		tween.tween_property(instance, "global_position", offset_target, duration * .3)
		tween.tween_callback(create_animation.bind(instance, target_relative, duration * .7))
		tween.tween_interval(duration * .7);
		tween.tween_callback(kill_animation.bind(instance))

func _process(delta):
	for a in actively_animated:
		#var l = (a.TimeEnd - a.TimeStart) = a.Duration
		var t = (Time.get_ticks_usec()/1000000.0)
		var l = (t - a.TimeStart) / a.Duration
		
		var lll = l*l*l*l*l*l
		
		var rect = camera.get_camera_world_rect()
		
		var topLeft = rect.position
		var bottomRight = rect.end
		
		var target = Vector2(
			lerp(topLeft.x, bottomRight.x, a.TargetRelative.x),
			lerp(topLeft.y, bottomRight.y, a.TargetRelative.y))
		
		a.Sprite.global_position = lerp(a.Sprite.global_position, target, lll)

func create_animation(instance, target_relative, duration):
	var anim = ActiveAnimation.new();
	anim.Sprite = instance
	anim.TargetRelative = target_relative
	anim.TimeStart = Time.get_ticks_usec()/1000000.0
	anim.TimeEnd = anim.TimeStart + duration
	anim.Duration = duration
	actively_animated.append(anim)
	
func kill_animation(instance):
	var toRemove = -1
	
	for i in actively_animated.size():
		if actively_animated[i].Sprite == instance:
			toRemove = i;
			
	if toRemove >= 0:
		actively_animated[toRemove].Sprite.queue_free()
		actively_animated.remove_at(toRemove)
	
class ActiveAnimation:
	var Sprite : AnimatedSprite2D
	var TargetRelative : Vector2
	var TimeStart : float
	var TimeEnd : float
	var Duration : float
