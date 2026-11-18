extends "res://tests/shots.gd"
func _process(_d: float) -> void:
	frames += 1
	if frames < 5:
		return
	wait -= 1
	if wait > 0:
		return
	match step:
		0:
			world.sky.time_of_day = 22.0
			world.hud.big_box.visible = false
			world.player.teleport(Vector3(470, 0.4, 560), PI * 0.75)
			world.cam.pitch = 0.15
			wait = 50
		1:
			snap("n1_night_street")
			world.sky.time_of_day = 19.2
			world.sky.weather = "rain"
			world.sky.cur = world.sky.PARAMS["rain"].duplicate()
			world.sky.wet = 1.0
			wait = 50
		2:
			snap("n2_dusk_rain")
			get_tree().quit()
	step += 1
