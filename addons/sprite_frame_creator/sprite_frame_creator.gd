@tool
extends EditorPlugin

var import_plugin

# preload custom class
const mg_script = preload("res://addons/sprite_frame_creator/mg_spriteframes.gd")
const mg_icon = preload("res://icon.svg")


func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	import_plugin = preload("import_plugin.gd").new()
	add_import_plugin(import_plugin)
	add_custom_type("MGSpriteFrames", "SpriteFrames", mg_script, mg_icon)


func _exit_tree() -> void:
	remove_import_plugin(import_plugin)
	remove_custom_type("MGSpriteFrames")
	import_plugin = null
