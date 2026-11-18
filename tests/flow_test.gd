extends Node
## Headless gameplay flow test.
var world
var t := 0.0
var step := 0
var wait_t := 0.0
var log_t := 0.0
var car

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 60
	Game.new_game(1, "Flow", Catalog.default_appearance("female"))
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)

func ok(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)

func _process(delta: float) -> void:
	t += delta
	wait_t -= delta
	if wait_t > 0:
		return
	match step:
		0:
			wait_t = 25.0
		1:
			var moving := 0
			var stuck := 0
			for c in world.traffic.cars:
				if c.speed > 1.0: moving += 1
				if c.wait > 5.0: stuck += 1
			print("traffic cars=%d moving=%d stuck=%d peds=%d" % [world.traffic.cars.size(), moving, stuck, world.peds.peds.size()])
			ok(world.traffic.cars.size() > 15, "traffic spawned")
			ok(moving > world.traffic.cars.size() / 2, "traffic moving")
			ok(world.peds.peds.size() > 5, "peds spawned")
			# steal a traffic car
			var tc = world.traffic.cars[0]
			world.player.teleport(tc.body.global_position + Vector3(3, 0.5, 0))
			world.near_traffic = tc
			world.near_car = null
			world._do_vehicle()
			ok(world.player.vehicle != null and world.player.vehicle.stolen, "hijacked traffic car")
			car = world.player.vehicle
			wait_t = 0.5
		2:
			# chop it
			var cash0 := Game.cash()
			world.jobs.chop_shop(car)
			ok(world.menu is DialogUI, "chop dialog opened")
			var value := int(Catalog.chop_value(car.model_id) * clamp(car.health / 1000.0, 0.25, 1.0))
			world.jobs._do_chop(car, value)
			ok(Game.cash() == cash0 + value, "chop paid %d" % value)
			wait_t = 0.5
		3:
			# delivery job
			world.player.teleport(world.city.poi_pos("quickship") + Vector3(0, 0.5, 0))
			world.jobs.open_depot()
			ok(world.menu is DialogUI, "depot dialog")
			var opt = world.menu.options[0]
			opt[1].call()
			ok(world.jobs.active == "delivery" and world.jobs.van != null, "delivery accepted, van spawned")
			wait_t = 1.0
		4:
			var van = world.jobs.van
			world.player.teleport(van.global_position + Vector3(3, 0.5, 0))
			world.player.enter_vehicle(van)
			world.jobs.on_entered_vehicle(van)
			ok(world.jobs.stage == "drive", "in van, driving stage")
			ok(world.gps_target() != null, "gps target set")
			# teleport van to destination
			var d: Vector3 = world.jobs.dest
			van.global_transform = Transform3D(Basis(), d + Vector3(0, 0.8, 0))
			van.linear_velocity = Vector3.ZERO
			wait_t = 1.5
		5:
			ok(world.jobs.active == "", "delivery completed")
			ok(int(Game.data["jobs"]["deliveries"]) == 1, "delivery counted")
			print("cash now ", Game.cash(), " xp ", Game.data["xp"], " level ", Game.level())
			world.player.exit_vehicle()
			# race
			Game.earn(100000, "test")
			var v = Game.add_vehicle("zephyr_gt")
			ok(not v.is_empty(), "vehicle added to motel parking")
			var rp = world.city.poi_pos("race_downtown")
			world.player.teleport(rp + Vector3(0, 0.5, 0))
			var c2 = world.retrieve_owned(int(v["uid"]), Transform3D(Basis(), rp + Vector3(0, 0.8, 0)))
			world.player.enter_vehicle(c2)
			world.jobs.open_race("downtown")
			world.menu.options[0][1].call()
			ok(world.jobs.active == "race", "race started")
			wait_t = 4.0
		6:
			ok(world.jobs.stage == "racing", "countdown done")
			# teleport through checkpoints
			for i in world.jobs.cps.size():
				var cp: Vector3 = world.jobs.cps[world.jobs.cp_index]
				world.player.vehicle.global_position = cp + Vector3(0, 0.6, 0)
				world.jobs._race_tick(0.016, world.player)
			ok(world.jobs.active == "", "race finished")
			ok(Game.data["jobs"]["race_best"].has("downtown"), "race best recorded")
			wait_t = 0.5
		7:
			# park in garage
			var car3 = world.player.vehicle
			world.store_vehicle(car3, "sunrise_motel")
			ok(world.player.interior == "sunrise_motel", "stored -> inside garage")
			var gp = 0
			for p in world.interiors.points:
				if p["kind"] == "garage_car": gp += 1
			ok(gp == 1, "car shown in garage")
			wait_t = 0.5
		8:
			var uid := int(Game.data["vehicles"][0]["uid"])
			world.take_out_vehicle(uid, "sunrise_motel")
			ok(world.player.vehicle != null and world.player.interior == "", "drove car out")
			# buy property & mods
			Game.earn(500000, "test", true)
			Game.data["level"] = 5
			ok(Game.buy_property("midtown_14"), "bought Midtown")
			ok(Game.garage_capacity() == 7, "garage capacity 7")
			var m := ModShopUI.new(world.player.vehicle, "shop")
			world.open_menu(m)
			wait_t = 0.2
		9:
			var m = world.menu
			m._set_cat("Engine")
			m._preview("engine", 3, 1000, "Race Tune")
			m._buy()
			ok(int(Game.data["vehicles"][0]["mods"]["engine"]) == 3, "engine upgraded")
			m.close()
			ok(world.player.vehicle != null and int(world.player.vehicle.mods["engine"]) == 3, "car respawned with mods")
			# deposit / withdraw
			Game.earn(5000, "test")
			var c0 := Game.cash()
			Game.deposit(1000)
			ok(Game.cash() == c0 - 1000, "deposit")
			Game.withdraw(500)
			ok(Game.cash() == c0 - 500, "withdraw")
			Game.save_game()
			wait_t = 0.3
		10:
			# reload
			var cash_before := Game.cash()
			var veh: int = Game.data["vehicles"].size()
			ok(Game.load_game(1), "load slot")
			ok(Game.cash() == cash_before and Game.data["vehicles"].size() == veh and Game.owns_property("midtown_14"), "state restored")
			ok(typeof(Game.data["vehicles"][0]["uid"]) == TYPE_INT, "uid int after load")
			get_tree().change_scene_to_file("res://scenes/world.tscn")
			wait_t = 2.0
		11:
			var w = get_tree().get_first_node_in_group("world")
			ok(w != null and w.player.vehicle != null, "reloaded world, player back in owned car")
			print("DONE t=", t)
			get_tree().quit()
	step += 1
