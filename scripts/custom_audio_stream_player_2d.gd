extends AudioStreamPlayer2D
class_name CustomAudioStreamPlayer2D

@export var random_pitch_min := 0.8
@export var random_pitch_max := 1.2

func play_random_pitch(min_pitch: float = random_pitch_min, max_pitch: float = random_pitch_max) -> void:
	pitch_scale = randf_range(min_pitch, max_pitch)
	play()
