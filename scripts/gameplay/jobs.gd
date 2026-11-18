class_name Jobs
extends Node3D
## Money-making activities: QuickShip deliveries, street races and the chop shop.

var world: World
var active := ""          # "", "delivery", "race"
var stage := ""
var target = null         # Vector3 for GPS / marker
var timer := 0.0
var marker: Node3D
var next_marker: Node3D

# delivery
var van: Car
var dest := Vector3.ZERO
var dest_name := ""
var offer := {}
var _away := 0.0
# race
var race_id := ""
var race: Dictionary = {}
var cps: Array = []
var cp_index := 0
var race_time := 0.0
var countdown := 0.0

func _process(delta: float) -> void:
	if active == "" or get_tree().paused:
		return
	var p := world.player
	match active:
		"delivery": _delivery_tick(delta, p)
		"race": _race_tick(delta, p)

# ------------------------------------------------------------------ helpers
func _make_marker(pos: Vector3, col: Color, big: bool = true) -> Node3D:
	var n := Node3D.new()
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.5 if big else 3.0
	cm.bottom_radius = cm.top_radius
	cm.height = 40.0 if big else 3.0
	cm.cap_top = false
	cm.cap_bottom = false
	m.mesh = cm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/marker.gdshader")
	sm.set_shader_parameter("color", col)
	m.material_override = sm
	m.position.y = cm.height / 2.0
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(m)
	world.add_child(n)
	n.global_position = pos
	return n

func _clear_markers() -> void:
	for mk in [marker, next_marker]:
		if mk and is_instance_valid(mk):
			mk.queue_free()
	marker = null
	next_marker = null

func cancel(msg: String) -> void:
	if active == "":
		return
	if van and is_instance_valid(van):
		van.job_tag = ""
	van = null
	active = ""
	stage = ""
	target = null
	_clear_markers()
	world.hud.set_objective("")
	world.hud.set_timer("")
	world.player.input_enabled = true
	if msg != "":
		world.hud.big_message("JOB FAILED", msg, UI.RED, 3.0)
		Sfx.play("fail")

# ------------------------------------------------------------------ delivery
func open_depot() -> void:
	if active != "":
		world.hud.notify("Finish your current job first (X to cancel).", "error")
		return
	var offers := []
	var depot := world.city.poi_pos("quickship")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var names := ["Downtown office", "Coral Beach hotel", "Maplewood residence", "Crestwood estate", "Port Calloway warehouse", "Ironside factory", "Beachfront café", "Midtown boutique"]
	for k in 3:
		var tries := 0
		var p := Vector3()
		var side := "n"
		var b := Vector2i()
		while tries < 20:
			b = Vector2i(rng.randi_range(0, CityLayout.N - 1), rng.randi_range(0, CityLayout.N - 1))
			side = ["n", "s", "e", "w"][rng.randi() % 4]
			p = CityLayout.road_point(b.x, b.y, side)
			if p.distance_to(depot) > 300.0 + k * 150.0:
				break
			tries += 1
		var dist := p.distance_to(depot)
		var d_name: String = CityLayout.DISTRICTS[CityLayout.district(b.x, b.y)]["name"]
		var pay := int(round((450.0 + dist * 1.5 + Game.level() * 40.0) / 50.0) * 50)
		var time := dist / 11.0 + 45.0
		var cargo = ["Electronics", "Fragile glassware", "Designer clothes", "Medical supplies", "Auto parts", "Art prints"][rng.randi() % 6]
		offers.append({"pos": p, "pay": pay, "time": time, "cargo": cargo, "name": "%s (%s)" % [names[rng.randi() % names.size()], d_name], "dist": dist})
	var opts := []
	for o in offers:
		var oo: Dictionary = o
		opts.append(["%s - %s  |  %s  |  %.1f km  |  %ds" % [oo["cargo"], oo["name"], Catalog.fmt_money(oo["pay"]), oo["dist"] / 1000.0, int(oo["time"])], func(): _accept_delivery(oo)])
	world.open_menu(DialogUI.new("QuickShip Depot", "Pick a delivery. Use the company van and get the goods there before the timer runs out. Faster, cleaner deliveries pay a bonus.\nDeliveries completed: %d" % int(Game.data["jobs"]["deliveries"]), opts))

func _accept_delivery(o: Dictionary) -> void:
	world.close_menu()
	offer = o
	dest = o["pos"]
	dest_name = o["name"]
	var b: Vector2i = Vector2i(12, 1)
	var spot := CityLayout.road_point(b.x, b.y, "w", 0.25)
	world._clear_area(spot, 6.0)
	van = world.spawn_car("job_van", {}, Transform3D(Basis(Vector3.UP, 0.0), spot + Vector3(0, 0.6, 0)))
	van.job_tag = "delivery"
	active = "delivery"
	stage = "get_in"
	target = van.global_position
	timer = float(o["time"])
	world.hud.set_objective("Get in the orange QuickShip van.")
	marker = _make_marker(van.global_position, Color(1.0, 0.55, 0.15), false)
	Sfx.play("phone")

