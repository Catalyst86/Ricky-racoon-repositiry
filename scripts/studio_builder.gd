@tool
extends Node3D
## Procedurally builds the Ricky's Rants studio room, stage, wood paneling,
## upper mezzanine, neon sign, and lighting rig.
##
## USAGE:
## - In the editor, click "Rebuild Studio" in the Inspector to populate the scene
##   with real editable nodes. Then Ctrl+S to save — everything becomes permanent
##   and you can drag/scale/rotate each piece freely in the 3D viewport.
## - "Clear Studio" removes all generated children.
## - At runtime, if build_on_ready is true and no children exist, it auto-builds
##   (fallback for scenes that haven't been baked).

@export var build_on_ready: bool = true
@export_tool_button("Rebuild Studio", "Reload") var _rebuild_btn = rebuild_in_editor
@export_tool_button("Clear Studio", "Remove") var _clear_btn = clear_children

# ---------- layout ----------
const ROOM_W := 20.0    # x extent
const ROOM_D := 16.0    # z extent
const ROOM_H := 8.5     # ceiling height
const MEZZ_H := 4.0     # mezzanine floor height
const MEZZ_DEPTH := 2.2 # how far mezzanine shelves protrude from wall
const STAGE_RADIUS := 3.8
const STAGE_HEIGHT := 0.35
const DESK_W := 3.4
const DESK_D := 1.4
const DESK_H := 1.05

# ---------- palette ----------
const COL_FLOOR := Color(0.42, 0.36, 0.30)
const COL_WOOD_LIGHT := Color(0.55, 0.30, 0.15)
const COL_WOOD_DARK := Color(0.30, 0.15, 0.08)
const COL_WOOD_RED := Color(0.42, 0.18, 0.09)
const COL_BRASS := Color(0.78, 0.55, 0.20)
const COL_NEON_ORANGE := Color(1.0, 0.45, 0.08)
const COL_NEON_BLUE := Color(0.35, 0.80, 1.0)
const COL_LEATHER := Color(0.38, 0.22, 0.12)
const COL_METAL_DARK := Color(0.15, 0.15, 0.17)


func _ready() -> void:
	if Engine.is_editor_hint():
		return  # edit mode — user clicks "Rebuild Studio" in Inspector
	# Runtime: only auto-build if the scene hasn't been baked (no children yet)
	if build_on_ready and get_child_count() == 0:
		build()


func rebuild_in_editor() -> void:
	clear_children()
	build()
	_mark_saved()


func clear_children() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()


func _mark_saved() -> void:
	# Mark every generated node as owned by the edited scene root so they save
	# to the .tscn when the user hits Ctrl+S. After saving, each node is a
	# first-class editable element in the 3D viewport.
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
		_reown_recursive(c, root)


func build() -> void:
	_build_floor()
	_build_walls()
	_build_ceiling_and_trusses()
	_build_stage()
	_build_mezzanine()
	_build_brass_railings()
	_build_neon_sign()
	_build_lighting_rig()
	_build_led_strip_under_stage()
	_build_bar_front_under_desk()
	_build_desk_props()
	_wrap_solids_post_pass()


# ================ collision post-process ================
func _wrap_solids_post_pass() -> void:
	# Walk every MeshInstance3D we just created and wrap solid (non-emissive, reachable)
	# ones with a StaticBody3D + CollisionShape3D sibling. The capsule player hits those.
	var to_wrap: Array[MeshInstance3D] = []
	_collect_solids_recursive(self, to_wrap)
	for mi in to_wrap:
		_wrap_one(mi)


func _collect_solids_recursive(node: Node, out: Array[MeshInstance3D]) -> void:
	for c in node.get_children():
		if c is StaticBody3D or c is CharacterBody3D:
			continue
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			if _should_collide(mi):
				out.append(mi)
		else:
			_collect_solids_recursive(c, out)


