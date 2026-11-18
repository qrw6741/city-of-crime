class_name City
extends Node3D
## Procedurally generates the city of Port Calloway (deterministic seed): ground, roads, blocks,
## buildings, landmarks, props, coast, minimap image and interaction points.

const CHUNK := 4   # blocks per chunk side

var rng := RandomNumberGenerator.new()
var chunks := {}
var points: Array = []           # interaction points: {pos, kind, id, name, radius, vehicle(bool)}
var minimap_image: Image
var minimap_texture: ImageTexture
const MAP_ORIGIN := Vector2(-320, -320)
const MAP_SCALE := 2.0           # metres per pixel
const MAP_SIZE := 920

var mat_building: ShaderMaterial
var mat_road: ShaderMaterial
var mat_block: ShaderMaterial
var mat_prop: ShaderMaterial
var mat_ground: ShaderMaterial
var mat_water: ShaderMaterial
var mat_marker: Shader
var tree_meshes := {}
var lamp_mesh: ArrayMesh
var special_blocks := {}   # Vector2i -> {kind, side, name, id}
var building_rects: Array = []   # for minimap

func generate() -> void:
	rng.seed = 90210
	_materials()
	_prop_meshes()
	for pid in Catalog.PROPERTIES:
		var p: Dictionary = Catalog.PROPERTIES[pid]
		special_blocks[p["block"]] = {"kind": "property", "tier": p["tier"], "side": p["side"], "name": p["name"], "id": pid}
	for poi in Catalog.POIS:
		if poi["kind"] in ["atm", "race"]:
			continue
		special_blocks[poi["block"]] = {"kind": poi["kind"], "side": poi["side"], "name": poi["name"], "id": poi["id"]}
	special_blocks[Vector2i(0, 8)] = {"kind": "gas", "side": "e", "name": "Fuel Stop", "id": "gas1"}
	special_blocks[Vector2i(10, 13)] = {"kind": "gas", "side": "n", "name": "Fuel Stop", "id": "gas2"}
	_ground_and_water()
	_roads()
	for i in CityLayout.N:
		for j in CityLayout.N:
			_block(i, j)
	_street_lights()
	_coast()
	_outskirts()
	_commit_chunks()
	_interaction_points()
	_minimap()

# ------------------------------------------------------------------ materials & shared meshes
func _materials() -> void:
	mat_building = _sm("res://shaders/building.gdshader")
	mat_road = _sm("res://shaders/road.gdshader")
	mat_block = _sm("res://shaders/block.gdshader")
	mat_prop = _sm("res://shaders/prop.gdshader")
	mat_ground = _sm("res://shaders/ground.gdshader")
	mat_water = _sm("res://shaders/water.gdshader")
	mat_marker = load("res://shaders/marker.gdshader")

