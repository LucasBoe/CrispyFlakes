extends GPUParticles2D
class_name FireFlameParticles

@export var min_lifetime := 0.45
@export var max_lifetime := 0.85
@export var h_frames := 6
@export var v_frames := 4
@export var animation_cycles_per_lifetime := 24.0
@export var extinguish_size_power := 2.0

var _size_factor := 0.0
var _source_texture: Texture2D
var _row_texture: AtlasTexture
var _current_row := -1

func _ready() -> void:
	_source_texture = texture
	emitting = false
	_update_particle_material()

func set_fire_state(propagation_ratio: float, extinguish_ratio: float) -> void:
	var propagation_size := lerpf(0.15, 1.0, clampf(propagation_ratio, 0.0, 1.0))
	var extinguish_size := pow(clampf(extinguish_ratio, 0.0, 1.0), extinguish_size_power)
	_size_factor = clampf(propagation_size * extinguish_size, 0.0, 1.0)

	emitting = _size_factor > 0.02
	lifetime = lerpf(min_lifetime, max_lifetime, _size_factor)
	_update_particle_material()

func _update_particle_material() -> void:
	var mat := process_material as ParticleProcessMaterial
	if mat == null:
		return

	var row := _current_size_row()
	_apply_animation_row(row)
	mat.anim_offset_min = 0.0
	mat.anim_offset_max = 1.0
	mat.anim_speed_min = animation_cycles_per_lifetime
	mat.anim_speed_max = animation_cycles_per_lifetime

func _current_size_row() -> int:
	return clampi(roundi(lerpf(float(v_frames - 1), 0.0, _size_factor)), 0, v_frames - 1)

func _apply_animation_row(row: int) -> void:
	if row == _current_row or _source_texture == null:
		return
	_current_row = row

	var frame_height := float(_source_texture.get_height()) / float(v_frames)
	if _row_texture == null:
		_row_texture = AtlasTexture.new()
		_row_texture.atlas = _source_texture

	_row_texture.region = Rect2(0.0, frame_height * float(row), float(_source_texture.get_width()), frame_height)
	texture = _row_texture

	var canvas_mat := material as CanvasItemMaterial
	if canvas_mat == null:
		return
	canvas_mat.particles_animation = true
	canvas_mat.particles_anim_h_frames = h_frames
	canvas_mat.particles_anim_v_frames = 1
