class_name CarModel
## Builds stylised low-poly vehicle meshes (body, glass, lights, wheels, mods) from catalog data.

static var _mats := {}

const SPECS := {
	# L length, W width, c clearance, h body height, cf/cr cabin base front/rear (fraction of L from front),
	# rf/rr roof front/rear fractions, rh roof height above beltline, r wheel radius, wf/wr wheel positions (fractions)
	"compact": {"L": 3.8, "W": 1.74, "c": 0.28, "h": 0.62, "cf": 0.30, "cr": 0.92, "rf": 0.46, "rr": 0.86, "rh": 0.62, "r": 0.31, "wf": 0.17, "wr": 0.83},
	"sedan": {"L": 4.7, "W": 1.84, "c": 0.3, "h": 0.62, "cf": 0.32, "cr": 0.80, "rf": 0.45, "rr": 0.70, "rh": 0.6, "r": 0.34, "wf": 0.17, "wr": 0.82},
	"luxury": {"L": 5.1, "W": 1.94, "c": 0.3, "h": 0.66, "cf": 0.34, "cr": 0.80, "rf": 0.46, "rr": 0.71, "rh": 0.6, "r": 0.36, "wf": 0.16, "wr": 0.82},
	"sports": {"L": 4.45, "W": 1.94, "c": 0.22, "h": 0.52, "cf": 0.36, "cr": 0.86, "rf": 0.50, "rr": 0.68, "rh": 0.48, "r": 0.35, "wf": 0.17, "wr": 0.81},
	"super": {"L": 4.6, "W": 2.04, "c": 0.18, "h": 0.5, "cf": 0.30, "cr": 0.72, "rf": 0.44, "rr": 0.60, "rh": 0.44, "r": 0.36, "wf": 0.17, "wr": 0.80},
	"muscle": {"L": 4.9, "W": 1.94, "c": 0.26, "h": 0.64, "cf": 0.42, "cr": 0.84, "rf": 0.53, "rr": 0.75, "rh": 0.5, "r": 0.36, "wf": 0.16, "wr": 0.82},
	"suv": {"L": 4.9, "W": 2.0, "c": 0.45, "h": 0.85, "cf": 0.28, "cr": 0.97, "rf": 0.38, "rr": 0.95, "rh": 0.72, "r": 0.42, "wf": 0.17, "wr": 0.80},
	"offroad": {"L": 4.4, "W": 1.96, "c": 0.55, "h": 0.8, "cf": 0.32, "cr": 0.95, "rf": 0.38, "rr": 0.93, "rh": 0.78, "r": 0.47, "wf": 0.16, "wr": 0.80},
	"buggy": {"L": 3.7, "W": 1.9, "c": 0.5, "h": 0.4, "cf": 0.30, "cr": 0.80, "rf": 0.38, "rr": 0.75, "rh": 0.8, "r": 0.46, "wf": 0.15, "wr": 0.82},
	"pickup": {"L": 5.4, "W": 2.0, "c": 0.48, "h": 0.85, "cf": 0.30, "cr": 0.56, "rf": 0.36, "rr": 0.55, "rh": 0.72, "r": 0.42, "wf": 0.16, "wr": 0.78},
	"boxtruck": {"L": 7.0, "W": 2.4, "c": 0.55, "h": 1.0, "cf": 0.04, "cr": 0.24, "rf": 0.08, "rr": 0.24, "rh": 0.9, "r": 0.5, "wf": 0.13, "wr": 0.76},
	"van": {"L": 5.2, "W": 2.0, "c": 0.38, "h": 0.95, "cf": 0.18, "cr": 0.99, "rf": 0.28, "rr": 0.99, "rh": 0.95, "r": 0.38, "wf": 0.14, "wr": 0.80},
	"camper": {"L": 5.8, "W": 2.1, "c": 0.4, "h": 1.0, "cf": 0.15, "cr": 0.99, "rf": 0.24, "rr": 0.99, "rh": 1.2, "r": 0.4, "wf": 0.14, "wr": 0.80},
	"bike": {"L": 2.1, "W": 0.7, "c": 0.35, "h": 0.5, "r": 0.33, "wf": 0.12, "wr": 0.86, "two": true},
	"scooter": {"L": 1.8, "W": 0.65, "c": 0.25, "h": 0.5, "r": 0.26, "wf": 0.12, "wr": 0.86, "two": true},
	"chopper": {"L": 2.5, "W": 0.8, "c": 0.3, "h": 0.5, "r": 0.36, "wf": 0.06, "wr": 0.86, "two": true},
}