func _should_collide(mi: MeshInstance3D) -> bool:
	if mi.mesh == null:
		return false
	# skip emissive / glowing stuff (neon, LED strip, sign glow)
	var mat := mi.material_override
	if mat is StandardMaterial3D:
		var sm: StandardMaterial3D = mat
		if sm.emission_enabled and sm.emission_energy_multiplier > 0.5:
			return false
	# skip anything above the reachable zone (ceiling, trusses, spot housings, mezzanine floor + railings)
	# global_position works because nodes are already in the scene tree by the time _ready runs
	if mi.global_position.y > 3.6:
		return false
	# skip tiny meshes (decorative bits)
	var aabb := mi.mesh.get_aabb()
	if aabb.size.length() < 0.1:
		return false
	return true


func _wrap_one(mi: MeshInstance3D) -> void:
	var parent := mi.get_parent()
	if parent == null:
		return
	var body := StaticBody3D.new()
	body.transform = mi.transform
	parent.add_child(body)

	var cs := CollisionShape3D.new()
	cs.shape = _shape_for_mesh(mi.mesh)
	# PlaneMesh has zero thickness — our box shape is 0.1 thick, offset so top sits on the plane's Y
	if mi.mesh is PlaneMesh:
		cs.position.y = -0.05
	body.add_child(cs)


func _shape_for_mesh(mesh: Mesh) -> Shape3D:
	if mesh is BoxMesh:
		var s := BoxShape3D.new()
		s.size = (mesh as BoxMesh).size
		return s
	if mesh is CylinderMesh:
		var cm: CylinderMesh = mesh
		var s := CylinderShape3D.new()
		s.height = cm.height
		s.radius = maxf(cm.top_radius, cm.bottom_radius)
		return s
	if mesh is CapsuleMesh:
		var cm: CapsuleMesh = mesh
		var s := CapsuleShape3D.new()
		s.radius = cm.radius
		s.height = cm.height
		return s
	if mesh is SphereMesh:
		var sm: SphereMesh = mesh
		var s := SphereShape3D.new()
		s.radius = sm.radius
		return s
	if mesh is PlaneMesh:
		var pm: PlaneMesh = mesh
		var s := BoxShape3D.new()
		s.size = Vector3(pm.size.x, 0.1, pm.size.y)
		return s
	# Fallback: trimesh (works for torus, custom shapes)
	return mesh.create_trimesh_shape()


# ================ floor ================
func _build_floor() -> void:
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(ROOM_W, ROOM_D)
	floor.mesh = pm
	floor.material_override = _mat_concrete_polished(COL_FLOOR)
	floor.position = Vector3(0, 0, 0)
	add_child(floor)

	# Inset decorative ring around stage (slightly darker band)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = STAGE_RADIUS + 0.6
	tm.outer_radius = STAGE_RADIUS + 0.8
	tm.rings = 96
	tm.ring_segments = 8
	ring.mesh = tm
	var rmat := _mat_concrete_polished(Color(0.28, 0.22, 0.17))
	rmat.metallic = 0.3
	ring.material_override = rmat
	ring.position = Vector3(0, 0.005, -2.0)
	add_child(ring)


# ================ walls ================
func _build_walls() -> void:
	# Back wall (where the neon sign mounts) - paneled wood, slight curve
	var back_panels := 38
	var back_radius := 9.2
	var back_z := -ROOM_D * 0.5
	for i in range(back_panels):
		var t := float(i) / float(back_panels - 1)
		var ang := deg_to_rad(-28.0 + 56.0 * t)
		var panel := _wood_panel_strip(Vector3(0.58, MEZZ_H, 0.22), i)
		panel.position = Vector3(sin(ang) * back_radius, MEZZ_H * 0.5, back_z + (1.0 - cos(ang)) * back_radius)
		panel.rotation.y = -ang
		add_child(panel)

	# Side walls - darker red wood vertical panels
	var panel_w := 0.6
	var side_panels := int(ROOM_D / panel_w)
	for i in range(side_panels):
		var z := -ROOM_D * 0.5 + (i + 0.5) * panel_w
		# left
		var lp := _wood_panel_strip(Vector3(panel_w * 0.95, MEZZ_H, 0.18), i + 37)
		lp.position = Vector3(-ROOM_W * 0.5 + 0.09, MEZZ_H * 0.5, z)
		lp.rotation.y = deg_to_rad(90)
		add_child(lp)
		# right
		var rp := _wood_panel_strip(Vector3(panel_w * 0.95, MEZZ_H, 0.18), i + 73)
		rp.position = Vector3(ROOM_W * 0.5 - 0.09, MEZZ_H * 0.5, z)
		rp.rotation.y = deg_to_rad(-90)
		add_child(rp)

	# Upper back wall (above mezzanine)
	var upper_back := MeshInstance3D.new()
	var ubm := BoxMesh.new()
	ubm.size = Vector3(ROOM_W, ROOM_H - MEZZ_H, 0.2)
	upper_back.mesh = ubm
	upper_back.material_override = _mat_wood(COL_WOOD_DARK, 0.85, 0.05)
	upper_back.position = Vector3(0, MEZZ_H + (ROOM_H - MEZZ_H) * 0.5, -ROOM_D * 0.5 + 0.1)
	add_child(upper_back)

	# Upper side walls
	for side in [-1, 1]:
		var w := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.2, ROOM_H - MEZZ_H, ROOM_D)
		w.mesh = bm
		w.material_override = _mat_wood(COL_WOOD_DARK, 0.85, 0.05)
		w.position = Vector3(side * (ROOM_W * 0.5 - 0.1), MEZZ_H + (ROOM_H - MEZZ_H) * 0.5, 0)
		add_child(w)


