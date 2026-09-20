extends GPUParticles2D

# expects top_level = true on this node, which stops it following the parent by itself
func _process(_delta: float) -> void:
	var parent := get_parent() as Node2D
	if parent != null:
		global_position = parent.global_position
