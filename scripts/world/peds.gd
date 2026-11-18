class_name Peds
extends Node3D
## Pedestrians that stroll around block sidewalks, react to danger, can be greeted and get knocked down.

class Ped:
	var node: Node3D
	var hum: Humanoid
	var block: Vector2i
	var s := 0.0
	var dir := 1.0
	var speed := 1.4
	var state := "walk"   # walk, flee, down, talk, idle
	var timer := 0.0
	var flee_dir := Vector3.ZERO
	var bubble: Label3D

var player: Player
var peds: Array = []
var target_count := 34
var rng := RandomNumberGenerator.new()
var _t := 0.0

const LINES := ["Nice day, huh?", "Do I know you?", "Watch where you're going!", "Hey there.", "Lovely weather.", "Can't talk, late for work.",
	"You new around here?", "Port Calloway never sleeps.", "Nice outfit!", "Get away from me!", "The bus is late again...", "Have a good one!",
	"Don't you have somewhere to be?", "I heard the docks are crawling with smugglers.", "Rent in this city is insane.", "Mind your business."]

func _ready() -> void:
	rng.randomize()

func _process(delta: float) -> void:
	if player == null:
		return
	if player.interior != "":
		for p in peds:
			p.node.queue_free()
		peds.clear()
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.3
		_maintain()
	var cam_pos := player.global_position
	for p in peds.duplicate():
		_update(p, delta, cam_pos)

func _density() -> float:
	var w := get_tree().get_first_node_in_group("world")
	var hour := 12.0
	if w and w.sky:
		hour = w.sky.time_of_day
	var f := 1.0
	if hour < 6.0 or hour > 22.0:
		f = 0.35
	elif hour < 8.0 or hour > 20.0:
		f = 0.7
	var d := CityLayout.district_at(player.global_position)
	if d in ["downtown", "beach"]:
		f *= 1.3
	elif d in ["industrial", "port", "golf"]:
		f *= 0.5
	return f

func _maintain() -> void:
	var focus := player.global_position
	for p in peds.duplicate():
		if p.node.global_position.distance_to(focus) > 150.0 or (p.state == "down" and p.timer > 20.0):
			p.node.queue_free()
			peds.erase(p)
	var want := int(target_count * _density())
	if peds.size() < want:
		for attempt in 3:
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(45.0, 120.0)
			var pos := focus + Vector3(cos(ang), 0, sin(ang)) * dist
			var bi := int(floor(pos.x / CityLayout.P))
			var bj := int(floor(pos.z / CityLayout.P))
			if bi < 0 or bj < 0 or bi >= CityLayout.N or bj >= CityLayout.N:
				continue
			spawn(Vector2i(bi, bj), rng.randf() * 200.0)
			break

func _perimeter(block: Vector2i) -> Rect2:
	var r := CityLayout.block_rect(block.x, block.y)
	return r.grow(-1.8)

func _pos_on(block: Vector2i, s: float) -> Array:
	var r := _perimeter(block)
	var w := r.size.x
	var h := r.size.y
	var per := 2.0 * (w + h)
	s = fposmod(s, per)
	var p := Vector3()
	var d := Vector3()
	if s < w:
		p = Vector3(r.position.x + s, 0, r.position.y)
		d = Vector3(1, 0, 0)
	elif s < w + h:
		p = Vector3(r.end.x, 0, r.position.y + (s - w))
		d = Vector3(0, 0, 1)
	elif s < 2.0 * w + h:
		p = Vector3(r.end.x - (s - w - h), 0, r.end.y)
		d = Vector3(-1, 0, 0)
	else:
		p = Vector3(r.position.x, 0, r.end.y - (s - 2.0 * w - h))
		d = Vector3(0, 0, -1)
	p.y = CityLayout.CURB_H
	return [p, d]

func spawn(block: Vector2i, s: float, app: Dictionary = {}) -> Ped:
	var p := Ped.new()
	p.block = block
	p.s = s
	p.dir = 1.0 if rng.randf() < 0.5 else -1.0
	p.speed = rng.randf_range(1.1, 1.7)
	p.node = Node3D.new()
	p.node.add_to_group("peds")
	p.hum = Humanoid.new()
	p.hum.build(app if not app.is_empty() else Catalog.random_appearance(), false)
	p.node.add_child(p.hum)
	add_child(p.node)
	var pd := _pos_on(block, s)
	p.node.global_position = pd[0]
	peds.append(p)
	return p

func spawn_fleeing(pos: Vector3, from: Vector3) -> void:
	var bi := clampi(int(floor(pos.x / CityLayout.P)), 0, CityLayout.N - 1)
	var bj := clampi(int(floor(pos.z / CityLayout.P)), 0, CityLayout.N - 1)
	var p := spawn(Vector2i(bi, bj), 0.0)
	p.node.global_position = Vector3(pos.x, max(pos.y - 0.5, 0.0), pos.z)
	_flee(p, from)
	_say(p, ["My car!", "Hey! That's my ride!", "Somebody stop him!", "Not again!"][rng.randi() % 4])