func on_entered_vehicle(car: Car) -> void:
	if active == "delivery" and car == van and stage == "get_in":
		stage = "drive"
		target = dest
		_clear_markers()
		marker = _make_marker(dest, Color(1.0, 0.55, 0.15))
		world.hud.set_objective("Deliver the %s to %s." % [offer["cargo"], dest_name])

func _delivery_tick(delta: float, p: Player) -> void:
	if van == null or not is_instance_valid(van):
		cancel("The van was lost.")
		return
	if stage == "get_in":
		marker.global_position = van.global_position
		target = van.global_position
		return
	timer -= delta
	world.hud.set_timer("%d:%02d" % [int(max(timer, 0.0)) / 60, int(max(timer, 0.0)) % 60])
	if timer <= 0.0:
		cancel("You ran out of time.")
		return
	if p.vehicle != van:
		_away += delta
		world.hud.set_objective("Get back in the van.")
		target = van.global_position
		if _away > 40.0:
			cancel("You abandoned the van.")
		return
	_away = 0.0
	target = dest
	world.hud.set_objective("Deliver the %s to %s." % [offer["cargo"], dest_name])
	var d := Vector2(van.global_position.x - dest.x, van.global_position.z - dest.z).length()
	if d < 7.0 and van.linear_velocity.length() < 5.0:
		var condition: float = clamp(van.health / 1000.0, 0.3, 1.0)
		var bonus := int(timer * 4.0)
		var pay := int((float(offer["pay"]) + bonus) * condition)
		Game.earn(pay, "QuickShip delivery")
		Game.add_xp(150 + int(float(offer["dist"]) / 10.0), "Delivery complete")
		Game.data["jobs"]["deliveries"] = int(Game.data["jobs"]["deliveries"]) + 1
		Game.add_stat("driving", 0.6)
		world.hud.big_message("DELIVERY COMPLETE", "%s  (time bonus %s, van condition %d%%)" % [Catalog.fmt_money(pay), Catalog.fmt_money(bonus), int(condition * 100)], UI.GREEN, 4.0)
		Sfx.play("win")
		van.job_tag = ""
		van = null
		active = ""
		target = null
		_clear_markers()
		world.hud.set_objective("")
		world.hud.set_timer("")
		Game.save_game()

# ------------------------------------------------------------------ races
func open_race(id: String) -> void:
	if active != "":
		world.hud.notify("Finish your current job first (X to cancel).", "error")
		return
	if world.player.vehicle == null:
		world.hud.notify("You need a vehicle to race.", "error")
		return
	var r: Dictionary = Catalog.RACES[id]
	var best = Game.data["jobs"]["race_best"].get(id)
	var txt := "Checkpoint sprint through the streets. Beat the target times for a payout.\n\nGold: %.0fs  (%s)\nSilver: %.0fs  (%s)\nBronze: %.0fs  (%s)\n\nYour best: %s" % [
		r["gold"], Catalog.fmt_money(r["pay"]), r["silver"], Catalog.fmt_money(int(r["pay"] * 0.6)), r["bronze"], Catalog.fmt_money(int(r["pay"] * 0.35)),
		("%.2fs" % float(best)) if best != null else "--"]
	world.open_menu(DialogUI.new(r["name"], txt, [["Start race", func(): _start_race(id)]]))

func _start_race(id: String) -> void:
	world.close_menu()
	race_id = id
	race = Catalog.RACES[id]
	cps.clear()
	for n in race["nodes"]:
		cps.append(CityLayout.node_pos(n.x, n.y) + Vector3(0, 0, 0))
	cp_index = 0
	race_time = 0.0
	countdown = 3.5
	active = "race"
	stage = "countdown"
	world.player.input_enabled = false
	var car := world.player.vehicle
	car.linear_velocity = Vector3.ZERO
	_show_cp()
	world.hud.set_objective("%s - get ready!" % race["name"])

func _show_cp() -> void:
	_clear_markers()
	if cp_index < cps.size():
		var last := cp_index == cps.size() - 1
		marker = _make_marker(cps[cp_index], Color(0.9, 0.9, 0.2) if last else Color(0.7, 0.4, 1.0))
		target = cps[cp_index]
		if cp_index + 1 < cps.size():
			next_marker = _make_marker(cps[cp_index + 1], Color(0.7, 0.4, 1.0, 0.35), false)

func _race_tick(delta: float, p: Player) -> void:
	if stage == "countdown":
		var before := ceili(countdown)
		countdown -= delta
		var after := ceili(countdown)
		if p.vehicle:
			p.vehicle.linear_velocity = Vector3(0, p.vehicle.linear_velocity.y, 0)
		if after != before and after > 0 and after <= 3:
			world.hud.big_message(str(after), "", UI.ACCENT, 0.9)
			Sfx.play("countdown")
		if countdown <= 0.0:
			stage = "racing"
			p.input_enabled = true
			world.hud.big_message("GO!", "", UI.GREEN, 1.0)
			Sfx.play("go")
		return
	race_time += delta
	world.hud.set_timer("%.2f" % race_time)
	world.hud.set_objective("%s - checkpoint %d / %d" % [race["name"], cp_index + 1, cps.size()])
	if p.vehicle == null:
		_away += delta
		if _away > 10.0:
			cancel("You left your vehicle.")
		return
	_away = 0.0
	var cp: Vector3 = cps[cp_index]
	if Vector2(p.vehicle.global_position.x - cp.x, p.vehicle.global_position.z - cp.z).length() < 9.0:
		cp_index += 1
		Sfx.play("checkpoint")
		if cp_index >= cps.size():
			_finish_race()
		else:
			_show_cp()

