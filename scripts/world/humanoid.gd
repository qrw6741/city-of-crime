class_name Humanoid
extends Node3D
## Procedural low-poly character built from an appearance dictionary, with procedural animation.

var appearance: Dictionary = {}
var detail := true   # false = cheaper model for crowds

var body: Node3D
var hips: Node3D
var chest: Node3D
var head: Node3D
var sh_l: Node3D
var sh_r: Node3D
var el_l: Node3D
var el_r: Node3D
var hip_l: Node3D
var hip_r: Node3D
var kn_l: Node3D
var kn_r: Node3D

var phase := 0.0
var _mat_cache := {}
var pose := "normal"   # normal, fall, dead, sit
var _fall_t := 0.0

func build(app: Dictionary, high_detail: bool = true) -> void:
	appearance = app.duplicate(true)
	detail = high_detail
	for c in get_children():
		c.queue_free()
	_mat_cache.clear()
	var a := appearance
	var female: bool = a.get("gender", "male") == "female"
	var skin: Color = Catalog.SKIN_TONES[int(a.get("skin", 2)) % Catalog.SKIN_TONES.size()]
	var hair_c: Color = Catalog.HAIR_COLORS[int(a.get("hair_color", 1)) % Catalog.HAIR_COLORS.size()]
	var top_c: Color = Catalog.CLOTH_COLORS[int(a.get("top_color", 0)) % Catalog.CLOTH_COLORS.size()]
	var bot_c: Color = Catalog.CLOTH_COLORS[int(a.get("bottom_color", 3)) % Catalog.CLOTH_COLORS.size()]
	var shoe_c: Color = Catalog.CLOTH_COLORS[int(a.get("shoe_color", 0)) % Catalog.CLOTH_COLORS.size()]
	var build_f: float = float(a.get("build", 0.5))
	var height: float = float(a.get("height", 1.0)) * (0.94 if female else 1.0)
	var top: int = int(a.get("top", 0))
	var bottom: int = int(a.get("bottom", 0))
	var tattoo: int = int(a.get("tattoo", 0))

	body = Node3D.new()
	body.name = "Body"
	body.scale = Vector3.ONE * height
	body.rotation.y = PI   # model is authored facing +Z; Godot forward is -Z
	add_child(body)
	hips = _pivot(body, Vector3(0, 0.95, 0))
	var bw: float = lerp(0.30, 0.42, build_f) * (0.88 if female else 1.0)
	var hipw: float = bw * (1.05 if female else 0.9)
	# pelvis
	_box(hips, Vector3(hipw, 0.18, 0.2), Vector3(0, 0.02, 0), bot_c)
	chest = _pivot(hips, Vector3(0, 0.1, 0))
	# torso
	var top_col := top_c
	_box(chest, Vector3(bw * (0.82 if female else 0.9), 0.22, 0.19), Vector3(0, 0.1, 0), top_col)
	_box(chest, Vector3(bw, 0.24, 0.22), Vector3(0, 0.3, 0), top_col)
	if top == 4:   # suit: shirt + tie
		_box(chest, Vector3(0.09, 0.3, 0.02), Vector3(0, 0.28, 0.105), Color(0.95, 0.95, 0.95))
		_box(chest, Vector3(0.035, 0.26, 0.025), Vector3(0, 0.27, 0.112), Color(0.5, 0.08, 0.1))
	elif top == 1:   # hoodie: hood on back + pocket
		_box(chest, Vector3(0.22, 0.12, 0.08), Vector3(0, 0.42, -0.12), top_col.darkened(0.15))
		_box(chest, Vector3(0.2, 0.08, 0.02), Vector3(0, 0.08, 0.1), top_col.darkened(0.1))
	elif top == 3:   # leather jacket: collar + zip
		_box(chest, Vector3(bw * 0.7, 0.05, 0.22), Vector3(0, 0.43, 0), top_col.darkened(0.3))
		_box(chest, Vector3(0.015, 0.4, 0.02), Vector3(0.03, 0.22, 0.112), Color(0.7, 0.7, 0.7))
	elif top == 5:   # polo collar
		_box(chest, Vector3(0.16, 0.04, 0.2), Vector3(0, 0.43, 0.01), top_col.lightened(0.2))
	# neck & head
	_box(chest, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.46, 0), skin)
	if tattoo == 4 or tattoo == 5:
		_box(chest, Vector3(0.102, 0.05, 0.06), Vector3(0, 0.46, 0.022), Color(0.1, 0.12, 0.2))
	if int(a.get("chain", 0)) > 0:
		var ch := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.07
		tm.outer_radius = 0.085
		tm.rings = 12
		tm.ring_segments = 6
		ch.mesh = tm
		ch.material_override = _mat(Color(0.8, 0.8, 0.85) if int(a["chain"]) == 1 else Color(0.95, 0.75, 0.25), 0.2, 1.0)
		ch.position = Vector3(0, 0.43, 0.03)
		ch.rotation.x = 1.2
		chest.add_child(ch)
	head = _pivot(chest, Vector3(0, 0.62, 0))
	_build_head(head, a, skin, hair_c, female)
	# arms
	var short_sleeve: bool = top in [0, 2, 5]
	var sleeveless: bool = top == 2
	var arm_x: float = bw * 0.5 + 0.05
	sh_l = _pivot(chest, Vector3(arm_x, 0.38, 0))
	sh_r = _pivot(chest, Vector3(-arm_x, 0.38, 0))
	for side in [sh_l, sh_r]:
		var is_left: bool = side == sh_l
		var up_c: Color = skin if sleeveless else top_col
		_box(side, Vector3(0.09, 0.3, 0.09), Vector3(0, -0.14, 0), up_c)
		if short_sleeve and not sleeveless:
			_box(side, Vector3(0.082, 0.12, 0.082), Vector3(0, -0.24, 0), skin)
		var tat: bool = (tattoo == 1 and is_left) or (tattoo == 2 and not is_left) or tattoo == 3 or tattoo == 5
		var el := _pivot(side, Vector3(0, -0.3, 0))
		_box(el, Vector3(0.08, 0.27, 0.08), Vector3(0, -0.13, 0), skin if short_sleeve or sleeveless else top_col)
		if tat and (short_sleeve or sleeveless):
			_box(el, Vector3(0.084, 0.16, 0.084), Vector3(0, -0.12, 0), skin.darkened(0.35).lerp(Color(0.12, 0.15, 0.3), 0.5))
		_box(el, Vector3(0.07, 0.08, 0.07), Vector3(0, -0.31, 0), skin)   # hand
		if is_left and int(a.get("watch", 0)) > 0:
			var wc: Color = [Color.BLACK, Color(0.75, 0.75, 0.8), Color(0.95, 0.75, 0.25), Color(0.1, 0.1, 0.12)][int(a["watch"])]
			_box(el, Vector3(0.088, 0.035, 0.088), Vector3(0, -0.25, 0), wc, 0.2, 0.9)
		if is_left:
			el_l = el
		else:
			el_r = el
	# legs
	var shorts: bool = bottom == 1
	hip_l = _pivot(hips, Vector3(hipw * 0.28, -0.04, 0))
	hip_r = _pivot(hips, Vector3(-hipw * 0.28, -0.04, 0))
	for side in [hip_l, hip_r]:
		_box(side, Vector3(0.13, 0.44, 0.14), Vector3(0, -0.22, 0), bot_c)
		if bottom == 2:   # cargo pockets
			_box(side, Vector3(0.14, 0.1, 0.1), Vector3(0, -0.28, 0.0), bot_c.darkened(0.15))
		if bottom == 4:   # track stripe
			_box(side, Vector3(0.135, 0.44, 0.03), Vector3(0, -0.22, 0), Color(0.95, 0.95, 0.95))
		var kn := _pivot(side, Vector3(0, -0.44, 0))
		_box(kn, Vector3(0.11, 0.42, 0.12), Vector3(0, -0.21, 0), skin if shorts else bot_c)
		if shorts:
			_box(kn, Vector3(0.12, 0.08, 0.13), Vector3(0, -0.02, 0), bot_c)
		_build_shoe(kn, int(a.get("shoes", 0)), shoe_c, skin)
		if side == hip_l:
			kn_l = kn
		else:
			kn_r = kn