func _flee(p: Ped, from: Vector3) -> void:
	if p.state == "down":
		return
	p.state = "flee"
	p.timer = rng.randf_range(4.0, 7.0)
	var away := p.node.global_position - from
	away.y = 0
	p.flee_dir = away.normalized() if away.length() > 0.1 else Vector3.FORWARD

func panic(from: Vector3, radius: float) -> void:
	for p in peds:
		if p.node.global_position.distance_to(from) < radius:
			_flee(p, from)

func _update(p: Ped, delta: float, focus: Vector3) -> void:
	var dist := p.node.global_position.distance_to(focus)
	p.node.visible = dist < 110.0
	if p.bubble and is_instance_valid(p.bubble):
		p.bubble.modulate.a = clamp(p.timer, 0.0, 1.0)
	match p.state:
		"walk":
			p.s += p.speed * p.dir * delta
			var pd := _pos_on(p.block, p.s)
			var target: Vector3 = pd[0]
			var d: Vector3 = pd[1] * p.dir
			p.node.global_position = target
			p.node.rotation.y = lerp_angle(p.node.rotation.y, atan2(-d.x, -d.z), delta * 8.0)
			if dist < 70.0:
				p.hum.animate(delta, p.speed, true, false)
			if rng.randf() < delta * 0.02:
				p.state = "idle"
				p.timer = rng.randf_range(2.0, 6.0)
		"idle", "talk":
			p.timer -= delta
			if dist < 70.0:
				p.hum.animate(delta, 0.0, true, false)
			if p.state == "talk":
				var to := player.global_position - p.node.global_position
				p.node.rotation.y = lerp_angle(p.node.rotation.y, atan2(-to.x, -to.z), delta * 6.0)
			if p.timer <= 0.0:
				p.state = "walk"
				if p.bubble and is_instance_valid(p.bubble):
					p.bubble.queue_free()
		"flee":
			p.timer -= delta
			p.node.global_position += p.flee_dir * 5.5 * delta
			p.node.global_position.y = CityLayout.CURB_H if not CityLayout.on_road(p.node.global_position) else 0.0
			p.node.rotation.y = atan2(-p.flee_dir.x, -p.flee_dir.z)
			if dist < 70.0:
				p.hum.animate(delta, 5.5, true, true)
			if p.timer <= 0.0:
				# rejoin nearest sidewalk loop
				var bi := clampi(int(floor(p.node.global_position.x / CityLayout.P)), 0, CityLayout.N - 1)
				var bj := clampi(int(floor(p.node.global_position.z / CityLayout.P)), 0, CityLayout.N - 1)
				p.block = Vector2i(bi, bj)
				p.s = rng.randf() * 200.0
				p.state = "walk"
		"down":
			p.timer += delta
			p.hum.animate(delta, 0, true, false)
	if p.state != "down":
		_check_hit(p)

func _check_hit(p: Ped) -> void:
	var pos := p.node.global_position
	for v in get_tree().get_nodes_in_group("vehicles"):
		var car := v as Car
		if car == null:
			continue
		var spd := car.linear_velocity.length()
		if spd < 3.0:
			continue
		var local := car.global_transform.affine_inverse() * pos
		if abs(local.x) < car.spec["W"] * 0.5 + 0.35 and abs(local.z) < car.spec["L"] * 0.5 + 0.35 and local.y < 2.5 and local.y > -1.0:
			_knock_down(p, car.linear_velocity)
			if car.driver != null:
				Game.add_stat("criminal", 0.5)
			return
		# panic if a fast car is heading at them
		if spd > 12.0 and pos.distance_to(car.global_position) < 10.0 and p.state == "walk":
			_flee(p, car.global_position)

func _knock_down(p: Ped, vel: Vector3) -> void:
	p.state = "down"
	p.timer = 0.0
	p.hum.set_pose("fall")
	p.node.global_position += vel.normalized() * 1.5
	p.node.rotation.y = atan2(vel.x, vel.z)
	Sfx.play("thud", 1.2, -4.0)
	panic(p.node.global_position, 25.0)

func nearest(pos: Vector3, max_d: float) -> Ped:
	var best: Ped = null
	var bd := max_d
	for p in peds:
		if p.state == "down":
			continue
		var d: float = p.node.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = p
	return best

func greet(p: Ped) -> void:
	p.state = "talk"
	p.timer = 3.5
	_say(p, LINES[rng.randi() % LINES.size()])

func _say(p: Ped, text: String) -> void:
	if p.bubble and is_instance_valid(p.bubble):
		p.bubble.queue_free()
	var l := Label3D.new()
	l.text = text
	l.font = UI.font(true)
	l.font_size = 40
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 10
	l.position = Vector3(0, 2.25, 0)
	l.no_depth_test = true
	p.node.add_child(l)
	p.bubble = l
	if p.state != "flee":
		p.timer = max(p.timer, 3.5)
	get_tree().create_timer(3.5).timeout.connect(l.queue_free)
