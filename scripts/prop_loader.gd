@tool
extends Node3D
## Loads Meshy-generated GLB props and places them in the scene.
##
## USAGE:
## - Click "Rebuild Props" in the Inspector to instantiate every prop listed in
##   PLACEMENTS as a child Node3D with the GLB mesh inside. Save with Ctrl+S and
##   every prop becomes a first-class editable node — drag/scale/rotate each from
##   the 3D viewport.
## - "Clear Props" removes all generated children.
## - Edit a prop's position after baking: just move it in the viewport. The
##   PLACEMENTS dict is only read when rebuilding.
## - Falls back to a labelled placeholder if a GLB isn't downloaded yet.

const MODELS_DIR := "res://assets/models/"

@export_tool_button("Rebuild Props", "Reload") var _rebuild_btn = rebuild_in_editor
@export_tool_button("Clear Props", "Remove") var _clear_btn = clear_children

## Default placements. Each entry: Vector3 pos, Vector3 rot (radians-like degrees),
## float target_size (longest axis scaled to fit this in meters). rot is degrees for readability.
## "file" key overrides the filename (for instancing the same GLB with different placement).
## "no_collide" key skips adding a collider (for tiny decorative items the player can't reach).
const PLACEMENTS := {
	# ==== hero furniture on/around the stage ====
	"curved_desk":        {"pos": Vector3(0.0,   0.35,  -1.0), "rot_deg": Vector3(0,   0, 0), "size": 3.4},
	"leather_armchair_l": {"file": "leather_armchair", "pos": Vector3(-1.5, 0.0,  4.2), "rot_deg": Vector3(0, 195, 0), "size": 0.95},
	"leather_armchair_r": {"file": "leather_armchair", "pos": Vector3( 1.5, 0.0,  4.2), "rot_deg": Vector3(0, 165, 0), "size": 0.95},
	"coffee_table":       {"pos": Vector3(0.0,   0.0,  5.4),  "rot_deg": Vector3(0,  0, 0), "size": 0.7},

	# ==== mezzanine back: row of busts ====
	"bust_1":             {"file": "marble_bust",         "pos": Vector3(-3.0, 4.62, -6.9), "rot_deg": Vector3(0, 180, 0), "size": 0.45, "no_collide": true},
	"bust_2":             {"file": "marble_bust_roman",   "pos": Vector3(-1.8, 4.62, -6.9), "rot_deg": Vector3(0, 180, 0), "size": 0.45, "no_collide": true},
	"bust_3":             {"file": "marble_bust_stoic",   "pos": Vector3(-0.6, 4.62, -6.9), "rot_deg": Vector3(0, 170, 0), "size": 0.45, "no_collide": true},
	"bust_4":             {"file": "marble_bust",         "pos": Vector3( 0.6, 4.62, -6.9), "rot_deg": Vector3(0, 190, 0), "size": 0.45, "no_collide": true},
	"bust_5":             {"file": "marble_bust_general", "pos": Vector3( 1.8, 4.62, -6.9), "rot_deg": Vector3(0, 180, 0), "size": 0.45, "no_collide": true},
	"bust_6":             {"file": "marble_bust_roman",   "pos": Vector3( 3.0, 4.62, -6.9), "rot_deg": Vector3(0, 180, 0), "size": 0.45, "no_collide": true},

	# ==== mezzanine left: industrial miniatures ====
	"oil_derrick":        {"pos": Vector3(-7.5, 4.28, -6.4), "rot_deg": Vector3(0, 40, 0),  "size": 1.2, "no_collide": true},
	"power_line_tower":   {"pos": Vector3(-5.9, 4.28, -6.4), "rot_deg": Vector3(0, 20, 0),  "size": 1.1, "no_collide": true},
	"factory_diorama":    {"pos": Vector3(-4.3, 4.28, -6.4), "rot_deg": Vector3(0, -10, 0), "size": 1.4, "no_collide": true},
	"vintage_train":      {"pos": Vector3(-2.8, 4.28, -6.4), "rot_deg": Vector3(0, 90, 0),  "size": 0.9, "no_collide": true},
	"steam_engine":       {"pos": Vector3(-1.6, 4.28, -6.4), "rot_deg": Vector3(0, 120, 0), "size": 0.7, "no_collide": true},

	# ==== mezzanine right: art deco skyline ====
	"skyline_empire":     {"file": "skyscraper_empire",    "pos": Vector3( 1.8, 4.28, -6.4), "rot_deg": Vector3(0, 15, 0),  "size": 1.8, "no_collide": true},
	"skyline_chrysler":   {"file": "skyscraper_chrysler",  "pos": Vector3( 3.4, 4.28, -6.4), "rot_deg": Vector3(0, -5, 0),  "size": 1.6, "no_collide": true},
	"skyline_woolworth":  {"file": "skyscraper_woolworth", "pos": Vector3( 4.9, 4.28, -6.4), "rot_deg": Vector3(0, 10, 0),  "size": 1.5, "no_collide": true},
	"skyline_artdeco":    {"file": "artdeco_skyscraper",   "pos": Vector3( 6.3, 4.28, -6.4), "rot_deg": Vector3(0, -10, 0), "size": 1.4, "no_collide": true},
	"skyline_artdeco2":   {"file": "artdeco_skyscraper",   "pos": Vector3( 7.6, 4.28, -6.4), "rot_deg": Vector3(0, 20, 0),  "size": 1.1, "no_collide": true},

	# ==== lower left: bookshelf wall ====
	"tall_bookshelf":     {"pos": Vector3(-7.0, 0.0, -5.4), "rot_deg": Vector3(0, 90, 0), "size": 2.3},
	"book_stack_1":       {"file": "book_stack", "pos": Vector3(-7.0, 2.35, -5.4), "rot_deg": Vector3(0, 0, 0), "size": 0.45, "no_collide": true},
	"antique_clock_1":    {"file": "antique_clock", "pos": Vector3(-6.4, 1.1, -5.6), "rot_deg": Vector3(0, 90, 0), "size": 0.3,  "no_collide": true},
	"antique_clock_2":    {"file": "antique_clock", "pos": Vector3(-6.4, 1.7, -5.6), "rot_deg": Vector3(0, 90, 0), "size": 0.3,  "no_collide": true},
	"desk_lamp":          {"pos": Vector3(-4.8, 0.0, -5.4), "rot_deg": Vector3(0, 90, 0), "size": 0.5},
	"picture_frame":      {"pos": Vector3(-9.7, 1.0, -4.0), "rot_deg": Vector3(0, 90, 0), "size": 0.8, "no_collide": true},
	"book_stack_2":       {"file": "book_stack", "pos": Vector3(-4.2, 0.0, -5.4), "rot_deg": Vector3(0, 45, 0), "size": 0.6},

	# ==== lower right: workbench wall ====
	"workbench":          {"pos": Vector3( 7.0, 0.0, -4.5), "rot_deg": Vector3(0, -90, 0), "size": 2.4},

	# ==== wall decor ====
	"framed_world_map":   {"pos": Vector3(-9.6, 2.0, -2.0), "rot_deg": Vector3(0, 90, 0), "size": 1.6, "no_collide": true},
	"giant_gear":         {"pos": Vector3( 9.5, 2.3, -4.0), "rot_deg": Vector3(0, -90, 0), "size": 1.2, "no_collide": true},
}

