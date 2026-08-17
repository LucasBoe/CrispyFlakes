extends RefCounted

## Demo campaign's story-beat entries, same _encounter()/_choice() shape as
## EncounterCatalog, plus a "trigger_condition" Callable per entry deciding
## when the beat fires. Loaded by ScenarioHandler via story_beat_script.new().

func load_entries() -> Array[Dictionary]:
	return [
		_beat(
			"welcome",
			"Well now, look who's setting up shop. Word is you're aiming to build the finest saloon this side of the river. Let's see if you've got the grit for it.",
			[
				_choice("Let's get started", 0, "Good. Sundown's coming quicker than you think."),
			],
			func() -> bool: return true
		),
	]

func _beat(
	entry_id: String,
	line: String,
	choices: Array[Dictionary],
	trigger_condition: Callable,
	name: String = "Stranger",
	appearance_id: String = "",
) -> Dictionary:
	return {
		"id": entry_id,
		"name": name,
		"line": line,
		"choices": choices,
		"appearance_id": appearance_id,
		"trigger_condition": trigger_condition,
	}

func _choice(text: String, money_delta: int, outcome_text: String, effects: Array[Callable] = []) -> Dictionary:
	return {
		"text": text,
		"money_delta": money_delta,
		"effects": effects,
		"outcome_text": outcome_text,
	}