func _sm(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m

func _prop_meshes() -> void:
	var k := MeshKit.new()
	k.add_mesh(MeshKit.prim_cyl(0.16, 0.22, 3.2, 6), Transform3D(Basis(), Vector3(0, 1.6, 0)), Color(0.32, 0.22, 0.14))
	k.add_mesh(MeshKit.prim_sphere(2.3, 8), Transform3D(Basis().scaled(Vector3(1, 0.85, 1)), Vector3(0, 4.6, 0)), Color(0.18, 0.36, 0.14))
	k.add_mesh(MeshKit.prim_sphere(1.6, 6), Transform3D(Basis(), Vector3(0.9, 5.6, 0.4)), Color(0.22, 0.42, 0.16))
	tree_meshes["round"] = k.commit(mat_prop)
	k = MeshKit.new()
	k.add_mesh(MeshKit.prim_cyl(0.15, 0.2, 2.0, 6), Transform3D(Basis(), Vector3(0, 1.0, 0)), Color(0.3, 0.2, 0.12))
	k.add_mesh(MeshKit.prim_cyl(0.0, 2.2, 4.5, 7), Transform3D(Basis(), Vector3(0, 4.0, 0)), Color(0.10, 0.26, 0.14))
	k.add_mesh(MeshKit.prim_cyl(0.0, 1.6, 3.5, 7), Transform3D(Basis(), Vector3(0, 6.2, 0)), Color(0.12, 0.30, 0.16))
	tree_meshes["pine"] = k.commit(mat_prop)
	k = MeshKit.new()
	k.add_mesh(MeshKit.prim_cyl(0.14, 0.22, 8.0, 6), Transform3D(Basis(Vector3.RIGHT, 0.06), Vector3(0, 4.0, 0)), Color(0.45, 0.36, 0.25))
	for a in 8:
		var b := Basis(Vector3.UP, TAU * a / 8.0) * Basis(Vector3.RIGHT, 0.45)
		k.add_mesh(MeshKit.prim_box(Vector3(0.6, 0.06, 3.4)), Transform3D(b, Vector3(0, 8.0, 0) + b * Vector3(0, 0, 1.6)), Color(0.20, 0.45, 0.15))
	k.add_mesh(MeshKit.prim_sphere(0.35, 6), Transform3D(Basis(), Vector3(0, 7.9, 0)), Color(0.35, 0.25, 0.12))
	tree_meshes["palm"] = k.commit(mat_prop)
	k = MeshKit.new()
	k.add_mesh(MeshKit.prim_sphere(1.1, 6), Transform3D(Basis().scaled(Vector3(1.2, 0.8, 1.2)), Vector3(0, 0.8, 0)), Color(0.16, 0.34, 0.12))
	tree_meshes["bush"] = k.commit(mat_prop)
	k = MeshKit.new()
	k.add_mesh(MeshKit.prim_cyl(0.09, 0.13, 7.5, 6), Transform3D(Basis(), Vector3(0, 3.75, 0)), Color(0.25, 0.26, 0.28))
	k.add_mesh(MeshKit.prim_box(Vector3(0.12, 0.12, 2.2)), Transform3D(Basis(), Vector3(0, 7.4, 1.0)), Color(0.25, 0.26, 0.28))
	k.add_mesh(MeshKit.prim_box(Vector3(0.45, 0.12, 0.7)), Transform3D(Basis(), Vector3(0, 7.3, 2.0)), Color(1.0, 0.86, 0.6, 0.0))
	lamp_mesh = k.commit(mat_prop)

func _chunk(i: int, j: int) -> Dictionary:
	var key := Vector2i(clampi(int(floor(float(i) / CHUNK)), -2, 6), clampi(int(floor(float(j) / CHUNK)), -2, 6))
	if not chunks.has(key):
		chunks[key] = {"bk": MeshKit.new(), "pk": MeshKit.new(), "boxes": [], "cyls": [], "trees": {}, "lamps": []}
	return chunks[key]

func _chunk_at(pos: Vector3) -> Dictionary:
	return _chunk(int(floor(pos.x / CityLayout.P)), int(floor(pos.z / CityLayout.P)))

# ------------------------------------------------------------------ ground, water, roads
func _ground_and_water() -> void:
	var lm := CityLayout.LAND_MIN
	var lx := CityLayout.LAND_MAX
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(lx.x - lm.x, lx.y - lm.y)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	ground.mesh = pm
	ground.material_override = mat_ground
	ground.position = Vector3((lm.x + lx.x) / 2.0, 0.0, (lm.y + lx.y) / 2.0)
	add_child(ground)
	# land collision: one big slab
	var sb := StaticBody3D.new()
	sb.name = "Land"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(lx.x - lm.x, 10.0, lx.y - lm.y)
	cs.shape = bs
	cs.position = ground.position + Vector3(0, -5.0, 0)
	sb.add_child(cs)
	add_child(sb)
	# coast skirt so the land edge isn't a floating sheet
	var skirt := MeshKit.new()
	skirt.add_box(Vector3(lm.x, CityLayout.WATER_Y - 4.0, lx.y - 0.5), Vector3(lx.x, -0.01, lx.y), Color(0.75, 0.68, 0.5))
	skirt.add_box(Vector3(lx.x - 0.5, CityLayout.WATER_Y - 4.0, lm.y), Vector3(lx.x, -0.01, lx.y), Color(0.45, 0.45, 0.45))
	var sk := MeshInstance3D.new()
	sk.mesh = skirt.commit(mat_prop)
	add_child(sk)
	# water
	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(6000, 6000)
	water.mesh = wm
	water.material_override = mat_water
	water.position = Vector3(640, CityLayout.WATER_Y, 640)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# sea floor so you can't see under the world
	var floor_mi := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(6000, 6000)
	floor_mi.mesh = fm
	floor_mi.material_override = CarModel.mat(Color(0.05, 0.1, 0.12), 1.0)
	floor_mi.position = Vector3(640, CityLayout.WATER_Y - 12.0, 640)
	add_child(floor_mi)

func _roads() -> void:
	var k := MeshKit.new()
	var P := CityLayout.P
	var hw := CityLayout.HALF_ROAD
	for a in CityLayout.N + 1:
		for b in CityLayout.N:
			# horizontal segment along x at z = a*P, between nodes (b, a) and (b+1, a)
			k.add_road(Vector3(b * P + hw, 0, a * P), Vector3((b + 1) * P - hw, 0, a * P), CityLayout.ROAD_W, 0.0)
			# vertical segment along z at x = a*P
			k.add_road(Vector3(a * P, 0, b * P + hw), Vector3(a * P, 0, (b + 1) * P - hw), CityLayout.ROAD_W, 0.0)
	for i in CityLayout.N + 1:
		for j in CityLayout.N + 1:
			k.add_road(Vector3(i * P - hw, 0, j * P), Vector3(i * P + hw, 0, j * P), CityLayout.ROAD_W, 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit(mat_road)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Roads"
	add_child(mi)
	# block slabs (sidewalk + lot)
	var bk := MeshKit.new()
	var sb := StaticBody3D.new()
	sb.name = "Blocks"
	add_child(sb)
	for i in CityLayout.N:
		for j in CityLayout.N:
			var r := CityLayout.block_rect(i, j)
			var d := CityLayout.district(i, j)
			var kind := 0.0
			match d:
				"downtown": kind = 2.0
				"industrial", "port": kind = 1.0 if (i + j) % 3 else 4.0
				"beach": kind = 3.0
				_: kind = 0.0
			if special_blocks.has(Vector2i(i, j)) and d == "suburbs" and special_blocks[Vector2i(i, j)]["kind"] in ["dealership", "hospital", "gas", "clothing"]:
				kind = 1.0
			var mn := Vector3(r.position.x, 0.0, r.position.y)
			var mx := Vector3(r.end.x, CityLayout.CURB_H, r.end.y)
			var base := bk.verts.size()
			bk.add_box(mn, mx, Color.WHITE, Vector2(kind, r.size.x))
			# rewrite UVs of the top face to local block metres
			for vi in range(base, bk.verts.size()):
				var vv := bk.verts[vi]
				bk.uvs[vi] = Vector2(vv.x - r.position.x, vv.z - r.position.y)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = mx - mn
			cs.shape = bs
			cs.position = (mn + mx) / 2.0
			sb.add_child(cs)
	var bmi := MeshInstance3D.new()
	bmi.mesh = bk.commit(mat_block)
	bmi.name = "Sidewalks"
	add_child(bmi)

func _street_lights() -> void:
	var P := CityLayout.P
	for i in CityLayout.N:
		for j in CityLayout.N:
			var r := CityLayout.block_rect(i, j)
			var c := _chunk(i, j)
			var y := CityLayout.CURB_H
			for t in [0.2, 0.75]:
				# lamps on the north and south edges face the road (arm pointing outward)
				c["lamps"].append(Transform3D(Basis(Vector3.UP, PI), Vector3(r.position.x + r.size.x * t, y, r.position.y + 0.7)))
				c["lamps"].append(Transform3D(Basis(), Vector3(r.position.x + r.size.x * (1.0 - t), y, r.end.y - 0.7)))
				c["lamps"].append(Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(r.position.x + 0.7, y, r.position.y + r.size.y * (1.0 - t))))
				c["lamps"].append(Transform3D(Basis(Vector3.UP, PI / 2), Vector3(r.end.x - 0.7, y, r.position.y + r.size.y * t)))
			for tf in c["lamps"].slice(c["lamps"].size() - 8):
				c["cyls"].append([tf.origin, 0.15, 7.5])

# ------------------------------------------------------------------ blocks
func _block(i: int, j: int) -> void:
	var d := CityLayout.district(i, j)
	var lot := CityLayout.lot_rect(i, j)
	var key := Vector2i(i, j)
	if special_blocks.has(key):
		var sp: Dictionary = special_blocks[key]
		var used := _special(i, j, sp, lot, d)
		var back := _back_rect(lot, sp["side"], used)
		if back.size.x > 14 and back.size.y > 14:
			_fill(i, j, d, back)
		return
	_fill(i, j, d, lot)

func _back_rect(lot: Rect2, side: String, depth: float) -> Rect2:
	var dd := depth + 4.0
	match side:
		"n": return Rect2(lot.position.x, lot.position.y + dd, lot.size.x, lot.size.y - dd)
		"s": return Rect2(lot.position.x, lot.position.y, lot.size.x, lot.size.y - dd)
		"w": return Rect2(lot.position.x + dd, lot.position.y, lot.size.x - dd, lot.size.y)
		_: return Rect2(lot.position.x, lot.position.y, lot.size.x - dd, lot.size.y)

func _fill(i: int, j: int, d: String, rect: Rect2) -> void:
	match d:
		"downtown": _fill_downtown(i, j, rect)
		"rich": _fill_rich(i, j, rect)
		"industrial": _fill_industrial(i, j, rect)
		"port": _fill_port(i, j, rect)
		"beach": _fill_beach(i, j, rect)
		"park": _fill_park(i, j, rect)
		"golf": _fill_golf(i, j, rect)
		_: _fill_suburbs(i, j, rect)

func _bld(i: int, j: int, mn: Vector3, mx: Vector3, col: Color, style: int, collide: bool = true) -> void:
	var c := _chunk(i, j)
	c["bk"].add_box(mn, mx, col, Vector2(rng.randf() * 100.0, style))
	if collide:
		c["boxes"].append(AABB(mn, mx - mn))
	building_rects.append([Rect2(mn.x, mn.z, mx.x - mn.x, mx.z - mn.z), col])

func _prop(i: int, j: int, mn: Vector3, mx: Vector3, col: Color, collide: bool = false) -> void:
	var c := _chunk(i, j)
	c["pk"].add_box(mn, mx, col)
	if collide:
		c["boxes"].append(AABB(mn, mx - mn))

func _tree(i: int, j: int, kind: String, pos: Vector3, s: float = 1.0) -> void:
	var c := _chunk(i, j)
	if not c["trees"].has(kind):
		c["trees"][kind] = []
	c["trees"][kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), pos))
	if kind != "bush":
		c["cyls"].append([pos, 0.3 * s, 4.0])

const Y0 := 0.15

func _fill_downtown(i: int, j: int, r: Rect2) -> void:
	var center := Vector2(7.5, 6.5)
	var cfac: float = clamp(1.0 - Vector2(i + 0.5, j + 0.5).distance_to(center) / 4.5, 0.0, 1.0)
	var nx := 2 if r.size.x > 40 else 1
	var nz := 2 if r.size.y > 40 else 1
	if rng.randf() < 0.3:
		nx = 1
	var palette := [Color(0.35, 0.45, 0.55), Color(0.55, 0.6, 0.62), Color(0.25, 0.3, 0.35), Color(0.6, 0.55, 0.45), Color(0.3, 0.5, 0.55), Color(0.7, 0.68, 0.62), Color(0.45, 0.35, 0.3)]
	for a in nx:
		for b in nz:
			var pw := r.size.x / nx
			var pd := r.size.y / nz
			var x0 := r.position.x + a * pw + 1.5
			var z0 := r.position.y + b * pd + 1.5
			var x1 := x0 + pw - 3.0
			var z1 := z0 + pd - 3.0
			var h: float = lerp(28.0, 150.0, cfac) * rng.randf_range(0.55, 1.25)
			var col: Color = palette[rng.randi() % palette.size()]
			var style := 0 if rng.randf() < 0.55 else 1
			if rng.randf() < 0.45 and h > 60:
				var split := h * rng.randf_range(0.45, 0.7)
				_bld(i, j, Vector3(x0, Y0, z0), Vector3(x1, split, z1), col, style)
				var inset = min(x1 - x0, z1 - z0) * 0.18
				_bld(i, j, Vector3(x0 + inset, split, z0 + inset), Vector3(x1 - inset, h, z1 - inset), col.lightened(0.05), style)
				_roof_details(i, j, Vector3(x0 + inset, h, z0 + inset), Vector3(x1 - inset, h, z1 - inset), h > 120)
			else:
				_bld(i, j, Vector3(x0, Y0, z0), Vector3(x1, h, z1), col, style)
				_roof_details(i, j, Vector3(x0, h, z0), Vector3(x1, h, z1), h > 120)

