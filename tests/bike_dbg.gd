extends "res://tests/car_test.gd"
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if t > 32.0 and t < 33.5:
		print("dbg t=%.2f pos=%s vel=%s angv=%s rot=%s ef=%.0f steer=%.2f" % [t, car.global_position, car.linear_velocity, car.angular_velocity, car.global_rotation, car.engine_force, car.steering])
