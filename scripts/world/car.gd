class_name Car
extends VehicleBody3D
## Player-drivable physics vehicle. Built entirely from catalog data + modifications.

signal destroyed(car: Car)

var model_id := ""
var def: Dictionary = {}
var mods: Dictionary = {}
var owned_uid := -1           # >0 if this is one of the player's vehicles
var stolen := false
var job_tag := ""             # e.g. "delivery" for job vehicles
var health := 1000.0
var driver: Node = null
var is_bike := false

var spec: Dictionary
var top_speed := 50.0
var engine_f := 4000.0
var brake_decel := 9.0
var grip := 3.0
var max_steer := 0.55
var reverse_speed := 11.0

var wheels: Array[VehicleWheel3D] = []
var rear_wheels: Array[VehicleWheel3D] = []
var steer_input := 0.0
var lights_on := false
var head_lights: Array[SpotLight3D] = []
var model: Node3D
var engine_audio: AudioStreamPlayer3D
var skid_audio: AudioStreamPlayer3D
var smoke: GPUParticles3D
var fire: GPUParticles3D
var _prev_vel := Vector3.ZERO
var _destroy_timer := -1.0
var dead := false
var rpm := 0.0
var gear := 1
var _wet := 0.0
var idle_time := 0.0
var _water_checked := false

func setup(id: String, vehicle_mods: Dictionary = {}, uid: int = -1) -> void:
	model_id = id
	def = Catalog.get_vehicle(id)
	mods = Catalog.default_mods(def)
	for k in vehicle_mods:
		mods[k] = vehicle_mods[k]
	owned_uid = uid
	spec = CarModel.spec(def["body"])
	is_bike = spec.get("two", false)
	mass = float(def["mass"])
	collision_layer = 4
	collision_mask = 1 | 4 | 8
	add_to_group("vehicles")
	_compute_stats()
	_build()

func _compute_stats() -> void:
	var eng: int = int(mods.get("engine", 0))
	var turbo: int = int(mods.get("turbo", 0))
	top_speed = float(def["top"]) / 3.6 * (1.0 + eng * 0.025 + turbo * 0.02)
	var accel: float = 27.78 / float(def["accel"]) * (1.0 + eng * 0.06 + turbo * 0.09)
	engine_f = mass * accel * 1.05
	brake_decel = lerp(7.0, 13.0, float(def["brake"])) * (1.0 + int(mods.get("brakes", 0)) * 0.08)
	var tire: int = int(mods.get("tires", 0))
	var tire_mult: float = [1.0, 1.1, 0.88, 1.0][clampi(tire, 0, 3)]
	grip = lerp(2.4, 3.6, float(def["grip"])) * tire_mult * (1.0 + int(mods.get("suspension", 0)) * 0.03)
	max_steer = 0.62 if is_bike else 0.55

func performance() -> Dictionary:
	## 0..1 bars for UI.
	return {"speed": clamp(top_speed * 3.6 / 400.0, 0.0, 1.0), "accel": clamp(engine_f / mass / 14.0, 0.0, 1.0),
		"braking": clamp((brake_decel - 6.0) / 9.0, 0.0, 1.0), "handling": clamp((grip - 2.0) / 2.2, 0.0, 1.0)}

