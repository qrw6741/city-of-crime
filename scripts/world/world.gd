class_name World
extends Node3D
## Gameplay root: builds the city and all systems, routes interactions, menus, vehicles and saving.

var city: City
var sky: SkyWeather
var player: Player
var cam: CameraRig
var traffic: Traffic
var peds: Peds
var interiors: Interiors
var hud: HUD
var jobs: Jobs
var thumbs: Thumbnails
var menu_layer: CanvasLayer
var vehicles_root: Node3D

var owned_cars := {}            # uid -> Car
var menu: Control = null        # currently open full-screen menu
var phone: Phone = null
var near_point = null
var near_car: Node = null
var near_traffic = null
var near_ped = null
var waypoint = null             # Vector3 or null
var gps_path := PackedVector3Array()
var _gps_timer := 0.0
var _water_timer := 0.0
var _district := ""
var _dead_timer := -1.0
var loading := true

func _ready() -> void:
	add_to_group("world")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	sky = SkyWeather.new()
	add_child(sky)
	city = City.new()
	city.name = "City"
	add_child(city)
	city.generate()
	vehicles_root = Node3D.new()
	vehicles_root.name = "Vehicles"
	add_child(vehicles_root)
	interiors = Interiors.new()
	add_child(interiors)
	player = Player.new()
	player.name = "Player"
	add_child(player)
	cam = CameraRig.new()
	add_child(cam)
	cam.player = player
	player.cam = cam
	sky.follow = cam
	traffic = Traffic.new()
	traffic.player = player
	add_child(traffic)
	peds = Peds.new()
	peds.player = player
	add_child(peds)
	jobs = Jobs.new()
	jobs.world = self
	add_child(jobs)
	thumbs = Thumbnails.new()
	add_child(thumbs)
	hud = HUD.new()
	hud.world = self
	add_child(hud)
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_layer)
	_restore()
	apply_quality()
	Game.level_up.connect(func(l): hud.big_message("LEVEL %d" % l, "New unlocks available", UI.ACCENT))
	Sfx.stop_music()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	loading = false

func apply_quality() -> void:
	var q: int = int(Game.settings["quality"])
	if sky:
		sky.apply_quality(q)
	if traffic:
		traffic.set_density(float(Game.settings["traffic"]))
	if peds:
		peds.target_count = int(34 * float(Game.settings["traffic"]))
	if cam and cam.camera:
		cam.camera.far = [1200.0, 2000.0, 2600.0][clampi(q, 0, 2)]

# ------------------------------------------------------------------ save / restore
func _restore() -> void:
	var d := Game.data
	sky.set_state(float(d.get("time_of_day", 9.0)), str(d.get("weather", "clear")))
	player.health = float(d.get("health", 100.0))
	player.armor = float(d.get("armor", 0.0))
	if player.health <= 0.0:
		player.health = 100.0
	var pos = d.get("position")
	if pos == null or typeof(pos) != TYPE_ARRAY:
		var pid: String = d.get("spawn_property", "sunrise_motel")
		var door := city.property_door(pid)
		player.teleport(door + Vector3(0, 0.3, 0), CityLayout.side_yaw(Catalog.PROPERTIES[pid]["side"]))
		hud.big_message("PORT CALLOWAY", "Welcome to the city. You've got $500 and a motel room.", UI.ACCENT)
		hud.set_objective("Earn some cash: QuickShip jobs, street races or Rusty's chop shop.  [T] Phone  [M] Map")
	else:
		var p := Vector3(pos[0], pos[1] + 0.3, pos[2])
		player.teleport(p, float(d.get("yaw", 0.0)))
		var uid := int(d.get("in_vehicle", -1))
		if uid > 0 and not Game.get_owned(uid).is_empty():
			var car := retrieve_owned(uid, Transform3D(Basis(Vector3.UP, float(d.get("yaw", 0.0))), p + Vector3(0, 0.6, 0)))
			if car:
				player.enter_vehicle(car)

func capture_state(d: Dictionary) -> void:
	if player == null:
		return
	var p := player.global_position
	var yaw := player.rotation.y
	d.erase("in_vehicle")
	if player.interior != "":
		p = city.property_door(player.interior)
		yaw = CityLayout.side_yaw(Catalog.PROPERTIES[player.interior]["side"])
	elif player.vehicle:
		p = player.vehicle.global_position
		yaw = player.vehicle.global_rotation.y
		if player.vehicle.owned_uid > 0:
			d["in_vehicle"] = player.vehicle.owned_uid
		else:
			p = player.vehicle.exit_position()
	if p.y < CityLayout.WATER_Y:
		p = city.property_door(d.get("spawn_property", "sunrise_motel"))
	d["position"] = [p.x, p.y, p.z]
	d["yaw"] = yaw
	d["time_of_day"] = sky.time_of_day
	d["weather"] = sky.weather
	d["health"] = player.health
	d["armor"] = player.armor
	d["location_name"] = CityLayout.district_name_at(p)

# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	if loading:
		return
	if _dead_timer >= 0.0:
		_dead_timer -= delta
		if _dead_timer < 0.0:
			_respawn_hospital()
		return
	_update_interaction()
	_update_gps(delta)
	var d = CityLayout.district_name_at(player.global_position) if player.interior == "" else Catalog.PROPERTIES[player.interior]["name"]
	if d != _district:
		_district = d
		hud.toast_area(d)
	if player.vehicle:
		player.vehicle.set_wetness(sky.wet)
		if sky.night_factor() > 0.6 and not player.vehicle.lights_on and player.vehicle.get_meta("auto_lights", true):
			player.vehicle.set_lights(true)
			player.vehicle.set_meta("auto_lights", false)
	# despawn abandoned non-owned vehicles far away
	for c in vehicles_root.get_children():
		var car := c as Car
		if car and car != player.vehicle and car.owned_uid < 0 and car.job_tag == "" and car.global_position.distance_to(player.global_position) > 300.0:
			car.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if loading or _dead_timer >= 0.0:
		return
	if menu != null:
		return
	if event.is_action_pressed("pause"):
		if phone:
			close_phone()
		else:
			open_menu(PauseMenu.new())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("phone"):
		if phone:
			close_phone()
		else:
			open_phone()
		get_viewport().set_input_as_handled()
		return
	if phone:
		return
	if event.is_action_pressed("map"):
		var mv := MapView.new()
		open_menu(mv)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		_do_interact()
	elif event.is_action_pressed("enter_vehicle"):
		_do_vehicle()
	elif event.is_action_pressed("cancel_job") and jobs.active != "":
		jobs.cancel("Job cancelled.")

func _update_interaction() -> void:
	near_point = null
	near_car = null
	near_traffic = null
	near_ped = null
	if menu or player.dead:
		hud.set_prompt("")
		return
	var pos := player.global_position
	var in_car := player.vehicle != null
	var best := 999.0
	var pts: Array = city.points if player.interior == "" else interiors.points
	for p in pts:
		if bool(p["vehicle"]) != in_car:
			continue
		var pp: Vector3 = p["pos"]
		var dxz := Vector2(pp.x - pos.x, pp.z - pos.z).length()
		if dxz < float(p["radius"]) + (1.5 if in_car else 0.4) and abs(pp.y - pos.y) < 4.0 and dxz < best:
			best = dxz
			near_point = p
	var prompt := ""
	if near_point:
		prompt = _prompt_for(near_point)
	if not in_car and player.interior == "":
		var bc: Car = null
		var bd := 3.6
		for c in vehicles_root.get_children():
			var car := c as Car
			if car and not car.dead:
				var dd := car.global_position.distance_to(pos)
				if dd < bd + car.spec["L"] * 0.3:
					bd = dd
					bc = car
		near_car = bc
		if near_car == null:
			near_traffic = traffic.nearest_car(pos, 4.2)
		if prompt == "" and near_car:
			prompt = "[F] Enter %s" % _car_label(near_car)
		elif prompt == "" and near_traffic:
			prompt = "[F] Steal this %s" % Catalog.get_vehicle(near_traffic.model_id)["name"]
		if prompt == "" and near_car == null and near_traffic == null:
			near_ped = peds.nearest(pos, 2.4)
			if near_ped:
				prompt = "[E] Greet"
	elif in_car and prompt == "":
		if player.vehicle.is_flipped():
			prompt = "[R] Flip vehicle"
	hud.set_prompt(prompt)

func _car_label(car: Car) -> String:
	if car.owned_uid > 0:
		return str(Game.get_owned(car.owned_uid).get("name", "vehicle"))
	return car.def["brand"] + " " + car.def["name"]

