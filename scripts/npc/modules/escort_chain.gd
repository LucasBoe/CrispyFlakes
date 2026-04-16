extends Node2D
class_name EscortChain

const CHAIN_TEXTURE := preload("res://assets/sprites/chain.png")
const HANDCUFF_OFFSET := Vector2(0, 1)
const TARGET_OFFSET := Vector2(0, -9)

var subject: NPC = null
var handcuffs: Node2D = null
var target: NPC = null

func _ready() -> void:
	z_as_relative = true
	z_index = -1
	show_behind_parent = true

func _process(_delta: float) -> void:
	visible = _can_draw_chain()
	queue_redraw()

func set_target(new_target: NPC) -> void:
	target = new_target
	visible = _can_draw_chain()

func clear_target() -> void:
	target = null
	visible = false

func _draw() -> void:
	if not _can_draw_chain():
		visible = false
		return

	visible = true

	var start := to_local(handcuffs.global_position + HANDCUFF_OFFSET)
	var end := to_local(target.global_position + TARGET_OFFSET)
	var chain := end - start
	var distance := chain.length()
	if distance < 1.0:
		return

	var direction := chain / distance
	var angle := direction.angle()
	var segment_width := maxf(1.0, float(CHAIN_TEXTURE.get_width()))
	var segment_height := float(CHAIN_TEXTURE.get_height())
	var drawn := 0.0

	while drawn < distance:
		var remaining := minf(segment_width, distance - drawn)
		var center := start + direction * (drawn + remaining * 0.5)
		draw_set_transform(center, angle, Vector2.ONE)
		draw_texture_rect_region(
			CHAIN_TEXTURE,
			Rect2(Vector2(-remaining * 0.5, -segment_height * 0.5), Vector2(remaining, segment_height)),
			Rect2(Vector2.ZERO, Vector2(remaining, segment_height))
		)
		drawn += remaining

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _can_draw_chain() -> bool:
	return (
		is_instance_valid(subject)
		and is_instance_valid(handcuffs)
		and is_instance_valid(target)
		and handcuffs.visible
	)
