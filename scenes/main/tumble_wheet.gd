extends Sprite2D

# Movement range
@export var left_limit: float = -1000.0
@export var right_limit: float = 1000.0

# Speed + rotation
@export var move_speed: float = 220.0
@export var rotation_speed: float = 3.5

# Jump behavior
@export var jump_height: float = 80.0
@export var jump_speed: float = 5.0
@export var jump_chance: float = 0.008   # chance per frame

var base_y: float
var is_jumping := false
var jump_timer := 0.0

func _ready():
	base_y = position.y
	randomize()

func _process(delta):
	# Move to the right
	position.x += move_speed * delta
	
	# Rotate while rolling
	rotation += rotation_speed * delta
	
	# Loop from +1000 back to -1000
	if position.x > right_limit:
		position.x = left_limit
	
	# Random jump trigger
	if not is_jumping and randf() < jump_chance:
		is_jumping = true
		jump_timer = 0.0
	
	# Jump motion
	if is_jumping:
		jump_timer += delta * jump_speed
		
		# Smooth arc jump
		position.y = base_y - sin(jump_timer * PI) * jump_height
		
		if jump_timer >= 1.0:
			is_jumping = false
			position.y = base_y
