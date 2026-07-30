extends Node

## Central switchboard for large, still-settling systems (temperature,
## upcoming room types, ...) so a whole feature can be disabled cleanly while
## it's being built or if it's causing regressions, instead of commenting out
## autoloads/scenes by hand or ripping code out mid-development.
##
## This node does not enforce anything by itself — each system checks
## is_enabled() at its own real entry points (an autoload's _process, a UI
## widget's visibility, a shader parameter) and no-ops/hides itself when
## disabled. Add a new Feature entry whenever starting one of these systems.

enum Feature {
	TEMPERATURE_SYSTEM,
	## Auto-triggered special/narrative NPC encounters. Naturally requires
	## get_active_guest_count() >= 10 — see _meets_natural_condition().
	SPECIAL_ENCOUNTERS,
	## Regular ongoing guest spawning. Off by default; the tutorial flips it
	## on the same way anything else would (a plain set_enabled call), it's
	## not a separate dedicated flag anymore.
	GUEST_AUTO_SPAWN,
	## NPC injuries. Naturally requires the infirmary to be unlockable.
	INJURY_SYSTEM,
	## Guests randomly rolling as robbers. Naturally requires enough
	## guests/workers around and >500 money in the bank.
	ROBBER_SPAWN,
}

const _NAMES := {
	Feature.TEMPERATURE_SYSTEM: "temperature_system",
	Feature.SPECIAL_ENCOUNTERS: "special_encounters",
	Feature.GUEST_AUTO_SPAWN: "guest_auto_spawn",
	Feature.INJURY_SYSTEM: "injury_system",
	Feature.ROBBER_SPAWN: "robber_spawn",
}

## Default on/off state per feature, used whenever there's no manual
## override AND (for features with one) the natural condition below is met.
## Flip here for a persistent default; use the console command below for a
## quick runtime toggle instead.
const _DEFAULTS := {
	Feature.TEMPERATURE_SYSTEM: false,
	Feature.SPECIAL_ENCOUNTERS: true,
	Feature.GUEST_AUTO_SPAWN: false,
	Feature.INJURY_SYSTEM: true,
	Feature.ROBBER_SPAWN: true,
}

const ROBBER_SPAWN_MIN_MONEY := 500

signal feature_changed_signal(feature: Feature, enabled: bool)

## Explicit console/set_enabled overrides — these win outright over the
## natural condition (that's the whole point of gate_unlock/gate_status for
## testing: you can force something on before the player has actually
## earned it, or force something off despite having earned it).
var _overrides: Dictionary = {}

func _ready() -> void:
	Console.add_command(
		"feature",
		_console_feature,
		["name", "on_off"],
		0,
		"Usage: feature [name] [on|off]. No args lists all gates; one arg shows its state; two toggles it."
	)
	Console.add_command(
		"gate_status",
		_console_gate_status,
		[],
		0,
		"Lists every feature gate and whether it's ON or OFF."
	)
	Console.add_command(
		"gate_unlock",
		_console_gate_unlock,
		["name"],
		1,
		"Turns a specific feature gate ON."
	)

func is_enabled(feature: Feature) -> bool:
	if _overrides.has(feature):
		return _overrides[feature]
	return _DEFAULTS.get(feature, true) and _meets_natural_condition(feature)

func set_enabled(feature: Feature, enabled: bool) -> void:
	if is_enabled(feature) == enabled:
		return
	_overrides[feature] = enabled
	feature_changed_signal.emit(feature, enabled)

## Whatever real-game-state condition each feature was gated on before this
## handler existed, lives here now instead of being duplicated at each call
## site — this is the actual point of a gate handler: is_enabled() alone
## should be able to answer "is this on," not just half of the answer.
func _meets_natural_condition(feature: Feature) -> bool:
	match feature:
		Feature.SPECIAL_ENCOUNTERS:
			return is_instance_valid(Global.NPCSpawner) and Global.NPCSpawner.get_active_guest_count() >= 10
		Feature.ROBBER_SPAWN:
			return is_instance_valid(Global.NPCSpawner) \
				and Global.NPCSpawner.guests.size() > 10 \
				and Global.NPCSpawner.workers.size() > 2 \
				and ResourceHandler.has_money(ROBBER_SPAWN_MIN_MONEY)
		Feature.INJURY_SYSTEM:
			var infirmary_room_data := load(InjuryHandler.INFIRMARY_ROOM_DATA_PATH) as RoomData
			return infirmary_room_data != null and ProgressionHandler.is_room_build_unlocked(infirmary_room_data)
		_:
			return true

func _console_feature(feature_name: String = "", on_off: String = "") -> void:
	if feature_name.is_empty():
		for feature in _NAMES:
			Console.print_line("%s: %s" % [_NAMES[feature], "ON" if is_enabled(feature) else "OFF"])
		return

	var feature = _find_feature_by_name(feature_name)
	if feature == null:
		Console.print_line("Unknown feature '%s'." % feature_name)
		return

	if not on_off.is_empty():
		var enabled := on_off.to_lower() in ["on", "true", "1", "enable", "enabled"]
		set_enabled(feature, enabled)

	Console.print_line("%s: %s" % [feature_name, "ON" if is_enabled(feature) else "OFF"])

func _console_gate_status(_unused: String = "") -> void:
	for feature in _NAMES:
		Console.print_line("%s: %s" % [_NAMES[feature], "ON" if is_enabled(feature) else "OFF"])

func _console_gate_unlock(feature_name: String) -> void:
	var feature = _find_feature_by_name(feature_name)
	if feature == null:
		Console.print_line("Unknown feature '%s'." % feature_name)
		return
	set_enabled(feature, true)
	Console.print_line("%s: ON" % feature_name)

func _find_feature_by_name(feature_name: String):
	for feature in _NAMES:
		if _NAMES[feature] == feature_name:
			return feature
	return null