func _roof_details(i: int, j: int, mn: Vector3, mx: Vector3, antenna: bool) -> void:
	var cx := (mn.x + mx.x) / 2.0
	var cz := (mn.z + mx.z) / 2.0
	_prop(i, j, Vector3(cx - 3, mn.y, cz - 2), Vector3(cx + 1, mn.y + 2.2, cz + 2), Color(0.5, 0.5, 0.52))
	_prop(i, j, Vector3(mn.x + 1, mn.y, mn.z + 1), Vector3(mn.x + 3.5, mn.y + 1.4, mn.z + 3), Color(0.6, 0.6, 0.62))
	if antenna:
		_prop(i, j, Vector3(cx - 0.2, mn.y, cz - 0.2), Vector3(cx + 0.2, mn.y + 18, cz + 0.2), Color(0.3, 0.3, 0.3))
		_prop(i, j, Vector3(cx - 0.3, mn.y + 18, cz - 0.3), Vector3(cx + 0.3, mn.y + 18.6, cz + 0.3), Color(1, 0.1, 0.1, 0.0))

func _fill_suburbs(i: int, j: int, r: Rect2) -> void:
	var roll := rng.randf()
	if roll < 0.15 and r.size.x > 50:
		# small apartment blocks
		var h := rng.randf_range(10, 20)
		var col = [Color(0.62, 0.38, 0.28), Color(0.7, 0.65, 0.55), Color(0.55, 0.5, 0.42)][rng.randi() % 3]
		_bld(i, j, Vector3(r.position.x + 3, Y0, r.position.y + 4), Vector3(r.end.x - 3, h, r.position.y + 20), col, 2)
		_bld(i, j, Vector3(r.position.x + 3, Y0, r.end.y - 20), Vector3(r.end.x - 3, h * 0.8, r.end.y - 4), col.darkened(0.1), 2)
		for t in 4:
			_tree(i, j, "round", Vector3(r.position.x + 6 + t * 14, Y0, r.get_center().y), rng.randf_range(0.8, 1.1))
		return
	if roll < 0.28 and r.size.x > 40:
		# strip mall + parking
		var col2 := Color(0.75, 0.7, 0.6)
		_bld(i, j, Vector3(r.position.x + 2, Y0, r.position.y + 2), Vector3(r.end.x - 2, 6.0, r.position.y + 16), col2, 1)
		for t in 5:
			var x := r.position.x + 6 + t * 10
			_prop(i, j, Vector3(x, Y0, r.position.y + 15.6), Vector3(x + 8, 5.5, r.position.y + 16.3), [Color(0.8, 0.2, 0.2), Color(0.2, 0.5, 0.8), Color(0.9, 0.7, 0.2), Color(0.3, 0.6, 0.3), Color(0.6, 0.3, 0.6)][t])
		for t in 6:
			var x2 := r.position.x + 4 + t * 8.5
			_prop(i, j, Vector3(x2, Y0, r.position.y + 24), Vector3(x2 + 0.15, Y0 + 0.02, r.position.y + 30), Color(0.9, 0.9, 0.9))
		return
	# houses facing north and south
	var cols := int(floor(r.size.x / 18.0))
	var rows := 2 if r.size.y >= 40 else 1
	var pw = r.size.x / max(1, cols)
	var house_cols := [Color(0.85, 0.82, 0.75), Color(0.75, 0.62, 0.5), Color(0.6, 0.68, 0.75), Color(0.8, 0.72, 0.55), Color(0.65, 0.72, 0.6), Color(0.88, 0.85, 0.85), Color(0.7, 0.45, 0.4)]
	var roof_cols := [Color(0.35, 0.18, 0.14), Color(0.25, 0.25, 0.28), Color(0.4, 0.3, 0.22), Color(0.2, 0.25, 0.32)]
	for c in cols:
		for row in rows:
			var x0 = r.position.x + c * pw + 3.0
			var x1 = x0 + pw - 6.0
			var facing_north := row == 0
			var zf := r.position.y + 5.0 if facing_north else r.end.y - 5.0
			var depth := rng.randf_range(8.0, 10.5)
			var z0: float = zf if facing_north else zf - depth
			var z1: float = zf + depth if facing_north else zf
			var w = min(x1 - x0, rng.randf_range(9.0, 12.0))
			var xa = x0 + rng.randf_range(0.0, max(0.0, (x1 - x0) - w))
			var h := 3.4 if rng.randf() < 0.6 else 6.2
			var hc: Color = house_cols[rng.randi() % house_cols.size()]
			_bld(i, j, Vector3(xa, Y0, z0), Vector3(xa + w, Y0 + h, z1), hc, 4)
			_chunk(i, j)["pk"].add_gable_roof(Vector3(xa - 0.4, Y0 + h, z0 - 0.4), Vector3(xa + w + 0.4, 0, z1 + 0.4), 2.2, roof_cols[rng.randi() % roof_cols.size()], true)
			# driveway & garage door
			var door_z: float = z0 - 0.02 if facing_north else z1 + 0.02
			_prop(i, j, Vector3(xa + w - 3.4, Y0, min(door_z, door_z)), Vector3(xa + w - 0.4, Y0 + 2.4, door_z + (0.05 if not facing_north else -0.05) + (0.0)), Color(0.85, 0.85, 0.82))
			# tree in yard & hedge at the back
			var yard_z: float = z1 + 5.0 if facing_north else z0 - 5.0
			if rng.randf() < 0.8:
				_tree(i, j, "round", Vector3(xa + rng.randf_range(1, w), Y0, yard_z), rng.randf_range(0.7, 1.1))
			_tree(i, j, "bush", Vector3(x0 + 1.0, Y0, (z0 + z1) * 0.5), 1.0)

func _fill_rich(i: int, j: int, r: Rect2) -> void:
	var c := r.get_center()
	var w := rng.randf_range(22, 30)
	var d := rng.randf_range(14, 18)
	var hc = [Color(0.92, 0.9, 0.85), Color(0.85, 0.8, 0.7), Color(0.8, 0.82, 0.85), Color(0.95, 0.93, 0.9)][rng.randi() % 4]
	var z0 := c.y - d / 2.0 - 4
	_bld(i, j, Vector3(c.x - w / 2, Y0, z0), Vector3(c.x + w / 2, Y0 + 8.0, z0 + d), hc, 4)
	_bld(i, j, Vector3(c.x + w / 2 - 2, Y0, z0 + 2), Vector3(c.x + w / 2 + 9, Y0 + 4.5, z0 + d - 2), hc.darkened(0.05), 4)
	_prop(i, j, Vector3(c.x - w / 2 - 0.5, Y0 + 8.0, z0 - 0.5), Vector3(c.x + w / 2 + 0.5, Y0 + 8.4, z0 + d + 0.5), Color(0.3, 0.3, 0.32))
	# pool and deck
	var pz := z0 + d + 3
	if pz + 8 < r.end.y:
		_prop(i, j, Vector3(c.x - 10, Y0, pz), Vector3(c.x + 10, Y0 + 0.05, pz + 9), Color(0.75, 0.7, 0.62))
		_prop(i, j, Vector3(c.x - 7, Y0 + 0.05, pz + 1.5), Vector3(c.x + 7, Y0 + 0.07, pz + 7.5), Color(0.15, 0.6, 0.85, 0.0))
	# hedges with gate gap at the front (north)
	var hcol := Color(0.13, 0.3, 0.12)
	_prop(i, j, Vector3(r.position.x, Y0, r.end.y - 1), Vector3(r.end.x, Y0 + 1.6, r.end.y), hcol, true)
	_prop(i, j, Vector3(r.position.x, Y0, r.position.y), Vector3(r.position.x + 1, Y0 + 1.6, r.end.y), hcol, true)
	_prop(i, j, Vector3(r.end.x - 1, Y0, r.position.y), Vector3(r.end.x, Y0 + 1.6, r.end.y), hcol, true)
	_prop(i, j, Vector3(r.position.x, Y0, r.position.y), Vector3(c.x - 5, Y0 + 1.6, r.position.y + 1), hcol, true)
	_prop(i, j, Vector3(c.x + 5, Y0, r.position.y), Vector3(r.end.x, Y0 + 1.6, r.position.y + 1), hcol, true)
	for t in 6:
		_tree(i, j, "round" if t % 2 else "pine", Vector3(r.position.x + 4 + rng.randf() * (r.size.x - 8), Y0, r.position.y + 4 + rng.randf() * 6), rng.randf_range(0.9, 1.3))

