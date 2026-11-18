extends Node3D
var car: Car
var t := 0.0
var log_t := 0.0
var model := "zephyr_gt"
var phase := 0
var start_z := 0.0
var maxroll := 0.0

func _ready() -> void:
	Engine.max_fps = 60
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		model = args[0]
	Game.new_game(2, "T", Catalog.default_appearance())
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4000, 2, 4000)
	cs.shape = bs
	cs.position.y = -1
	sb.add_child(cs)
	add_child(sb)
	car = Car.new()
	car.setup(model, {})
	add_child(car)
	car.global_position = Vector3(0, 0.8, 0)
	var p := Node.new()
	p.set_script(load("res://tests/fake_driver.gd"))
	add_child(p)
	car.set_driver(p)

func _physics_process(delta: float) -> void:
	t += delta
	if t > 0.5 and phase == 0:
		phase = 1
		Input.action_press("move_forward")
		start_z = car.global_position.z
	log_t += delta
	var kmh := car.speed() * 3.6
	if phase == 1 and kmh >= 100.0:
		print("0-100: %.2fs (target %.1f)" % [t - 0.5, car.def["accel"]])
		phase = 2
	if log_t > 1.0:
		log_t = 0.0
		var contact := 0
		for w in car.wheels:
			if w.is_in_contact():
				contact += 1
		print("t=%.1f v=%.1f km/h y=%.3f contact=%d ef=%.0f rot=%s" % [t, kmh, car.global_position.y, contact, car.engine_force, str(car.global_rotation)])
	if t > 30.0 and phase < 4:
		Input.action_release("move_forward")
		Input.action_press("move_back")
		phase = 4
		print("braking from %.1f" % kmh)
	if phase == 4 and kmh < 1.0:
		print("stopped at t=%.1f" % t)
		phase = 5
		Input.action_release("move_back")
		Input.action_press("move_forward")
		Input.action_press("move_left")
	if phase == 5:
		maxroll = max(maxroll, abs(car.global_rotation.z))
	if phase == 5 and t > 40.0:
		print("turn test v=%.1f yaw rate=%.2f roll=%.2f maxroll=%.2f" % [kmh, car.angular_velocity.y, car.global_rotation.z, maxroll])
		get_tree().quit()
