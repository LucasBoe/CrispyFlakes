extends Camera2D

@export var zoomSpeed : float = 10;
@export var minZoom: float = 0.5
@export var maxZoom: float = 3.0
@export var panBounds: Rect2 = Rect2(Vector2.ZERO, Vector2.ZERO)


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
	clamp_pan_to_bounds()
	
func handle_zoom(delta):
	if Input.is_action_just_pressed("zoom_in"):
		zoomTarget *= 0.9
		zoom_in_out();
		
	if Input.is_action_just_pressed("zoom_out"):
		zoomTarget *= 1.1
		zoom_in_out();		
	
func _input(event):
	
	var delta = get_process_delta_time() 
	
	#if event is InputEventMouseButton and event.is_pressed() and not event.is_echo():
		#if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			#zoomTarget *= 1.1
			#zoom_in_out();
		#elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			#zoomTarget *= 0.9
			#zoom_in_out();
		
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
	
func clamp_pan_to_bounds() -> void:
	if panBounds.size == Vector2.ZERO:
		return

	var view := get_camera_world_rect()
	var bounds_end := panBounds.position + panBounds.size
	var view_end := view.position + view.size

	var shift := Vector2.ZERO

	# X
	if panBounds.size.x <= view.size.x:
		shift.x = (panBounds.position.x + panBounds.size.x * 0.5) - (view.position.x + view.size.x * 0.5)
	else:
		if view.position.x < panBounds.position.x:
			shift.x = panBounds.position.x - view.position.x
		elif view_end.x > bounds_end.x:
			shift.x = bounds_end.x - view_end.x

	# Y
	if panBounds.size.y <= view.size.y:
		shift.y = (panBounds.position.y + panBounds.size.y * 0.5) - (view.position.y + view.size.y * 0.5)
	else:
		if view.position.y < panBounds.position.y:
			shift.y = panBounds.position.y - view.position.y
		elif view_end.y > bounds_end.y:
			shift.y = bounds_end.y - view_end.y

	if shift != Vector2.ZERO:
		if isDragging:
			offset += shift
			dragStartCameraPos += shift
		else:
			global_position += shift
	
func ClickAndDrag():
	if !isDragging and Input.is_action_just_pressed("camera_pan"):
		dragStartMousePos = get_viewport().get_mouse_position()
		dragStartCameraPos = global_position
		isDragging = true

	if isDragging and Input.is_action_just_released("camera_pan"):
		isDragging = false

	if isDragging:
		var moveVector = get_viewport().get_mouse_position() - dragStartMousePos
		global_position = dragStartCameraPos - moveVector * (1.0 / zoomFactor)
		
func zoom_in_out():
	zoomTarget = clampf(zoomTarget, minZoom, maxZoom)
	var mousePositionBefore = get_global_mouse_position()
	var cameraCenter = self.global_position;
	
	zoom = Vector2(zoomTarget, zoomTarget);
	
	var diff = mousePositionBefore - get_global_mouse_position()
	offset += diff
	
	#print(diff)
	
	

func get_camera_world_rect() -> Rect2:
	var viewport := get_viewport_rect() # size in pixels

	var adjusted_size := viewport.size / zoom
	var center := global_position + offset

	var top_left := center - adjusted_size / 2.0
	return Rect2(top_left, adjusted_size)
