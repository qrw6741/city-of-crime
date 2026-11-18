class_name SkyWeather
extends Node3D
## Day/night cycle and dynamic weather (clear, cloudy, overcast, rain, storm, fog).

const MINUTES_PER_SECOND := 1.0     # 1 real second = 1 game minute (24 minute day)
const WEATHERS := ["clear", "clear", "cloudy", "overcast", "rain", "storm", "fog"]
const PARAMS := {
	"clear": {"cloud": 0.1, "fog": 0.0006, "rain": 0.0, "light": 1.0},
	"cloudy": {"cloud": 0.45, "fog": 0.0009, "rain": 0.0, "light": 0.85},
	"overcast": {"cloud": 0.8, "fog": 0.0014, "rain": 0.0, "light": 0.6},
	"rain": {"cloud": 0.9, "fog": 0.002, "rain": 0.7, "light": 0.45},
	"storm": {"cloud": 1.0, "fog": 0.0026, "rain": 1.0, "light": 0.32},
	"fog": {"cloud": 0.6, "fog": 0.009, "rain": 0.0, "light": 0.55},
}

var time_of_day := 9.0
var weather := "clear"
var next_weather_in := 600.0
var cur := {"cloud": 0.1, "fog": 0.0006, "rain": 0.0, "light": 1.0}
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var rain: GPUParticles3D
var rain_audio: AudioStreamPlayer
var wet := 0.0
var _lightning := 0.0
var follow: Node3D

func _ready() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_density = 0.0008
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = false
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.0
	sun.light_angular_distance = 0.5
	add_child(sun)
	_build_rain()
	rain_audio = AudioStreamPlayer.new()
	rain_audio.stream = Sfx.streams.get("ambience")
	rain_audio.bus = "SFX"
	rain_audio.volume_db = -40.0
	add_child(rain_audio)
	rain_audio.play()
	apply_quality(int(Game.settings["quality"]))

func apply_quality(q: int) -> void:
	sun.shadow_enabled = q > 0
	sun.directional_shadow_max_distance = [80.0, 160.0, 260.0][clampi(q, 0, 2)]
	env.ssao_enabled = q >= 2
	env.glow_enabled = q >= 1
	env.sdfgi_enabled = false
	rain.amount = [1500, 3000, 6000][clampi(q, 0, 2)]
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(q, 0, 2)]
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED

func _build_rain() -> void:
	rain = GPUParticles3D.new()
	rain.amount = 3000
	rain.lifetime = 1.2
	rain.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(35, 2, 35)
	pm.direction = Vector3(0.1, -1, 0.05)
	pm.spread = 3.0
	pm.initial_velocity_min = 28.0
	pm.initial_velocity_max = 34.0
	pm.gravity = Vector3(0, -10, 0)
	rain.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.025, 0.7)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.8, 0.9, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	qm.material = m
	rain.draw_pass_1 = qm
	rain.emitting = false
	add_child(rain)

func set_state(t: float, w: String) -> void:
	time_of_day = t
	weather = w if PARAMS.has(w) else "clear"
	cur = PARAMS[weather].duplicate()
	wet = cur["rain"]

func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + delta * MINUTES_PER_SECOND / 60.0, 24.0)
	next_weather_in -= delta
	if next_weather_in <= 0.0:
		next_weather_in = randf_range(420.0, 780.0)
		var nw: String = WEATHERS[randi() % WEATHERS.size()]
		if nw != weather:
			weather = nw
	var target: Dictionary = PARAMS[weather]
	for k in cur:
		cur[k] = lerp(float(cur[k]), float(target[k]), delta * 0.05)
	_update_sky(delta)
	if follow:
		rain.global_position = follow.global_position + Vector3(0, 18, 0)
	rain.emitting = cur["rain"] > 0.15
	wet = move_toward(wet, 1.0 if cur["rain"] > 0.2 else 0.0, delta * (0.02 if cur["rain"] > 0.2 else 0.006))
	RenderingServer.global_shader_parameter_set("wetness", wet)
	rain_audio.volume_db = lerp(-40.0, -10.0, clamp(cur["rain"], 0.0, 1.0))

