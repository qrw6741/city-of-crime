extends Node
## Renders screenshots of key scenes (run with a real renderer).
var frames := 0
var world
var step := 0
var wait := 0
var out := "/home/claude/shots/"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.new_game(2, "Tester", Catalog.default_appearance("male"))
	Game.earn(3000000, "test", true)
	Game.data["level"] = 20
	var w = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	world = w

func snap(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + name + ".png")
	print("saved ", name)

func _process(_d: float) -> void:
	frames += 1
	if frames < 5:
		return
	wait -= 1
	if wait > 0:
		return
	match step:
		0:
			world.sky.time_of_day = 10.0
			world.hud.big_box.visible = false
			wait = 40
		1:
			snap("01_street")
			world.player.teleport(Vector3(600, 0.4, 470), 0.3)
			world.cam.pitch = -0.05
			wait = 40
		2:
			snap("02_downtown")
			var v = Game.add_vehicle("vortex_x9")
			var spot = CityLayout.nearest_road_spot(Vector3(560, 0, 500))
			var car = world.retrieve_owned(int(v["uid"]), Transform3D(Basis(Vector3.UP, spot["yaw"]), spot["pos"]))
			world.player.enter_vehicle(car)
			world.cam.snap_behind(spot["yaw"])
			wait = 50
		3:
			snap("03_driving")
			world.sky.time_of_day = 21.5
			world.player.vehicle.global_position += Vector3(0, 0, -150)
			wait = 50
		4:
			snap("04_night")
			world.sky.time_of_day = 18.6
			world.player.exit_vehicle()
			world.player.teleport(CityLayout.front_point(4, 6, "e") + Vector3(6, 0.3, 0), -PI / 2)
			world.cam.snap_behind(PI / 2)
			wait = 40
		5:
			snap("05_dealer_outside")
			world.open_menu(DealershipUI.new())
			wait = 30
		6:
			snap("06_dealership_ui")
			world.close_menu()
			world.sky.time_of_day = 12.0
			Game.buy_property("skyline_ph")
			world.enter_property("skyline_ph")
			wait = 40
		7:
			snap("07_interior")
			world.player.teleport(world.interiors.garage_spawn, PI)
			wait = 30
		8:
			snap("08_garage")
			world.exit_property()
			world.open_phone()
			wait = 20
		9:
			snap("09_phone")
			world.close_phone()
			world.player.teleport(Vector3(1200, 0.4, 900), -PI / 2)
			world.cam.snap_behind(-PI / 2)
			wait = 40
		10:
			snap("10_port")
			world.player.teleport(Vector3(600, 0.4, 1300), PI)
			world.cam.snap_behind(PI)
			wait = 40
		11:
			snap("11_beach")
			world.open_menu(ModShopUI.new(null, "garage", 1))
			wait = 20
		12:
			snap("12_modshop")
			world.close_menu()
			world.open_menu(MapView.new())
			wait = 20
		13:
			snap("13_map")
			world.close_menu()
			world.open_menu(ShopUI.new("clothing"))
			wait = 20
		14:
			snap("14_clothing")
			get_tree().quit()
	step += 1