func _wood_panel_strip(size: Vector3, seed_i: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	# Slight color variation to suggest individual wood slats
	var variation := 1.0 + (float((seed_i * 73) % 100) / 100.0 - 0.5) * 0.2
	var c := COL_WOOD_RED * variation
	c.a = 1.0
	mi.material_override = _mat_wood(c, 0.55, 0.05)
	return mi


# ================ ceiling + trusses ================
func _build_ceiling_and_trusses() -> void:
	# Dark ceiling
	var ceil := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(ROOM_W, ROOM_D)
	ceil.mesh = pm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.04, 0.03, 0.03)
	cmat.roughness = 1.0
	ceil.material_override = cmat
	ceil.position = Vector3(0, ROOM_H, 0)
	ceil.rotation.x = deg_to_rad(180)
	add_child(ceil)

	# Truss beams - 3 longitudinal
	var truss_mat := _mat_metal(COL_METAL_DARK, 0.35, 0.9)
	for x in [-4.5, 0.0, 4.5]:
		var t := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 0.35, ROOM_D - 0.4)
		t.mesh = bm
		t.material_override = truss_mat
		t.position = Vector3(x, ROOM_H - 0.25, 0)
		add_child(t)

	# Cross-truss struts every 2m
	for z in range(-6, 7, 2):
		var t := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(ROOM_W - 1.0, 0.2, 0.14)
		t.mesh = bm
		t.material_override = truss_mat
		t.position = Vector3(0, ROOM_H - 0.25, z)
		add_child(t)


# ================ stage ================
func _build_stage() -> void:
	# Outer concentric band (darker wood edge)
	var outer := MeshInstance3D.new()
	var co := CylinderMesh.new()
	co.top_radius = STAGE_RADIUS + 0.35
	co.bottom_radius = STAGE_RADIUS + 0.35
	co.height = STAGE_HEIGHT
	co.radial_segments = 96
	outer.mesh = co
	outer.material_override = _mat_wood(COL_WOOD_DARK, 0.5, 0.1)
	outer.position = Vector3(0, STAGE_HEIGHT * 0.5, -1.5)
	add_child(outer)

	# Inner platform (polished wood)
	var inner := MeshInstance3D.new()
	var ci := CylinderMesh.new()
	ci.top_radius = STAGE_RADIUS
	ci.bottom_radius = STAGE_RADIUS
	ci.height = STAGE_HEIGHT + 0.01
	ci.radial_segments = 96
	inner.mesh = ci
	inner.material_override = _mat_wood(COL_WOOD_LIGHT, 0.28, 0.15)
	inner.position = Vector3(0, STAGE_HEIGHT * 0.5 + 0.005, -1.5)
	add_child(inner)


