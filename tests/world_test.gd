extends Node
## Headless smoke test: new game -> world -> simulate driving & systems -> save/load.
var frames := 0
var world
var t0 := 0

func _ready() -> void:
	t0 = Time.get_ticks_msec()
	Engine.max_fps = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.new_game(2, "Tester", Catalog.default_appearance("male"))
	var w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	world = w

func _process(_d: float) -> void:
	frames += 1
	if frames == 2:
		print("frame 2")
		print("world build ms: ", Time.get_ticks_msec() - t0)
		print("points: ", world.city.points.size(), " chunks: ", world.city.chunks.size())
	if frames == 30:
		print("frame 30")
		print("traffic: ", world.traffic.cars.size(), " peds: ", world.peds.peds.size())
		# give money & buy a car
		Game.earn(200000, "test")
		var v = Game.add_vehicle("zephyr_gt")
		print("added vehicle: ", v.get("name"), " garage ", v.get("garage"))
		var spot = CityLayout.nearest_road_spot(world.player.global_position)
		var car = world.retrieve_owned(int(v["uid"]), Transform3D(Basis(Vector3.UP, spot["yaw"]), spot["pos"]))
		world.player.enter_vehicle(car)
	if frames == 31:
		print("frame 31")
		Input.action_press("move_forward")
	if frames == 200:
		print("frame 200")
		var car = world.player.vehicle
		print("speed after ~170 frames: ", car.speed() * 3.6, " km/h  pos ", car.global_position, " health ", car.health)
		Input.action_release("move_forward")
	if frames == 220:
		print("frame 220")
		Game.save_game()
		print("saved; slot info: ", Game.slot_info(2))
		world.player.exit_vehicle()
		world.open_menu(DealershipUI.new())
	if frames == 230:
		print("frame 230")
		world.close_menu()
		world.open_menu(GarageUI.new())
	if frames == 240:
		print("frame 240")
		world.close_menu()
		world.open_menu(ModShopUI.new(null, "garage", 1))
	if frames == 250:
		print("frame 250")
		world.close_menu()
		world.open_menu(PauseMenu.new())
	if frames == 255:
		print("frame 255")
		world.close_menu()
		world.open_phone()
	if frames == 260:
		print("frame 260")
		for a in ["contacts", "internet", "bank", "properties", "vehicles", "jobs"]:
			world.phone._open(a)
		world.close_phone()
		world.open_menu(ShopUI.new("clothing"))
	if frames == 265:
		print("frame 265")
		world.close_menu()
		world.open_menu(PropertyUI.new("ridgeway_3b"))
	if frames == 270:
		print("frame 270")
		world.close_menu()
		world.enter_property("sunrise_motel")
	if frames == 280:
		print("frame 280")
		print("interior points: ", world.interiors.points.size())
		world.exit_property()
		world.open_menu(MapView.new())
	if frames == 290:
		print("frame 290")
		world.close_menu()
		world.jobs.open_depot()
	if frames == 295:
		print("frame 295")
		world.close_menu()
		world.open_menu(ATMUI.new(true))
	if frames == 300:
		print("frame 300")
		world.close_menu()
		world.open_menu(RealtyUI.new())
	if frames == 305:
		print("frame 305")
		world.close_menu()
		world.open_menu(StatsUI.new())
	if frames == 310:
		print("frame 310")
		world.close_menu()
		world.open_menu(SettingsUI.new())
	if frames == 315:
		print("frame 315")
		world.close_menu()
		print("total frames ok, elapsed ms ", Time.get_ticks_msec() - t0)
		get_tree().quit()
