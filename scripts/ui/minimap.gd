class_name Minimap
extends Control
## Rotating radar-style minimap with blips and GPS route.

var world: World
var zoom := 1.0           # pixels of map texture per screen pixel scale
var big := false          # full map mode (no rotation)
var center_override = null

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_d: float) -> void:
	queue_redraw()

func _view_center() -> Vector3:
	if center_override != null:
		return center_override
	return world.player.global_position

func _rot() -> float:
	if big:
		return 0.0
	return world.cam.yaw

func map_scale() -> float:
	## screen pixels per world metre
	var base := 0.55 if not big else 0.6
	if not big and world.player.vehicle:
		base = 0.38 - clamp(world.player.vehicle.linear_velocity.length() / 200.0, 0.0, 0.15)
	return base * zoom

func world_to_screen(p: Vector3) -> Vector2:
	var c := _view_center()
	var d := Vector2(p.x - c.x, p.z - c.z) * map_scale()
	d = d.rotated(_rot())
	return size / 2.0 + d

func _draw() -> void:
	if world == null or world.city == null:
		return
	var c := _view_center()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.22, 0.33))
	# map texture, rotated around the player
	var s := map_scale()
	var mp := world.city.world_to_map(c)
	draw_set_transform(size / 2.0, _rot(), Vector2.ONE * s * City.MAP_SCALE)
	draw_texture(world.city.minimap_texture, -mp)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# GPS route
	if world.gps_path.size() > 1:
		var pts := PackedVector2Array()
		for p in world.gps_path:
			pts.append(world_to_screen(p))
		draw_polyline(pts, Color(0.75, 0.35, 1.0), 5.0 if not big else 4.0, true)
	# POI blips
	if world.player.interior == "":
		for p in world.city.points:
			var kind: String = p["kind"]
			if kind == "garage":
				continue
			if kind == "property" and not Game.owns_property(p["id"]) and not big:
				continue
			var sp := world_to_screen(p["pos"])
			if not big and not Rect2(Vector2(-10, -10), size + Vector2(20, 20)).has_point(sp):
				continue
			_blip(sp, p["color"], _letter(kind, p), kind == "property" and Game.owns_property(p["id"]))
	# owned vehicles
	for uid in world.owned_cars:
		var car = world.owned_cars[uid]
		if is_instance_valid(car) and car != world.player.vehicle:
			_blip(world_to_screen(car.global_position), Color(0.3, 0.85, 1.0), "V", false)
	# job / waypoint
	var t = world.gps_target()
	if t != null:
		var sp2 := world_to_screen(t)
		if not big:
			var half := size / 2.0 - Vector2(10, 10)
			var off := sp2 - size / 2.0
			if abs(off.x) > half.x or abs(off.y) > half.y:
				var k: float = min(half.x / max(abs(off.x), 0.01), half.y / max(abs(off.y), 0.01))
				sp2 = size / 2.0 + off * k
		draw_circle(sp2, 8.0, Color(0.1, 0.1, 0.1))
		draw_circle(sp2, 6.0, UI.ACCENT if world.jobs.target != null else Color(0.75, 0.35, 1.0))
	# player arrow
	var pp := world_to_screen(world.player.global_position)
	var ang := -world.player.global_rotation.y + _rot()
	if world.player.vehicle:
		ang = -world.player.vehicle.global_rotation.y + _rot()
	var pts2 := PackedVector2Array([Vector2(0, -11), Vector2(7, 8), Vector2(0, 4), Vector2(-7, 8)])
	var xf := Transform2D(ang, pp)
	var tri := PackedVector2Array()
	for q in pts2:
		tri.append(xf * q)
	draw_colored_polygon(tri, Color.WHITE)
	draw_polyline(tri + PackedVector2Array([tri[0]]), Color.BLACK, 1.5)
	# north indicator
	if not big:
		var n := size / 2.0 + Vector2(0, -min(size.x, size.y) * 0.44).rotated(_rot())
		draw_circle(n, 9.0, Color(0, 0, 0, 0.6))
		draw_string(UI.font(true), n + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.8), false, 3.0)

func _letter(kind: String, p: Dictionary) -> String:
	match kind:
		"dealership": return "$"
		"modshop": return "M"
		"chopshop": return "C"
		"bank", "atm": return "B"
		"jobs": return "J"
		"race": return "R"
		"clothing": return "T"
		"barber": return "H"
		"tattoo": return "I"
		"property": return "H"
	return "?"

func _blip(p: Vector2, col: Color, letter: String, home: bool) -> void:
	var r := 8.0 if not big else 9.0
	if home:
		draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2), Color(0.05, 0.05, 0.05, 0.9))
		draw_rect(Rect2(p - Vector2(r - 2, r - 2), Vector2(r - 2, r - 2) * 2), col)
	else:
		draw_circle(p, r, Color(0.05, 0.05, 0.05, 0.9))
		draw_circle(p, r - 2.0, col)
	draw_string(UI.font(true), p + Vector2(-4.5, 5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
