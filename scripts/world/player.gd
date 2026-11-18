class_name Player
extends CharacterBody3D
## On-foot third/first-person character controller. Also tracks the vehicle the player is in.

const WALK := 3.0
const RUN := 5.6
const SPRINT := 8.2
const JUMP_V := 7.2
const GRAVITY := 22.0

var visual: Humanoid
var cam: Node   # CameraRig
var vehicle: Car = null
var input_enabled := true
var health := 100.0
var armor := 0.0
var stamina := 100.0
var dead := false
var _step_t := 0.0
var _air_vy := 0.0
var _was_on_floor := true
var _hit_cooldown := 0.0
var _drive_dist := 0.0
var interior := ""     # property id if inside an interior

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	visual = Humanoid.new()
	add_child(visual)
	rebuild_visual()
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50)
	add_to_group("player")

func rebuild_visual() -> void:
	visual.build(Game.data.get("appearance", Catalog.default_appearance()), true)

func max_stamina() -> float:
	return 60.0 + Game.stat("stamina") * 1.4

func _physics_process(delta: float) -> void:
	_hit_cooldown = max(0.0, _hit_cooldown - delta)
	if vehicle:
		_ride(delta)
		return
	if dead:
		velocity.x = move_toward(velocity.x, 0, delta * 10)
		velocity.z = move_toward(velocity.z, 0, delta * 10)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		visual.animate(delta, 0, true, false)
		return
	var input := Vector2.ZERO
	var sprinting := false
	if input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		sprinting = Input.is_action_pressed("sprint") and stamina > 1.0 and input.length() > 0.1
	var cam_yaw: float = cam.yaw if cam else 0.0
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, cam_yaw)
	var target_speed := 0.0
	if input.length() > 0.1:
		target_speed = SPRINT if sprinting else RUN
		if input.length() < 0.6:
			target_speed = WALK
	var hv := Vector3(velocity.x, 0, velocity.z)
	var accel := 14.0 if is_on_floor() else 3.0
	hv = hv.move_toward(dir.normalized() * target_speed, accel * delta * max(target_speed, 4.0))
	velocity.x = hv.x
	velocity.z = hv.z
	# stamina
	if sprinting and hv.length() > RUN:
		stamina = max(0.0, stamina - delta * 14.0)
		Game.add_stat("stamina", delta * 0.03)
	else:
		stamina = min(max_stamina(), stamina + delta * 10.0)
	# gravity & jump
	if is_on_floor():
		if input_enabled and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_V + Game.stat("strength") * 0.01
			Sfx.play("jump", randf_range(0.9, 1.1), -6.0)
	else:
		velocity.y -= GRAVITY * delta
		_air_vy = min(_air_vy, velocity.y)
	move_and_slide()
	# landing / fall damage
	if is_on_floor() and not _was_on_floor:
		if _air_vy < -15.0:
			take_damage((-_air_vy - 15.0) * 6.0, "fall")
		_air_vy = 0.0
	_was_on_floor = is_on_floor()
	# face movement direction (or camera in first person)
	if cam and cam.first_person:
		rotation.y = lerp_angle(rotation.y, cam_yaw, delta * 20.0)
	elif hv.length() > 0.3:
		var target_yaw := atan2(-hv.x, -hv.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 12.0)
	visual.animate(delta, hv.length(), is_on_floor(), sprinting)
	# footsteps
	if is_on_floor() and hv.length() > 1.0:
		_step_t += delta * hv.length() * 0.42
		if _step_t > 1.0:
			_step_t = 0.0
			Sfx.play("step", randf_range(0.85, 1.15), -14.0)
	# water
	if global_position.y < CityLayout.WATER_Y - 0.8:
		var w := get_tree().get_first_node_in_group("world")
		if w:
			w.player_in_water()
	# getting hit by vehicles
	_check_vehicle_hits()