func _fill_industrial(i: int, j: int, r: Rect2) -> void:
	var cols := [Color(0.55, 0.55, 0.52), Color(0.45, 0.42, 0.38), Color(0.5, 0.35, 0.28), Color(0.35, 0.42, 0.48)]
	if rng.randf() < 0.6:
		var h := rng.randf_range(8, 15)
		_bld(i, j, Vector3(r.position.x + 3, Y0, r.position.y + 3), Vector3(r.end.x - 3, h, r.position.y + r.size.y * 0.55), cols[rng.randi() % cols.size()], 3)
		for t in 3:
			var x := r.position.x + 8 + t * 14
			_prop(i, j, Vector3(x, Y0, r.position.y + 2.9), Vector3(x + 6, Y0 + 5, r.position.y + 3.0), Color(0.3, 0.3, 0.32))
		# tanks
		for t in 2:
			var p := Vector3(r.position.x + 10 + t * 14, Y0, r.end.y - 10)
			var c := _chunk(i, j)
			c["pk"].add_mesh(MeshKit.prim_cyl(5, 5, 9, 12), Transform3D(Basis(), p + Vector3(0, 4.5, 0)), Color(0.75, 0.75, 0.72))
			c["cyls"].append([p, 5.0, 9.0])
	else:
		_bld(i, j, Vector3(r.position.x + 3, Y0, r.position.y + 3), Vector3(r.get_center().x - 2, rng.randf_range(10, 18), r.end.y - 3), cols[rng.randi() % cols.size()], 3)
		# chimney
		var cx := r.end.x - 10
		var cz := r.position.y + 12
		_chunk(i, j)["pk"].add_mesh(MeshKit.prim_cyl(1.4, 2.0, 34, 10), Transform3D(Basis(), Vector3(cx, 17, cz)), Color(0.55, 0.3, 0.25))
		_chunk(i, j)["cyls"].append([Vector3(cx, 0, cz), 2.0, 34.0])
		_containers(i, j, Rect2(r.get_center().x + 2, r.position.y + 24, r.size.x / 2 - 6, r.size.y - 30), 1)
	# fence
	_prop(i, j, Vector3(r.position.x, Y0, r.end.y - 0.2), Vector3(r.end.x, Y0 + 2.2, r.end.y), Color(0.4, 0.42, 0.42), true)

func _containers(i: int, j: int, r: Rect2, max_stack: int) -> void:
	var cols := [Color(0.7, 0.2, 0.15), Color(0.15, 0.35, 0.6), Color(0.85, 0.55, 0.1), Color(0.2, 0.5, 0.3), Color(0.55, 0.55, 0.55), Color(0.5, 0.15, 0.4)]
	var x := r.position.x
	while x + 2.6 < r.end.x:
		var z := r.position.y
		while z + 12.2 < r.end.y:
			if rng.randf() < 0.85:
				var stack := rng.randi_range(1, max_stack)
				for s in stack:
					var y := Y0 + s * 2.6
					_prop(i, j, Vector3(x, y, z), Vector3(x + 2.45, y + 2.55, z + 12.0), cols[rng.randi() % cols.size()])
				_chunk(i, j)["boxes"].append(AABB(Vector3(x, Y0, z), Vector3(2.45, stack * 2.6, 12.0)))
			z += 13.5
		x += 3.0

func _fill_port(i: int, j: int, r: Rect2) -> void:
	if rng.randf() < 0.3:
		_bld(i, j, Vector3(r.position.x + 3, Y0, r.position.y + 3), Vector3(r.end.x - 3, rng.randf_range(9, 13), r.position.y + 26), Color(0.4, 0.45, 0.5), 3)
		_containers(i, j, Rect2(r.position.x + 3, r.position.y + 30, r.size.x - 6, r.size.y - 32), 3)
	else:
		_containers(i, j, Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, r.size.y - 4), 4)

func _fill_beach(i: int, j: int, r: Rect2) -> void:
	var pastel := [Color(0.95, 0.92, 0.85), Color(0.9, 0.75, 0.65), Color(0.7, 0.85, 0.85), Color(0.95, 0.85, 0.6), Color(0.85, 0.75, 0.85)]
	if j == 13 and r.size.y > 40:
		var h := rng.randf_range(20, 48)
		_bld(i, j, Vector3(r.position.x + 4, Y0, r.position.y + 4), Vector3(r.end.x - 4, h, r.position.y + 24), pastel[rng.randi() % pastel.size()], 5)
		_bld(i, j, Vector3(r.position.x + 10, Y0, r.position.y + 24), Vector3(r.end.x - 10, h * 0.5, r.position.y + 34), pastel[rng.randi() % pastel.size()], 5)
		_prop(i, j, Vector3(r.position.x + 8, Y0, r.end.y - 16), Vector3(r.end.x - 8, Y0 + 0.08, r.end.y - 5), Color(0.15, 0.6, 0.85, 0.0))
	else:
		var n := 3
		var pw := r.size.x / n
		for t in n:
			var x0 := r.position.x + t * pw + 3
			var col: Color = pastel[rng.randi() % pastel.size()]
			var h2 := rng.randf_range(5, 8)
			_bld(i, j, Vector3(x0, Y0, r.position.y + 6), Vector3(x0 + pw - 6, Y0 + h2, r.position.y + 20), col, 4)
			_prop(i, j, Vector3(x0 - 0.3, Y0 + h2, r.position.y + 5.7), Vector3(x0 + pw - 5.7, Y0 + h2 + 0.3, r.position.y + 20.3), col.darkened(0.3))
			_bld(i, j, Vector3(x0, Y0, r.end.y - 20), Vector3(x0 + pw - 6, Y0 + h2 * 0.9, r.end.y - 6), pastel[rng.randi() % pastel.size()], 4)
	for t in 5:
		_tree(i, j, "palm", Vector3(r.position.x + 3 + rng.randf() * (r.size.x - 6), Y0, r.position.y + 1.5 + (r.size.y - 3) * rng.randf()), rng.randf_range(0.85, 1.2))

func _fill_park(i: int, j: int, r: Rect2) -> void:
	var c := r.get_center()
	_prop(i, j, Vector3(c.x - 12, Y0, c.y - 8), Vector3(c.x + 12, Y0 + 0.06, c.y + 8), Color(0.12, 0.45, 0.6, 0.0))
	_chunk(i, j)["pk"].add_mesh(MeshKit.prim_cyl(1.5, 2.0, 1.0, 12), Transform3D(Basis(), Vector3(c.x, Y0 + 0.5, c.y)), Color(0.7, 0.7, 0.68))
	for p in [Rect2(r.position.x, c.y - 1.5, r.size.x, 3), Rect2(c.x - 1.5, r.position.y, 3, r.size.y)]:
		_prop(i, j, Vector3(p.position.x, Y0, p.position.y), Vector3(p.end.x, Y0 + 0.03, p.end.y), Color(0.65, 0.6, 0.5))
	for t in 22:
		var pos := Vector3(r.position.x + 2 + rng.randf() * (r.size.x - 4), Y0, r.position.y + 2 + rng.randf() * (r.size.y - 4))
		if abs(pos.x - c.x) < 14 and abs(pos.z - c.y) < 10:
			continue
		_tree(i, j, "round" if rng.randf() < 0.7 else "pine", pos, rng.randf_range(0.8, 1.4))

func _fill_golf(i: int, j: int, r: Rect2) -> void:
	var c := r.get_center()
	_prop(i, j, Vector3(c.x - 6, Y0, c.y - 6), Vector3(c.x + 6, Y0 + 0.03, c.y + 6), Color(0.25, 0.6, 0.25))
	_prop(i, j, Vector3(c.x - 0.05, Y0, c.y - 0.05), Vector3(c.x + 0.05, Y0 + 2.4, c.y + 0.05), Color(0.9, 0.9, 0.9))
	_prop(i, j, Vector3(c.x + 0.05, Y0 + 1.8, c.y - 0.02), Vector3(c.x + 0.8, Y0 + 2.35, c.y + 0.02), Color(0.9, 0.1, 0.1))
	_prop(i, j, Vector3(c.x + 10, Y0, c.y + 4), Vector3(c.x + 18, Y0 + 0.04, c.y + 10), Color(0.88, 0.8, 0.6))
	if i == 1 and j == 1:
		_bld(i, j, Vector3(r.position.x + 4, Y0, r.end.y - 18), Vector3(r.position.x + 30, Y0 + 7, r.end.y - 4), Color(0.9, 0.88, 0.8), 4)
		_label(Vector3(r.position.x + 17, Y0 + 8.5, r.end.y - 3.9), "CRESTWOOD GOLF CLUB", Color(0.2, 0.5, 0.2), 0.0, 1.0)
	for t in 8:
		_tree(i, j, "pine" if t % 3 == 0 else "round", Vector3(r.position.x + 2 + rng.randf() * (r.size.x - 4), Y0, r.position.y + 2 + rng.randf() * (r.size.y - 4)), rng.randf_range(0.9, 1.4))

