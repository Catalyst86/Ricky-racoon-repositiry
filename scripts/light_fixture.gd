@tool
extends Node3D
## Light fixture controller. Drives every SpotLight3D / OmniLight3D under this
## node from a single set of Inspector knobs. Drop on a Node3D that has lights
## as descendants — adjust color/energy/cone/range from the Inspector and every
## bulb updates live in the editor.

@export var light_color: Color = Color(1.0, 0.85, 0.7) :
	set(value):
		light_color = value
		_apply()

@export_range(0.0, 50.0, 0.1) var energy: float = 8.0 :
	set(value):
		energy = value
		_apply()

@export_range(5.0, 90.0, 0.5) var cone_angle_deg: float = 35.0 :
	set(value):
		cone_angle_deg = value
		_apply()

@export_range(1.0, 50.0, 0.5) var light_range: float = 12.0 :
	set(value):
		light_range = value
		_apply()

@export var cast_shadows: bool = true :
	set(value):
		cast_shadows = value
		_apply()

@export var enabled: bool = true :
	set(value):
		enabled = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return
	for child in find_children("*", "SpotLight3D", true, false):
		var sl: SpotLight3D = child
		sl.light_color = light_color
		sl.light_energy = energy if enabled else 0.0
		sl.spot_angle = cone_angle_deg
		sl.spot_range = light_range
		sl.shadow_enabled = cast_shadows and enabled
		sl.visible = enabled
	for child in find_children("*", "OmniLight3D", true, false):
		var ol: OmniLight3D = child
		ol.light_color = light_color
		ol.light_energy = energy if enabled else 0.0
		ol.omni_range = light_range
		ol.shadow_enabled = cast_shadows and enabled
		ol.visible = enabled
	# Drive any "glow" emissive housing (mesh with a metadata tag) so the
	# fixture itself glows when on
	for child in find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		if mi.has_meta("glows") and mi.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = mi.material_override
			mat.emission_enabled = enabled
			mat.emission = light_color
			mat.emission_energy_multiplier = (energy * 0.15) if enabled else 0.0