func _prompt_for(p: Dictionary) -> String:
	match p["kind"]:
		"dealership": return "[E] Browse Apex Motors"
		"modshop": return "[E] Enter Torque Customs"
		"chopshop": return "[E] Sell vehicle to Rusty's Salvage"
		"bank": return "[E] Use Meridian Bank"
		"atm": return "[E] Use ATM"
		"jobs": return "[E] QuickShip delivery jobs"
		"race": return "[E] Start race: %s" % p["name"]
		"clothing": return "[E] Shop for clothes"
		"barber": return "[E] Get a haircut"
		"tattoo": return "[E] Get inked"
		"property":
			return ("[E] Enter %s" if Game.owns_property(p["id"]) else "[E] View property: %s") % p["name"]
		"garage":
			if Game.owns_property(p["id"]):
				return "[E] Park in garage"
			return ""
		"exit": return "[E] Leave"
		"bed": return "[E] Sleep & save game"
		"designer": return "[E] Interior design & property"
		"to_garage": return "[E] Go to garage"
		"to_apartment": return "[E] Go to apartment"
		"garage_menu": return "[E] Manage garage"
		"garage_car": return "[E] Drive out: %s" % p["name"]
	return ""

func _do_interact() -> void:
	if player.dead:
		return
	if near_point == null:
		if near_ped:
			peds.greet(near_ped)
		return
	var p: Dictionary = near_point
	match p["kind"]:
		"dealership": open_menu(DealershipUI.new())
		"modshop": open_menu(ModShopUI.new(player.vehicle, "shop"))
		"chopshop": jobs.chop_shop(player.vehicle)
		"bank", "atm": open_menu(ATMUI.new(p["kind"] == "bank"))
		"jobs": jobs.open_depot()
		"race": jobs.open_race(p.get("race", ""))
		"clothing", "barber", "tattoo": open_menu(ShopUI.new(p["kind"]))
		"property": open_menu(PropertyUI.new(p["id"]))
		"garage": store_vehicle(player.vehicle, p["id"])
		"exit": exit_property()
		"bed": sleep()
		"designer": open_menu(PropertyUI.new(interiors.current, true))
		"to_garage": player.teleport(interiors.garage_spawn, PI)
		"to_apartment": player.teleport(interiors.apt_spawn, 0.0)
		"garage_menu": open_menu(GarageUI.new(interiors.current))
		"garage_car": take_out_vehicle(int(p["uid"]), interiors.current)

func _do_vehicle() -> void:
	if player.dead:
		return
	if player.vehicle:
		var car := player.vehicle
		if car.speed() > 9.0:
			player.exit_vehicle()
			player.velocity = car.linear_velocity * 0.7 + Vector3.UP * 3.0
			player.take_damage(car.linear_velocity.length() * 1.2, "bail")
		else:
			player.exit_vehicle()
		return
	if near_point and near_point["kind"] == "garage_car":
		take_out_vehicle(int(near_point["uid"]), interiors.current)
		return
	if near_car:
		var car2 := near_car as Car
		if car2.owned_uid < 0 and not car2.stolen and car2.job_tag == "":
			car2.stolen = true
			Game.data["totals"]["stolen"] = int(Game.data["totals"]["stolen"]) + 1
			Game.add_stat("criminal", 1.0)
		if car2.is_flipped():
			car2.flip_upright()
		player.enter_vehicle(car2)
		jobs.on_entered_vehicle(car2)
		return
	if near_traffic:
		var c := traffic.convert_to_physics(near_traffic)
		c.stolen = true
		c.linear_velocity = Vector3.ZERO
		Game.data["totals"]["stolen"] = int(Game.data["totals"]["stolen"]) + 1
		Game.add_stat("criminal", 1.5)
		Game.add_xp(25, "Vehicle stolen")
		peds.panic(c.global_position, 18.0)
		player.enter_vehicle(c)
		jobs.on_entered_vehicle(c)

# ------------------------------------------------------------------ vehicles
func spawn_car(model_id: String, mods: Dictionary, xf: Transform3D, uid: int = -1) -> Car:
	var c := Car.new()
	c.setup(model_id, mods, uid)
	vehicles_root.add_child(c)
	c.global_transform = xf
	if uid > 0:
		owned_cars[uid] = c
		var v := Game.get_owned(uid)
		c.health = float(v.get("health", 1000.0))
		if c.health <= 50.0:
			c.health = 1000.0
	return c

func retrieve_owned(uid: int, xf: Transform3D) -> Car:
	var v := Game.get_owned(uid)
	if v.is_empty():
		return null
	if owned_cars.has(uid) and is_instance_valid(owned_cars[uid]):
		var old: Car = owned_cars[uid]
		if player.vehicle == old:
			player.exit_vehicle()
		old.queue_free()
	return spawn_car(v["model"], v["mods"], xf, uid)

