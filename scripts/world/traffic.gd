class_name Traffic
extends Node3D
## Lane-following ambient traffic on the road grid, with intersection reservation, car following,
## player avoidance, hijacking and crash-to-physics conversion.

class TCar:
	var body: AnimatableBody3D
	var model_id: String
	var mods: Dictionary
	var a: Vector2i
	var b: Vector2i
	var c := Vector2i(-1, -1)
	var t := 0.0
	var speed := 0.0
	var cruise := 12.0
	var turning := false
	var turn_t := 0.0
	var turn_len := 10.0
	var p0: Vector3
	var p1: Vector3
	var p2: Vector3
	var wait := 0.0
	var wheels: Array = []
	var length := 4.5
	var id := 0

var player: Player
var cars: Array = []
var target_count := 34
var locks := {}            # Vector2i -> car id
var _next_id := 1
var rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0
var _sorted_segments := {}

const POOL := {
	"default": ["novak_pip", "valor_cruiser", "valor_cruiser", "haldane_meridian", "kestrel_avanti", "atlas_ranger", "courier_van", "workhorse_2500", "taxi", "dominus_classic", "mule_4x4", "sprite_125", "razor_600"],
	"rich": ["orion_stately", "summit_lx", "mirage_coupe", "lynx_rs", "zephyr_gt", "bastion_v8", "kestrel_avanti", "raiden_s7"],
	"industrial": ["ironclad_hauler", "workhorse_2500", "courier_van", "mule_4x4", "valor_cruiser", "atlas_ranger"],
	"downtown": ["valor_cruiser", "taxi", "taxi", "haldane_meridian", "orion_stately", "kestrel_avanti", "summit_lx", "courier_van", "mirage_coupe", "brawler_ss"],
}

func _ready() -> void:
	rng.randomize()

func set_density(d: float) -> void:
	target_count = int(34 * d)

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var focus := player.global_position
	if player.interior != "":
		_clear_all()
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 0.25
		_maintain(focus)
	_rebuild_segment_index()
	for car in cars.duplicate():
		_drive(car, delta)

func _clear_all() -> void:
	for car in cars:
		car.body.queue_free()
	cars.clear()
	locks.clear()

func _maintain(focus: Vector3) -> void:
	# despawn far cars
	for car in cars.duplicate():
		if car.body.global_position.distance_to(focus) > 280.0:
			_remove(car)
	if cars.size() < target_count:
		_spawn_near(focus)

func _remove(car: TCar) -> void:
	for k in locks.keys():
		if locks[k] == car.id:
			locks.erase(k)
	cars.erase(car)
	if is_instance_valid(car.body):
		car.body.queue_free()

func _neighbors(n: Vector2i) -> Array:
	var out := []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var m: Vector2i = n + d
		if m.x >= 0 and m.y >= 0 and m.x <= CityLayout.N and m.y <= CityLayout.N:
			out.append(m)
	return out

func _lane_points(a: Vector2i, b: Vector2i) -> Array:
	var pa := CityLayout.node_pos(a.x, a.y)
	var pb := CityLayout.node_pos(b.x, b.y)
	var d := (pb - pa).normalized()
	var right := Vector3(-d.z, 0, d.x)
	return [pa + d * 10.0 + right * CityLayout.LANE_OFF, pb - d * 10.0 + right * CityLayout.LANE_OFF, d, right]

func _spawn_near(focus: Vector3) -> void:
	for attempt in 6:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(90.0, 230.0)
		var p := focus + Vector3(cos(ang), 0, sin(ang)) * dist
		var n := CityLayout.nearest_node(p)
		var nb := _neighbors(n)
		var b: Vector2i = nb[rng.randi() % nb.size()]
		var t := rng.randf_range(5.0, 50.0)
		# avoid stacking
		var ok := true
		var lp := _lane_points(n, b)
		var spawn_pos: Vector3 = lp[0] + lp[2] * t
		if spawn_pos.distance_to(focus) < 70.0:
			continue
		for other in cars:
			if other.body.global_position.distance_to(spawn_pos) < 12.0:
				ok = false
				break
		if not ok:
			continue
		_create(n, b, t)
		return

