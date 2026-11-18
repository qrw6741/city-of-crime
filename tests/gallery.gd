extends Node3D
var frames := 0
func _ready() -> void:
	Game.new_game(2, "T", Catalog.default_appearance())
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.45, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.54, 0.6)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	fl.mesh = pm
	fl.material_override = CarModel.mat(Color(0.3, 0.3, 0.32))
	add_child(fl)
	var ids := ["novak_pip", "valor_cruiser", "orion_stately", "zephyr_gt", "vortex_x9", "brawler_ss", "summit_lx", "mule_4x4", "dune_raider", "workhorse_2500", "ironclad_hauler", "courier_van", "nomad_camper", "razor_600", "sprite_125", "drifter_chopper"]
	for k in ids.size():
		var def := Catalog.get_vehicle(ids[k])
		var mods := Catalog.default_mods(def)
		var m := CarModel.build(def, mods)
		var s := CarModel.spec(def["body"])
		var wv := CarModel.wheel(def, mods)
		for zi in [s["wf"], s["wr"]]:
			for sx in ([0.0] if s.get("two", false) else [-1.0, 1.0]):
				var w: Node3D = wv.duplicate()
				w.position = Vector3(sx * CarModel.wheel_x(s), s["r"], -s["L"] / 2.0 + s["L"] * zi)
				m.add_child(w)
		m.position = Vector3((k % 4) * 9.0, 0, (k / 4) * 9.0)
		m.rotation.y = PI / 2 + 0.5
		add_child(m)
	for k in 6:
		var h := Humanoid.new()
		add_child(h)
		var app := Catalog.random_appearance()
		app["hat"] = 0
		app["glasses"] = 0
		if k == 0:
			app = Catalog.default_appearance("male")
		if k == 1:
			app = Catalog.default_appearance("female")
		h.build(app, true)
		h.position = Vector3(-6, 0, k * 1.2)
		h.rotation.y = PI / 2 + 0.6
		h.animate(0.016, 0, true, false)
	var cam := Camera3D.new()
	add_child(cam)
	cam.transform = Transform3D(Basis(), Vector3(36, 14, 42)).looking_at(Vector3(12, 0, 14))
	cam.fov = 45
	var cam2 := Camera3D.new()
	cam2.name = "Cam2"
	add_child(cam2)
	cam2.transform = Transform3D(Basis(), Vector3(-2.2, 1.7, 3.5)).looking_at(Vector3(-6, 1.4, 2.5))
	cam2.fov = 40
	cam.current = true
func _process(_d):
	frames += 1
	if frames == 10:
		get_viewport().get_texture().get_image().save_png("/home/claude/shots/g_cars.png")
		($Cam2 as Camera3D).current = true
	if frames == 20:
		get_viewport().get_texture().get_image().save_png("/home/claude/shots/g_people.png")
		get_tree().quit()
