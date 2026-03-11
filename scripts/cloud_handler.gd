extends Node2D

@onready var cloud_dummy = $Cloud
@onready var camera = %Camera

var active_clouds = []

func _ready():
	cloud_dummy.visible = false
	var target_amount = int(8.0 / camera.zoom.x)
	var rect : Rect2 = camera.get_camera_world_rect()
	while active_clouds.size() < target_amount:
		spawn_new_cloud(rect, true)

func _process(delta):
	var target_amount = int(8.0 / camera.zoom.x)
	var rect : Rect2 = camera.get_camera_world_rect()
	while active_clouds.size() < target_amount:
		spawn_new_cloud(rect)

	for cloud : Sprite2D in active_clouds:
		cloud.position = Vector2(cloud.position.x + delta * 8, cloud.position.y)
		var tex_size = cloud.texture.get_size().x

		if (cloud.position.x > (rect.end.x + tex_size)
		|| cloud.position.x < rect.position.x - tex_size):
			active_clouds.erase(cloud)
			cloud.queue_free()

func spawn_new_cloud(rect, fully_randomize_position = false):
	var instance : Sprite2D = cloud_dummy.duplicate()
	add_child(instance)
	instance.visible = true
	instance.texture = pick_random_texture()
	var x_size = instance.texture.get_size().x
	var x_position = randf_range(rect.position.x, rect.end.x) if fully_randomize_position else rect.position.x - x_size / 2.0
	var y_position = randf_range(rect.position.y, min(0, rect.end.y))
	var spawn_position = Vector2(x_position, y_position)
	instance.global_position = spawn_position
	active_clouds.append(instance)

func pick_random_texture():
	var path = str("res://assets/sprites/clouds/cloud_", randi_range(1, 6) ,".png")
	return load(path);