func _pick_model(pos: Vector3) -> String:
	var d := CityLayout.district_at(pos)
	var pool: Array = POOL.get(d, POOL["default"])
	if d in ["port"]:
		pool = POOL["industrial"]
	if d in ["golf"]:
		pool = POOL["rich"]
	return pool[rng.randi() % pool.size()]

func _create(a: Vector2i, b: Vector2i, t: float) -> TCar:
	var car := TCar.new()
	car.id = _next_id
	_next_id += 1
	car.a = a
	car.b = b
	car.t = t
	var lp := _lane_points(a, b)
	car.model_id = _pick_model(lp[0])
	var def := Catalog.get_vehicle(car.model_id)
	car.mods = Catalog.default_mods(def)
	if not def.get("taxi", false) and model_rng_paint():
		car.mods["paint"] = (Catalog.PAINTS[rng.randi() % Catalog.PAINTS.size()][1] as Color).to_html(false)
	car.cruise = rng.randf_range(10.0, 14.5) if def["cat"] != "Truck" else 9.0
	car.speed = car.cruise
	var spec := CarModel.spec(def["body"])
	car.length = spec["L"]
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = 8
	body.collision_mask = 0
	body.add_to_group("traffic")
	body.set_meta("tcar", car)
	var model := CarModel.build(def, car.mods)
	body.add_child(model)
	var wv := CarModel.wheel(def, car.mods)
	var zs := [-spec["L"] / 2.0 + spec["L"] * spec["wf"], -spec["L"] / 2.0 + spec["L"] * spec["wr"]]
	var two: bool = spec.get("two", false)
	for z in zs:
		for sx in ([0.0] if two else [-1.0, 1.0]):
			var w: Node3D = wv.duplicate()
			w.position = Vector3(sx * CarModel.wheel_x(spec), spec["r"], z)
			model.add_child(w)
			car.wheels.append(w)
	wv.queue_free()
	# simple driver silhouette
	var skin: Color = Catalog.SKIN_TONES[rng.randi() % Catalog.SKIN_TONES.size()]
	if not two:
		CarModel.box(model, Vector3(0.22, 0.26, 0.22), Vector3(-spec["W"] * 0.22, spec["c"] + spec["h"] + 0.28, -spec["L"] * 0.05), CarModel.mat(skin))
		CarModel.box(model, Vector3(0.42, 0.4, 0.3), Vector3(-spec["W"] * 0.22, spec["c"] + spec["h"] - 0.05, -spec["L"] * 0.02), CarModel.mat(Catalog.CLOTH_COLORS[rng.randi() % Catalog.CLOTH_COLORS.size()]))
	else:
		var rider := Humanoid.new()
		var app := Catalog.random_appearance()
		app["hat"] = 0
		rider.build(app, false)
		rider.position = Vector3(0, spec["r"] + 0.45, 0.25)
		rider.set_pose("sit")
		rider.animate(0.016, 0, true, false)
		model.add_child(rider)
		CarModel.box(rider, Vector3(0.3, 0.3, 0.32), Vector3(0, 1.72, 0), CarModel.mat(Color(0.1, 0.1, 0.12), 0.3, 0.3))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	if two:
		bs.size = Vector3(0.6, 1.2, spec["L"])
		cs.position = Vector3(0, 0.7, 0)
	else:
		bs.size = Vector3(spec["W"], spec["h"] + spec.get("rh", 0.5), spec["L"])
		cs.position = Vector3(0, spec["c"] + bs.size.y / 2.0, 0)
	cs.shape = bs
	body.add_child(cs)
	add_child(body)
	car.body = body
	_place(car)
	cars.append(car)
	return car

func model_rng_paint() -> bool:
	return rng.randf() < 0.85