static func spec(body: String) -> Dictionary:
	return SPECS.get(body, SPECS["sedan"])

static func wheel_x(s: Dictionary) -> float:
	## Lateral wheel position so the tyre sits flush with the bodywork.
	return 0.0 if s.get("two", false) else (s["W"] / 2.0 - 0.1)

static func mat(c: Color, rough: float = 0.5, metal: float = 0.0, emit: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f|%.2f" % [c.to_html(), rough, metal, emit, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

static func paint_mat(mods: Dictionary) -> StandardMaterial3D:
	var c := Color.html(str(mods.get("paint", "888888")))
	var fin: Array = Catalog.FINISHES[int(mods.get("finish", 1)) % Catalog.FINISHES.size()]
	var m := mat(c, fin[1], fin[2])
	if int(mods.get("finish", 1)) <= 1:
		m.clearcoat_enabled = true
		m.clearcoat = 0.6
		m.clearcoat_roughness = 0.1
	return m

static func glass_mat(tint: int) -> StandardMaterial3D:
	var a: float = [0.78, 0.85, 0.92, 0.97][clampi(tint, 0, 3)]
	var m := mat(Color(0.08, 0.1, 0.13), 0.05, 0.9, 0.0, a)
	return m

# ------------------------------------------------------------------ geometry
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	# Godot front faces are clockwise when viewed from the front.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)

static func extrude(profile: PackedVector2Array, x0: float, x1: float, material: Material) -> MeshInstance3D:
	## profile: points (z, y). Extruded along X from x0 to x1.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(profile)
	for i in range(0, idx.size(), 3):
		var a := profile[idx[i]]
		var b := profile[idx[i + 1]]
		var c := profile[idx[i + 2]]
		_tri(st, Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x1, c.y, c.x), Vector3.RIGHT)
		_tri(st, Vector3(x0, a.y, a.x), Vector3(x0, b.y, b.x), Vector3(x0, c.y, c.x), Vector3.LEFT)
	var n := profile.size()
	# polygon centroid used to orient edge normals outward
	var cen := Vector2.ZERO
	for p in profile:
		cen += p
	cen /= n
	for i in n:
		var p0 := profile[i]
		var p1 := profile[(i + 1) % n]
		var e := p1 - p0
		var nn := Vector2(-e.y, e.x).normalized()
		if nn.dot((p0 + p1) * 0.5 - cen) < 0.0:
			nn = -nn
		var nrm := Vector3(0, nn.y, nn.x)
		var a0 := Vector3(x0, p0.y, p0.x)
		var a1 := Vector3(x1, p0.y, p0.x)
		var b0 := Vector3(x0, p1.y, p1.x)
		var b1 := Vector3(x1, p1.y, p1.x)
		_tri(st, a0, a1, b1, nrm)
		_tri(st, a0, b1, b0, nrm)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	return mi

