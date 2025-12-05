extends AudioStreamPlayer
class_name CustomAudioStreamPlayer

func play_random_pitch():
	self.pitch_scale = .8 + randf() * .4
	self.play()