@onready var _fallback_mat: StandardMaterial3D = _make_fallback_mat()


func _ready() -> void:
	if Engine.is_editor_hint():
		return  # edit mode — user clicks "Rebuild Props" in Inspector
	# Runtime: only auto-populate if not already baked
	if get_child_count() == 0:
		_spawn_all()


func _spawn_all() -> void:
	for key in PLACEMENTS.keys():
		var data: Dictionary = PLACEMENTS[key]
		var filename: String = data.get("file", key)
		var pos: Vector3 = data.get("pos", Vector3.ZERO)
		var rot_deg: Vector3 = data.get("rot_deg", Vector3.ZERO)
		var size: float = data.get("size", 1.0)
		var no_collide: bool = data.get("no_collide", false)
		_spawn(key, filename, pos, rot_deg, size, no_collide)


func rebuild_in_editor() -> void:
	clear_children()
	_spawn_all()
	_mark_saved()


func clear_children() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()


func _mark_saved() -> void:
	if not Engine.is_editor_hint():
		return
	var root: Node = get_tree().edited_scene_root
	if root == null:
		return
	_reown_recursive(self, root)


func _reown_recursive(node: Node, root: Node) -> void:
	for c in node.get_children():
		if c == root:
			continue
		c.owner = root
		# Don't recurse into instanced scenes (GLBs) — they stay as instance references,
		# reconstructed from the PackedScene on load. Setting owner on their internal
		# nodes would break encapsulation.
		if c.scene_file_path != "":
			continue
		_reown_recursive(c, root)


