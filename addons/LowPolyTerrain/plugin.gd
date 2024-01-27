@tool
extends EditorPlugin

var terrain_node_name = "LowPolyTerrain"
var terrain_node_script = preload("res://addons/LowPolyTerrain/terrain-script.gd")
var terrain_node_icon = preload("res://icon.svg") # Platzhalter
var terrain_node_ui_script = preload("res://addons/LowPolyTerrain/ui-script.gd").new()

func _enter_tree(): # Einzug
	add_custom_type(terrain_node_name,"MeshInstance3D",terrain_node_script,terrain_node_icon)
	add_inspector_plugin(terrain_node_ui_script)


func _exit_tree(): # Abzug
	remove_custom_type(terrain_node_name)
	remove_inspector_plugin(terrain_node_ui_script)