func _check_vehicle_hits() -> void:
	if _hit_cooldown > 0.0:
		return
	for c in get_tree().get_nodes_in_group("vehicles"):
		var car := c as Node3D
		if car == null or car == vehicle:
			continue
		var d := car.global_position.distance_to(global_position)
		if d > 3.2:
			continue
		var cv: Vector3 = car.get("linear_velocity") if car is RigidBody3D else car.get("velocity")
		if cv == null:
			continue
		var rel := cv - velocity
		if rel.length() > 5.0:
			var to_me := (global_position - car.global_position).normalized()
			if rel.normalized().dot(to_me) > 0.3:
				take_damage(rel.length() * 3.5, "vehicle")
				velocity = rel * 0.8 + Vector3.UP * 4.0
				_hit_cooldown = 1.0
				Sfx.play("thud")
				return

func take_damage(amount: float, _source: String = "") -> void:
	if dead or Game.data.is_empty():
		return
	var absorbed: float = min(armor, amount * 0.7)
	armor -= absorbed
	health -= amount - absorbed
	Game.data["health"] = health
	Game.data["armor"] = armor
	if health <= 0.0:
		health = 0.0
		die()

func heal(amount: float) -> void:
	health = min(100.0, health + amount)
	Game.data["health"] = health

func die() -> void:
	if dead:
		return
	dead = true
	visual.set_pose("dead")
	var w := get_tree().get_first_node_in_group("world")
	if w:
		w.on_player_died()

func revive(at: Vector3, yaw: float = 0.0) -> void:
	dead = false
	health = 100.0
	Game.data["health"] = health
	visual.set_pose("normal")
	teleport(at, yaw)

func teleport(at: Vector3, yaw: float = 0.0) -> void:
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO
	_air_vy = 0.0
	if cam:
		cam.snap_behind(yaw)

# ------------------------------------------------------------------ vehicles
func enter_vehicle(car: Car) -> void:
	vehicle = car
	car.set_driver(self)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	Sfx.play("door")
	visual.visible = car.is_bike
	if car.is_bike:
		visual.set_pose("sit")
	var w := get_tree().get_first_node_in_group("world")
	var night: bool = w and w.has_method("is_night") and w.is_night()
	car.set_lights(night)

func exit_vehicle() -> void:
	if vehicle == null:
		return
	var car := vehicle
	vehicle = null
	car.set_driver(null)
	var p := car.exit_position()
	# don't drop the player inside a wall: fall back to the roof if blocked
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(car.global_position + Vector3.UP, p)
	q.exclude = [car.get_rid()]
	if not space.intersect_ray(q).is_empty():
		p = car.global_position + Vector3.UP * 2.5
	global_position = p
	rotation.y = car.global_rotation.y
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	visual.visible = true
	visual.set_pose("normal")
	Sfx.play("door")

func _ride(delta: float) -> void:
	if not is_instance_valid(vehicle):
		vehicle = null
		collision_layer = 2
		collision_mask = 1 | 4 | 8
		visual.visible = true
		visual.set_pose("normal")
		return
	global_transform = vehicle.global_transform.translated_local(vehicle.seat_position())
	velocity = vehicle.linear_velocity
	var spd := vehicle.linear_velocity.length()
	_drive_dist += spd * delta
	if _drive_dist > 100.0:
		Game.data["totals"]["distance_km"] = float(Game.data["totals"]["distance_km"]) + _drive_dist / 1000.0
		_drive_dist = 0.0
	if spd > float(Game.data["totals"].get("max_speed", 0.0)):
		Game.data["totals"]["max_speed"] = spd
	if spd > 25.0:
		Game.add_stat("driving", delta * 0.02)
	if vehicle.is_bike:
		visual.animate(delta, 0, true, false)
	if input_enabled and Input.is_action_just_pressed("reset_vehicle") and vehicle.is_flipped():
		vehicle.flip_upright()

func on_vehicle_crash(dv: float) -> void:
	if vehicle and vehicle.is_bike and dv > 14.0:
		# thrown off the bike
		var car := vehicle
		exit_vehicle()
		velocity = car.linear_velocity * 0.6 + Vector3.UP * 6.0
		take_damage(dv * 2.0, "crash")
	elif dv > 22.0:
		take_damage((dv - 22.0) * 2.0, "crash")