func _build() -> void:
	model = CarModel.build(def, mods)
	add_child(model)
	var L: float = spec["L"]
	var W: float = spec["W"]
	var c: float = spec["c"]
	var h: float = spec["h"]
	var r: float = spec["r"]
	# collision
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	if is_bike:
		bs.size = Vector3(0.5, 0.8, L * 0.9)
		cs.position = Vector3(0, r + 0.3, 0)
	else:
		bs.size = Vector3(W, h, L)
		cs.position = Vector3(0, c + h / 2.0, 0)
	cs.shape = bs
	add_child(cs)
	if not is_bike and def["body"] != "buggy":
		var cs2 := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		var cf: float = -L / 2.0 + L * spec["cf"]
		var cr: float = -L / 2.0 + L * spec["cr"]
		b2.size = Vector3(W * 0.85, spec["rh"], max(0.5, cr - cf))
		cs2.shape = b2
		cs2.position = Vector3(0, c + h + spec["rh"] / 2.0, (cf + cr) / 2.0)
		add_child(cs2)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.12 if not is_bike else 0.2, 0.05)
	# we model drag ourselves (engine curve), so no global damping
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.6
	# wheels
	var track: float = 0.28 if is_bike else CarModel.wheel_x(spec)
	var zs := [-L / 2.0 + L * spec["wf"], -L / 2.0 + L * spec["wr"]]
	var drive: String = def["drive"]
	var wheel_vis := CarModel.wheel(def, mods)
	for zi in 2:
		for side in [-1.0, 1.0]:
			var w := VehicleWheel3D.new()
			w.position = Vector3(side * track, r + 0.15, zs[zi])
			w.wheel_radius = r
			w.wheel_rest_length = 0.2
			w.suspension_travel = 0.25
			var stiff := 55.0 + int(mods.get("suspension", 0)) * 8.0
			if def["body"] in ["offroad", "buggy", "suv"]:
				stiff = 40.0
			w.suspension_stiffness = stiff
			w.suspension_max_force = mass * 20.0
			w.damping_compression = 3.2
			w.damping_relaxation = 3.8
			w.wheel_friction_slip = grip
			w.wheel_roll_influence = 0.02
			w.use_as_steering = zi == 0
			w.use_as_traction = (drive == "AWD") or (drive == "FWD" and zi == 0) or (drive == "RWD" and zi == 1)
			add_child(w)
			wheels.append(w)
			if zi == 1:
				rear_wheels.append(w)
			if not is_bike or side > 0:
				var vis: Node3D = wheel_vis.duplicate()
				if is_bike:
					vis.position.x = -track
				w.add_child(vis)
	wheel_vis.queue_free()
	# lights
	var lamp_z: float = -L / 2.0 + 0.1
	for side in ([0.0] if is_bike else [-1.0, 1.0]):
		var sl := SpotLight3D.new()
		sl.position = Vector3(side * (W / 2.0 - 0.3), c + h * 0.7, lamp_z)
		sl.spot_range = 45.0
		sl.spot_angle = 32.0
		sl.light_energy = 3.0
		sl.light_color = Color(1.0, 0.96, 0.85)
		sl.shadow_enabled = false
		sl.visible = false
		sl.rotation.x = -0.06
		add_child(sl)
		head_lights.append(sl)
	# audio
	engine_audio = AudioStreamPlayer3D.new()
	engine_audio.stream = Sfx.engine_loops.get(def.get("sound", "v6"))
	engine_audio.bus = "SFX"
	engine_audio.unit_size = 8.0
	engine_audio.max_distance = 120.0
	engine_audio.volume_db = -4.0
	add_child(engine_audio)
	skid_audio = AudioStreamPlayer3D.new()
	skid_audio.stream = Sfx.streams.get("skid")
	skid_audio.bus = "SFX"
	skid_audio.unit_size = 6.0
	skid_audio.volume_db = -8.0
	add_child(skid_audio)
	# damage particles
	smoke = _particles(Color(0.25, 0.25, 0.25, 0.5), 1.2, 20, Vector3(0, c + h + 0.1, -L / 2.0 + 0.8))
	fire = _particles(Color(1.0, 0.45, 0.1, 0.9), 0.7, 30, Vector3(0, c + h + 0.1, -L / 2.0 + 0.8))

