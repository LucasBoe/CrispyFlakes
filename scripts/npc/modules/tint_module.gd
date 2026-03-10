class_name TintModule

var npc : NPC
var active_tints = {}
var active_outlines = {}

func _init(_npc):
	npc = _npc

func add_tint(color : Color, priority : int, author):
	var tint = color_info.new(self, color, priority)
	active_tints[author] = tint
	refresh_active_tint()
	
func remove_tint_for(author):
	if active_tints.has(author):
		active_tints.erase(author)
		refresh_active_tint()
	
func refresh_active_tint():
	var highest_prio = -1
	var highest_color = Color.WHITE
	
	for tint : color_info in active_tints.values():
		if tint.priority > highest_prio:
			highest_prio = tint.priority
			highest_color = tint.color
	
	npc.Animator.modulate = highest_color

func add_outline(color : Color, priority : int, author):
	var outline = color_info.new(self, color, priority)
	active_outlines[author] = outline
	refresh_active_outline()

func remove_outline_for(author):
	if active_outlines.has(author):
		active_outlines.erase(author)
		refresh_active_outline()

func refresh_active_outline():
	var highest_prio = -1
	var highest_color = Color.BLACK

	for outline : color_info in active_outlines.values():
		if outline.priority > highest_prio:
			highest_prio = outline.priority
			highest_color = outline.color

	set_material_outline_color(highest_color)
	
func set_material_outline_color(color):
	if npc.Animator.material == null:
		return
	
	var mat := npc.Animator.material as ShaderMaterial
	if mat == null:
		return
		
	mat.set_shader_parameter("outline_color", color)
	
class color_info:
	var module : TintModule
	var color : Color
	var priority : int
	
	func _init(_module, _color, _priority):
		module = _module
		color = _color
		priority = _priority
		
	func destroy(author):
		if _try_delete_from(module.active_tints, author):
			module.refresh_active_tint()
			
		if _try_delete_from(module.active_outlines, author):
			module.refresh_active_outline()

	func _try_delete_from(dict, author):
		if dict.has(author):
			dict.erase(author)