func sun_elevation() -> float:
	return sin((time_of_day - 6.0) / 12.0 * PI)

func night_factor() -> float:
	return clamp((0.12 - sun_elevation()) * 4.0, 0.0, 1.0)

func _update_sky(delta: float) -> void:
	var e := sun_elevation()
	var day: float = clamp(e * 3.0 + 0.3, 0.0, 1.0)
	var sunset: float = clamp(1.0 - abs(e) * 4.0, 0.0, 1.0)
	var cloud: float = cur["cloud"]
	var nf := night_factor()
	RenderingServer.global_shader_parameter_set("night_factor", nf)
	# sun / moon direction
	var ang := (time_of_day - 6.0) / 24.0 * TAU
	if e > -0.05:
		sun.rotation = Vector3(-max(0.08, asin(clamp(e, -1.0, 1.0))), PI * 0.25 + ang * 0.3, 0)
		sun.light_color = Color(1.0, 0.95, 0.88).lerp(Color(1.0, 0.55, 0.3), sunset)
		sun.light_energy = lerp(0.15, 1.05, day) * float(cur["light"])
	else:
		# moonlight
		sun.rotation = Vector3(-0.9, PI * 0.25 + ang * 0.3 + PI, 0)
		sun.light_color = Color(0.55, 0.65, 0.95)
		sun.light_energy = 0.22 * float(cur["light"])
	var top_day := Color(0.22, 0.45, 0.85).lerp(Color(0.45, 0.48, 0.52), cloud)
	var hor_day := Color(0.65, 0.75, 0.88).lerp(Color(0.62, 0.64, 0.66), cloud)
	var top_night := Color(0.01, 0.015, 0.04)
	var hor_night := Color(0.05, 0.06, 0.1)
	var hor_set := Color(0.95, 0.5, 0.25).lerp(Color(0.5, 0.45, 0.45), cloud)
	sky_mat.sky_top_color = top_night.lerp(top_day, day)
	var hor := hor_night.lerp(hor_day, day)
	sky_mat.sky_horizon_color = hor.lerp(hor_set, sunset * 0.8)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color.darkened(0.2)
	sky_mat.ground_bottom_color = Color(0.05, 0.05, 0.06)
	sky_mat.sun_angle_max = 25.0
	var amb_day := Color(0.50, 0.54, 0.60).lerp(Color(0.55, 0.56, 0.58), cloud)
	var amb_night := Color(0.16, 0.18, 0.28)
	env.ambient_light_color = amb_night.lerp(amb_day, day).lerp(Color(0.6, 0.45, 0.4), sunset * 0.3)
	env.ambient_light_energy = lerp(0.55, 0.75, day) * lerp(1.0, 0.85, cloud)
	env.fog_density = float(cur["fog"]) * (1.3 if nf > 0.5 else 1.0)
	env.fog_light_color = sky_mat.sky_horizon_color.lerp(Color(0.5, 0.5, 0.52), cloud * 0.5)
	env.background_energy_multiplier = lerp(0.35, 1.0, day)
	# lightning in storms
	if weather == "storm" and randf() < delta * 0.08:
		_lightning = 1.0
		get_tree().create_timer(randf_range(0.4, 1.4)).timeout.connect(func(): Sfx.play("explosion", 0.5, -8.0))
	if _lightning > 0.0:
		_lightning = max(0.0, _lightning - delta * 4.0)
		env.ambient_light_energy += _lightning * 3.0

func clock_text() -> String:
	var h := int(time_of_day)
	var m := int((time_of_day - h) * 60.0)
	return "%02d:%02d" % [h, m]

func weather_name() -> String:
	return weather.capitalize()
