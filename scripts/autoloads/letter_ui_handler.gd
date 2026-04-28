extends CanvasLayer

signal presentation_finished

enum State { IDLE, ENTERING, CLOSED, OPENING, OPENED, SHEET_RISING, SHEET_FULL, DISMISSING }

@onready var _background: ColorRect = $Background
@onready var _letter_anchor: Node2D = $LetterAnchor
@onready var _letter_hover: Node2D = $LetterAnchor/LetterHover
@onready var _letter_closed: Sprite2D = $LetterAnchor/LetterHover/LetterClosed
@onready var _letter_opened_bg: Sprite2D = $LetterAnchor/LetterHover/LetterOpenedBg
@onready var _letter_opened_fg: Sprite2D = $LetterAnchor/LetterHover/LetterOpenedFg
@onready var _sheet_wrapper: Node2D = $LetterAnchor/LetterHover/SheetWrapper
@onready var _sheet: NinePatchRect = $LetterAnchor/LetterHover/SheetWrapper/Sheet
@onready var _sheet_label: RichTextLabel = $LetterAnchor/LetterHover/SheetWrapper/Sheet/MarginContainer/SheetLabel

var _state: State = State.IDLE
var _hover_tween: Tween
var _sheet_hover_tween: Tween
var _letter_hovered: bool = false
var _sheet_hovered: bool = false
var _letter_mat: ShaderMaterial
var _sheet_mat: ShaderMaterial

const LETTER_CENTER: Vector2 = Vector2(640.0, 360.0)
const LETTER_ENTER_FROM_Y: float = 1080.0

const SHEET_INITIAL_SIZE: Vector2 = Vector2(256.0, 192.0)
const SHEET_FULL_SIZE: Vector2 = Vector2(400.0, 300.0)
const SHEET_WRAPPER_HIDDEN: Vector2 = Vector2(-128.0, -32.0)
const SHEET_WRAPPER_PEEK: Vector2 = Vector2(-128.0, -48.0)
const SHEET_WRAPPER_HOVER_PEEK: Vector2 = Vector2(-128.0, -64.0)
const SHEET_WRAPPER_FULL: Vector2 = Vector2(-200.0, -150.0)

const HOVER_AMPLITUDE: float = 8.0
const HOVER_DURATION: float = 1.2


func _ready() -> void:
	visible = false
	_letter_mat = _letter_closed.material as ShaderMaterial
	_sheet_mat = _sheet.material as ShaderMaterial


func present() -> void:
	visible = true
	get_tree().paused = true
	_reset_nodes()
	_state = State.ENTERING
	_animate_in()
	await presentation_finished


func skip() -> void:
	if _state == State.IDLE:
		return
	visible = false
	get_tree().paused = false
	_state = State.IDLE
	presentation_finished.emit()


func _reset_nodes() -> void:
	_letter_anchor.position = Vector2(LETTER_CENTER.x, LETTER_ENTER_FROM_Y)
	_letter_anchor.modulate.a = 0.0
	_background.color = Color(0.0, 0.0, 0.0, 0.0)
	_letter_hover.position = Vector2.ZERO
	_letter_closed.visible = true
	_letter_opened_bg.visible = false
	_letter_opened_bg.modulate.a = 1.0
	_letter_opened_bg.position = Vector2.ZERO
	_letter_opened_fg.visible = false
	_letter_opened_fg.modulate.a = 1.0
	_letter_opened_fg.position = Vector2.ZERO
	_sheet_wrapper.visible = false
	_sheet_wrapper.position = SHEET_WRAPPER_HIDDEN
	_sheet.size = SHEET_INITIAL_SIZE
	_sheet.visible = false
	_sheet_label.add_theme_font_size_override("normal_font_size", 9)
	_letter_hovered = false
	_sheet_hovered = false
	_letter_mat.set_shader_parameter("outline_color", Color.BLACK)
	_sheet_mat.set_shader_parameter("outline_color", Color.BLACK)


func _animate_in() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_letter_anchor, "rotation", 0.1, 0.6)
	tween.tween_property(_background, "color", Color(0.0, 0.0, 0.0, 0.5), 0.5)
	tween.tween_property(_letter_anchor, "position:y", LETTER_CENTER.y, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)
	tween.tween_property(_letter_anchor, "modulate:a", 1.0, 0.4).set_delay(0.1)
	await tween.finished
	_state = State.CLOSED
	_start_letter_hover()


