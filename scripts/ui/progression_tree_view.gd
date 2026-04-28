extends Control

const NODE_W := 48
const NODE_H := 48
const H_GAP := 24
const V_GAP := 48

const CONNECTOR_DOWN    := preload("res://assets/sprites/ui/2x/tree_connector_down.png")
const CONNECTOR_LEFT    := preload("res://assets/sprites/ui/2x/tree_connector_left.png")
const CONNECTOR_RIGHT   := preload("res://assets/sprites/ui/2x/tree_connector_right.png")
const ITEM_BUTTON       := preload("res://scenes/ui/progression_item_button.tscn")
const BTN_FILLED        := preload("res://assets/sprites/ui/2x/tree_filled_button.png")
const BTN_EMPTY         := preload("res://assets/sprites/ui/2x/tree_empty_button.png")
const TREE_LAYOUTER     := preload("res://scripts/ui/progression_tree_layouter.gd")

const ALL_ITEMS := [
	preload("res://assets/resources/progression/prog_empty_room.tres"),
	preload("res://assets/resources/progression/prog_tables.tres"),
	preload("res://assets/resources/progression/prog_stairs.tres"),
	preload("res://assets/resources/progression/prog_outhouse.tres"),
	preload("res://assets/resources/progression/prog_bar.tres"),
	preload("res://assets/resources/progression/prog_broom_room.tres"),
	preload("res://assets/resources/progression/prog_entertainment.tres"),
	preload("res://assets/resources/progression/prog_horsestand.tres"),
	preload("res://assets/resources/progression/prog_water_tower.tres"),
	preload("res://assets/resources/progression/prog_bed_room.tres"),
	preload("res://assets/resources/progression/prog_storage.tres"),
	preload("res://assets/resources/progression/prog_brewery.tres"),
	preload("res://assets/resources/progression/prog_bouncer.tres"),
	preload("res://assets/resources/progression/prog_gambling.tres"),
	preload("res://assets/resources/progression/prog_stables.tres"),
	preload("res://assets/resources/progression/prog_toilets.tres"),
	preload("res://assets/resources/progression/prog_aging_cellar.tres"),
	preload("res://assets/resources/progression/prog_destillery.tres"),
	preload("res://assets/resources/progression/prog_prison.tres"),
	preload("res://assets/resources/progression/prog_safe.tres"),
	preload("res://assets/resources/progression/prog_bath.tres"),
	preload("res://assets/resources/progression/prog_big_brewer.tres"),
]

@onready var _content:        Control       = $MarginContainer/MarginContainer/VBoxContainer/PanCanvas/Content
@onready var _sidebar:        Control       = $MarginContainer/SidePanel
@onready var _close_button:   Button        = %CloseButton
@onready var _points_label:   RichTextLabel = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer/MarginContainer/Label
@onready var _points_btn:     NinePatchRect = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer/NinePatchRect

var _positions: Dictionary = {}
var _connectors: Dictionary = {}

func _ready() -> void:
	var tree_layout = TREE_LAYOUTER.new(ALL_ITEMS, NODE_W, NODE_H, H_GAP, V_GAP)
	tree_layout.build()
	_positions = tree_layout.positions
	tree_layout.spawn_connectors(_content, CONNECTOR_DOWN, CONNECTOR_LEFT, CONNECTOR_RIGHT)
	_connectors = tree_layout.connectors
	_spawn_buttons()
	_sidebar.z_index = 2
	_close_button.pressed.connect(hide)
	ProgressionHandler.points_changed.connect(_on_points_changed)
	_on_points_changed(ProgressionHandler.get_points())

func _on_points_changed(pts: int) -> void:
	var has_points := pts > 0
	if has_points:
		_points_label.text = "Points available: [color=#ff0055]%d[/color]" % pts
	else:
		_points_label.text = "[color=#888888]Points available: 0[/color]"
	_points_btn.texture = BTN_FILLED if has_points else BTN_EMPTY
	(_points_btn.material as ShaderMaterial).set_shader_parameter("is_unlocked", has_points)

func _spawn_buttons() -> void:
	for item: ProgressionItem in ALL_ITEMS:
		var btn: Control = ITEM_BUTTON.instantiate()
		btn.position = _positions[item]
		_content.add_child(btn)
		btn.setup(item, _connectors.get(item))
		btn.item_selected.connect(_sidebar.on_item_selected)
