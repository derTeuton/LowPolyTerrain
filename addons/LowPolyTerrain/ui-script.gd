extends EditorInspectorPlugin

func _can_handle(_object): return _object is LowPolyTerrain

func _parse_property(
	_object: Object, _type: Variant.Type, _name: String, 
	_hint_type: PropertyHint, _hint_string: String, _usage_flags, _wide: bool):
		
		if _name == "generate_button":
			var button : Button = Button.new()
			button.text = "Generate Terrain"
			button.pressed.connect(func _on_pressed(): _object.emit_signal("generate") )
			add_custom_control(button)
			return true