func _start_letter_hover() -> void:
	if _hover_tween:
		_hover_tween.kill()
	_letter_hover.position.y = 0.0
	_hover_tween = create_tween().set_loops()
	_hover_tween.tween_property(_letter_hover, "position:y", -HOVER_AMPLITUDE, HOVER_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hover_tween.tween_property(_letter_hover, "position:y", HOVER_AMPLITUDE, HOVER_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_hover() -> void:
	if _hover_tween:
		_hover_tween.kill()
		_hover_tween = null
	var snap: Tween = create_tween()
	snap.tween_property(_letter_hover, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_SINE)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseMotion:
		_handle_hover((event as InputEventMouseMotion).position)
		return

	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return

	match _state:
		State.CLOSED:
			_on_letter_clicked()
		State.OPENED:
			_on_sheet_clicked()
		State.SHEET_FULL:
			_on_dismiss_clicked()


func _handle_hover(vp_pos: Vector2) -> void:
	match _state:
		State.CLOSED:
			var over: bool = _point_in_sprite(_letter_closed, vp_pos)
			if over != _letter_hovered:
				_letter_hovered = over
				_letter_mat.set_shader_parameter("outline_color", Color.WHITE if over else Color.BLACK)

		State.OPENED:
			var over: bool = _point_in_control(_sheet, vp_pos)
			if over and not _sheet_hovered:
				_sheet_hovered = true
				_sheet_mat.set_shader_parameter("outline_color", Color.WHITE)
				if _sheet_hover_tween:
					_sheet_hover_tween.kill()
				_sheet_hover_tween = create_tween()
				_sheet_hover_tween.tween_property(_sheet_wrapper, "position", SHEET_WRAPPER_HOVER_PEEK, 0.2) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			elif not over and _sheet_hovered:
				_sheet_hovered = false
				_sheet_mat.set_shader_parameter("outline_color", Color.BLACK)
				if _sheet_hover_tween:
					_sheet_hover_tween.kill()
				_sheet_hover_tween = create_tween()
				_sheet_hover_tween.tween_property(_sheet_wrapper, "position", SHEET_WRAPPER_PEEK, 0.2) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		State.SHEET_FULL:
			var over: bool = _point_in_control(_sheet, vp_pos)
			if over != _sheet_hovered:
				_sheet_hovered = over
				_sheet_mat.set_shader_parameter("outline_color", Color.WHITE if over else Color.BLACK)


func _point_in_sprite(sprite: Sprite2D, vp_pos: Vector2) -> bool:
	if sprite.texture == null or not sprite.visible:
		return false
	var local: Vector2 = sprite.get_global_transform().affine_inverse() * vp_pos
	var half: Vector2 = Vector2(sprite.texture.get_width(), sprite.texture.get_height()) * 0.5
	return Rect2(-half, half * 2.0).has_point(local)


func _point_in_control(ctrl: Control, vp_pos: Vector2) -> bool:
	if not ctrl.visible:
		return false
	var local: Vector2 = ctrl.get_global_transform().affine_inverse() * vp_pos
	return Rect2(Vector2.ZERO, ctrl.size).has_point(local)


func _on_letter_clicked() -> void:
	if _state != State.CLOSED:
		return
	_state = State.OPENING
	_letter_hovered = false
	_stop_hover()

	_letter_closed.visible = false
	_letter_opened_bg.visible = true
	_letter_opened_fg.visible = true
	_sheet_wrapper.visible = true
	_sheet.visible = true
	_sheet_wrapper.position = SHEET_WRAPPER_HIDDEN
	_sheet.size = SHEET_INITIAL_SIZE

	var tween: Tween = create_tween()
	tween.tween_property(_sheet_wrapper, "position", SHEET_WRAPPER_PEEK, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	_state = State.OPENED


func _on_sheet_clicked() -> void:
	if _state != State.OPENED:
		return
	_state = State.SHEET_RISING
	_sheet_hovered = false
	_sheet_mat.set_shader_parameter("outline_color", Color.BLACK)
	if _sheet_hover_tween:
		_sheet_hover_tween.kill()

	var exit_tween: Tween = create_tween().set_parallel(true)
	exit_tween.tween_property(_letter_opened_bg, "position:y", -300.0, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(_letter_opened_fg, "position:y", -300.0, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(_letter_opened_bg, "modulate:a", 0.0, 0.35).set_delay(0.1)
	exit_tween.tween_property(_letter_opened_fg, "modulate:a", 0.0, 0.35).set_delay(0.1)
	await exit_tween.finished

	_letter_opened_bg.visible = false
	_letter_opened_fg.visible = false
	_letter_opened_bg.modulate.a = 1.0
	_letter_opened_fg.modulate.a = 1.0
	_letter_opened_bg.position = Vector2.ZERO
	_letter_opened_fg.position = Vector2.ZERO

	var unfold_tween: Tween = create_tween().set_parallel(true)
	unfold_tween.tween_property(_sheet_wrapper, "position", SHEET_WRAPPER_FULL, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	unfold_tween.tween_property(_sheet, "size", SHEET_FULL_SIZE, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	unfold_tween.tween_property(_sheet_label, "theme_override_font_sizes/normal_font_size", 16, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await unfold_tween.finished
	_state = State.SHEET_FULL


func _on_dismiss_clicked() -> void:
	if _state != State.SHEET_FULL:
		return
	_state = State.DISMISSING
	_sheet_hovered = false

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_letter_anchor, "position:x", -800.0, 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_letter_anchor, "modulate:a", 0.0, 0.45).set_delay(0.05)
	tween.tween_property(_background, "color:a", 0.0, 0.6)
	await tween.finished

	visible = false
	get_tree().paused = false
	presentation_finished.emit()