# ================ desk props (mics, laptop) ================
func _build_desk_props() -> void:
	# Two microphones on boom arms — gives it a podcast feel.
	# Positioned on the desk top (desk GLB comes from Meshy).
	for side in [-1, 1]:
		var mic_root := Node3D.new()
		mic_root.position = Vector3(side * 0.55, DESK_H, -1.1)
		add_child(mic_root)

		var base := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.08
		cm.bottom_radius = 0.1
		cm.height = 0.02
		base.mesh = cm
		base.material_override = _mat_metal(COL_METAL_DARK, 0.3, 0.95)
		base.position.y = 0.01
		mic_root.add_child(base)

		var arm := MeshInstance3D.new()
		var am := CylinderMesh.new()
		am.top_radius = 0.012
		am.bottom_radius = 0.012
		am.height = 0.35
		arm.mesh = am
		arm.material_override = _mat_metal(COL_METAL_DARK, 0.3, 0.95)
		arm.position = Vector3(0, 0.18, 0)
		mic_root.add_child(arm)

		var capsule := MeshInstance3D.new()
		var caps := CapsuleMesh.new()
		caps.radius = 0.035
		caps.height = 0.14
		capsule.mesh = caps
		capsule.material_override = _mat_metal(Color(0.15, 0.15, 0.15), 0.7, 0.4)
		capsule.position = Vector3(0, 0.42, 0)
		mic_root.add_child(capsule)

		var windscreen := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.055
		sm.height = 0.11
		windscreen.mesh = sm
		var wsmat := StandardMaterial3D.new()
		wsmat.albedo_color = Color(0.08, 0.08, 0.08, 0.85)
		wsmat.roughness = 0.95
		wsmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		windscreen.material_override = wsmat
		windscreen.position = Vector3(0, 0.49, 0)
		mic_root.add_child(windscreen)


# ================ mezzanine ================
func _build_mezzanine() -> void:
	# Mezzanine floor slab wrapping three walls in a U
	var thickness := 0.25
	var mat := _mat_wood(COL_WOOD_DARK, 0.55, 0.1)

	# Back slab
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(ROOM_W - 0.6, thickness, MEZZ_DEPTH)
	back.mesh = bm
	back.material_override = mat
	back.position = Vector3(0, MEZZ_H, -ROOM_D * 0.5 + MEZZ_DEPTH * 0.5 + 0.1)
	add_child(back)

	# Left slab
	var left := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(MEZZ_DEPTH, thickness, ROOM_D - 0.6)
	left.mesh = lm
	left.material_override = mat
	left.position = Vector3(-ROOM_W * 0.5 + MEZZ_DEPTH * 0.5 + 0.1, MEZZ_H, 0)
	add_child(left)

	# Right slab
	var right := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(MEZZ_DEPTH, thickness, ROOM_D - 0.6)
	right.mesh = rm
	right.material_override = mat
	right.position = Vector3(ROOM_W * 0.5 - MEZZ_DEPTH * 0.5 - 0.1, MEZZ_H, 0)
	add_child(right)

	# Shelves on back mezzanine (stepped shelves for miniatures)
	var shelf_mat := _mat_wood(COL_WOOD_DARK, 0.7, 0.05)
	for i in range(2):
		var shelf := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(ROOM_W - 2.0, 0.04, 0.5)
		shelf.mesh = sm
		shelf.material_override = shelf_mat
		shelf.position = Vector3(0, MEZZ_H + 0.6 + i * 0.7, -ROOM_D * 0.5 + 0.4 + i * 0.2)
		add_child(shelf)