# ------------------------------------------------------------------ special buildings
func _place_front(lot: Rect2, side: String, w: float, d: float, setback: float = 2.0) -> Rect2:
	var c := lot.get_center()
	match side:
		"n": return Rect2(c.x - w / 2, lot.position.y + setback, w, d)
		"s": return Rect2(c.x - w / 2, lot.end.y - setback - d, w, d)
		"w": return Rect2(lot.position.x + setback, c.y - w / 2, d, w)
		_: return Rect2(lot.end.x - setback - d, c.y - w / 2, d, w)

func _label(pos: Vector3, text: String, col: Color, yaw: float, size: float = 1.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UI.font(true)
	l.font_size = 96
	l.pixel_size = 0.02 * size
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.outline_size = 18
	l.position = pos
	l.rotation.y = yaw
	l.double_sided = false
	l.visibility_range_end = 350.0
	add_child(l)
	return l

func _facade_sign(r: Rect2, side: String, h: float, text: String, col: Color, size: float = 1.0) -> void:
	var c := r.get_center()
	var pos := Vector3()
	match side:
		"n": pos = Vector3(c.x, h, r.position.y - 0.15)
		"s": pos = Vector3(c.x, h, r.end.y + 0.15)
		"w": pos = Vector3(r.position.x - 0.15, h, c.y)
		_: pos = Vector3(r.end.x + 0.15, h, c.y)
	# Label3D's readable side faces +Z; rotate to face outward
	var yaw := 0.0
	match side:
		"n": yaw = PI
		"s": yaw = 0.0
		"w": yaw = -PI / 2.0
		_: yaw = PI / 2.0
	_label(pos, text, col, yaw, size)

func _special(i: int, j: int, sp: Dictionary, lot: Rect2, d: String) -> float:
	var side: String = sp["side"]
	var kind: String = sp["kind"]
	var r: Rect2
	var depth := 20.0
	match kind:
		"dealership":
			r = _place_front(lot, side, 38, 22, 10)
			_bld(i, j, Vector3(r.position.x, Y0, r.position.y), Vector3(r.end.x, 9, r.end.y), Color(0.3, 0.38, 0.45), 0)
			_facade_sign(r, side, 10.5, "APEX MOTORS", UI.ACCENT, 1.4)
			_display_cars(r, side)
			depth = 32
		"modshop":
			r = _place_front(lot, side, 30, 22)
			_bld(i, j, Vector3(r.position.x, Y0, r.position.y), Vector3(r.end.x, 10, r.end.y), Color(0.45, 0.22, 0.16), 3)
			_door(i, j, r, side, 9.0, 5.5, Color(0.12, 0.12, 0.13))
			_facade_sign(r, side, 8.0, sp["name"].to_upper(), Color(0.95, 0.35, 0.2), 1.1)
		"chopshop":
			r = _place_front(lot, side, 26, 18, 8)
			_bld(i, j, Vector3(r.position.x, Y0, r.position.y), Vector3(r.end.x, 7, r.end.y), Color(0.42, 0.33, 0.24), 3)
			_door(i, j, r, side, 8.0, 5.0, Color(0.2, 0.15, 0.1))
			_facade_sign(r, side, 6.0, "RUSTY'S SALVAGE", Color(0.9, 0.6, 0.2), 1.0)
			for t in 4:
				var p := Vector3(r.position.x + 3 + t * 6, Y0, r.end.y + 4)
				_prop(i, j, p, p + Vector3(4.2, 1.3, 2.0), [Color(0.4, 0.25, 0.2), Color(0.3, 0.3, 0.35), Color(0.5, 0.45, 0.3), Color(0.25, 0.3, 0.25)][t], true)
			depth = 26
		"bank":
			r = _place_front(lot, side, 40, 30)
			_bld(i, j, Vector3(r.position.x, Y0, r.position.y), Vector3(r.end.x, 28, r.end.y), Color(0.82, 0.8, 0.75), 1)
			_columns(i, j, r, side)
			_facade_sign(r, side, 22.0, "MERIDIAN BANK", Color(0.95, 0.85, 0.5), 1.5)
			depth = 30
		"jobs":
			r = _place_front(lot, side, 40, 26)
			_bld(i, j, Vector3(r.position.x, Y0, r.position.y), Vector3(r.end.x, 11, r.end.y), Color(0.25, 0.35, 0.55), 3)
			_door(i, j, r, side, 10.0, 6.0, Color(0.15, 0.15, 0.18))
			_facade_sign(r, side, 9.0, "QUICKSHIP DEPOT", Color(1.0, 0.55, 0.15), 1.2)
			depth = 26
		"clothing", "barber", "tattoo":
			var w := 26.0 if kind == "clothing" else 16.0
			r = _place_front(lot, side, w, 14)
			var col = {"clothing": Color(0.6, 0.35, 0.45), "barber": Color(0.75, 0.75, 0.78), "tattoo": Color(0.18, 0.18, 0.2)}[kind]
			_bld(i, j, Vector3(r.position.x, Y0, r.position.y), Vector3(r.end.x, 7, r.end.y), col, 1)
			var sc = {"clothing": Color(1.0, 0.7, 0.85), "barber": Color(0.3, 0.6, 1.0), "tattoo": Color(0.9, 0.2, 0.3)}[kind]
			_facade_sign(r, side, 5.2, sp["name"].to_upper(), sc, 0.75)
			depth = 14
		"hospital":
			r = _place_front(lot, side, 46, 34)
			_bld(i, j, Vector3(r.position.x, Y0, r.position.y), Vector3(r.end.x, 24, r.end.y), Color(0.9, 0.92, 0.93), 1)
			_facade_sign(r, side, 20.0, "ST. HELENA MEDICAL", Color(0.9, 0.15, 0.15), 1.3)
			depth = 34
		"gas":
			r = _place_front(lot, side, 30, 18, 4)
			_prop(i, j, Vector3(r.position.x, 5.0, r.position.y), Vector3(r.end.x, 5.6, r.end.y), Color(0.9, 0.9, 0.9))
			_prop(i, j, Vector3(r.position.x + 1, 4.9, r.position.y + 1), Vector3(r.end.x - 1, 5.0, r.end.y - 1), Color(1.0, 1.0, 0.95, 0.0))
			for t in 4:
				var px := r.position.x + 4 + t * 7.0
				_prop(i, j, Vector3(px, Y0, r.get_center().y - 0.5), Vector3(px + 1.0, 1.8, r.get_center().y + 0.5), Color(0.85, 0.15, 0.1), true)
				_prop(i, j, Vector3(px + 0.4, Y0, r.position.y + 2), Vector3(px + 0.7, 5.0, r.position.y + 2.3), Color(0.8, 0.8, 0.8), true)
			var back2 := _place_front(lot, side, 20, 10, 24)
			_bld(i, j, Vector3(back2.position.x, Y0, back2.position.y), Vector3(back2.end.x, 5, back2.end.y), Color(0.85, 0.8, 0.7), 1)
			_label(Vector3(r.get_center().x, 6.3, r.get_center().y), "FUEL STOP", Color(1.0, 0.3, 0.2), CityLayout.side_yaw(side) + PI, 0.8)
			depth = 36
		"property":
			depth = _property_building(i, j, sp, lot)
	return depth

func _door(i: int, j: int, r: Rect2, side: String, w: float, h: float, col: Color) -> void:
	var c := r.get_center()
	match side:
		"n": _prop(i, j, Vector3(c.x - w / 2, Y0, r.position.y - 0.1), Vector3(c.x + w / 2, h, r.position.y), col)
		"s": _prop(i, j, Vector3(c.x - w / 2, Y0, r.end.y), Vector3(c.x + w / 2, h, r.end.y + 0.1), col)
		"w": _prop(i, j, Vector3(r.position.x - 0.1, Y0, c.y - w / 2), Vector3(r.position.x, h, c.y + w / 2), col)
		_: _prop(i, j, Vector3(r.end.x, Y0, c.y - w / 2), Vector3(r.end.x + 0.1, h, c.y + w / 2), col)

func _columns(i: int, j: int, r: Rect2, side: String) -> void:
	for t in 6:
		var f := (t + 0.5) / 6.0
		var p := Vector3()
		match side:
			"n": p = Vector3(r.position.x + r.size.x * f, Y0, r.position.y - 2.5)
			"s": p = Vector3(r.position.x + r.size.x * f, Y0, r.end.y + 2.5)
			"w": p = Vector3(r.position.x - 2.5, Y0, r.position.y + r.size.y * f)
			_: p = Vector3(r.end.x + 2.5, Y0, r.position.y + r.size.y * f)
		_chunk(i, j)["pk"].add_mesh(MeshKit.prim_cyl(0.8, 0.8, 14, 10), Transform3D(Basis(), p + Vector3(0, 7, 0)), Color(0.9, 0.88, 0.82))
		_chunk(i, j)["cyls"].append([p, 0.8, 14.0])

func _display_cars(r: Rect2, side: String) -> void:
	var ids := ["zephyr_gt", "summit_lx", "brawler_ss"]
	var yaw := CityLayout.side_yaw(side)
	var out := -Basis(Vector3.UP, yaw).z
	var along := Basis(Vector3.UP, yaw).x
	var front := Vector3(r.get_center().x, Y0, r.get_center().y) + out * ((r.size.y if side in ["n", "s"] else r.size.x) / 2.0 + 5.0)
	for t in 3:
		var def := Catalog.get_vehicle(ids[t])
		var m := CarModel.build(def, Catalog.default_mods(def))
		m.position = front + along * ((t - 1) * 8.0)
		m.rotation.y = yaw + 0.6
		add_child(m)
		var wheel := CarModel.wheel(def, Catalog.default_mods(def))
		var s := CarModel.spec(def["body"])
		for zi in [s["wf"], s["wr"]]:
			for sx in [-1.0, 1.0]:
				var wv: Node3D = wheel.duplicate()
				wv.position = Vector3(sx * CarModel.wheel_x(s), s["r"], -s["L"] / 2.0 + s["L"] * zi)
				m.add_child(wv)
		wheel.queue_free()
		var c := _chunk_at(m.position)
		c["boxes"].append(AABB(m.position - Vector3(2.4, 0, 2.4), Vector3(4.8, 1.3, 4.8)))

func _property_building(i: int, j: int, sp: Dictionary, lot: Rect2) -> float:
	var side: String = sp["side"]
	var tier: String = sp["tier"]
	var r: Rect2
	match tier:
		"motel":
			r = _place_front(lot, side, 34, 12, 8)
			_bld(i, j, Vector3(r.position.x, Y0, r.position.y), Vector3(r.end.x, 6.5, r.end.y), Color(0.78, 0.62, 0.45), 2)
			_prop(i, j, Vector3(r.position.x - 0.5, 3.3, r.position.y - 1.5), Vector3(r.end.x + 0.5, 3.5, r.end.y + 1.5), Color(0.5, 0.35, 0.25))
			_facade_sign(r, side, 8.0, "SUNRISE MOTEL", Color(1.0, 0.4, 0.6), 1.0)
			return 22.0
		"cheap":
			r = _place_front(lot, side, 30, 18)
			_bld(i, j, Vector3(r.position.x, Y0, r.position.y), Vector3(r.end.x, 15, r.end.y), [Color(0.58, 0.32, 0.24), Color(0.62, 0.55, 0.45), Color(0.45, 0.42, 0.4)][int(sp["id"].hash()) % 3], 2)
			_facade_sign(r, side, 12.5, sp["name"].to_upper(), Color(0.9, 0.9, 0.9), 0.45)
			return 18.0
		"medium":
			r = _place_front(lot, side, 34, 24)
			_bld(i, j, Vector3(r.position.x, Y0, r.position.y), Vector3(r.end.x, 38, r.end.y), [Color(0.85, 0.82, 0.75), Color(0.7, 0.8, 0.82), Color(0.9, 0.78, 0.65)][int(sp["id"].hash()) % 3], 5)
			_facade_sign(r, side, 6.0, sp["name"].to_upper(), Color(0.95, 0.95, 0.95), 0.4)
			return 24.0
		"luxury":
			r = _place_front(lot, side, 32, 32)
			_bld(i, j, Vector3(r.position.x, Y0, r.position.y), Vector3(r.end.x, 150, r.end.y), Color(0.25, 0.32, 0.4), 0)
			_roof_details(i, j, Vector3(r.position.x, 150, r.position.y), Vector3(r.end.x, 150, r.end.y), true)
			_facade_sign(r, side, 7.0, sp["name"].to_upper(), UI.ACCENT, 0.45)
			return 40.0
		"mansion":
			_fill_rich(i, j, lot)
			_facade_sign(Rect2(lot.get_center().x - 5, lot.position.y - 0.3, 10, 1), "n", 2.6, sp["name"].to_upper(), Color(0.95, 0.85, 0.55), 0.5)
			return 99.0
	return 20.0

# ------------------------------------------------------------------ coast & outskirts
func _coast() -> void:
	var k := MeshKit.new()
	var sb := StaticBody3D.new()
	sb.name = "Docks"
	add_child(sb)
	# port piers
	for z in [740.0, 860.0, 980.0, 1100.0, 1220.0]:
		var mn := Vector3(1295, -3.0, z - 10)
		var mx := Vector3(1370, 0.0, z + 10)
		k.add_box(mn, mx, Color(0.5, 0.5, 0.5))
		_static_box(sb, mn, mx)
		for b in 3:
			k.add_mesh(MeshKit.prim_cyl(0.3, 0.3, 0.8, 6), Transform3D(Basis(), Vector3(1310 + b * 22, 0.4, z + 9.5)), Color(0.9, 0.8, 0.2))
	# gantry cranes
	for z2 in [800.0, 920.0, 1040.0, 1160.0]:
		var x := 1292.0
		for leg in [[-6, -8], [6, -8], [-6, 8], [6, 8]]:
			k.add_box(Vector3(x + leg[0] - 0.6, 0, z2 + leg[1] - 0.6), Vector3(x + leg[0] + 0.6, 32, z2 + leg[1] + 0.6), Color(0.85, 0.35, 0.1))
			_static_box(sb, Vector3(x + leg[0] - 0.6, 0, z2 + leg[1] - 0.6), Vector3(x + leg[0] + 0.6, 32, z2 + leg[1] + 0.6))
		k.add_box(Vector3(x - 25, 32, z2 - 2), Vector3(x + 50, 35, z2 + 2), Color(0.85, 0.35, 0.1))
		k.add_box(Vector3(x - 8, 35, z2 - 9), Vector3(x + 8, 39, z2 + 9), Color(0.85, 0.35, 0.1))
	# cargo ship
	var sx := 1400.0
	var sz0 := 780.0
	k.add_box(Vector3(sx - 12, -6, sz0), Vector3(sx + 12, 4, sz0 + 150), Color(0.55, 0.12, 0.1))
	k.add_box(Vector3(sx - 12.1, 4, sz0), Vector3(sx + 12.1, 7, sz0 + 150), Color(0.1, 0.12, 0.15))
	k.add_box(Vector3(sx - 10, 7, sz0 + 125), Vector3(sx + 10, 24, sz0 + 145), Color(0.92, 0.92, 0.9))
	_static_box(sb, Vector3(sx - 12, -6, sz0), Vector3(sx + 12, 7, sz0 + 150))
	var cols := [Color(0.7, 0.2, 0.15), Color(0.15, 0.35, 0.6), Color(0.85, 0.55, 0.1), Color(0.2, 0.5, 0.3), Color(0.55, 0.55, 0.55)]
	for row in 8:
		for col in 7:
			var h := rng.randi_range(1, 4)
			for s in h:
				var y := 7.0 + s * 2.6
				var x0 := sx - 10 + col * 2.9
				var z0 := sz0 + 8 + row * 14.5
				k.add_box(Vector3(x0, y, z0), Vector3(x0 + 2.5, y + 2.55, z0 + 12), cols[rng.randi() % cols.size()])
	# beach pier with ferris wheel
	var px := 600.0
	k.add_box(Vector3(px - 5, -3.0, 1340), Vector3(px + 5, 0.3, 1460), Color(0.45, 0.33, 0.22))
	_static_box(sb, Vector3(px - 5, -3.0, 1340), Vector3(px + 5, 0.3, 1460))
	k.add_box(Vector3(px - 18, -3.0, 1460), Vector3(px + 18, 0.3, 1500), Color(0.45, 0.33, 0.22))
	_static_box(sb, Vector3(px - 18, -3.0, 1460), Vector3(px + 18, 0.3, 1500))
	var wc := Vector3(px, 22, 1482)
	for a in 24:
		var ang := TAU * a / 24.0
		var p := wc + Vector3(0, cos(ang) * 18, sin(ang) * 18)
		k.add_mesh(MeshKit.prim_box(Vector3(0.6, 0.6, 4.8)), Transform3D(Basis(Vector3.RIGHT, ang), p), Color(0.9, 0.9, 0.92))
		k.add_mesh(MeshKit.prim_box(Vector3(0.3, 18, 0.3)), Transform3D(Basis(Vector3.RIGHT, ang), wc + Vector3(0, cos(ang) * 9, sin(ang) * 9)), Color(0.8, 0.8, 0.82))
		if a % 2 == 0:
			k.add_mesh(MeshKit.prim_box(Vector3(2.2, 2.0, 2.0)), Transform3D(Basis(), p + Vector3(0, -1.6, 0)), [Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.9), Color(0.95, 0.8, 0.2)][a % 3])
		k.add_mesh(MeshKit.prim_box(Vector3(0.3, 0.3, 0.3)), Transform3D(Basis(), p + Vector3(0.5, 0, 0)), Color(1, 0.6, 0.9, 0.0))
	for leg in [-1.0, 1.0]:
		k.add_mesh(MeshKit.prim_box(Vector3(0.8, 24, 0.8)), Transform3D(Basis(Vector3.RIGHT, leg * 0.35), Vector3(px - 2, 11, 1482 + leg * 4)), Color(0.8, 0.8, 0.82))
		k.add_mesh(MeshKit.prim_box(Vector3(0.8, 24, 0.8)), Transform3D(Basis(Vector3.RIGHT, leg * 0.35), Vector3(px + 2, 11, 1482 + leg * 4)), Color(0.8, 0.8, 0.82))
	# lifeguard towers & umbrellas on the beach
	for t in 10:
		var bx := 40.0 + t * 120.0
		k.add_box(Vector3(bx - 1.5, 2.0, 1312), Vector3(bx + 1.5, 4.5, 1315), Color(0.95, 0.4, 0.3))
		for leg2 in [[-1.3, 1312.2], [1.3, 1312.2], [-1.3, 1314.8], [1.3, 1314.8]]:
			k.add_box(Vector3(bx + leg2[0] - 0.1, 0, leg2[1] - 0.1), Vector3(bx + leg2[0] + 0.1, 2.0, leg2[1] + 0.1), Color(0.9, 0.9, 0.9))
		for u in 4:
			var up := Vector3(bx + 25 + u * 9, 0, 1300 + rng.randf() * 30)
			k.add_mesh(MeshKit.prim_cyl(0.04, 0.04, 2.4, 4), Transform3D(Basis(), up + Vector3(0, 1.2, 0)), Color(0.9, 0.9, 0.9))
			k.add_mesh(MeshKit.prim_cyl(0.05, 1.4, 0.5, 8), Transform3D(Basis(), up + Vector3(0, 2.4, 0)), [Color(0.95, 0.3, 0.3), Color(0.2, 0.6, 0.9), Color(0.95, 0.85, 0.3)][u % 3])
		for p2 in 3:
			_tree_at("palm", Vector3(bx + rng.randf() * 100.0, 0, 1292 + rng.randf() * 8.0), rng.randf_range(0.9, 1.3))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit(mat_prop)
	mi.name = "Coast"
	add_child(mi)
	_label(Vector3(px, 7, 1341), "CORAL PIER", Color(1.0, 0.5, 0.7), PI, 1.2)