func _build_head(h: Node3D, a: Dictionary, skin: Color, hair_c: Color, female: bool) -> void:
	var jaw: float = float(a.get("jaw", 0.5))
	var hm := _sphere(h, 0.12, Vector3.ZERO, skin)
	hm.scale = Vector3(lerp(0.88, 1.05, jaw), 1.08, 1.0)
	if detail:
		var eye_c: Color = Catalog.EYE_COLORS[int(a.get("eyes", 0)) % Catalog.EYE_COLORS.size()]
		for x in [-0.042, 0.042]:
			_sphere(h, 0.022, Vector3(x, 0.02, 0.1), Color(0.95, 0.95, 0.95))
			_sphere(h, 0.012, Vector3(x, 0.02, 0.118), eye_c)
			_box(h, Vector3(0.045, 0.01, 0.02), Vector3(x, 0.055, 0.105), hair_c.darkened(0.2))
		_box(h, Vector3(0.025, 0.04, 0.03), Vector3(0, -0.01, 0.12), skin.darkened(0.08))
		_box(h, Vector3(0.05, 0.012, 0.01), Vector3(0, -0.06, 0.11), (Color(0.7, 0.3, 0.35) if female else skin.darkened(0.35)))
		for x in [-0.122, 0.122]:
			_sphere(h, 0.025, Vector3(x * lerp(0.88, 1.05, jaw), 0.0, 0.0), skin)
	# hair
	var style: int = int(a.get("hair", 2))
	match style:
		1: _cap(h, 0.124, hair_c, 0.97)
		2: _cap(h, 0.13, hair_c, 1.0)
		3:
			_cap(h, 0.13, hair_c, 1.0)
			_box(h, Vector3(0.2, 0.06, 0.16), Vector3(0, 0.09, -0.04), hair_c)
		4:
			_cap(h, 0.124, hair_c.darkened(0.2), 0.95)
			_box(h, Vector3(0.04, 0.09, 0.24), Vector3(0, 0.14, -0.01), hair_c)
		5: _sphere(h, 0.19, Vector3(0, 0.07, -0.03), hair_c)
		6:
			_cap(h, 0.132, hair_c, 1.0)
			_box(h, Vector3(0.25, 0.3, 0.07), Vector3(0, -0.07, -0.09), hair_c)
		7:
			_cap(h, 0.13, hair_c, 1.0)
			_sphere(h, 0.045, Vector3(0, 0.06, -0.14), hair_c)
			_box(h, Vector3(0.05, 0.2, 0.05), Vector3(0, -0.06, -0.16), hair_c)
		8:
			_cap(h, 0.13, hair_c, 1.0)
			_sphere(h, 0.06, Vector3(0, 0.14, -0.08), hair_c)
		9:
			_cap(h, 0.134, hair_c, 1.0)
			_box(h, Vector3(0.27, 0.16, 0.2), Vector3(0, -0.02, -0.03), hair_c)
	# beard
	var beard: int = int(a.get("beard", 0))
	var bc := hair_c
	match beard:
		1:
			var s := _sphere(h, 0.122, Vector3(0, -0.015, 0.006), skin.lerp(bc, 0.35))
			s.scale = Vector3(lerp(0.88, 1.05, jaw) * 1.0, 0.85, 0.98)
			(s.mesh as SphereMesh).is_hemisphere = true
			(s.mesh as SphereMesh).height = 0.122 * 0.9
			s.rotation.x = PI
		2: _box(h, Vector3(0.05, 0.06, 0.04), Vector3(0, -0.09, 0.09), bc)
		3:
			var s2 := _sphere(h, 0.128, Vector3(0, -0.02, 0.01), bc)
			s2.scale = Vector3(lerp(0.88, 1.05, jaw), 1.0, 1.0)
			(s2.mesh as SphereMesh).is_hemisphere = true
			(s2.mesh as SphereMesh).height = 0.128
			s2.rotation.x = PI
			_box(h, Vector3(0.05, 0.012, 0.012), Vector3(0, -0.06, 0.118), skin.darkened(0.4))
		4: _box(h, Vector3(0.07, 0.018, 0.02), Vector3(0, -0.04, 0.115), bc)
	# hat
	var hat: int = int(a.get("hat", 0))
	var hat_c: Color = Catalog.CLOTH_COLORS[int(a.get("hat_color", 1)) % Catalog.CLOTH_COLORS.size()]
	match hat:
		1:
			_cap(h, 0.138, hat_c, 1.0)
			_box(h, Vector3(0.16, 0.012, 0.12), Vector3(0, 0.06, 0.15), hat_c.darkened(0.2))
		2:
			var b := _cap(h, 0.142, hat_c, 1.0)
			b.scale.y = 1.25
		3:
			_cyl(h, 0.11, 0.12, Vector3(0, 0.12, 0), hat_c)
			_cyl(h, 0.2, 0.012, Vector3(0, 0.07, 0), hat_c)
			_cyl(h, 0.112, 0.025, Vector3(0, 0.09, 0), Color(0.1, 0.1, 0.1))
		4:
			_cyl(h, 0.13, 0.1, Vector3(0, 0.11, 0), hat_c)
			_cyl(h, 0.18, 0.012, Vector3(0, 0.065, 0), hat_c)
	# glasses
	var gl: int = int(a.get("glasses", 0))
	if gl > 0:
		var frame := Color(0.1, 0.1, 0.1) if gl != 1 else Color(0.85, 0.75, 0.4)
		var lens := Color(0.05, 0.05, 0.08) if gl != 2 else Color(0.6, 0.8, 0.9, 0.4)
		for x in [-0.045, 0.045]:
			_box(h, Vector3(0.06, 0.04 if gl != 3 else 0.035, 0.012), Vector3(x, 0.02, 0.125), lens, 0.1, 0.4)
		_box(h, Vector3(0.17, 0.008, 0.01), Vector3(0, 0.045, 0.125), frame)