func store_vehicle(car: Car, pid: String) -> void:
	if car == null:
		return
	if not Game.owns_property(pid):
		hud.notify("You don't own this property.", "error")
		return
	if car.owned_uid < 0:
		if car.job_tag != "":
			hud.notify("This vehicle belongs to a job.", "error")
		else:
			hud.notify("You can only store vehicles you own. Buy cars at Apex Motors or sell stolen ones at Rusty's Salvage.", "error")
		return
	var v := Game.get_owned(car.owned_uid)
	if v["garage"] != pid:
		if Game.property_vehicle_count(pid) >= int(Catalog.PROPERTIES[pid]["garage"]):
			hud.notify("This garage is full.", "error")
			return
		v["garage"] = pid
	v["health"] = car.health
	player.exit_vehicle()
	owned_cars.erase(car.owned_uid)
	car.queue_free()
	Game.save_game()
	enter_property(pid, "garage")
	hud.notify("%s parked." % v["name"], "info")

func take_out_vehicle(uid: int, pid: String) -> void:
	var v := Game.get_owned(uid)
	if v.is_empty():
		return
	v["garage"] = pid
	exit_property(false)
	var spot := city.property_garage_spot(pid)
	_clear_area(spot["pos"], 5.0)
	var car := retrieve_owned(uid, Transform3D(Basis(Vector3.UP, spot["yaw"]), spot["pos"]))
	if car:
		player.enter_vehicle(car)
		cam.snap_behind(spot["yaw"])

func deliver_vehicle(uid: int) -> bool:
	## Mechanic brings an owned vehicle to the nearest road.
	if player.interior != "":
		hud.notify("Leave the building first.", "error")
		return false
	var spot := CityLayout.nearest_road_spot(player.global_position)
	_clear_area(spot["pos"], 5.0)
	var car := retrieve_owned(uid, Transform3D(Basis(Vector3.UP, spot["yaw"]), spot["pos"]))
	if car:
		set_waypoint(car.global_position)
		hud.notify("Your %s has been delivered nearby." % Game.get_owned(uid)["name"], "info")
		return true
	return false

func _clear_area(pos: Vector3, r: float) -> void:
	for car in traffic.cars.duplicate():
		if car.body.global_position.distance_to(pos) < r + 4.0:
			traffic._remove(car)
	for c in vehicles_root.get_children():
		var car2 := c as Car
		if car2 and car2 != player.vehicle and car2.owned_uid < 0 and car2.global_position.distance_to(pos) < r:
			car2.queue_free()

func on_vehicle_destroyed(car: Car) -> void:
	peds.panic(car.global_position, 30.0)
	if car.global_position.distance_to(player.global_position) < 8.0 and not player.vehicle == car:
		player.take_damage(25.0, "explosion")
	if player.vehicle == car:
		player.exit_vehicle()
		if car.global_position.y > CityLayout.WATER_Y:
			player.take_damage(45.0, "explosion")
	cam.shake = 1.0 if car.global_position.distance_to(player.global_position) < 40.0 else 0.0
	if car.owned_uid > 0:
		var v := Game.get_owned(car.owned_uid)
		if not v.is_empty():
			v["health"] = 1000.0
			owned_cars.erase(car.owned_uid)
			var fee: int = min(500, Game.total_money())
			if fee > 0:
				Game.spend(fee, "Insurance deductible")
			hud.notify("Your %s was destroyed. Insurance returned it to your garage (-%s)." % [v["name"], Catalog.fmt_money(fee)], "error")
	jobs.on_vehicle_destroyed(car)

func on_horn(pos: Vector3) -> void:
	for p in peds.peds:
		if p.node.global_position.distance_to(pos) < 12.0 and p.state == "walk":
			if randf() < 0.3:
				peds.greet(p)

func spawn_fleeing_ped(pos: Vector3, from: Vector3) -> void:
	peds.spawn_fleeing(pos, from)

# ------------------------------------------------------------------ properties
func enter_property(pid: String, where: String = "apartment") -> void:
	if not Game.owns_property(pid):
		return
	if player.vehicle:
		player.exit_vehicle()
	interiors.build(pid)
	player.interior = pid
	if where == "garage":
		player.teleport(interiors.garage_spawn, PI)
	else:
		player.teleport(interiors.apt_spawn, 0.0)
	Sfx.play("door")

