extends RoomBase
class_name RoomKitchen

const TIMEOUT_DURATION_IN_MSEC := 10000
const LOAD_DURATION := 2.5
const COOK_DURATION := 6.0
const SOUP_BATCH_SIZE := 5
const SERVICE_PRICE := 7

const STOVE_BACK_OFF_TEX := preload("res://assets/sprites/rooms/kitchen_stove_back_offt.png")
const STOVE_BACK_ON_TEX := preload("res://assets/sprites/rooms/kitchen_stove_back_on.png")
const SOUP_BOWL_TEX := preload("res://assets/sprites/item_soup_bowl.png")
const AURA_TEXTURE := preload("res://assets/sprites/sun.png")
const AURA_POSITION := Vector2(33.0, -10.0)
const AURA_TINT := Color(1.0, 0.74, 0.38, 1.0)
# Bottom row of three on the table top, then two stacked on top.
const _TABLE_BOWL_POSITIONS := [
	Vector2(8, -13.5), Vector2(16, -13.5), Vector2(24, -13.5),
	Vector2(12, -17.5), Vector2(20, -17.5),
]

var soup_requests: Array[SoupRequest] = []
var soups_available: int = 0

var water_loaded := false
var fuel_loaded := false

var _table_bowls: Array[Sprite2D] = []
var _overlay_light_registered := false

func init_room(_x: int, _y: int) -> void:
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.KITCHEN
	# Shift the right flame half an animation cycle so the pair doesn't flicker in sync.
	var flame_right: GPUParticles2D = $BurningEffects/FlameRight
	var flame_material := flame_right.process_material.duplicate() as ParticleProcessMaterial
	flame_material.anim_offset_min = 0.5
	flame_material.anim_offset_max = 0.5
	flame_right.process_material = flame_material
	for pos in _TABLE_BOWL_POSITIONS:
		var bowl := Sprite2D.new()
		bowl.texture = SOUP_BOWL_TEX
		bowl.position = pos
		bowl.z_index = -9
		add_child(bowl)
		_table_bowls.append(bowl)
	_refresh_visuals()

func _exit_tree() -> void:
	RoomTemperatureOverlayHandler.unregister_light_input(self)

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func uses_infrastructure_layer(layer_name: StringName) -> bool:
	return layer_name == &"water" and Building.infrastructure.room_has_service(self, &"water")

func wants_infrastructure_layer(layer_name: StringName) -> bool:
	return layer_name == &"water"

func request_soup(_requestor) -> SoupRequest:
	var request := SoupRequest.new()
	request.status = Enum.RequestStatus.OPEN
	request.time = Time.get_ticks_msec()
	soup_requests.append(request)
	return request

func fulfill_next_request() -> void:
	if soup_requests.is_empty() or soups_available <= 0:
		return
	var req := soup_requests[0] as SoupRequest
	req.status = Enum.RequestStatus.FULFILLED
	soup_requests.erase(req)
	soups_available -= 1
	_refresh_visuals()

func has_pending_requests() -> bool:
	return not soup_requests.is_empty()

func has_available_soup() -> bool:
	return soups_available > 0

func load_water() -> void:
	water_loaded = true
	_refresh_visuals()

func load_fuel() -> void:
	fuel_loaded = true
	_refresh_visuals()

## One water and one fuel cook a full batch; the next batch starts once the pot is empty.
func can_cook_batch() -> bool:
	return water_loaded and fuel_loaded and soups_available == 0

func cook_batch() -> void:
	water_loaded = false
	fuel_loaded = false
	soups_available += SOUP_BATCH_SIZE
	_refresh_visuals()

func _refresh_visuals() -> void:
	$StovePot.visible = water_loaded
	$StoveBack.texture = STOVE_BACK_ON_TEX if fuel_loaded else STOVE_BACK_OFF_TEX
	for i in _table_bowls.size():
		_table_bowls[i].visible = i < soups_available
	for child in $BurningEffects.get_children():
		(child as GPUParticles2D).emitting = fuel_loaded
	_sync_overlay_light()

func _sync_overlay_light() -> void:
	if fuel_loaded == _overlay_light_registered:
		return
	_overlay_light_registered = fuel_loaded
	if fuel_loaded:
		RoomTemperatureOverlayHandler.register_light_input(self, self, AURA_TEXTURE, global_position + AURA_POSITION, AURA_TINT)
	else:
		RoomTemperatureOverlayHandler.unregister_light_input(self)

func get_sale_price() -> int:
	return SERVICE_PRICE

func _process_requests_timeout() -> void:
	var now := Time.get_ticks_msec()
	var expired: Array[SoupRequest] = []
	for request in soup_requests:
		if now - request.time > TIMEOUT_DURATION_IN_MSEC:
			expired.append(request)
	for request in expired:
		request.status = Enum.RequestStatus.TIMEOUT
		soup_requests.erase(request)

func _physics_process(_delta: float) -> void:
	_process_requests_timeout()

class SoupRequest:
	var time: float
	var status: Enum.RequestStatus
