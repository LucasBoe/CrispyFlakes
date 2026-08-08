class_name NPCArchetypeLibrary
extends RefCounted

## Order matches NPCLookInfo.body_type / npc_recolor.gdshader's body_type
## hint_enum: Default, Cowboy, Investor, Farmer, Settler, Outlaw, Miner,
## Undefined.
const PATHS := [
	"res://assets/resources/npc_archetypes/default.tres",
	"res://assets/resources/npc_archetypes/cowboy.tres",
	"res://assets/resources/npc_archetypes/investor.tres",
	"res://assets/resources/npc_archetypes/farmer.tres",
	"res://assets/resources/npc_archetypes/settler.tres",
	"res://assets/resources/npc_archetypes/outlaw.tres",
	"res://assets/resources/npc_archetypes/miner.tres",
	"res://assets/resources/npc_archetypes/undefined.tres",
]

# Loaded lazily (not via preload() consts) so resource loading happens on
# first actual use rather than at script-parse time, avoiding a
# class-resolution ordering race during project startup.
static var _cache: Array = []

static func get_archetype(body_type: int):
	if _cache.is_empty():
		for path in PATHS:
			_cache.append(load(path))
	var index: int = clampi(body_type, 0, PATHS.size() - 1)
	return _cache[index]

## look_info may be an NPCLookInfo, or null (e.g. special NPCs that don't
## use body_type yet) - falls back to the Default archetype in that case.
static func get_archetype_for_look(look_info):
	if look_info == null:
		return get_archetype(0)
	return get_archetype(look_info.body_type)
