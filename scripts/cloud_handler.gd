extends Node2D

@onready var cloudDummy = $Cloud
@onready var camera = %Camera

var activeClouds = []

func _ready():
	cloudDummy.visible = false
	var targetAmount = int(8.0 / camera.zoom.x)
	var rect : Rect2 = camera.get_camera_world_rect()
	while activeClouds.size() < targetAmount:
		spawn_new_cloud(rect, true)

func _process(delta):
	var targetAmount = int(8.0 / camera.zoom.x)
	var rect : Rect2 = camera.get_camera_world_rect()
	while activeClouds.size() < targetAmount:
		spawn_new_cloud(rect)
		
	for cloud : Sprite2D in activeClouds:
		cloud.position = Vector2(cloud.position.x + delta * 8, cloud.position.y)
		var texSize = cloud.texture.get_size().x
		
		if (cloud.position.x > (rect.end.x + texSize)
		|| cloud.position.x < rect.position.x - texSize):
			activeClouds.erase(cloud)
			cloud.queue_free()
		
func spawn_new_cloud(rect, fully_randomize_position = false):
	var instance : Sprite2D = cloudDummy.duplicate()
	add_child(instance)
	instance.visible = true
	instance.texture = pick_random_texture()
	var xSize = instance.texture.get_size().x
	var xPosition = randf_range(rect.position.x, rect.end.x) if fully_randomize_position else rect.position.x - xSize / 2.0
	var yPosition = randf_range(rect.position.y, min(0, rect.end.y))
	var spawnPosition = Vector2(xPosition, yPosition)
	instance.global_position = spawnPosition
	activeClouds.append(instance)

func pick_random_texture():
	var path = str("res://assets/sprites/clouds/cloud_", randi_range(1, 6) ,".png")
	return load(path);