func exit_property(place_at_door: bool = true) -> void:
	var pid := player.interior
	if pid == "":
		return
	interiors.clear()
	player.interior = ""
	if place_at_door:
		var side: String = Catalog.PROPERTIES[pid]["side"]
		var out := -Basis(Vector3.UP, CityLayout.side_yaw(side)).z
		player.teleport(city.property_door(pid) + out * 1.5 + Vector3(0, 0.3, 0), CityLayout.side_yaw(side))
	Sfx.play("door")

func sleep() -> void:
	player.heal(100.0)
	sky.time_of_day = fmod(sky.time_of_day + 8.0, 24.0)
	Game.save_game()
	hud.big_message("SAVED", "You slept 8 hours. Health restored.", UI.GREEN)

func rebuild_interior() -> void:
	if player.interior != "":
		var pos := player.global_position
		var yaw := player.rotation.y
		interiors.build(player.interior)
		player.teleport(pos, yaw)

# ------------------------------------------------------------------ death & water
func on_player_died() -> void:
	if player.vehicle:
		player.exit_vehicle()
	jobs.cancel("")
	Game.data["totals"]["deaths"] = int(Game.data["totals"]["deaths"]) + 1
	hud.big_message("HOSPITALIZED", "", UI.RED, 4.0)
	_dead_timer = 4.0

func _respawn_hospital() -> void:
	var hp := CityLayout.front_point(2, 7, "e")
	player.revive(hp + Vector3(2.0, 0.3, 0), -PI / 2.0)
	var bill: int = min(500, Game.total_money())
	if bill > 0:
		Game.spend(bill, "Hospital bill")
	hud.notify("St. Helena Medical patched you up. Bill: %s" % Catalog.fmt_money(bill), "info")
	Game.save_game()

func player_in_water() -> void:
	_water_timer += get_process_delta_time()
	if _water_timer > 1.5:
		_water_timer = 0.0
		var p := player.global_position
		p.x = clamp(p.x, CityLayout.LAND_MIN.x + 5, min(CityLayout.LAND_MAX.x - 15, 1285.0))
		p.z = clamp(p.z, CityLayout.LAND_MIN.y + 5, CityLayout.LAND_MAX.y - 8)
		player.teleport(Vector3(p.x, 1.0, p.z), player.rotation.y)
		player.take_damage(10.0, "water")
		hud.notify("You swam back to shore.", "info")

func is_night() -> bool:
	return sky.night_factor() > 0.5

# ------------------------------------------------------------------ GPS
func set_waypoint(p) -> void:
	waypoint = p
	_gps_timer = 0.0
	_update_gps(0.0)

func gps_target():
	if jobs.target != null:
		return jobs.target
	return waypoint

func _update_gps(delta: float) -> void:
	_gps_timer -= delta
	if _gps_timer > 0.0:
		return
	_gps_timer = 0.5
	var t = gps_target()
	if t == null or player.interior != "":
		gps_path = PackedVector3Array()
		return
	var target: Vector3 = t
	var pos := player.global_position
	if waypoint != null and jobs.target == null and Vector2(pos.x - target.x, pos.z - target.z).length() < 12.0:
		waypoint = null
		hud.notify("Destination reached.", "info")
		gps_path = PackedVector3Array()
		return
	var a := CityLayout.nearest_node(pos)
	var b := CityLayout.nearest_node(target)
	var path := PackedVector3Array([pos, CityLayout.node_pos(a.x, a.y)])
	# simple Manhattan route along the grid: longer leg first
	var mid := Vector2i(b.x, a.y) if abs(b.x - a.x) >= abs(b.y - a.y) else Vector2i(a.x, b.y)
	path.append(CityLayout.node_pos(mid.x, mid.y))
	path.append(CityLayout.node_pos(b.x, b.y))
	path.append(target)
	gps_path = path

# ------------------------------------------------------------------ menus & phone
func open_menu(m: Control) -> void:
	if menu:
		close_menu()
	if phone:
		close_phone()
	menu = m
	m.set("world", self)
	menu_layer.add_child(m)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false

func close_menu() -> void:
	if menu and is_instance_valid(menu):
		menu.queue_free()
	menu = null
	get_tree().paused = false
	hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func open_phone() -> void:
	phone = Phone.new()
	phone.world = self
	menu_layer.add_child(phone)
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("phone")

func close_phone() -> void:
	if phone and is_instance_valid(phone):
		phone.queue_free()
	phone = null
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func quit_to_menu() -> void:
	Game.save_game()
	Game.playing = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
