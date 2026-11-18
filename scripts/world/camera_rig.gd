class_name CameraRig
extends Node3D
## Third-person orbit camera with collision, vehicle chase mode and a first-person option.

var player: Player
var camera: Camera3D
var arm: SpringArm3D
var yaw := 0.0
var pitch := -0.18
var first_person := false
var distance := 4.2
var _mouse_idle := 10.0
var _target_dist := 4.2
var shake := 0.0
var override_transform = null   # Transform3D when a cutscene / menu controls the view

func _ready() -> void:
	arm = SpringArm3D.new()
	arm.spring_length = distance
	arm.collision_mask = 1
	arm.margin = 0.25
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	arm.shape = shape
	add_child(arm)
	camera = Camera3D.new()
	camera.fov = Game.settings["fov"]
	camera.far = 2600.0
	camera.near = 0.08
	arm.add_child(camera)
	camera.current = true

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var s: float = 0.0025 * float(Game.settings["mouse_sens"])
		yaw -= event.relative.x * s
		var inv := -1.0 if Game.settings["invert_y"] else 1.0
		pitch = clamp(pitch - event.relative.y * s * inv, -1.25, 0.9 if first_person else 0.6)
		_mouse_idle = 0.0
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_dist = max(2.0, _target_dist - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_dist = min(12.0, _target_dist + 0.5)

func snap_behind(target_yaw: float) -> void:
	yaw = target_yaw
	pitch = -0.18

func _process(delta: float) -> void:
	if player == null:
		return
	camera.fov = lerp(camera.fov, float(Game.settings["fov"]) + _speed_fov(), delta * 3.0)
	if override_transform != null:
		camera.global_transform = override_transform
		return
	_mouse_idle += delta
	var car := player.vehicle
	if Input.is_action_just_pressed("camera_toggle") and player.input_enabled:
		first_person = not first_person
	if car:
		var L: float = car.spec["L"]
		var spd := car.linear_velocity.length()
		var car_yaw := car.global_rotation.y
		if Input.is_action_pressed("look_back"):
			car_yaw += PI
		if _mouse_idle > 1.2 and spd > 3.0 and not first_person:
			yaw = lerp_angle(yaw, car_yaw, delta * 2.5)
			pitch = lerp(pitch, -0.2, delta * 1.5)
		if first_person:
			var seat := car.global_transform.translated_local(car.seat_position() + Vector3(0, 0.75, 0))
			global_position = seat.origin
			arm.spring_length = 0.0
			yaw = lerp_angle(yaw, car_yaw, delta * 4.0) if _mouse_idle > 1.0 else yaw
		else:
			var h: float = car.spec["c"] + car.spec["h"] + (car.spec.get("rh", 0.5))
			global_position = global_position.lerp(car.global_position + Vector3(0, h + 0.4, 0), min(1.0, delta * 14.0))
			distance = L * 0.9 + 3.6 + _target_dist * 0.3 - 1.26
			arm.spring_length = lerp(arm.spring_length, distance + spd * 0.025, delta * 4.0)
		player.visual.visible = car.is_bike and not first_person
	else:
		if first_person:
			global_position = player.global_position + Vector3(0, 1.62 * float(Game.data.get("appearance", {}).get("height", 1.0)), 0) - player.global_transform.basis.z * 0.12
			arm.spring_length = 0.0
			player.visual.visible = false
		else:
			var target := player.global_position + Vector3(0, 1.55, 0)
			global_position = global_position.lerp(target, min(1.0, delta * 16.0))
			arm.spring_length = lerp(arm.spring_length, _target_dist, delta * 6.0)
			if not player.dead:
				player.visual.visible = player.interior == "" or true
	rotation = Vector3(pitch, yaw, 0)
	arm.position = Vector3.ZERO if (first_person or car) else Vector3(0.0, 0, 0)
	if shake > 0.0:
		shake = max(0.0, shake - delta * 2.0)
		camera.h_offset = randf_range(-1, 1) * shake * 0.15
		camera.v_offset = randf_range(-1, 1) * shake * 0.15
	else:
		camera.h_offset = 0.4 if not car and not first_person else 0.0
		camera.v_offset = 0.0

func _speed_fov() -> float:
	if player and player.vehicle:
		return clamp(player.vehicle.linear_velocity.length() * 0.18, 0.0, 14.0)
	return 0.0

func forward() -> Vector3:
	return -camera.global_transform.basis.z
