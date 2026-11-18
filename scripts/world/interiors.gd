class_name Interiors
extends Node3D
## Builds walk-in property interiors (apartment + garage room) on demand, high above the property,
## so big windows look out over the real city.

var points: Array = []
var current := ""
var root: Node3D
var apt_origin := Vector3.ZERO
var garage_origin := Vector3.ZERO
var apt_spawn := Vector3.ZERO
var garage_spawn := Vector3.ZERO
var car_spots: Array = []       # [{pos, yaw, uid}]
var rng := RandomNumberGenerator.new()

const TIER_SIZE := {"motel": Vector2(9, 7), "cheap": Vector2(12, 10), "medium": Vector2(16, 13), "luxury": Vector2(24, 18), "mansion": Vector2(30, 22)}
const TIER_HEIGHT := {"motel": 2.8, "cheap": 2.9, "medium": 3.2, "luxury": 3.6, "mansion": 5.5}

func build(pid: String) -> void:
	clear()
	current = pid
	var pr: Dictionary = Catalog.PROPERTIES[pid]
	var tier: String = pr["tier"]
	var decor: Dictionary = Game.data["properties"][pid]["decor"]
	rng.seed = pid.hash()
	var b: Vector2i = pr["block"]
	var c := CityLayout.block_center(b.x, b.y)
	var alt = {"motel": 60.0, "cheap": 70.0, "medium": 120.0, "luxury": 190.0, "mansion": 90.0}[tier]
	apt_origin = Vector3(c.x, alt, c.z)
	garage_origin = apt_origin + Vector3(0, 30, 0)
	root = Node3D.new()
	root.name = "Interior"
	add_child(root)
	_build_apartment(pid, tier, decor)
	_build_garage(pid, int(pr["garage"]))

func clear() -> void:
	points.clear()
	car_spots.clear()
	current = ""
	if root and is_instance_valid(root):
		root.queue_free()
	root = null

