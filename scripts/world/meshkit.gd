class_name MeshKit
## Batches lots of boxes / primitives into single meshes (vertex coloured, with custom UVs).

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var idx := PackedInt32Array()

func is_empty() -> bool:
	return verts.is_empty()

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, u2: Vector2) -> void:
	## a-b-c-d in order around the quad; winding fixed so the face points along n.
	var base := verts.size()
	verts.append_array([a, b, c, d])
	for i in 4:
		norms.append(n)
		cols.append(col)
		uv2s.append(u2)
	uvs.append_array([ua, ub, uc, ud])
	if (b - a).cross(c - a).dot(n) > 0.0:
		idx.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	else:
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

func add_box(mn: Vector3, mx: Vector3, col: Color, u2: Vector2 = Vector2.ZERO, bottom: bool = false) -> void:
	## Axis-aligned box. Side UVs are in metres (u along face, v = world height), top UV = xz.
	var x0 := mn.x
	var x1 := mx.x
	var y0 := mn.y
	var y1 := mx.y
	var z0 := mn.z
	var z1 := mx.z
	var w := x1 - x0
	var d := z1 - z0
	# +Z face
	_quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.BACK, col, Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1), u2)
	# -Z face
	_quad(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3.FORWARD, col, Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1), u2)
	# +X
	_quad(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3.RIGHT, col, Vector2(0, y0), Vector2(d, y0), Vector2(d, y1), Vector2(0, y1), u2)
	# -X
	_quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3.LEFT, col, Vector2(0, y0), Vector2(d, y0), Vector2(d, y1), Vector2(0, y1), u2)
	# top
	_quad(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP, col, Vector2(0, 0), Vector2(w, 0), Vector2(w, d), Vector2(0, d), u2)
	if bottom:
		_quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3.DOWN, col, Vector2(0, 0), Vector2(w, 0), Vector2(w, d), Vector2(0, d), u2)

func add_flat(mn: Vector3, mx: Vector3, col: Color, uv_origin: Vector2, u2: Vector2) -> void:
	## Horizontal quad at mn.y with UV = local metres.
	var y := mn.y
	var o := uv_origin
	_quad(Vector3(mn.x, y, mn.z), Vector3(mx.x, y, mn.z), Vector3(mx.x, y, mx.z), Vector3(mn.x, y, mx.z), Vector3.UP, col,
		Vector2(mn.x, mn.z) - o, Vector2(mx.x, mn.z) - o, Vector2(mx.x, mx.z) - o, Vector2(mn.x, mx.z) - o, u2)

func add_road(a: Vector3, b: Vector3, width: float, kind: float) -> void:
	## Road strip from a to b (axis aligned). UV.x across (0..width), UV.y along (m). UV2 = (kind, length).
	var dir := (b - a)
	var length := dir.length()
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0, dir.x) * (width / 2.0)
	var y := Vector3(0, 0.02, 0)
	_quad(a - side + y, a + side + y, b + side + y, b - side + y, Vector3.UP, Color.WHITE,
		Vector2(0, 0), Vector2(width, 0), Vector2(width, length), Vector2(0, length), Vector2(kind, length))

func add_gable_roof(mn: Vector3, mx: Vector3, height: float, col: Color, along_x: bool) -> void:
	var y0 := mn.y
	var y1 := y0 + height
	var u2 := Vector2(0, 9)
	if along_x:
		var zm := (mn.z + mx.z) / 2.0
		var n1 := Vector3(0, mx.z - mn.z, -2.0 * height).normalized()
		var n2 := Vector3(0, mx.z - mn.z, 2.0 * height).normalized()
		_quad(Vector3(mn.x, y0, mn.z), Vector3(mx.x, y0, mn.z), Vector3(mx.x, y1, zm), Vector3(mn.x, y1, zm), n1, col, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, u2)
		_quad(Vector3(mn.x, y0, mx.z), Vector3(mn.x, y1, zm), Vector3(mx.x, y1, zm), Vector3(mx.x, y0, mx.z), n2, col, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, u2)
		_tri3(Vector3(mn.x, y0, mn.z), Vector3(mn.x, y0, mx.z), Vector3(mn.x, y1, zm), Vector3.LEFT, col.darkened(0.1), u2)
		_tri3(Vector3(mx.x, y0, mn.z), Vector3(mx.x, y1, zm), Vector3(mx.x, y0, mx.z), Vector3.RIGHT, col.darkened(0.1), u2)
	else:
		var xm := (mn.x + mx.x) / 2.0
		var n3 := Vector3(-(2.0 * height), mx.x - mn.x, 0).normalized()
		var n4 := Vector3(2.0 * height, mx.x - mn.x, 0).normalized()
		_quad(Vector3(mn.x, y0, mn.z), Vector3(xm, y1, mn.z), Vector3(xm, y1, mx.z), Vector3(mn.x, y0, mx.z), n3, col, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, u2)
		_quad(Vector3(mx.x, y0, mn.z), Vector3(mx.x, y0, mx.z), Vector3(xm, y1, mx.z), Vector3(xm, y1, mn.z), n4, col, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, u2)
		_tri3(Vector3(mn.x, y0, mn.z), Vector3(mx.x, y0, mn.z), Vector3(xm, y1, mn.z), Vector3.FORWARD, col.darkened(0.1), u2)
		_tri3(Vector3(mn.x, y0, mx.z), Vector3(xm, y1, mx.z), Vector3(mx.x, y0, mx.z), Vector3.BACK, col.darkened(0.1), u2)

func _tri3(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color, u2: Vector2) -> void:
	var base := verts.size()
	verts.append_array([a, b, c])
	for i in 3:
		norms.append(n)
		cols.append(col)
		uvs.append(Vector2.ZERO)
		uv2s.append(u2)
	if (b - a).cross(c - a).dot(n) > 0.0:
		idx.append_array([base, base + 2, base + 1])
	else:
		idx.append_array([base, base + 1, base + 2])

func add_mesh(mesh: Mesh, xf: Transform3D, col: Color) -> void:
	## Appends a primitive mesh (surface 0) transformed and coloured.
	var arr: Array = (mesh as PrimitiveMesh).get_mesh_arrays() if mesh is PrimitiveMesh else mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var base := verts.size()
	var nb := xf.basis.inverse().transposed()
	for i in v.size():
		verts.append(xf * v[i])
		norms.append((nb * n[i]).normalized())
		cols.append(col)
		uvs.append(Vector2.ZERO)
		uv2s.append(Vector2.ZERO)
	if ind.is_empty():
		for i in v.size():
			idx.append(base + i)
	else:
		for i in ind:
			idx.append(base + i)

func commit(material: Material = null) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	if verts.is_empty():
		return m
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		m.surface_set_material(0, material)
	return m

static func prim_box(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b

static func prim_cyl(r_top: float, r_bot: float, h: float, seg: int = 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

static func prim_sphere(r: float, seg: int = 8) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = max(3, seg / 2)
	return s
