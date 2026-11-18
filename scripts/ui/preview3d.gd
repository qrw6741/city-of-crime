class_name Preview3D
extends SubViewportContainer
## Interactive 3D turntable for vehicles and characters, used by shops and the character creator.

var viewport: SubViewport
var pivot: Node3D
var cam: Camera3D
var spin := 0.4
var dragging := false
var subject: Node3D
var cam_dist := 7.0
var cam_height := 1.6
var look_height := 0.6

func _init(sz: Vector2 = Vector2(640, 420)) -> void:
	custom_minimum_size = sz
	stretch = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(sz)
	viewport.transparent_bg = false
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.1, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	we.environment = env
	viewport.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.8, 0.6, 0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.4, 0)
	rim.light_energy = 0.7
	rim.light_color = Color(0.7, 0.8, 1.0)
	viewport.add_child(rim)
	var floor_mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.5
	cm.bottom_radius = 4.6
	cm.height = 0.1
	cm.radial_segments = 48
	floor_mi.mesh = cm
	floor_mi.material_override = CarModel.mat(Color(0.16, 0.17, 0.2), 0.25, 0.3)
	floor_mi.position.y = -0.05
	viewport.add_child(floor_mi)
	pivot = Node3D.new()
	viewport.add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 40
	viewport.add_child(cam)
	_place_cam()

func _place_cam() -> void:
	cam.transform = Transform3D(Basis(), Vector3(0, cam_height, cam_dist)).looking_at(Vector3(0, look_height, 0))

func set_car(def: Dictionary, mods: Dictionary) -> void:
	_clear()
	var m := CarModel.build(def, mods)
	var s := CarModel.spec(def["body"])
	var wv := CarModel.wheel(def, mods)
	for zi in [s["wf"], s["wr"]]:
		for sx in ([0.0] if s.get("two", false) else [-1.0, 1.0]):
			var w: Node3D = wv.duplicate()
			w.position = Vector3(sx * CarModel.wheel_x(s), s["r"], -s["L"] / 2.0 + s["L"] * zi)
			m.add_child(w)
	wv.queue_free()
	subject = m
	pivot.add_child(m)
	var L: float = s["L"]
	cam_dist = L * 1.45 + 2.0
	cam_height = 1.6 + L * 0.12
	look_height = 0.6
	_place_cam()

func set_humanoid(app: Dictionary) -> void:
	var keep_rot := pivot.rotation.y
	_clear()
	var h := Humanoid.new()
	pivot.add_child(h)
	h.build(app, true)
	h.animate(0.016, 0.0, true, false)
	subject = h
	cam_dist = 3.6
	cam_height = 1.3
	look_height = 1.0
	_place_cam()
	pivot.rotation.y = keep_rot

func focus_head() -> void:
	cam_dist = 1.4
	cam_height = 1.7
	look_height = 1.6
	_place_cam()

func focus_body() -> void:
	cam_dist = 3.6
	cam_height = 1.3
	look_height = 1.0
	_place_cam()

func _clear() -> void:
	for c in pivot.get_children():
		c.queue_free()
	subject = null

func _process(delta: float) -> void:
	if not dragging:
		pivot.rotation.y += spin * delta

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		pivot.rotation.y += event.relative.x * 0.01
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = max(1.0, cam_dist * 0.9)
			_place_cam()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = min(16.0, cam_dist * 1.1)
			_place_cam()