func _make_fallback_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.28, 0.14, 1.0)
	m.roughness = 0.6
	m.metallic = 0.1
	return m


func _spawn(key: String, filename: String, pos: Vector3, rot_deg: Vector3, size: float, no_collide: bool) -> void:
	var container := Node3D.new()
	container.name = key
	container.position = pos
	container.rotation = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	add_child(container)

	var full_path := MODELS_DIR + filename + ".glb"

	# Work around the editor-import requirement: try loading via ResourceLoader,
	# and if it's not imported yet, try loading the raw .glb via a runtime GLTFDocument.
	var inst: Node = null
	if ResourceLoader.exists(full_path):
		var res: Resource = load(full_path)
		if res is PackedScene:
			inst = (res as PackedScene).instantiate()

	if inst == null:
		inst = _try_runtime_load(full_path)

	if inst:
		container.add_child(inst)
		_auto_scale(container, inst, size)
		if not no_collide:
			_add_prop_collision(container, inst)
	else:
		_add_placeholder(container, key, size)
		if not no_collide:
			_add_placeholder_collision(container, size)


func _try_runtime_load(res_path: String) -> Node:
	# res_path is res:// — convert to absolute and use GLTFDocument to import
	var abs_path := ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(abs_path, state)
	if err != OK:
		return null
	return doc.generate_scene(state)


func _auto_scale(container: Node3D, inst: Node, target_size: float) -> void:
	var aabb := _compute_aabb(inst)
	if aabb.size.length() < 0.001:
		return
	var longest: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if longest > 0.001:
		var s: float = target_size / longest
		container.scale = Vector3(s, s, s)
	# Shift so feet sit on y=0 of container
	if inst is Node3D:
		(inst as Node3D).position.y -= aabb.position.y


func _compute_aabb(root: Node) -> AABB:
	var result := AABB()
	var first := true
	for mi in _collect_mesh_instances(root):
		if mi.mesh == null:
			continue
		var local_aabb: AABB = mi.mesh.get_aabb()
		var xform: Transform3D = _transform_relative_to(mi, root)
		var transformed: AABB = xform * local_aabb
		if first:
			result = transformed
			first = false
		else:
			result = result.merge(transformed)
	return result


func _transform_relative_to(node: Node3D, ancestor: Node) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform


func _collect_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		out.append_array(_collect_mesh_instances(c))
	return out


func _add_prop_collision(container: Node3D, inst: Node) -> void:
	# Use the AABB we just used for auto-scaling. Bottom was shifted to sit at y=0.
	var aabb := _compute_aabb(inst)
	if aabb.size.length() < 0.05:
		return
	var body := StaticBody3D.new()
	body.position = Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.size.y * 0.5,  # bottom was pinned to 0 by _auto_scale
		aabb.position.z + aabb.size.z * 0.5
	)
	container.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = aabb.size
	cs.shape = shape
	body.add_child(cs)


func _add_placeholder_collision(container: Node3D, size: float) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(0, size * 0.5, 0)
	container.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size * 0.6, size, size * 0.6)
	cs.shape = shape
	body.add_child(cs)


func _add_placeholder(container: Node3D, key: String, size: float) -> void:
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size * 0.6, size, size * 0.6)
	box.mesh = bm
	box.material_override = _fallback_mat
	box.position.y = size * 0.5
	container.add_child(box)

	var label := Label3D.new()
	label.text = key
	label.font_size = 64
	label.pixel_size = 0.003
	label.modulate = Color(1, 0.85, 0.5)
	label.outline_size = 8
	label.position = Vector3(0, size + 0.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	container.add_child(label)