func _build_shoe(kn: Node3D, kind: int, c: Color, skin: Color) -> void:
	match kind:
		0:
			_box(kn, Vector3(0.12, 0.08, 0.24), Vector3(0, -0.45, 0.04), c)
			_box(kn, Vector3(0.125, 0.025, 0.25), Vector3(0, -0.485, 0.04), Color(0.95, 0.95, 0.95))
		1:
			_box(kn, Vector3(0.13, 0.16, 0.25), Vector3(0, -0.42, 0.04), c.darkened(0.4))
			_box(kn, Vector3(0.135, 0.03, 0.26), Vector3(0, -0.485, 0.04), Color(0.1, 0.08, 0.06))
		2: _box(kn, Vector3(0.11, 0.07, 0.25), Vector3(0, -0.46, 0.04), Color(0.08, 0.06, 0.05), 0.2, 0.3)
		_:
			_box(kn, Vector3(0.11, 0.05, 0.23), Vector3(0, -0.47, 0.04), skin)
			_box(kn, Vector3(0.115, 0.02, 0.24), Vector3(0, -0.49, 0.04), c)

# ------------------------------------------------------------------ mesh helpers
func _mat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [c.to_html(), rough, metal]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if c.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _box(parent: Node3D, sz: Vector3, pos: Vector3, c: Color, rough: float = 0.8, metal: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(c, rough, metal)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if detail else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, r: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12 if detail else 8
	sm.rings = 6 if detail else 4
	mi.mesh = sm
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi

func _cap(parent: Node3D, r: float, c: Color, ys: float) -> MeshInstance3D:
	var mi := _sphere(parent, r, Vector3(0, 0.012, -0.012), c)
	(mi.mesh as SphereMesh).is_hemisphere = true
	(mi.mesh as SphereMesh).height = r
	mi.rotation.x = -0.28
	mi.scale = Vector3(1.0, ys, 1.05)
	return mi

func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 12
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi

# ------------------------------------------------------------------ animation
func animate(delta: float, speed: float, grounded: bool, running: bool) -> void:
	if hips == null:
		return
	if pose == "fall" or pose == "dead":
		_fall_t = min(1.0, _fall_t + delta * 3.0)
		body.rotation.x = lerp(body.rotation.x, -PI / 2.0, _fall_t)
		body.position.y = lerp(body.position.y, 0.15, _fall_t)
		return
	if pose == "sit":
		hip_l.rotation.x = 1.4
		hip_r.rotation.x = 1.4
		kn_l.rotation.x = -1.4
		kn_r.rotation.x = -1.4
		sh_l.rotation.x = 0.9
		sh_r.rotation.x = 0.9
		return
	body.rotation.x = 0.0
	body.position.y = 0.0
	if not grounded:
		_blend(hip_l, 0.6, delta)
		_blend(hip_r, -0.2, delta)
		_blend(kn_l, -0.9, delta)
		_blend(kn_r, -0.4, delta)
		_blend(sh_l, -2.3, delta)
		_blend(sh_r, -2.3, delta)
		_blend(el_l, 0.0, delta)
		_blend(el_r, 0.0, delta)
		return
	if speed > 0.3:
		var stride: float = 1.7 if running else 1.25
		phase += delta * speed * 4.2 / stride
		var amp: float = clamp(speed / 4.0, 0.2, 1.0) * (0.95 if running else 0.6)
		var s := sin(phase)
		hip_l.rotation.x = s * amp
		hip_r.rotation.x = -s * amp
		kn_l.rotation.x = -max(0.0, -cos(phase)) * amp * 1.4
		kn_r.rotation.x = -max(0.0, cos(phase)) * amp * 1.4
		sh_l.rotation.x = -s * amp * 0.9
		sh_r.rotation.x = s * amp * 0.9
		el_l.rotation.x = -(0.9 if running else 0.25)
		el_r.rotation.x = -(0.9 if running else 0.25)
		chest.rotation.x = 0.18 if running else 0.04
		body.position.y = abs(cos(phase)) * (0.06 if running else 0.025)
	else:
		phase += delta * 1.5
		for n in [hip_l, hip_r, kn_l, kn_r, sh_l, sh_r]:
			_blend(n, 0.0, delta)
		_blend(el_l, -0.1, delta)
		_blend(el_r, -0.1, delta)
		chest.rotation.x = lerp(chest.rotation.x, 0.0, delta * 8.0)
		chest.position.y = 0.1 + sin(phase) * 0.004
		sh_l.rotation.z = 0.06
		sh_r.rotation.z = -0.06

func _blend(n: Node3D, target: float, delta: float) -> void:
	n.rotation.x = lerp(n.rotation.x, target, min(1.0, delta * 12.0))

func set_pose(p: String) -> void:
	pose = p
	_fall_t = 0.0
	if p == "normal" and body:
		body.rotation = Vector3(0, PI, 0)
		body.position = Vector3.ZERO