func _tree_at(kind: String, pos: Vector3, s: float) -> void:
	var c := _chunk_at(pos)
	if not c["trees"].has(kind):
		c["trees"][kind] = []
	c["trees"][kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), pos))
	if kind != "bush":
		c["cyls"].append([pos, 0.3 * s, 4.0])

func _static_box(sb: StaticBody3D, mn: Vector3, mx: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = mx - mn
	cs.shape = bs
	cs.position = (mn + mx) / 2.0
	sb.add_child(cs)

func _outskirts() -> void:
	# scattered woods north and west of the city
	for t in 900:
		var x := rng.randf_range(-300, 1290)
		var z := rng.randf_range(-300, 1290)
		if x > -14 and z > -14:
			continue
		_tree_at("pine" if rng.randf() < 0.6 else "round", Vector3(x, 0, z), rng.randf_range(0.8, 1.6))
	# distant mountains (scenery only)
	var k := MeshKit.new()
	for t in 26:
		var ang = lerp(PI * 0.55, PI * 1.45, t / 25.0) + rng.randf_range(-0.04, 0.04)
		var dist := rng.randf_range(900, 1300)
		var p := Vector3(640 + cos(ang) * dist * 1.3, -2, 640 - sin(ang) * dist * 0.2 - abs(sin(ang)) * 0.0)
		p = Vector3(640 + cos(ang + PI * 0.25) * dist + 0.0, -2.0, 640 + sin(ang + PI * 0.25) * dist)
		if p.x > 1200 or p.z > 1200:
			continue
		var h := rng.randf_range(120, 320)
		var rad := h * rng.randf_range(1.2, 1.8)
		k.add_mesh(MeshKit.prim_cyl(h * 0.06, rad, h, 9), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p + Vector3(0, h / 2.0, 0)), Color(0.24, 0.3, 0.22).lerp(Color(0.4, 0.38, 0.35), rng.randf()))
		k.add_mesh(MeshKit.prim_cyl(0.0, h * 0.2, h * 0.14, 9), Transform3D(Basis(), p + Vector3(0, h * 0.98, 0)), Color(0.92, 0.93, 0.95))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit(mat_prop)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Mountains"
	add_child(mi)
	# invisible boundary walls on land
	var sb := StaticBody3D.new()
	sb.name = "Bounds"
	add_child(sb)
	_static_box(sb, Vector3(-330, -5, -330), Vector3(-310, 60, 1360))
	_static_box(sb, Vector3(-330, -5, -330), Vector3(1320, 60, -310))