# ================ brass railings ================
func _build_brass_railings() -> void:
	var brass := _mat_metal(COL_BRASS, 0.15, 1.0)

	# Top rails along the inner edge of the mezzanine (U-shape)
	# Back rail
	var br := _make_cylinder(0.05, ROOM_W - 1.8, brass)
	br.position = Vector3(0, MEZZ_H + 1.0, -ROOM_D * 0.5 + MEZZ_DEPTH + 0.0)
	br.rotation.z = deg_to_rad(90)
	add_child(br)

	# Side rails
	for side in [-1, 1]:
		var sr := _make_cylinder(0.05, ROOM_D - 1.8, brass)
		sr.position = Vector3(side * (ROOM_W * 0.5 - MEZZ_DEPTH - 0.1), MEZZ_H + 1.0, 0)
		sr.rotation.x = deg_to_rad(90)
		add_child(sr)

	# Vertical posts every ~1m along the inner edge
	var post_spacing := 1.1
	var back_z_edge := -ROOM_D * 0.5 + MEZZ_DEPTH + 0.0
	var n_back := int((ROOM_W - 1.8) / post_spacing) + 1
	for i in range(n_back):
		var x := -ROOM_W * 0.5 + 0.9 + i * post_spacing
		if x > ROOM_W * 0.5 - 0.9:
			continue
		var p := _make_cylinder(0.04, 1.0, brass)
		p.position = Vector3(x, MEZZ_H + 0.5, back_z_edge)
		add_child(p)

	var n_side := int((ROOM_D - 1.8) / post_spacing) + 1
	for side in [-1, 1]:
		for i in range(n_side):
			var z := -ROOM_D * 0.5 + 0.9 + i * post_spacing
			if z > ROOM_D * 0.5 - 0.9:
				continue
			var p := _make_cylinder(0.04, 1.0, brass)
			p.position = Vector3(side * (ROOM_W * 0.5 - MEZZ_DEPTH - 0.1), MEZZ_H + 0.5, z)
			add_child(p)


func _make_cylinder(radius: float, height: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = material
	return mi


# ================ neon sign ================
func _build_neon_sign() -> void:
	# Mounted on upper back wall, facing forward.
	var sign_root := Node3D.new()
	sign_root.name = "NeonSign"
	sign_root.position = Vector3(0, MEZZ_H + 2.0, -ROOM_D * 0.5 + 0.25)
	add_child(sign_root)

	# Background gear-and-flame silhouette (emissive orange)
	var bg := MeshInstance3D.new()
	var bg_mesh := TorusMesh.new()
	bg_mesh.inner_radius = 1.25
	bg_mesh.outer_radius = 1.55
	bg_mesh.rings = 48
	bg_mesh.ring_segments = 12
	bg.mesh = bg_mesh
	bg.material_override = _mat_emissive(COL_NEON_ORANGE, 4.0)
	bg.rotation.x = deg_to_rad(90)
	sign_root.add_child(bg)

	# Decorative gear teeth (small boxes around the torus)
	for i in range(18):
		var ang := deg_to_rad(float(i) / 18.0 * 360.0)
		var tooth := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.12, 0.12, 0.08)
		tooth.mesh = tm
		tooth.material_override = _mat_emissive(COL_NEON_ORANGE, 4.0)
		tooth.position = Vector3(cos(ang) * 1.72, sin(ang) * 1.72, 0.0)
		sign_root.add_child(tooth)

	# "RICKY'S" text row — stylized as stacked horizontal bars to fake a neon outline
	_spawn_neon_text_bar(sign_root, "RICKY'S", Vector3(-0.05, 0.25, 0.02), 1.8, 0.35, COL_NEON_BLUE)
	_spawn_neon_text_bar(sign_root, "RANTS",   Vector3(0.02, -0.30, 0.02), 1.5, 0.35, COL_NEON_ORANGE)

	# Fill glow plate behind text
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(3.0, 1.6, 0.04)
	plate.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.08, 0.05, 0.04, 1.0)
	pmat.roughness = 0.9
	plate.material_override = pmat
	plate.position = Vector3(0, 0, -0.02)
	sign_root.add_child(plate)

	# Practical light source pushing orange spill onto the back wall
	var sign_light := OmniLight3D.new()
	sign_light.light_color = COL_NEON_ORANGE
	sign_light.light_energy = 3.0
	sign_light.omni_range = 6.0
	sign_light.shadow_enabled = false
	sign_light.position = Vector3(0, 0, 0.6)
	sign_root.add_child(sign_light)


func _spawn_neon_text_bar(parent: Node, _text: String, offset: Vector3, width: float, height: float, color: Color) -> void:
	# Fake neon text using Label3D with emissive-like setup.
	var label := Label3D.new()
	label.text = _text
	label.font_size = 140
	label.outline_size = 8
	label.modulate = color
	label.outline_modulate = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 1.0)
	label.pixel_size = 0.005
	label.no_depth_test = false
	label.position = offset
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	parent.add_child(label)

	# Thin emissive tube framing the text
	var frame := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, height, 0.02)
	frame.mesh = bm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 1.0)
	fmat.emission_enabled = true
	fmat.emission = color
	fmat.emission_energy_multiplier = 2.0
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	frame.material_override = fmat
	frame.position = offset + Vector3(0, 0, -0.01)
	parent.add_child(frame)