# ------------------------------------------------------------------ helpers
func _mat(c: Color, rough: float = 0.7, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	return CarModel.mat(c, rough, metal, emit)

func _box(mn: Vector3, mx: Vector3, c: Color, collide: bool = true, rough: float = 0.7, metal: float = 0.0, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = mx - mn
	mi.mesh = bm
	mi.position = (mn + mx) / 2.0
	mi.material_override = _mat(c, rough, metal, emit)
	root.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = mx - mn
		cs.shape = bs
		sb.position = mi.position
		sb.add_child(cs)
		root.add_child(sb)
	return mi

func _glass(mn: Vector3, mx: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = mx - mn
	mi.mesh = bm
	mi.position = (mn + mx) / 2.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.85, 0.95, 0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.3
	mi.material_override = m
	root.add_child(mi)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = mx - mn
	cs.shape = bs
	sb.position = mi.position
	sb.add_child(cs)
	root.add_child(sb)

func _light(pos: Vector3, energy: float, rng_m: float, col: Color = Color(1.0, 0.9, 0.75)) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_energy = energy
	l.omni_range = rng_m
	l.light_color = col
	l.shadow_enabled = false
	root.add_child(l)

func _point(pos: Vector3, kind: String, label: String, extra: Dictionary = {}) -> void:
	var p := {"pos": pos, "kind": kind, "id": current, "name": label, "vehicle": false, "radius": 1.6, "color": Color(0.3, 0.85, 1.0), "icon": label}
	for k in extra:
		p[k] = extra[k]
	points.append(p)
	var l := Label3D.new()
	l.text = label
	l.font = UI.font(true)
	l.font_size = 40
	l.pixel_size = 0.0035
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(0.4, 0.9, 1.0)
	l.outline_size = 10
	l.position = pos + Vector3(0, 1.25, 0)
	root.add_child(l)
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.6
	cm.height = 0.05
	ring.mesh = cm
	ring.material_override = _mat(Color(0.3, 0.85, 1.0), 0.5, 0.0, 1.5)
	ring.position = pos + Vector3(0, 0.03, 0)
	root.add_child(ring)

# ------------------------------------------------------------------ apartment
func _style_colors(decor: Dictionary) -> Dictionary:
	var style: int = int(decor.get("style", 0))
	var wall: Color = Catalog.WALL_COLORS[int(decor.get("wall", 0)) % Catalog.WALL_COLORS.size()][1]
	var flr: Color = Catalog.FLOORS[int(decor.get("floor", 0)) % Catalog.FLOORS.size()][1]
	var pal = [
		{"sofa": Color(0.2, 0.22, 0.25), "wood": Color(0.15, 0.15, 0.16), "accent": Color(0.9, 0.55, 0.2), "fabric": Color(0.85, 0.85, 0.85)},
		{"sofa": Color(0.45, 0.12, 0.12), "wood": Color(0.35, 0.2, 0.1), "accent": Color(0.85, 0.7, 0.3), "fabric": Color(0.9, 0.85, 0.7)},
		{"sofa": Color(0.35, 0.25, 0.18), "wood": Color(0.25, 0.25, 0.27), "accent": Color(0.6, 0.6, 0.62), "fabric": Color(0.5, 0.5, 0.52)},
		{"sofa": Color(0.75, 0.82, 0.85), "wood": Color(0.85, 0.8, 0.7), "accent": Color(0.2, 0.55, 0.7), "fabric": Color(0.95, 0.95, 0.92)},
	][style % 4]
	pal["wall"] = wall
	pal["floor"] = flr
	return pal

func _build_apartment(pid: String, tier: String, decor: Dictionary) -> void:
	var sz: Vector2 = TIER_SIZE[tier]
	# small per-property size variation keeps each interior unique
	sz += Vector2(rng.randf_range(-0.5, 1.5), rng.randf_range(-0.5, 1.0))
	var h: float = TIER_HEIGHT[tier]
	var o := apt_origin
	var x0 := o.x - sz.x / 2.0
	var x1 := o.x + sz.x / 2.0
	var z0 := o.z - sz.y / 2.0
	var z1 := o.z + sz.y / 2.0
	var y := o.y
	var col := _style_colors(decor)
	var big_windows: bool = tier in ["medium", "luxury", "mansion"]
	var window_side := rng.randi() % 2   # 0: north wall glass, 1: east wall glass
	# floor & ceiling
	_box(Vector3(x0 - 0.2, y - 0.3, z0 - 0.2), Vector3(x1 + 0.2, y, z1 + 0.2), col["floor"], true, 0.5 if decor.get("floor", 0) != 2 else 0.15)
	_box(Vector3(x0 - 0.2, y + h, z0 - 0.2), Vector3(x1 + 0.2, y + h + 0.3, z1 + 0.2), col["wall"].lightened(0.3), true)
	# walls
	var t := 0.2
	# south wall (door)
	_box(Vector3(x0, y, z1), Vector3(o.x - 0.8, y + h, z1 + t), col["wall"])
	_box(Vector3(o.x + 0.8, y, z1), Vector3(x1, y + h, z1 + t), col["wall"])
	_box(Vector3(o.x - 0.8, y + 2.3, z1), Vector3(o.x + 0.8, y + h, z1 + t), col["wall"])
	_box(Vector3(o.x - 0.8, y, z1 + 0.05), Vector3(o.x + 0.8, y + 2.3, z1 + 0.15), col["wood"], true)   # door
	# west wall
	_box(Vector3(x0 - t, y, z0), Vector3(x0, y + h, z1), col["wall"])
	# north / east walls with windows
	if big_windows and window_side == 0:
		_glass(Vector3(x0, y, z0 - t), Vector3(x1, y + h, z0))
		for k in int(sz.x / 4.0) + 1:
			var mx := x0 + k * 4.0
			_box(Vector3(mx - 0.08, y, z0 - t), Vector3(mx + 0.08, y + h, z0), Color(0.1, 0.1, 0.1), false)
	else:
		_wall_with_window(Vector3(x0, y, z0 - t), Vector3(x1, y + h, z0), col["wall"], true, tier)
	if big_windows and window_side == 1:
		_glass(Vector3(x1, y, z0), Vector3(x1 + t, y + h, z1))
	else:
		_wall_with_window(Vector3(x1, y, z0), Vector3(x1 + t, y + h, z1), col["wall"], false, tier)
	# lights
	var nl := 2 if tier in ["motel", "cheap"] else 4
	for k in nl:
		var lx: float = lerp(x0 + 2.0, x1 - 2.0, float(k) / max(1, nl - 1))
		_light(Vector3(lx, y + h - 0.4, o.z), 1.2 if tier != "motel" else 0.8, 9.0)
		_box(Vector3(lx - 0.3, y + h - 0.06, o.z - 0.3), Vector3(lx + 0.3, y + h, o.z + 0.3), Color(1, 0.95, 0.8), false, 0.3, 0.0, 2.0)
	# furniture
	var fx := func(f: float) -> float: return lerp(x0, x1, f)
	var fz := func(f: float) -> float: return lerp(z0, z1, f)
	# bed (in the west part)
	var bed_w := 1.5 if tier in ["motel", "cheap"] else 2.0
	var bx := x0 + 0.3
	var bz := z0 + 1.0
	_box(Vector3(bx, y, bz), Vector3(bx + 2.2, y + 0.5, bz + bed_w), col["wood"])
	_box(Vector3(bx + 0.05, y + 0.5, bz + 0.05), Vector3(bx + 2.15, y + 0.65, bz + bed_w - 0.05), col["fabric"], false)
	_box(Vector3(bx + 0.05, y + 0.65, bz + 0.15), Vector3(bx + 0.5, y + 0.8, bz + bed_w - 0.15), Color(0.95, 0.95, 0.95), false)
	_box(Vector3(bx + 0.9, y + 0.66, bz + 0.05), Vector3(bx + 2.15, y + 0.7, bz + bed_w - 0.05), col["accent"], false)
	_box(Vector3(x0, y, bz - 0.1), Vector3(x0 + 0.15, y + 1.3, bz + bed_w + 0.1), col["wood"], false)   # headboard
	_box(Vector3(bx, y, bz + bed_w + 0.2), Vector3(bx + 0.5, y + 0.55, bz + bed_w + 0.7), col["wood"])   # nightstand
	_light(Vector3(bx + 0.25, y + 0.9, bz + bed_w + 0.45), 0.4, 3.0, Color(1, 0.8, 0.5))
	_point(Vector3(bx + 2.8, y, bz + bed_w * 0.5), "bed", "SLEEP & SAVE")
	# living area: sofa + coffee table + TV
	var sx: float = fx.call(0.55)
	var sz2: float = fz.call(0.55)
	_box(Vector3(sx - 1.4, y, sz2), Vector3(sx + 1.4, y + 0.45, sz2 + 0.9), col["sofa"])
	_box(Vector3(sx - 1.4, y + 0.45, sz2 + 0.65), Vector3(sx + 1.4, y + 0.95, sz2 + 0.9), col["sofa"], false)
	_box(Vector3(sx - 1.55, y, sz2), Vector3(sx - 1.3, y + 0.65, sz2 + 0.9), col["sofa"], false)
	_box(Vector3(sx + 1.3, y, sz2), Vector3(sx + 1.55, y + 0.65, sz2 + 0.9), col["sofa"], false)
	_box(Vector3(sx - 0.7, y, sz2 - 1.4), Vector3(sx + 0.7, y + 0.4, sz2 - 0.7), col["wood"])
	var tv_z := sz2 - 3.2 if tier != "motel" else sz2 - 2.6
	_box(Vector3(sx - 1.0, y, tv_z), Vector3(sx + 1.0, y + 0.5, tv_z + 0.45), col["wood"])
	var tv_w := 1.1 if tier in ["motel", "cheap"] else 1.6
	_box(Vector3(sx - tv_w / 2.0, y + 0.55, tv_z + 0.15), Vector3(sx + tv_w / 2.0, y + 0.55 + tv_w * 0.56, tv_z + 0.22), Color(0.03, 0.03, 0.05), false, 0.1, 0.5)
	_box(Vector3(sx - tv_w / 2.0 + 0.05, y + 0.6, tv_z + 0.225), Vector3(sx + tv_w / 2.0 - 0.05, y + 0.5 + tv_w * 0.56, tv_z + 0.23), Color(0.2, 0.5, 0.8), false, 0.2, 0.0, 0.8)
	# rug
	if tier != "motel":
		_box(Vector3(sx - 2.0, y + 0.005, sz2 - 2.2), Vector3(sx + 2.0, y + 0.02, sz2 + 1.2), col["accent"].darkened(0.3), false)
	# kitchen along the east wall
	if tier != "motel":
		var kx := x1 - 0.7
		_box(Vector3(kx, y, z1 - 5.0), Vector3(x1, y + 0.9, z1 - 0.6), col["wood"])
		_box(Vector3(kx - 0.02, y + 0.9, z1 - 5.0), Vector3(x1, y + 0.95, z1 - 0.6), Color(0.85, 0.85, 0.85) if decor.get("style", 0) != 2 else Color(0.2, 0.2, 0.2), false, 0.2)
		_box(Vector3(kx, y, z1 - 5.9), Vector3(x1, y + 2.0, z1 - 5.05), Color(0.8, 0.8, 0.82), true, 0.3, 0.6)   # fridge
		_box(Vector3(kx + 0.1, y + 0.95, z1 - 2.5), Vector3(x1 - 0.1, y + 0.97, z1 - 1.8), Color(0.1, 0.1, 0.1), false)   # hob
		if tier in ["medium", "luxury", "mansion"]:
			_box(Vector3(kx - 3.0, y, z1 - 4.2), Vector3(kx - 1.6, y + 0.95, z1 - 1.4), col["wood"])   # island
			for st in 3:
				_box(Vector3(kx - 3.5, y, z1 - 4.0 + st * 0.9), Vector3(kx - 3.1, y + 0.7, z1 - 3.6 + st * 0.9), col["accent"], false)
	else:
		_box(Vector3(x1 - 1.2, y, z1 - 2.6), Vector3(x1, y + 0.8, z1 - 1.0), col["wood"])   # dresser
	# dining table
	if tier in ["medium", "luxury", "mansion"]:
		var dx: float = fx.call(0.3)
		var dz: float = fz.call(0.75)
		_box(Vector3(dx - 1.0, y + 0.72, dz - 0.5), Vector3(dx + 1.0, y + 0.78, dz + 0.5), col["wood"], false)
		_box(Vector3(dx - 0.1, y, dz - 0.1), Vector3(dx + 0.1, y + 0.72, dz + 0.1), col["wood"])
		for side in [-1.0, 1.0]:
			for k2 in 2:
				var cx: float = dx - 0.5 + k2 * 1.0
				_box(Vector3(cx - 0.22, y, dz + side * 0.75 - 0.22), Vector3(cx + 0.22, y + 0.45, dz + side * 0.75 + 0.22), col["sofa"], false)
	# bathroom pod
	var bath_w := 2.2 if tier != "mansion" else 3.5
	_box(Vector3(x0, y, z1 - 2.6), Vector3(x0 + bath_w, y + h, z1 - 2.5), col["wall"])
	_box(Vector3(x0 + bath_w, y, z1 - 2.6), Vector3(x0 + bath_w + 0.1, y + h, z1 - 1.4), col["wall"])
	_box(Vector3(x0 + 0.2, y, z1 - 1.0), Vector3(x0 + 0.8, y + 0.45, z1 - 0.3), Color(0.95, 0.95, 0.95), false, 0.2)
	# laptop / designer desk
	var lx2: float = fx.call(0.82)
	var lz2: float = fz.call(0.25)
	_box(Vector3(lx2 - 0.8, y + 0.72, lz2 - 0.4), Vector3(lx2 + 0.8, y + 0.76, lz2 + 0.4), col["wood"], false)
	_box(Vector3(lx2 - 0.7, y, lz2 - 0.3), Vector3(lx2 - 0.6, y + 0.72, lz2 + 0.3), col["wood"])
	_box(Vector3(lx2 + 0.6, y, lz2 - 0.3), Vector3(lx2 + 0.7, y + 0.72, lz2 + 0.3), col["wood"])
	_box(Vector3(lx2 - 0.25, y + 0.76, lz2 - 0.15), Vector3(lx2 + 0.25, y + 0.78, lz2 + 0.15), Color(0.2, 0.2, 0.22), false, 0.3, 0.6)
	_box(Vector3(lx2 - 0.25, y + 0.78, lz2 - 0.17), Vector3(lx2 + 0.25, y + 1.08, lz2 - 0.15), Color(0.3, 0.6, 0.9), false, 0.2, 0.0, 1.0)
	_point(Vector3(lx2, y, lz2 + 1.0), "designer", "INTERIOR DESIGN")
	# art & plants
	if decor.get("art", true):
		var art_cols := [Color(0.9, 0.3, 0.2), Color(0.2, 0.4, 0.8), Color(0.95, 0.8, 0.2), Color(0.2, 0.7, 0.5)]
		for k3 in (2 if tier in ["motel", "cheap"] else 4):
			var ax := x0 + 0.13
			var az := z0 + 4.0 + k3 * 2.4
			if az > z1 - 3.0:
				break
			_box(Vector3(ax, y + 1.4, az), Vector3(ax + 0.04, y + 2.2, az + 1.2), Color(0.1, 0.1, 0.1), false)
			_box(Vector3(ax + 0.04, y + 1.45, az + 0.05), Vector3(ax + 0.05, y + 2.15, az + 1.15), art_cols[(k3 + rng.randi()) % 4], false, 0.6, 0.0, 0.2)
	if decor.get("plants", true):
		for k4 in (2 if tier in ["motel", "cheap"] else 5):
			var px = lerp(x0 + 1.0, x1 - 1.0, rng.randf())
			var pz := z0 + 0.6
			_box(Vector3(px - 0.25, y, pz - 0.25), Vector3(px + 0.25, y + 0.5, pz + 0.25), Color(0.85, 0.85, 0.82), false)
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.45
			sm.height = 1.2
			mi.mesh = sm
			mi.material_override = _mat(Color(0.15, 0.4, 0.15))
			mi.position = Vector3(px, y + 1.0, pz)
			root.add_child(mi)
	# tier extras
	if tier == "luxury" or tier == "mansion":
		var bar_x: float = fx.call(0.45)
		_box(Vector3(bar_x - 2.0, y, z0 + 1.2), Vector3(bar_x + 2.0, y + 1.05, z0 + 1.8), Color(0.08, 0.08, 0.1), true, 0.1, 0.4)
		_box(Vector3(bar_x - 2.0, y + 1.05, z0 + 1.2), Vector3(bar_x + 2.0, y + 1.1, z0 + 1.8), col["accent"], false, 0.2, 0.6)
		# pool table
		var px2: float = fx.call(0.75)
		var pz2: float = fz.call(0.7)
		_box(Vector3(px2 - 1.3, y, pz2 - 0.7), Vector3(px2 + 1.3, y + 0.8, pz2 + 0.7), col["wood"])
		_box(Vector3(px2 - 1.15, y + 0.8, pz2 - 0.55), Vector3(px2 + 1.15, y + 0.82, pz2 + 0.55), Color(0.1, 0.45, 0.2), false)
	if tier == "mansion":
		# chandelier & terrace with pool outside the glass
		_box(Vector3(o.x - 0.8, y + h - 1.4, o.z - 0.8), Vector3(o.x + 0.8, y + h - 0.6, o.z + 0.8), Color(1, 0.9, 0.6), false, 0.1, 0.8, 1.5)
		_light(Vector3(o.x, y + h - 1.6, o.z), 2.0, 16.0)
		var tz0 := z1 + 0.2
		_box(Vector3(x0, y - 0.3, tz0), Vector3(x1, y, tz0 + 16), Color(0.82, 0.78, 0.7))
		_box(Vector3(o.x - 6, y - 0.29, tz0 + 4), Vector3(o.x + 6, y + 0.01, tz0 + 11), Color(0.1, 0.55, 0.8), false, 0.05, 0.1, 0.3)
		_box(Vector3(x0, y, tz0 + 15.8), Vector3(x1, y + 1.1, tz0 + 16), Color(0.85, 0.85, 0.85))
		_box(Vector3(x0 - 0.2, y, tz0), Vector3(x0, y + 1.1, tz0 + 16), Color(0.85, 0.85, 0.85))
		_box(Vector3(x1, y, tz0), Vector3(x1 + 0.2, y + 1.1, tz0 + 16), Color(0.85, 0.85, 0.85))
		for k5 in 6:
			var hx: float = lerp(x0 + 1.0, x1 - 1.0, k5 / 5.0)
			var mi2 := MeshInstance3D.new()
			var sm2 := SphereMesh.new()
			sm2.radius = 0.9
			sm2.height = 1.6
			mi2.mesh = sm2
			mi2.material_override = _mat(Color(0.12, 0.35, 0.12))
			mi2.position = Vector3(hx, y + 0.8, tz0 + 14.8)
			root.add_child(mi2)
		for k6 in 3:
			_box(Vector3(o.x - 8 + k6 * 2.0, y, tz0 + 12.5), Vector3(o.x - 7.2 + k6 * 2.0, y + 0.35, tz0 + 14.5), Color(0.95, 0.95, 0.95), false)
		# guard post for private security flavour
		_box(Vector3(x1 - 2.5, y, tz0 + 13), Vector3(x1 - 0.5, y + 2.4, tz0 + 15), Color(0.3, 0.3, 0.32))
	# points
	apt_spawn = Vector3(o.x, y + 0.1, z1 - 1.2)
	_point(Vector3(o.x, y, z1 - 0.7), "exit", "EXIT")
	_point(Vector3(x1 - 1.0, y, o.z + 1.0) if tier != "motel" else Vector3(x1 - 1.0, y, z0 + 1.2), "to_garage", "GARAGE")

func _wall_with_window(mn: Vector3, mx: Vector3, c: Color, along_x: bool, tier: String) -> void:
	var h := mx.y - mn.y
	var y0 := mn.y + 0.9
	var y1 = mn.y + min(h - 0.4, 2.3)
	_box(mn, Vector3(mx.x, y0, mx.z), c)
	_box(Vector3(mn.x, y1, mn.z), mx, c)
	if along_x:
		var w := mx.x - mn.x
		var cx := mn.x + w / 2.0
		var ww = min(w * 0.5, 4.0)
		_box(Vector3(mn.x, y0, mn.z), Vector3(cx - ww / 2.0, y1, mx.z), c)
		_box(Vector3(cx + ww / 2.0, y0, mn.z), Vector3(mx.x, y1, mx.z), c)
		_glass(Vector3(cx - ww / 2.0, y0, mn.z), Vector3(cx + ww / 2.0, y1, mx.z))
	else:
		var d := mx.z - mn.z
		var cz := mn.z + d / 2.0
		var wd = min(d * 0.5, 4.0)
		_box(Vector3(mn.x, y0, mn.z), Vector3(mx.x, y1, cz - wd / 2.0), c)
		_box(Vector3(mn.x, y0, cz + wd / 2.0), Vector3(mx.x, y1, mx.z), c)
		_glass(Vector3(mn.x, y0, cz - wd / 2.0), Vector3(mx.x, y1, cz + wd / 2.0))

# ------------------------------------------------------------------ garage
func _build_garage(pid: String, slots: int) -> void:
	var cols = {1: 1, 2: 2, 6: 3, 10: 5, 20: 5}.get(slots, 3)
	var rows := int(ceil(float(slots) / cols))
	var spot_w := 4.6
	var spot_d := 7.0
	var aisle := 7.0
	var w = cols * spot_w + 2.0
	var d := rows * spot_d + aisle * int(ceil(rows / 2.0)) + 2.0
	var o := garage_origin
	var x0 = o.x - w / 2.0
	var x1 = o.x + w / 2.0
	var z0 := o.z - d / 2.0
	var z1 := o.z + d / 2.0
	var y := o.y
	var h := 3.4
	var lux := slots >= 10
	var floor_c := Color(0.35, 0.35, 0.37) if not lux else Color(0.12, 0.12, 0.14)
	_box(Vector3(x0 - 0.2, y - 0.3, z0 - 0.2), Vector3(x1 + 0.2, y, z1 + 0.2), floor_c, true, 0.3 if lux else 0.8)
	_box(Vector3(x0 - 0.2, y + h, z0 - 0.2), Vector3(x1 + 0.2, y + h + 0.3, z1 + 0.2), Color(0.5, 0.5, 0.52))
	var wc := Color(0.7, 0.7, 0.7) if not lux else Color(0.2, 0.2, 0.22)
	_box(Vector3(x0 - 0.2, y, z0 - 0.2), Vector3(x0, y + h, z1 + 0.2), wc)
	_box(Vector3(x1, y, z0 - 0.2), Vector3(x1 + 0.2, y + h, z1 + 0.2), wc)
	_box(Vector3(x0, y, z0 - 0.2), Vector3(x1, y + h, z0), wc)
	_box(Vector3(x0, y, z1), Vector3(x1, y + h, z1 + 0.2), wc)
	if lux:
		_box(Vector3(x0, y + 0.3, z0 + 0.01), Vector3(x1, y + 0.36, z0 + 0.03), UI.ACCENT, false, 0.3, 0.0, 2.0)
	for k in max(2, cols):
		var lx: float = lerp(x0 + 2.0, x1 - 2.0, float(k) / max(1, max(2, cols) - 1))
		_light(Vector3(lx, y + h - 0.3, o.z), 1.3, 14.0, Color(0.9, 0.95, 1.0))
		_box(Vector3(lx - 0.6, y + h - 0.06, o.z - 0.1), Vector3(lx + 0.6, y + h, o.z + 0.1), Color(1, 1, 1), false, 0.3, 0.0, 3.0)
	# parking spots
	var idx := 0
	for r in rows:
		var facing_north := r % 2 == 0
		var row_z0 := z0 + 1.0 + int(r / 2) * (spot_d * 2.0 + aisle) + (0.0 if facing_north else spot_d + aisle)
		for c in cols:
			if idx >= slots:
				break
			var sx = x0 + 1.0 + c * spot_w + spot_w / 2.0
			var sz := row_z0 + spot_d / 2.0
			for line in [-1.0, 1.0]:
				_box(Vector3(sx + line * spot_w / 2.0 - 0.05, y + 0.005, row_z0), Vector3(sx + line * spot_w / 2.0 + 0.05, y + 0.012, row_z0 + spot_d), Color(0.9, 0.9, 0.9), false)
			car_spots.append({"pos": Vector3(sx, y, sz), "yaw": 0.0 if facing_north else PI})
			idx += 1
	garage_spawn = Vector3(o.x, y + 0.1, z1 - 1.5)
	_point(Vector3(o.x - 1.5, y, z1 - 1.0), "to_apartment", "APARTMENT")
	_point(Vector3(o.x + 1.5, y, z1 - 1.0), "garage_menu", "MANAGE GARAGE")
	# place stored vehicles
	var stored := []
	for v in Game.data["vehicles"]:
		if v["garage"] == pid:
			stored.append(v)
	for k2 in min(stored.size(), car_spots.size()):
		var v2: Dictionary = stored[k2]
		var spot: Dictionary = car_spots[k2]
		spot["uid"] = int(v2["uid"])
		var def := Catalog.get_vehicle(v2["model"])
		var m := CarModel.build(def, v2["mods"])
		m.position = spot["pos"]
		m.rotation.y = spot["yaw"]
		root.add_child(m)
		var s := CarModel.spec(def["body"])
		var wv := CarModel.wheel(def, v2["mods"])
		for zi in [s["wf"], s["wr"]]:
			for sx2 in ([0.0] if s.get("two", false) else [-1.0, 1.0]):
				var wn: Node3D = wv.duplicate()
				wn.position = Vector3(sx2 * CarModel.wheel_x(s), s["r"], -s["L"] / 2.0 + s["L"] * zi)
				m.add_child(wn)
		wv.queue_free()
		var nm := Label3D.new()
		nm.text = str(v2["name"])
		nm.font = UI.font(true)
		nm.font_size = 36
		nm.pixel_size = 0.006
		nm.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nm.outline_size = 8
		nm.position = spot["pos"] + Vector3(0, 2.4, 0)
		root.add_child(nm)
		points.append({"pos": spot["pos"], "kind": "garage_car", "id": pid, "uid": int(v2["uid"]), "name": str(v2["name"]), "vehicle": false, "radius": 3.2, "color": Color(0.3, 0.85, 1.0), "icon": ""})
