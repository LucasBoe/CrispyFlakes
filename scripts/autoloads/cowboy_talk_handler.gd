extends Node

const BUBBLE_DURATION := 4.0

var show_talk: bool = false

func _ready() -> void:
	Console.add_command("talk", _console_toggle_talk, 0, 0, "Toggles cowboy talk notifications.")

func talk(text: String, npc: Node2D) -> void:
	if not show_talk:
		return
	var parts := _split_sentences(text)
	if parts.size() <= 1:
		UiNotifications.create_notification_dynamic(text, npc, Vector2(0, -32), null, Color.BLACK, BUBBLE_DURATION)
		return
	_show_sequentially(parts, npc)

func _show_sequentially(parts: Array, npc: Node2D) -> void:
	for part: String in parts:
		if not is_instance_valid(npc):
			return
		UiNotifications.create_notification_dynamic(part, npc, Vector2(0, -32), null, Color.BLACK, BUBBLE_DURATION)
		await get_tree().create_timer(BUBBLE_DURATION + 0.3).timeout

func _split_sentences(text: String) -> Array:
	var result: Array = []
	var current := ""
	for i in text.length():
		current += text[i]
		if text[i] in [".", "?", "!"] and (i + 1 >= text.length() or text[i + 1] == " "):
			var trimmed := current.strip_edges()
			if trimmed != "":
				result.append(trimmed)
			current = ""
	var remainder := current.strip_edges()
	if remainder != "":
		result.append(remainder)
	return result if result.size() > 0 else [text]

func _console_toggle_talk() -> void:
	show_talk = !show_talk
	Console.print_line("Cowboy talk " + ("ON" if show_talk else "OFF"))