func _finish_race() -> void:
	var t := race_time
	var medal := ""
	var pay := 0
	if t <= race["gold"]:
		medal = "GOLD"
		pay = race["pay"]
		Game.data["jobs"]["races_won"] = int(Game.data["jobs"]["races_won"]) + 1
	elif t <= race["silver"]:
		medal = "SILVER"
		pay = int(race["pay"] * 0.6)
	elif t <= race["bronze"]:
		medal = "BRONZE"
		pay = int(race["pay"] * 0.35)
	var best = Game.data["jobs"]["race_best"].get(race_id)
	var record := best == null or t < float(best)
	if record:
		Game.data["jobs"]["race_best"][race_id] = t
	if pay > 0:
		Game.earn(pay, "Race: " + race["name"])
		Game.add_xp(int(race["xp"]) if medal == "GOLD" else int(race["xp"]) / 2, "Race finished")
		Game.add_stat("driving", 1.5)
		world.hud.big_message("%s MEDAL" % medal, "%.2fs  %s%s" % [t, Catalog.fmt_money(pay), "  NEW RECORD" if record else ""], UI.ACCENT, 4.5)
		Sfx.play("win")
	else:
		Game.add_xp(50, "Race finished")
		world.hud.big_message("TOO SLOW", "%.2fs - bronze needs %.0fs%s" % [t, race["bronze"], "  (personal best)" if record else ""], UI.RED, 4.0)
		Sfx.play("fail")
	active = ""
	target = null
	_clear_markers()
	world.hud.set_objective("")
	world.hud.set_timer("")
	Game.save_game()

# ------------------------------------------------------------------ chop shop
func chop_shop(car: Car) -> void:
	if car == null:
		return
	if car.owned_uid > 0:
		world.hud.notify("Rusty doesn't take registered cars. Sell personal vehicles from your garage.", "error")
		return
	if car.job_tag != "":
		world.hud.notify("That's a company vehicle - Rusty won't touch it.", "error")
		return
	var now := Time.get_unix_time_from_system()
	var cd := float(Game.data.get("chop_cooldown", 0.0))
	if now < cd:
		world.hud.notify("Rusty: \"Lay low, come back in %ds.\"" % int(cd - now), "error")
		return
	var value := int(Catalog.chop_value(car.model_id) * clamp(car.health / 1000.0, 0.25, 1.0))
	world.open_menu(DialogUI.new("Rusty's Salvage", "\"Nice %s. I'll give you %s for it, no questions asked.\"" % [car.def["brand"] + " " + car.def["name"], Catalog.fmt_money(value)],
		[["Sell for %s" % Catalog.fmt_money(value), func(): _do_chop(car, value)]]))

func _do_chop(car: Car, value: int) -> void:
	world.close_menu()
	if not is_instance_valid(car):
		return
	world.player.exit_vehicle()
	car.queue_free()
	Game.earn(value, "Chop shop sale")
	Game.add_xp(120, "Car sold to chop shop")
	Game.add_stat("criminal", 2.0)
	Game.data["jobs"]["cars_chopped"] = int(Game.data["jobs"]["cars_chopped"]) + 1
	Game.data["chop_cooldown"] = Time.get_unix_time_from_system() + 90.0
	world.hud.big_message("SOLD", Catalog.fmt_money(value), UI.GREEN, 3.0)
	Game.save_game()

func on_vehicle_destroyed(car: Car) -> void:
	if active == "delivery" and car == van:
		cancel("The van was destroyed.")
	elif active == "race" and world.player.vehicle == null:
		pass

func job_list() -> Array:
	## Used by the phone's Jobs app.
	var out := []
	out.append({"name": "QuickShip Deliveries", "desc": "Timed van deliveries across the city. Completed: %d" % int(Game.data["jobs"]["deliveries"]), "pos": world.city.poi_pos("quickship")})
	for id in Catalog.RACES:
		var best = Game.data["jobs"]["race_best"].get(id)
		out.append({"name": "Street Race: " + Catalog.RACES[id]["name"], "desc": "Best: %s  |  Gold %.0fs" % [("%.2fs" % float(best)) if best != null else "--", Catalog.RACES[id]["gold"]], "pos": world.city.poi_pos("race_" + id)})
	out.append({"name": "Rusty's Salvage", "desc": "Sell stolen cars for quick cash. Sold: %d" % int(Game.data["jobs"]["cars_chopped"]), "pos": world.city.poi_pos("rustys")})
	return out