func _particles(col: Color, size: float, amount: int, pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.4
	p.emitting = false
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, 1.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.color = col
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	qm.material = m
	p.draw_pass_1 = qm
	add_child(p)
	return p

func _ready() -> void:
	_prev_vel = linear_velocity

func set_driver(d: Node) -> void:
	driver = d
	if d:
		if not engine_audio.playing:
			engine_audio.play()
		idle_time = 0.0
	else:
		engine_force = 0.0
		brake = 2.0
		steering = 0.0

func speed() -> float:
	return linear_velocity.dot(-global_transform.basis.z)

func set_lights(on: bool) -> void:
	lights_on = on
	for l in head_lights:
		l.visible = on

func _physics_process(delta: float) -> void:
	if dead:
		return
	var fwd := -global_transform.basis.z
	var v := speed()
	var spd := linear_velocity.length()
	var grounded := false
	for w in wheels:
		if w.is_in_contact():
			grounded = true
			break
	# --- crash damage from sudden velocity change
	var dv := (linear_velocity - _prev_vel).length()
	if dv > 7.0 and delta > 0.0:
		var dmg := (dv - 7.0) * 18.0
		take_damage(dmg)
		Sfx.play("crash" if dv > 12.0 else "thud", randf_range(0.9, 1.1), clamp(-14.0 + dv, -12.0, 4.0) if driver else -12.0)
		if driver and driver.has_method("on_vehicle_crash"):
			driver.on_vehicle_crash(dv)
	_prev_vel = linear_velocity
	# --- input
	var throttle := 0.0
	var brake_in := 0.0
	var steer := 0.0
	var handbrake := false
	if driver and not get_tree().paused and driver.get("input_enabled") != false:
		throttle = Input.get_action_strength("move_forward")
		brake_in = Input.get_action_strength("move_back")
		steer = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		handbrake = Input.is_action_pressed("handbrake")
		if Input.is_action_just_pressed("horn"):
			Sfx.play("horn")
			var w := get_tree().get_first_node_in_group("world")
			if w and w.has_method("on_horn"):
				w.on_horn(global_position)
		if Input.is_action_just_pressed("headlights"):
			set_lights(not lights_on)
	if health <= 150.0:
		throttle *= 0.45
	# --- steering (reduced at speed, smoothed)
	var speed_factor: float = clamp(abs(v) / 40.0, 0.0, 1.0)
	var target = steer * lerp(max_steer, max_steer * 0.28, speed_factor)
	steer_input = move_toward(steer_input, target, delta * (3.0 if steer != 0.0 else 4.5))
	steering = steer_input
	# --- engine / brakes
	var driven := 0
	for w in wheels:
		if w.use_as_traction:
			driven += 1
	var f := 0.0
	var braking := false
	if throttle > 0.0:
		if v < -1.0:
			braking = true
		else:
			var ratio: float = clamp(v / top_speed, 0.0, 1.2)
			f = engine_f * throttle * max(0.0, 1.0 - pow(ratio, 3.0))
	if brake_in > 0.0:
		if v > 1.0:
			braking = true
		elif v > -reverse_speed:
			f = -engine_f * 0.5 * brake_in
	# Godot VehicleBody3D drives along +Z; our models face -Z, so the force is negated.
	engine_force = -f / max(1, driven) if grounded else 0.0
	if braking and grounded:
		var bdir := -linear_velocity.normalized()
		apply_central_force(bdir * mass * brake_decel * max(throttle, brake_in))
	# idle rolling resistance / no-driver hold
	if driver == null:
		brake = 3.0
	else:
		brake = 0.0
		if throttle == 0.0 and brake_in == 0.0 and grounded:
			apply_central_force(-linear_velocity * mass * 0.18)
	# --- handbrake drift
	var wet_mult: float = 1.0 - _wet * 0.15
	for w in wheels:
		w.wheel_friction_slip = grip * wet_mult
	if handbrake:
		for w in rear_wheels:
			w.wheel_friction_slip = grip * 0.42
			w.brake = 6.0 if abs(v) < 3.0 else 1.5
		if grounded and abs(v) > 3.0:
			apply_central_force(-linear_velocity.normalized() * mass * 2.0)
	else:
		for w in rear_wheels:
			w.brake = brake
	# --- stability: downforce, anti-roll, yaw damping
	if grounded:
		apply_central_force(Vector3.DOWN * min(spd * spd * 0.0012, 8.0) * mass)
	var up := global_transform.basis.y
	var roll_axis := up.cross(Vector3.UP)
	var k_up := 6.0 if is_bike else 7.0
	if grounded or is_bike:
		apply_torque(roll_axis * mass * k_up * (2.0 if is_bike else 1.0))
		apply_torque(-angular_velocity * Vector3(1, 0, 1) * mass * (0.8 if is_bike else 0.25))
	if not handbrake and grounded and abs(v) > 5.0:
		# keep slides controllable: damp excess yaw rate
		var yaw_rate := angular_velocity.y
		var desired: float = steer_input * v / 4.0
		apply_torque(Vector3.UP * (desired - yaw_rate) * mass * 0.6)
	if is_bike and model:
		model.rotation.z = lerp(model.rotation.z, -steer_input * clamp(abs(v) / 20.0, 0.0, 1.0) * 0.6, delta * 5.0)
	# --- audio
	_update_audio(v, throttle, handbrake, grounded, delta)
	# --- damage effects
	smoke.emitting = health < 450.0
	fire.emitting = health < 120.0
	if health <= 0.0 and _destroy_timer < 0.0:
		_destroy_timer = 4.0
	if _destroy_timer >= 0.0:
		_destroy_timer -= delta
		if _destroy_timer <= 0.0:
			explode()
	# --- water
	if global_position.y < CityLayout.WATER_Y - 0.5 and not dead:
		if not _water_checked:
			_water_checked = true
			Sfx.play("splash")
		health = 0.0
		linear_velocity *= 0.9
		if global_position.y < CityLayout.WATER_Y - 3.0:
			_sink()
	if driver == null:
		idle_time += delta
		if engine_audio.playing and idle_time > 2.0:
			engine_audio.stop()

func _update_audio(v: float, throttle: float, handbrake: bool, grounded: bool, delta: float) -> void:
	if not engine_audio.playing:
		return
	var gears := 6 if not def["body"] in ["boxtruck", "van", "camper"] else 5
	var gear_span := top_speed / gears
	var av: float = abs(v)
	gear = clampi(int(av / gear_span) + 1, 1, gears)
	var in_gear: float = (av - (gear - 1) * gear_span) / gear_span
	var target_rpm: float = 0.15 + in_gear * 0.75 + throttle * 0.1
	if not grounded:
		target_rpm = 0.3 + throttle * 0.7
	rpm = lerp(rpm, target_rpm, delta * 8.0)
	engine_audio.pitch_scale = 0.7 + rpm * 2.2
	engine_audio.volume_db = -10.0 + throttle * 6.0 + rpm * 3.0
	var lateral: float = abs(linear_velocity.dot(global_transform.basis.x))
	var skid = grounded and (lateral > 4.5 or (handbrake and abs(v) > 5.0))
	if skid and not skid_audio.playing:
		skid_audio.play()
	elif not skid and skid_audio.playing:
		skid_audio.stop()

func take_damage(amount: float) -> void:
	if dead:
		return
	health = max(0.0, health - amount)
	if owned_uid > 0:
		var v := Game.get_owned(owned_uid)
		if not v.is_empty():
			v["health"] = health

func repair() -> void:
	health = 1000.0
	_destroy_timer = -1.0
	smoke.emitting = false
	fire.emitting = false

func explode() -> void:
	if dead:
		return
	dead = true
	Sfx.play("explosion")
	var w := get_tree().get_first_node_in_group("world")
	if w and w.has_method("on_vehicle_destroyed"):
		w.on_vehicle_destroyed(self)
	apply_central_impulse(Vector3.UP * mass * 6.0)
	apply_torque_impulse(Vector3(randf() - 0.5, 0, randf() - 0.5) * mass * 3.0)
	engine_force = 0.0
	engine_audio.stop()
	# char the body
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = CarModel.mat(Color(0.08, 0.07, 0.07), 0.9)
	fire.emitting = true
	smoke.emitting = true
	destroyed.emit(self)
	get_tree().create_timer(25.0).timeout.connect(_despawn_wreck)

func _sink() -> void:
	if dead:
		return
	dead = true
	destroyed.emit(self)
	var w := get_tree().get_first_node_in_group("world")
	if w and w.has_method("on_vehicle_destroyed"):
		w.on_vehicle_destroyed(self)
	get_tree().create_timer(4.0).timeout.connect(_despawn_wreck)

func _despawn_wreck() -> void:
	if driver == null:
		queue_free()

func flip_upright() -> void:
	var yaw := global_rotation.y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3.UP * 1.2)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func is_flipped() -> bool:
	return global_transform.basis.y.dot(Vector3.UP) < 0.3

func set_wetness(w: float) -> void:
	_wet = w

func seat_position() -> Vector3:
	if is_bike:
		return Vector3(0, spec["r"] + 0.45, 0.25)
	return Vector3(-spec["W"] * 0.22, spec["c"] + 0.3, -spec["L"] * 0.05)

func exit_position() -> Vector3:
	var side = global_transform.basis.x * -(spec["W"] / 2.0 + 0.9)
	return global_position + side + Vector3.UP * 0.5
