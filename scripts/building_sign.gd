extends Node2D
class_name BuildingSign

@onready var _label: Label = $Label
@onready var _sign_rect: NinePatchRect = $Sprite2D
@onready var _area: Area2D = $Area2D
@onready var _collision: CollisionShape2D = $Area2D/CollisionShape2D

var saloon_name: String = "My Saloon"
var _tween: Tween
var _outline_material: ShaderMaterial

func _ready():
	_label.text = saloon_name
	_area.input_event.connect(_on_area_input)
	_area.mouse_entered.connect(_on_mouse_entered)
	_area.mouse_exited.connect(_on_mouse_exited)
	_outline_material = (load("res://assets/materials/mat_outline_outside_rooms.tres") as ShaderMaterial).duplicate(true)
	_sign_rect.material = _outline_material
	_update_sign_size()

func set_target_position(target: Vector2):
	if not visible:
		position = target
		visible = true
		return
	if (position - target).length_squared() < 1.0:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", target, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func set_saloon_name(new_name: String):
	saloon_name = new_name
	_label.text = new_name
	_update_sign_size()

func _update_sign_size():
	var font: Font = _label.get_theme_font("font")
	if font == null:
		return
	var font_size: int = _label.get_theme_font_size("font_size")
	var text_w: float = font.get_string_size(saloon_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# patch margins are 16px each side; add 16px inner breathing room
	var sign_w: float = maxf(64.0, text_w + 16.0)
	var half_w: float = sign_w / 2.0

	_sign_rect.custom_minimum_size.x = sign_w
	_sign_rect.offset_left = -half_w
	_sign_rect.offset_right = half_w

	# label stays 8px inside the patch edges
	_label.offset_left = -half_w + 8.0
	_label.offset_right = half_w - 8.0

	(_collision.shape as RectangleShape2D).size.x = sign_w

func _on_mouse_entered() -> void:
	_outline_material.set_shader_parameter("outline_color", Color.WHITE)

func _on_mouse_exited() -> void:
	_outline_material.set_shader_parameter("outline_color", Color.BLACK)

func _on_area_input(_viewport: Viewport, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Global.UI.rename.show_rename(saloon_name, func(new_name: String): set_saloon_name(new_name))