func _place(car: TCar) -> void:
	var pos: Vector3
	var dir: Vector3
	if car.turning:
		var u: float = clamp(car.turn_t / car.turn_len, 0.0, 1.0)
		pos = car.p0.lerp(car.p1, u).lerp(car.p1.lerp(car.p2, u), u)
		dir = (car.p1 - car.p0).lerp(car.p2 - car.p1, u).normalized()
	else:
		var lp := _lane_points(car.a, car.b)
		pos = lp[0] + lp[2] * car.t
		dir = lp[2]
	var yaw := atan2(-dir.x, -dir.z)
	car.body.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)

func _rebuild_segment_index() -> void:
	_sorted_segments.clear()
	for car in cars:
		if car.turning:
			continue
		var k := "%d_%d_%d_%d" % [car.a.x, car.a.y, car.b.x, car.b.y]
		if not _sorted_segments.has(k):
			_sorted_segments[k] = []
		_sorted_segments[k].append(car)

func _car_ahead_gap(car: TCar) -> float:
	var k := "%d_%d_%d_%d" % [car.a.x, car.a.y, car.b.x, car.b.y]
	var best := 999.0
	if _sorted_segments.has(k):
		for o in _sorted_segments[k]:
			if o == car:
				continue
			var g: float = o.t - car.t
			if g > 0.0 and g < best:
				best = g - (o.length + car.length) * 0.5
	return best

func _drive(car: TCar, delta: float) -> void:
	if not is_instance_valid(car.body):
		cars.erase(car)
		return
	var desired := car.cruise
	var lp := _lane_points(car.a, car.b)
	var seg_len: float = (lp[1] - lp[0]).length()
	if car.turning:
		desired = 6.5 if car.p0.direction_to(car.p1).dot(car.p1.direction_to(car.p2)) < 0.9 else car.cruise
	else:
		var gap := _car_ahead_gap(car)
		if gap < 14.0:
			desired = min(desired, max(0.0, (gap - 3.0) * 1.2))
		# approaching intersection
		var to_end: float = seg_len - car.t
		if to_end < 18.0:
			if car.c == Vector2i(-1, -1) or car.c == car.a or not _valid_next(car):
				_choose_next(car)
			var lock_owner = locks.get(car.b, -1)
			if lock_owner != -1 and lock_owner != car.id:
				desired = min(desired, max(0.0, (to_end - 0.5) * 1.0))
			elif to_end < 8.0 and _car_ahead_gap(car) > 900.0:
				locks[car.b] = car.id
	# player / obstacle avoidance
	var fwd := -car.body.global_transform.basis.z
	var obstacle := _obstacle_ahead(car, fwd)
	if obstacle < 16.0:
		desired = min(desired, max(0.0, (obstacle - 4.0) * 1.1))
		if car.speed < 0.5:
			car.wait += delta
			if car.wait > 3.0 and fmod(car.wait, 4.0) < delta:
				if car.body.global_position.distance_to(player.global_position) < 40.0:
					Sfx.play("horn", 0.9, -12.0)
			if car.wait > 8.0 and car.body.global_position.distance_to(player.global_position) > 35.0:
				_remove(car)
				return
	else:
		car.wait = 0.0
	var acc := 4.0 if desired > car.speed else 9.0
	car.speed = move_toward(car.speed, desired, acc * delta)
	var step := car.speed * delta
	if car.turning:
		car.turn_t += step
		if car.turn_t >= car.turn_len:
			# finished the intersection
			if locks.get(car.b, -1) == car.id:
				locks.erase(car.b)
			car.a = car.b
			car.b = car.c
			car.c = Vector2i(-1, -1)
			car.t = car.turn_t - car.turn_len
			car.turning = false
	else:
		car.t += step
		if car.t >= seg_len:
			if (locks.get(car.b, -1) != car.id and locks.get(car.b, -1) != -1) or _car_ahead_gap(car) < 900.0:
				car.t = seg_len
				car.speed = 0.0
			else:
				locks[car.b] = car.id
				_begin_turn(car, lp)
	_place(car)
	for w in car.wheels:
		w.rotate_x(-step / 0.35)
	_check_crash(car)

