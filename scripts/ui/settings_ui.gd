class_name SettingsUI
extends MenuBase
## Graphics, controls and audio settings (saved to user://settings.cfg).

func build() -> void:
	var v := center_panel(Vector2(720, 0))
	v.add_child(UI.header("Settings"))
	var s := Game.settings
	v.add_child(_choice("Graphics quality", ["Low", "Medium", "High"], int(s["quality"]), func(i): _apply("quality", i)))
	v.add_child(_choice("Display", ["Windowed", "Fullscreen"], 1 if s["fullscreen"] else 0, func(i): _apply("fullscreen", i == 1)))
	v.add_child(_choice("V-Sync", ["Off", "On"], 1 if s["vsync"] else 0, func(i): _apply("vsync", i == 1)))
	v.add_child(_choice("Speed units", ["KM/H", "MPH"], 1 if s["units"] == "mph" else 0, func(i): _apply("units", "mph" if i == 1 else "kmh")))
	v.add_child(_choice("Show FPS", ["Off", "On"], 1 if s["show_fps"] else 0, func(i): _apply("show_fps", i == 1)))
	v.add_child(_choice("Invert mouse Y", ["Off", "On"], 1 if s["invert_y"] else 0, func(i): _apply("invert_y", i == 1)))
	v.add_child(_slider("Mouse sensitivity", float(s["mouse_sens"]), 0.2, 3.0, func(x): _apply("mouse_sens", x)))
	v.add_child(_slider("Field of view", float(s["fov"]), 55.0, 100.0, func(x): _apply("fov", x)))
	v.add_child(_slider("Traffic & pedestrian density", float(s["traffic"]), 0.0, 1.5, func(x): _apply("traffic", x)))
	v.add_child(_slider("Master volume", float(s["master"]), 0.0, 1.0, func(x): _apply("master", x)))
	v.add_child(_slider("Music volume", float(s["music"]), 0.0, 1.0, func(x): _apply("music", x)))
	v.add_child(_slider("Effects volume", float(s["sfx"]), 0.0, 1.0, func(x): _apply("sfx", x)))
	v.add_child(UI.button("Back [Esc]", close, 660))

func _apply(k: String, val) -> void:
	Game.settings[k] = val
	Game.save_settings()
	Game.apply_settings()

func _choice(label: String, opts: Array, cur: int, cb: Callable) -> Control:
	var h := UI.hbox()
	var l := UI.label(label, 17)
	l.custom_minimum_size.x = 280
	h.add_child(l)
	var ob := OptionButton.new()
	for o in opts:
		ob.add_item(o)
	ob.selected = cur
	ob.custom_minimum_size = Vector2(360, 38)
	ob.item_selected.connect(func(i):
		Sfx.play("click")
		cb.call(i))
	h.add_child(ob)
	return h

func _slider(label: String, cur: float, mn: float, mx: float, cb: Callable) -> Control:
	var h := UI.hbox()
	var l := UI.label(label, 17)
	l.custom_minimum_size.x = 280
	h.add_child(l)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = (mx - mn) / 100.0
	sl.value = cur
	sl.custom_minimum_size = Vector2(300, 30)
	var vl := UI.label("%.2f" % cur, 15, UI.DIM)
	sl.value_changed.connect(func(x):
		vl.text = "%.2f" % x
		cb.call(x))
	h.add_child(sl)
	h.add_child(vl)
	return h
