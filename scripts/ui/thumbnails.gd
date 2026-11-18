class_name Thumbnails
extends Node
## Renders small vehicle thumbnails off-screen and caches them.

var cache := {}
var queue: Array = []
var busy := false
var vp: SubViewport
var pivot: Node3D
var cam: Camera3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	vp = SubViewport.new()
	vp.size = Vector2i(256, 150)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.14, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	vp.add_child(we)
	var l := DirectionalLight3D.new()
	l.rotation = Vector3(-0.7, 0.7, 0)
	l.light_energy = 1.4
	vp.add_child(l)
	pivot = Node3D.new()
	vp.add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 35
	vp.add_child(cam)

static func key_for(v: Dictionary) -> String:
	return "%s_%s" % [v["model"], str(v["mods"].hash())]

func request(v: Dictionary, cb: Callable) -> void:
	var k := key_for(v)
	if cache.has(k):
		cb.call(cache[k])
		return
	queue.append([v.duplicate(true), cb])
	if not busy:
		_run()

func _run() -> void:
	busy = true
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var v: Dictionary = item[0]
		var k := key_for(v)
		if not cache.has(k):
			for c in pivot.get_children():
				c.free()
			var def := Catalog.get_vehicle(v["model"])
			var m := CarModel.build(def, v["mods"])
			var s := CarModel.spec(def["body"])
			var wv := CarModel.wheel(def, v["mods"])
			for zi in [s["wf"], s["wr"]]:
				for sx in ([0.0] if s.get("two", false) else [-1.0, 1.0]):
					var w: Node3D = wv.duplicate()
					w.position = Vector3(sx * CarModel.wheel_x(s), s["r"], -s["L"] / 2.0 + s["L"] * zi)
					m.add_child(w)
			wv.free()
			m.rotation.y = 2.4
			pivot.add_child(m)
			var L: float = s["L"]
			cam.transform = Transform3D(Basis(), Vector3(0, 1.5 + L * 0.15, L * 1.25 + 1.0)).looking_at(Vector3(0, 0.6, 0))
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			await get_tree().process_frame
			var img := vp.get_texture().get_image()
			if img:
				cache[k] = ImageTexture.create_from_image(img)
			else:
				cache[k] = null
		var cb: Callable = item[1]
		if cb.is_valid():
			cb.call(cache[k])
	busy = false