func _valid_next(car: TCar) -> bool:
	return car.c in _neighbors(car.b) and car.c != car.a

func _choose_next(car: TCar) -> void:
	var opts := _neighbors(car.b)
	opts.erase(car.a)
	if opts.is_empty():
		opts = [car.a]
	# prefer going straight
	var d := car.b - car.a
	var straight: Vector2i = car.b + d
	if straight in opts and rng.randf() < 0.5:
		car.c = straight
	else:
		car.c = opts[rng.randi() % opts.size()]

func _begin_turn(car: TCar, lp: Array) -> void:
	if not _valid_next(car):
		_choose_next(car)
	var np := _lane_points(car.b, car.c)
	car.p0 = lp[1]
	car.p2 = np[0]
	var d1: Vector3 = lp[2]
	var d2: Vector3 = np[2]
	if d1.dot(d2) > 0.9:
		car.p1 = (car.p0 + car.p2) * 0.5
	elif d1.dot(d2) < -0.9:
		car.p1 = CityLayout.node_pos(car.b.x, car.b.y) + d1 * 6.0
	else:
		car.p1 = CityLayout.node_pos(car.b.x, car.b.y) + (lp[3] as Vector3) * CityLayout.LANE_OFF + (np[3] as Vector3) * CityLayout.LANE_OFF
	car.turn_len = car.p0.distance_to(car.p1) + car.p1.distance_to(car.p2)
	car.turn_t = 0.0
	car.turning = true

func _obstacle_ahead(car: TCar, fwd: Vector3) -> float:
	var best := 999.0
	var origin := car.body.global_position
	var targets: Array = [player]
	for v in get_tree().get_nodes_in_group("vehicles"):
		targets.append(v)
	for o in cars:
		if o != car and o.turning:
			targets.append(o.body)
	for t in targets:
		if t == null or not is_instance_valid(t):
			continue
		var tp: Vector3 = (t as Node3D).global_position
		var to := tp - origin
		var fd := to.dot(fwd)
		if fd < 0.0 or fd > 20.0:
			continue
		var lateral := (to - fwd * fd).length()
		if lateral < 2.4:
			best = min(best, fd - car.length * 0.5)
	return best

func _check_crash(car: TCar) -> void:
	# A fast player-driven vehicle hitting a traffic car turns it into a physics wreck.
	if player.vehicle == null:
		return
	var pv := player.vehicle
	var d := pv.global_position.distance_to(car.body.global_position)
	if d > (pv.spec["L"] + car.length) * 0.5 + 0.6:
		return
	var tv := -car.body.global_transform.basis.z * car.speed
	var rel := (pv.linear_velocity - tv).length()
	if rel > 7.0:
		var w := get_tree().get_first_node_in_group("world")
		if w:
			var c := convert_to_physics(car)
			c.linear_velocity = tv + (pv.linear_velocity - tv) * 0.35
			c.take_damage(rel * 12.0)

func convert_to_physics(car: TCar) -> Car:
	var xf := car.body.global_transform
	var tv := -xf.basis.z * car.speed
	var w := get_tree().get_first_node_in_group("world")
	var c: Car = w.spawn_car(car.model_id, car.mods, xf, -1)
	c.linear_velocity = tv
	_remove(car)
	if w.has_method("spawn_fleeing_ped"):
		w.spawn_fleeing_ped(xf.origin + xf.basis.x * -2.2, xf.origin)
	return c

func nearest_car(pos: Vector3, max_d: float) -> TCar:
	var best: TCar = null
	var bd := max_d
	for car in cars:
		var d: float = car.body.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = car
	return best

func scatter(from: Vector3, radius: float) -> void:
	## Panic: nearby cars speed up.
	for car in cars:
		if car.body.global_position.distance_to(from) < radius:
			car.cruise = 17.0
