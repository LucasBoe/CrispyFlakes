extends Node

func _ready():
	# Force pixel-perfect rendering on all fonts before any glyphs are rasterized.
	# Godot resets .import files on reimport so this is more reliable than import settings.
	var pixel_fonts: Array[String] = [
		"res://assets/fonts/Micro5-Regular.ttf",
		"res://assets/fonts/Cubix.ttf",
		"res://assets/fonts/Cubix_Mystical.ttf",
	]
	for path in pixel_fonts:
		var font: FontFile = load(path)
		if font == null:
			continue
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.oversampling = 1.0

var ItemSpawner : ItemSpawner
var NPCSpawner : NPCSpawner
var UI : UIHolder

var should_auto_spawn_guests = false

const DAY_DURATION = 60.0
const LEAVE_POSITION = Vector2(512, 0)

var time_now: float = 0.0

func _physics_process(delta: float) -> void:
	time_now += delta

func _input(event):
	if event.is_action_released("toggle_dev_console"):
		Console.toggle_console()
