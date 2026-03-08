extends RefCounted
class_name DebugLog

static var COLOR_NAME := "#7dcfff"
static var COLOR_ID_TAIL := "#f4d03f"
static var COLOR_ID_DIM := "#5c6370"

static var ID_TAIL_LEN := 6
static var SHOW_FULL_ID := false


static func debug(...args) -> void:
	_log("DEBUG", "#7f8c8d", args)

static func info(...args) -> void:
	_log("INFO", "#5dade2", args)

static func warn(...args) -> void:
	_log("WARN", "#f4d03f", args)

static func error(...args) -> void:
	_log("ERROR", "#ec7063", args)

static func _log(level: String, color: String, args: Array) -> void:
	var parts := PackedStringArray()
	var stack: Array = []

	for arg in args:
		if _looks_like_stack(arg):
			stack = arg
		else:
			parts.append(_fmt(arg))

	print_rich("[color=%s][%s][/color] %s" % [color, level, " ".join(parts)])

	if not stack.is_empty():
		print_rich(_format_stack(stack))

static func _looks_like_script_instance(value: Variant) -> bool:
	return value is Object and is_instance_valid(value) and value.get_script() is Script

static func _fmt(value: Variant) -> String:
	if value == null:
		return "null"

	if value is Script:
		return _fmt_script(value)

	if value is Object:
		return _fmt_object(value)

	return var_to_str(value)


static func _fmt_script(script: Script) -> String:
	if script == null:
		return "<null script>"

	return "<[color=%s]%s[/color] %s>" % [
		COLOR_NAME,
		_script_name(script),
		_fmt_id(script.get_instance_id())
	]


static func _fmt_object(obj: Object) -> String:
	if not is_instance_valid(obj):
		return "<freed>"

	var script := obj.get_script() as Script
	if script != null:
		return "<[color=%s]%s[/color] %s>" % [
			COLOR_NAME,
			_script_name(script),
			_fmt_id(obj.get_instance_id())
		]

	return "<%s>" % _fmt_id(obj.get_instance_id())


static func _script_name(script: Script) -> String:
	var global_name := String(script.get_global_name())
	if not global_name.is_empty():
		return global_name

	var path := String(script.resource_path)
	if not path.is_empty():
		return path.get_file().get_basename()

	return "script"


static func _fmt_id(id: int) -> String:
	var s := str(abs(id))
	var split := s.length() - ID_TAIL_LEN

	if split < 0:
		split = 0

	var head := s.substr(0, split)
	var tail := s.substr(split)

	if SHOW_FULL_ID:
		if head.is_empty():
			return "[color=%s]%s[/color]" % [COLOR_ID_TAIL, tail]
		return "[color=%s]%s[/color][color=%s]%s[/color]" % [
			COLOR_ID_DIM, head,
			COLOR_ID_TAIL, tail
		]

	return "[color=%s]%s[/color]" % [COLOR_ID_TAIL, tail]

static func _looks_like_stack(value: Variant) -> bool:
	if not (value is Array):
		return false

	var arr: Array = value
	if arr.is_empty():
		return false

	var first = arr[0]
	return first is Dictionary \
		and first.has("source") \
		and first.has("line") \
		and first.has("function")

static func _format_stack(stack: Array) -> String:
	var lines := PackedStringArray()
	lines.append("[color=#aab7b8]Stack trace:[/color]")

	for i in range(stack.size()):
		var frame: Dictionary = stack[i]
		lines.append(
			"  [color=#7f8c8d]#%d[/color] [color=#5dade2]%s[/color]:[color=#f4d03f]%s[/color] in [b]%s()[/b]" % [
				i,
				str(frame.get("source", "<unknown>")),
				str(frame.get("line", "?")),
				str(frame.get("function", "<unknown>"))
			]
		)

	return "\n".join(lines)