# ------------------------------------------------------------------ commit
func _commit_chunks() -> void:
	for key in chunks:
		var c: Dictionary = chunks[key]
		var node := Node3D.new()
		node.name = "Chunk_%d_%d" % [key.x, key.y]
		add_child(node)
		if not c["bk"].is_empty():
			var mi := MeshInstance3D.new()
			mi.mesh = c["bk"].commit(mat_building)
			node.add_child(mi)
		if not c["pk"].is_empty():
			var mi2 := MeshInstance3D.new()
			mi2.mesh = c["pk"].commit(mat_prop)
			node.add_child(mi2)
		for kind in c["trees"]:
			var arr: Array = c["trees"][kind]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = tree_meshes[kind]
			mm.instance_count = arr.size()
			for n in arr.size():
				mm.set_instance_transform(n, arr[n])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.visibility_range_end = 700.0
			node.add_child(mmi)
		if c["lamps"].size() > 0:
			var mm2 := MultiMesh.new()
			mm2.transform_format = MultiMesh.TRANSFORM_3D
			mm2.mesh = lamp_mesh
			mm2.instance_count = c["lamps"].size()
			for n in c["lamps"].size():
				mm2.set_instance_transform(n, c["lamps"][n])
			var mmi2 := MultiMeshInstance3D.new()
			mmi2.multimesh = mm2
			mmi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi2.visibility_range_end = 500.0
			node.add_child(mmi2)
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		node.add_child(sb)
		for b in c["boxes"]:
			var bb: AABB = b
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = bb.size
			cs.shape = bs
			cs.position = bb.get_center()
			sb.add_child(cs)
		for cy in c["cyls"]:
			var cs2 := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = cy[1]
			cyl.height = cy[2]
			cs2.shape = cyl
			cs2.position = cy[0] + Vector3(0, cy[2] / 2.0, 0)
			sb.add_child(cs2)