static func box(parent: Node3D, sz: Vector3, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, seg: int = 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

# ------------------------------------------------------------------ build
static func build(def: Dictionary, mods: Dictionary) -> Node3D:
	## Returns the vehicle body (no wheels). Origin is at ground level, centred; forward is -Z.
	var root := Node3D.new()
	root.name = "Model"
	var body: String = def.get("body", "sedan")
	var s := spec(body)
	if s.get("two", false):
		_build_bike(root, body, s, def, mods)
		return root
	var L: float = s["L"]
	var W: float = s["W"]
	var c: float = s["c"]
	var h: float = s["h"]
	var kit: int = int(mods.get("bodykit", 0))
	var susp: int = int(mods.get("suspension", 0))
	c -= [0.0, 0.06, 0.04, 0.08][clampi(susp, 0, 3)]
	var paint := paint_mat(mods)
	var trim := mat(Color(0.06, 0.06, 0.07), 0.6)
	var glass := glass_mat(int(mods.get("tint", 0)))
	var front := -L / 2.0
	var rear := L / 2.0
	var belt := c + h
	# --- lower body profile (z, y)
	var nose := 0.25 if body in ["sports", "super"] else 0.12
	var prof := PackedVector2Array()
	match body:
		"van", "camper", "boxtruck":
			prof = PackedVector2Array([Vector2(front + 0.05, c), Vector2(front, c + h * 0.55), Vector2(front + 0.12, belt), Vector2(rear, belt), Vector2(rear, c)])
		_:
			prof = PackedVector2Array([Vector2(front + 0.12, c), Vector2(front, c + h * 0.45), Vector2(front + nose, belt - 0.04), Vector2(front + L * s["cf"], belt),
				Vector2(rear - 0.25, belt), Vector2(rear, belt - 0.08), Vector2(rear, c + 0.08), Vector2(rear - 0.1, c)])
	var lower := extrude(prof, -W / 2.0, W / 2.0, paint)
	lower.name = "Paint"
	root.add_child(lower)
	# --- greenhouse
	var cf: float = front + L * s["cf"]
	var cr: float = front + L * s["cr"]
	var rf: float = front + L * s["rf"]
	var rr: float = front + L * s["rr"]
	var roof: float = belt + s["rh"]
	if body == "buggy":
		_buggy_cage(root, cf, cr, belt, roof, W, paint, trim)
	elif body == "boxtruck":
		var cab := PackedVector2Array([Vector2(cf, belt), Vector2(rf, roof), Vector2(rr, roof), Vector2(cr, belt)])
		root.add_child(extrude(cab, -W / 2.0 + 0.05, W / 2.0 - 0.05, glass))
		box(root, Vector3(W - 0.05, 0.08, rr - rf + 0.05), Vector3(0, roof + 0.04, (rf + rr) / 2.0), paint)
		var cargo := box(root, Vector3(W + 0.05, 2.5, L * 0.72), Vector3(0, belt + 1.1, rear - L * 0.36), mat(Color(0.95, 0.95, 0.95), 0.6))
		cargo.name = "Cargo"
		box(root, Vector3(W + 0.08, 0.5, L * 0.6), Vector3(W * 0.0, belt + 1.4, rear - L * 0.36), paint)
	else:
		var g := PackedVector2Array([Vector2(cf, belt), Vector2(rf, roof), Vector2(rr, roof), Vector2(cr, belt)])
		var inset := 0.1 if body not in ["van", "camper"] else 0.02
		var green := extrude(g, -W / 2.0 + inset, W / 2.0 - inset, glass)
		green.name = "Glass"
		root.add_child(green)
		# roof skin and pillars in paint colour
		box(root, Vector3(W - inset * 2.0 + 0.02, 0.05, rr - rf), Vector3(0, roof + 0.02, (rf + rr) / 2.0), paint)
		for x in [-1.0, 1.0]:
			var px: float = x * (W / 2.0 - inset - 0.005)
			# B pillar
			box(root, Vector3(0.03, roof - belt, 0.09), Vector3(px, (belt + roof) / 2.0, lerp(rf, rr, 0.45)), paint)
			if body in ["van", "camper"]:
				box(root, Vector3(0.03, roof - belt, 1.2), Vector3(px, (belt + roof) / 2.0, lerp(rf, rr, 0.75)), paint)
		if body == "pickup":
			# bed
			var bed_z0: float = cr + 0.05
			box(root, Vector3(W, 0.45, 0.06), Vector3(0, belt + 0.2, rear - 0.03), paint)
			for x2 in [-1.0, 1.0]:
				box(root, Vector3(0.06, 0.45, rear - bed_z0), Vector3(x2 * (W / 2.0 - 0.03), belt + 0.2, (bed_z0 + rear) / 2.0), paint)
			box(root, Vector3(W - 0.12, 0.04, rear - bed_z0 - 0.06), Vector3(0, belt, (bed_z0 + rear) / 2.0), trim)
		if body == "camper":
			box(root, Vector3(W * 0.6, 0.25, 1.4), Vector3(0, roof + 0.14, rear - 1.8), mat(Color(0.95, 0.95, 0.93), 0.5))
			box(root, Vector3(0.02, 0.18, 2.6), Vector3(W / 2.0 + 0.005, belt - 0.15, 0.4), mat(Color(0.7, 0.4, 0.2), 0.5))
		if body == "offroad":
			box(root, Vector3(W * 0.9, 0.06, (rr - rf) * 0.8), Vector3(0, roof + 0.12, (rf + rr) / 2.0), trim)
			box(root, Vector3(W * 0.7, 0.1, 0.1), Vector3(0, roof + 0.18, rf + 0.1), mat(Color(1, 1, 0.9), 0.3, 0.0, 2.0))
			box(root, Vector3(0.6, 0.6, 0.25), Vector3(0, c + 0.6, rear + 0.13), trim)   # spare tyre
		if def.get("taxi", false):
			box(root, Vector3(0.6, 0.18, 0.25), Vector3(0, roof + 0.12, (rf + rr) / 2.0), mat(Color(1.0, 0.9, 0.4), 0.5, 0.0, 1.5))
	# --- details
	var lamp_y: float = c + h * 0.7
	var head_m := mat(Color(1.0, 0.97, 0.88), 0.2, 0.0, 1.5)
	var tail_m := mat(Color(0.9, 0.05, 0.05), 0.3, 0.0, 1.2)
	var hl := Node3D.new()
	hl.name = "HeadLamps"
	root.add_child(hl)
	for x in [-1.0, 1.0]:
		box(hl, Vector3(0.38 if body not in ["super", "sports"] else 0.42, 0.11, 0.05), Vector3(x * (W / 2.0 - 0.3), lamp_y, front + nose * 0.4 + 0.02), head_m)
		var tl := box(root, Vector3(0.36, 0.12, 0.05), Vector3(x * (W / 2.0 - 0.28), belt - 0.12 if body not in ["van", "camper", "boxtruck"] else c + 0.6, rear + 0.005), tail_m)
		tl.name = "Tail"
		# mirrors
		if body != "buggy":
			box(root, Vector3(0.14, 0.09, 0.12), Vector3(x * (W / 2.0 + 0.05), belt + 0.12, cf + 0.25), paint)
		# side trim & door lines
		box(root, Vector3(0.012, 0.03, L * 0.4), Vector3(x * (W / 2.0 + 0.002), c + h * 0.45, (cf + cr) * 0.5 - 0.1), trim)
	# grille & bumpers
	box(root, Vector3(W * 0.45 if body != "muscle" else W * 0.75, 0.16, 0.04), Vector3(0, c + h * 0.42, front + 0.02), trim)
	box(root, Vector3(W * 1.0, 0.14, 0.12), Vector3(0, c + 0.08, front + 0.1), trim)
	box(root, Vector3(W * 1.0, 0.14, 0.12), Vector3(0, c + 0.08, rear - 0.06), trim)
	# exhaust
	cyl(root, 0.045, 0.2, Vector3(W * 0.28, c + 0.08, rear + 0.02), mat(Color(0.7, 0.7, 0.72), 0.3, 1.0), Vector3(PI / 2, 0, 0), 8)
	if body == "muscle":
		box(root, Vector3(0.5, 0.12, 0.8), Vector3(0, belt + 0.04, front + L * 0.2), trim)   # hood scoop
		box(root, Vector3(0.25, 0.012, L * 0.95), Vector3(0.22, belt + 0.003, 0), mat(Color(0.95, 0.95, 0.95), 0.4))
		box(root, Vector3(0.25, 0.012, L * 0.95), Vector3(-0.22, belt + 0.003, 0), mat(Color(0.95, 0.95, 0.95), 0.4))
	if body == "super":
		box(root, Vector3(W * 0.8, 0.05, 0.6), Vector3(0, belt - 0.02, rear - 0.6), trim)   # engine vents
		for x in [-1.0, 1.0]:
			box(root, Vector3(0.05, 0.22, 0.7), Vector3(x * (W / 2.0 - 0.01), c + h * 0.6, (cr + rear) * 0.5 - 0.3), trim)
	# plates
	var ps: int = int(mods.get("plate_style", 0))
	var plate_bg: Color = [Color(0.95, 0.95, 0.95), Color(0.98, 0.82, 0.2), Color(0.05, 0.05, 0.06), Color(0.2, 0.4, 0.8)][clampi(ps, 0, 3)]
	var plate_fg: Color = Color.BLACK if ps < 2 else Color.WHITE
	for zz in [front - 0.005, rear + 0.075]:
		var is_rear: bool = zz > 0
		box(root, Vector3(0.52, 0.12, 0.01), Vector3(0, c + 0.32, zz), mat(plate_bg, 0.6))
		var lbl := Label3D.new()
		lbl.text = str(mods.get("plate", "CITY 00"))
		lbl.font_size = 40
		lbl.pixel_size = 0.0025
		lbl.modulate = plate_fg
		lbl.outline_size = 0
		lbl.position = Vector3(0, c + 0.32, zz + (0.008 if is_rear else -0.008))
		lbl.rotation.y = 0.0 if is_rear else PI
		lbl.double_sided = false
		root.add_child(lbl)
	# --- mods
	_add_spoiler(root, int(mods.get("spoiler", 0)), W, belt, rear, paint, trim, body)
	if kit > 0:
		for x in [-1.0, 1.0]:
			box(root, Vector3(0.08 + 0.06 * kit, 0.1, L * 0.5), Vector3(x * (W / 2.0 + 0.02 * kit), c + 0.05, 0), trim if kit != 2 else paint)
		box(root, Vector3(W * 1.02, 0.04, 0.25), Vector3(0, c + 0.01, front + 0.05), trim)   # splitter
		if kit >= 2:
			for x in [-1.0, 1.0]:
				for wz in [s["wf"], s["wr"]]:
					box(root, Vector3(0.12, 0.2, s["r"] * 2.6), Vector3(x * (W / 2.0 + 0.04), c + h * 0.55, front + L * wz), paint)
		if kit == 3:
			box(root, Vector3(W * 0.9, 0.12, 0.35), Vector3(0, c + 0.12, rear + 0.1), trim)   # diffuser
	return root

static func _add_spoiler(root: Node3D, kind: int, W: float, belt: float, rear: float, paint: Material, trim: Material, body: String) -> void:
	if kind == 0 or body in ["van", "camper", "boxtruck", "pickup"]:
		return
	match kind:
		1: box(root, Vector3(W * 0.9, 0.05, 0.15), Vector3(0, belt + 0.03, rear - 0.12), paint)
		2:
			box(root, Vector3(W * 0.85, 0.05, 0.28), Vector3(0, belt + 0.22, rear - 0.2), paint)
			for x in [-0.5, 0.5]:
				box(root, Vector3(0.05, 0.2, 0.12), Vector3(x * W * 0.7, belt + 0.1, rear - 0.2), trim)
		3:
			box(root, Vector3(W * 1.0, 0.04, 0.38), Vector3(0, belt + 0.42, rear - 0.12), trim)
			for x in [-1.0, 1.0]:
				box(root, Vector3(0.03, 0.2, 0.42), Vector3(x * W * 0.5, belt + 0.38, rear - 0.12), trim)
				box(root, Vector3(0.05, 0.42, 0.1), Vector3(x * W * 0.32, belt + 0.2, rear - 0.12), trim)

static func _buggy_cage(root: Node3D, cf: float, cr: float, belt: float, roof: float, W: float, paint: Material, trim: Material) -> void:
	var tube := mat(Color(0.1, 0.1, 0.1), 0.4, 0.6)
	for x in [-1.0, 1.0]:
		var px: float = x * (W / 2.0 - 0.2)
		box(root, Vector3(0.06, 0.06, cr - cf), Vector3(px, roof, (cf + cr) / 2.0), tube)
		box(root, Vector3(0.06, roof - belt, 0.06), Vector3(px, (roof + belt) / 2.0, cf + 0.2), tube, Vector3(0.3, 0, 0))
		box(root, Vector3(0.06, roof - belt, 0.06), Vector3(px, (roof + belt) / 2.0, cr), tube)
	box(root, Vector3(W - 0.4, 0.06, 0.06), Vector3(0, roof, cf + 0.05), tube)
	box(root, Vector3(W - 0.4, 0.06, 0.06), Vector3(0, roof, cr), tube)
	box(root, Vector3(0.5, 0.5, 0.5), Vector3(0.35, belt + 0.1, (cf + cr) / 2.0), trim)
	box(root, Vector3(0.5, 0.5, 0.5), Vector3(-0.35, belt + 0.1, (cf + cr) / 2.0), trim)

static func _build_bike(root: Node3D, body: String, s: Dictionary, def: Dictionary, mods: Dictionary) -> void:
	var paint := paint_mat(mods)
	var trim := mat(Color(0.07, 0.07, 0.08), 0.5, 0.3)
	var chrome := mat(Color(0.8, 0.8, 0.82), 0.2, 1.0)
	var L: float = s["L"]
	var r: float = s["r"]
	var fz: float = -L / 2.0 + L * s["wf"]
	var rz: float = -L / 2.0 + L * s["wr"]
	var axle: float = r
	match body:
		"scooter":
			box(root, Vector3(0.38, 0.3, 0.9), Vector3(0, axle + 0.12, rz - 0.35), paint)
			box(root, Vector3(0.3, 0.12, 0.6), Vector3(0, axle + 0.36, rz - 0.35), trim)
			box(root, Vector3(0.3, 0.08, 0.5), Vector3(0, axle - 0.05, (fz + rz) / 2.0 - 0.1), paint)
			box(root, Vector3(0.36, 0.7, 0.15), Vector3(0, axle + 0.25, fz + 0.25), paint, Vector3(-0.25, 0, 0))
		"chopper":
			box(root, Vector3(0.28, 0.2, 0.55), Vector3(0, axle + 0.45, -0.1), paint)
			box(root, Vector3(0.3, 0.1, 0.5), Vector3(0, axle + 0.32, 0.35), trim)
			box(root, Vector3(0.3, 0.32, 0.4), Vector3(0, axle + 0.12, 0.0), chrome)
			box(root, Vector3(0.05, 0.05, 1.3), Vector3(0.12, axle + 0.6, fz + 0.55), chrome, Vector3(0.65, 0, 0))
			box(root, Vector3(0.05, 0.05, 1.3), Vector3(-0.12, axle + 0.6, fz + 0.55), chrome, Vector3(0.65, 0, 0))
			cyl(root, 0.05, 1.0, Vector3(0.2, axle - 0.05, 0.6), chrome, Vector3(PI / 2 - 0.1, 0, 0), 8)
		_:
			box(root, Vector3(0.34, 0.28, 0.6), Vector3(0, axle + 0.42, -0.15), paint)   # tank
			box(root, Vector3(0.3, 0.1, 0.55), Vector3(0, axle + 0.42, 0.35), trim)    # seat
			box(root, Vector3(0.28, 0.12, 0.5), Vector3(0, axle + 0.48, 0.7), paint, Vector3(-0.25, 0, 0))   # tail
			box(root, Vector3(0.3, 0.3, 0.45), Vector3(0, axle + 0.08, 0.0), trim)    # engine
			box(root, Vector3(0.42, 0.42, 0.5), Vector3(0, axle + 0.5, fz + 0.35), paint, Vector3(0.5, 0, 0))   # fairing
			box(root, Vector3(0.3, 0.18, 0.04), Vector3(0, axle + 0.75, fz + 0.2), glass_mat(1), Vector3(-0.6, 0, 0))
			for x in [-0.08, 0.08]:
				box(root, Vector3(0.04, 0.75, 0.04), Vector3(x, axle + 0.3, fz + 0.12), chrome, Vector3(0.35, 0, 0))
			cyl(root, 0.05, 0.6, Vector3(0.16, axle + 0.1, rz - 0.15), chrome, Vector3(PI / 2 - 0.3, 0, 0), 8)
	# handlebar
	box(root, Vector3(0.7, 0.04, 0.04), Vector3(0, axle + 0.8, fz + 0.32), trim)
	var head_m := mat(Color(1.0, 0.97, 0.88), 0.2, 0.0, 1.5)
	var hl := Node3D.new()
	hl.name = "HeadLamps"
	root.add_child(hl)
	box(hl, Vector3(0.16, 0.1, 0.05), Vector3(0, axle + 0.55, fz + 0.05), head_m)
	var tl := box(root, Vector3(0.14, 0.06, 0.04), Vector3(0, axle + 0.5, L / 2.0 - 0.15), mat(Color(0.9, 0.05, 0.05), 0.3, 0.0, 1.2))
	tl.name = "Tail"

static func wheel(def: Dictionary, mods: Dictionary) -> Node3D:
	## Wheel visual centred at origin with axle along X.
	var s := spec(def.get("body", "sedan"))
	var r: float = s["r"]
	var two: bool = s.get("two", false)
	var w := 0.12 if two else 0.24
	var n := Node3D.new()
	var tyre := mat(Color(0.05, 0.05, 0.05), 0.9)
	var style: int = int(mods.get("wheels", 0))
	var rim_c := Color.html(str(mods.get("wheel_color", "c0c0c8")))
	var rim := mat(rim_c, 0.25, 0.9)
	var tw: float = w * (1.25 if int(mods.get("tires", 0)) == 3 or def.get("body") in ["offroad", "buggy"] else 1.0)
	cyl(n, r, tw, Vector3.ZERO, tyre, Vector3(0, 0, PI / 2), 16)
	cyl(n, r * 0.68, tw + 0.01, Vector3.ZERO, mat(Color(0.12, 0.12, 0.13), 0.5, 0.5), Vector3(0, 0, PI / 2), 14)
	var face := tw / 2.0 + 0.006
	for side in [-1.0, 1.0]:
		var hub := cyl(n, r * 0.16, 0.02, Vector3(side * face, 0, 0), rim, Vector3(0, 0, PI / 2), 8)
		hub.name = "Hub"
		var spokes: int = [5, 5, 10, 6, 8, 6][clampi(style, 0, 5)]
		var sw: float = [0.06, 0.07, 0.025, 0.05, 0.09, 0.08][clampi(style, 0, 5)]
		for k in spokes:
			var a := TAU * k / spokes
			var len_r: float = r * 0.62
			box(n, Vector3(0.02, len_r, sw), Vector3(side * face, cos(a) * len_r * 0.5, sin(a) * len_r * 0.5), rim, Vector3(a, 0, 0))
		if style == 3:
			cyl(n, r * 0.66, 0.02, Vector3(side * (face - 0.01), 0, 0), rim, Vector3(0, 0, PI / 2), 16)
	return n

static func thumbnail_color(mods: Dictionary) -> Color:
	return Color.html(str(mods.get("paint", "888888")))
