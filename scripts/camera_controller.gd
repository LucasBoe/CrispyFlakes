extends Camera2D

@export var zoomSpeed : float = 10;


var zoomTarget : float = 1

var dragStartMousePos = Vector2.ZERO
var dragStartCameraPos = Vector2.ZERO
var isDragging : bool = false
var zoomFactor : float = 1

func _ready():
	offset = Vector2(0,-96)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	handle_zoom(delta)
	SimplePan(delta)
	ClickAndDrag()
	
func handle_zoom(delta):
	if Input.is_action_just_pressed("zoom_in"):
		zoomTarget *= 1.1
		zoom_in_out();
		
	if Input.is_action_just_pressed("zoom_out"):
		zoomTarget *= 0.9
		zoom_in_out();
	
func _input(event):
	
	var delta = get_process_delta_time() 
	
	if event is InputEventMouseButton and event.is_pressed() and not event.is_echo():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoomTarget *= 1.1
			zoom_in_out();
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoomTarget *= 0.9
			zoom_in_out();
		
	if event is InputEventPanGesture:
		if event.delta.y < 0:
			zoomTarget *= 1.005
			zoom_in_out();
		else:
			zoomTarget *= 0.99
			zoom_in_out();
		
func SimplePan(delta):
	var moveAmount = Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		moveAmount.x += 1
		
	if Input.is_action_pressed("ui_left"):
		moveAmount.x -= 1
		
	if Input.is_action_pressed("ui_up"):
		moveAmount.y -= 1
		
	if Input.is_action_pressed("ui_down"):
		moveAmount.y += 1
		
	moveAmount = moveAmount.normalized()
	position += moveAmount * delta * 100 * (1/zoomFactor)
	
func ClickAndDrag():
	if !isDragging and Input.is_action_just_pressed("camera_pan"):
		dragStartMousePos = get_viewport().get_mouse_position()
		dragStartCameraPos = global_position
		isDragging = true
		
	if isDragging and Input.is_action_just_released("camera_pan"):
		isDragging  = false
		
	if isDragging:
		var moveVector = get_viewport().get_mouse_position() - dragStartMousePos
		offset = dragStartCameraPos - moveVector * 1/zoomFactor	
		
func zoom_in_out():
	var mousePositionBefore = get_global_mouse_position()
	var cameraCenter = self.global_position;
	
	zoom = Vector2(zoomTarget, zoomTarget);
	
	var diff = mousePositionBefore - get_global_mouse_position()
	offset += diff
	
	#print(diff)