# ------------------------------------------------------------------ interaction points
func _add_point(pos: Vector3, kind: String, id: String, pname: String, vehicle: bool, col: Color, icon: String, radius: float = 2.2) -> Dictionary:
	var p := {"pos": pos, "kind": kind, "id": id, "name": pname, "vehicle": vehicle, "radius": radius, "color": col, "icon": icon}
	points.append(p)
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius if not vehicle else 3.4
	cm.bottom_radius = cm.top_radius
	cm.height = 1.6 if not vehicle else 2.4
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 24
	m.mesh = cm
	var sm := ShaderMaterial.new()
	sm.shader = mat_marker
	sm.set_shader_parameter("color", col)
	m.material_override = sm
	m.position = pos + Vector3(0, cm.height / 2.0, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visibility_range_end = 220.0
	add_child(m)
	var l := Label3D.new()
	l.text = icon
	l.font = UI.font(true)
	l.font_size = 48
	l.pixel_size = 0.007
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = col
	l.outline_size = 14
	l.position = pos + Vector3(0, cm.height + 0.9, 0)
	l.no_depth_test = false
	l.visibility_range_end = 160.0
	add_child(l)
	p["node"] = m
	p["label"] = l
	return p

func _interaction_points() -> void:
	var icons := {"dealership": "$ CARS", "modshop": "MOD SHOP", "chopshop": "CHOP SHOP", "bank": "BANK", "atm": "ATM", "jobs": "JOBS",
		"clothing": "CLOTHES", "barber": "BARBER", "tattoo": "TATTOO", "race": "RACE", "hospital": "+"}
	var colors := {"dealership": UI.ACCENT, "modshop": Color(0.95, 0.35, 0.2), "chopshop": Color(0.9, 0.6, 0.2), "bank": UI.GREEN, "atm": UI.GREEN,
		"jobs": Color(1.0, 0.55, 0.15), "clothing": Color(1.0, 0.6, 0.85), "barber": Color(0.4, 0.7, 1.0), "tattoo": Color(0.9, 0.25, 0.35), "race": Color(0.7, 0.4, 1.0), "hospital": Color(1, 0.2, 0.2)}
	for poi in Catalog.POIS:
		var b: Vector2i = poi["block"]
		var kind: String = poi["kind"]
		if kind == "hospital":
			continue
		if kind in ["modshop", "chopshop"]:
			var rp := CityLayout.road_point(b.x, b.y, poi["side"])
			_add_point(rp, kind, poi["id"], poi["name"], true, colors[kind], icons[kind], 4.0)
		elif kind == "race":
			var rp2 := CityLayout.road_point(b.x, b.y, poi["side"])
			var p := _add_point(rp2, kind, poi["id"], poi["name"], true, colors[kind], icons[kind], 4.0)
			p["race"] = poi["race"]
		else:
			var fp := CityLayout.front_point(b.x, b.y, poi["side"], 0.5 if kind != "atm" else 0.3)
			if kind == "atm":
				_atm_prop(fp, poi["side"])
			_add_point(fp, kind, poi["id"], poi["name"], false, colors[kind], icons[kind], 1.4 if kind == "atm" else 2.0)
	for pid in Catalog.PROPERTIES:
		var pr: Dictionary = Catalog.PROPERTIES[pid]
		var b2: Vector2i = pr["block"]
		var fp2 := CityLayout.front_point(b2.x, b2.y, pr["side"], 0.38)
		var p2 := _add_point(fp2, "property", pid, pr["name"], false, Color(0.3, 0.85, 1.0), "HOME", 1.8)
		var gp := CityLayout.road_point(b2.x, b2.y, pr["side"], 0.62)
		var p3 := _add_point(gp, "garage", pid, pr["name"] + " Garage", true, Color(0.3, 0.85, 1.0), "GARAGE", 4.0)
		p2["property"] = pid
		p3["property"] = pid

func _atm_prop(pos: Vector3, side: String) -> void:
	var yaw := CityLayout.side_yaw(side)
	var k := MeshKit.new()
	var back := -Basis(Vector3.UP, yaw).z * -1.4
	k.add_mesh(MeshKit.prim_box(Vector3(0.9, 1.8, 0.6)), Transform3D(Basis(Vector3.UP, yaw), pos + back + Vector3(0, 0.9, 0)), Color(0.15, 0.4, 0.25))
	k.add_mesh(MeshKit.prim_box(Vector3(0.6, 0.4, 0.05)), Transform3D(Basis(Vector3.UP, yaw), pos + back * 0.78 + Vector3(0, 1.3, 0)), Color(0.4, 0.9, 1.0, 0.0))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit(mat_prop)
	add_child(mi)

func property_door(pid: String) -> Vector3:
	var pr: Dictionary = Catalog.PROPERTIES[pid]
	return CityLayout.front_point(pr["block"].x, pr["block"].y, pr["side"], 0.38)

func property_garage_spot(pid: String) -> Dictionary:
	var pr: Dictionary = Catalog.PROPERTIES[pid]
	var side: String = pr["side"]
	var p := CityLayout.road_point(pr["block"].x, pr["block"].y, side, 0.62)
	# park facing along the road (right-hand lane direction)
	var yaw := 0.0
	match side:
		"n": yaw = -PI / 2.0
		"s": yaw = PI / 2.0
		"w": yaw = 0.0
		_: yaw = PI
	return {"pos": p + Vector3(0, 0.6, 0), "yaw": yaw}

func poi_pos(id: String) -> Vector3:
	for p in points:
		if p["id"] == id:
			return p["pos"]
	for poi in Catalog.POIS:
		if poi["id"] == id:
			return CityLayout.front_point(poi["block"].x, poi["block"].y, poi["side"])
	return Vector3(100, 1, 100)

# ------------------------------------------------------------------ minimap
func world_to_map(p: Vector3) -> Vector2:
	return (Vector2(p.x, p.z) - MAP_ORIGIN) / MAP_SCALE

func _minimap() -> void:
	var img := Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.10, 0.22, 0.33))
	var lm := world_to_map(Vector3(CityLayout.LAND_MIN.x, 0, CityLayout.LAND_MIN.y))
	var lx := world_to_map(Vector3(CityLayout.LAND_MAX.x, 0, CityLayout.LAND_MAX.y))
	img.fill_rect(Rect2i(Vector2i(lm), Vector2i(lx - lm)), Color(0.17, 0.24, 0.16))
	var sand_a := world_to_map(Vector3(CityLayout.LAND_MIN.x, 0, 1288))
	img.fill_rect(Rect2i(Vector2i(sand_a), Vector2i(lx - sand_a)), Color(0.55, 0.5, 0.38))
	for i in CityLayout.N:
		for j in CityLayout.N:
			var r := CityLayout.block_rect(i, j)
			var dc: Color = CityLayout.DISTRICTS[CityLayout.district(i, j)]["color"]
			var a := world_to_map(Vector3(r.position.x, 0, r.position.y))
			var b := world_to_map(Vector3(r.end.x, 0, r.end.y))
			img.fill_rect(Rect2i(Vector2i(a), Vector2i(b - a)), dc.darkened(0.45))
	for br in building_rects:
		var rr: Rect2 = br[0]
		var a2 := world_to_map(Vector3(rr.position.x, 0, rr.position.y))
		var b2 := world_to_map(Vector3(rr.end.x, 0, rr.end.y))
		img.fill_rect(Rect2i(Vector2i(a2), Vector2i((b2 - a2).ceil())), (br[1] as Color).darkened(0.35).lerp(Color(0.3, 0.3, 0.32), 0.5))
	var P := CityLayout.P
	for n in CityLayout.N + 1:
		var a3 := world_to_map(Vector3(n * P - 7, 0, -8))
		var b3 := world_to_map(Vector3(n * P + 7, 0, CityLayout.SIZE + 8))
		img.fill_rect(Rect2i(Vector2i(a3), Vector2i(b3 - a3)), Color(0.62, 0.64, 0.68))
		var a4 := world_to_map(Vector3(-8, 0, n * P - 7))
		var b4 := world_to_map(Vector3(CityLayout.SIZE + 8, 0, n * P + 7))
		img.fill_rect(Rect2i(Vector2i(a4), Vector2i(b4 - a4)), Color(0.62, 0.64, 0.68))
	# piers
	for z in [740.0, 860.0, 980.0, 1100.0, 1220.0]:
		var a5 := world_to_map(Vector3(1295, 0, z - 10))
		var b5 := world_to_map(Vector3(1370, 0, z + 10))
		img.fill_rect(Rect2i(Vector2i(a5), Vector2i(b5 - a5)), Color(0.45, 0.45, 0.47))
	var a6 := world_to_map(Vector3(595, 0, 1340))
	var b6 := world_to_map(Vector3(605, 0, 1500))
	img.fill_rect(Rect2i(Vector2i(a6), Vector2i(b6 - a6)), Color(0.5, 0.4, 0.3))
	minimap_image = img
	minimap_texture = ImageTexture.create_from_image(img)
