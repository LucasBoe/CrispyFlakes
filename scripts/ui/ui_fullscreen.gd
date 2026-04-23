extends Control
class_name UIFullscreen

@onready var _version_label: Label = $VersionLabel


func _ready():
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	if version.is_empty():
		_version_label.hide()
		return

	_version_label.text = "v%s" % version