# ================ lighting rig ================
func _build_lighting_rig() -> void:
	# Warm key from above-right (like the track light hitting desk)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.85, 0.68)
	key.light_energy = 0.6
	key.shadow_enabled = true
	key.rotation = Vector3(deg_to_rad(-55), deg_to_rad(25), 0)
	add_child(key)

	# Ceiling spot lights — 6 arranged in an arc above the stage
	for i in range(6):
		var t := float(i) / 5.0
		var x := -4.5 + t * 9.0
		var s := SpotLight3D.new()
		s.light_color = Color(1.0, 0.78, 0.55)
		s.light_energy = 8.0
		s.spot_angle = 32.0
		s.spot_attenuation = 1.2
		s.spot_range = 12.0
		s.shadow_enabled = true
		s.position = Vector3(x, ROOM_H - 0.6, -1.0)
		s.rotation = Vector3(deg_to_rad(-80), 0, 0)
		add_child(s)

		# Small housing mesh
		var hold := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 0.14
		cm.height = 0.22
		hold.mesh = cm
		hold.material_override = _mat_metal(COL_METAL_DARK, 0.35, 0.9)
		hold.position = Vector3(x, ROOM_H - 0.5, -1.0)
		add_child(hold)

	# Mezzanine under-lights (warm spill washing the shelves)
	for i in range(8):
		var t := float(i) / 7.0
		var x := -ROOM_W * 0.45 + t * ROOM_W * 0.9
		var s := SpotLight3D.new()
		s.light_color = Color(1.0, 0.7, 0.4)
		s.light_energy = 3.0
		s.spot_angle = 40.0
		s.spot_range = 4.0
		s.shadow_enabled = false
		s.position = Vector3(x, MEZZ_H - 0.1, -ROOM_D * 0.5 + 0.3)
		s.rotation = Vector3(deg_to_rad(-90), 0, 0)
		add_child(s)

	# Accent fill lights at chair area (golden glow)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.6, 0.3)
	fill.light_energy = 1.8
	fill.omni_range = 8.0
	fill.shadow_enabled = false
	fill.position = Vector3(0, 1.6, 4.0)
	add_child(fill)


func _build_led_strip_under_stage() -> void:
	# Glowing warm ring under the stage edge (from the photo reference)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = STAGE_RADIUS - 0.02
	tm.outer_radius = STAGE_RADIUS + 0.05
	tm.rings = 96
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = _mat_emissive(Color(1.0, 0.72, 0.35), 6.0)
	ring.position = Vector3(0, 0.02, -1.5)
	add_child(ring)

	# Subtle kicker lights around the ring (8 small omnis)
	for i in range(8):
		var ang := deg_to_rad(float(i) / 8.0 * 360.0)
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.6, 0.3)
		ol.light_energy = 0.6
		ol.omni_range = 2.0
		ol.shadow_enabled = false
		ol.position = Vector3(cos(ang) * STAGE_RADIUS, 0.05, -1.5 + sin(ang) * STAGE_RADIUS)
		add_child(ol)


func _build_bar_front_under_desk() -> void:
	# Warm glow strip under the desk lip
	var strip := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.4
	tm.outer_radius = 1.45
	tm.rings = 48
	tm.ring_segments = 6
	strip.mesh = tm
	strip.material_override = _mat_emissive(Color(1.0, 0.55, 0.2), 3.5)
	strip.position = Vector3(0, 0.5, -0.6)
	strip.rotation.x = deg_to_rad(90)
	add_child(strip)


# ================ materials ================
func _mat_wood(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.metallic_specular = 0.5
	return m


func _mat_concrete_polished(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.35
	m.metallic = 0.15
	m.metallic_specular = 0.5
	return m


func _mat_metal(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.metallic_specular = 0.6
	return m


func _mat_emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m
