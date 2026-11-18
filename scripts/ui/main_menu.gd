extends Control
## Title screen.

var buttons: VBoxContainer
var t := 0.0
var stars: Array = []
var bldgs: Array = []

func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 140:
		stars.append(Vector2(rng.randf(), rng.randf() * 0.55))
	var x := 0.0
	while x < 1.0:
		var w := rng.randf_range(0.02, 0.06)
		bldgs.append([x, w, rng.randf_range(0.12, 0.5), rng.randi()])
		x += w + rng.randf_range(0.0, 0.01)
	var left := UI.vbox(10)
	left.position = Vector2(110, 180)
	add_child(left)
	var title := UI.shadow_label("CITY OF CRIME", 92, UI.ACCENT)
	left.add_child(title)
	left.add_child(UI.shadow_label("Port Calloway is yours for the taking.", 24, Color(0.9, 0.9, 0.95), false))
	left.add_child(UI.spacer(30))
	buttons = UI.vbox(10)
	left.add_child(buttons)
	_build_buttons()
	var ver := UI.label("Build 0.1 - Stages 1-4  |  Godot 4.3", 14, UI.DIM)
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.position = Vector2(20, -34)
	add_child(ver)
	Sfx.play_music("menu")

func _build_buttons() -> void:
	UI.clear(buttons)
	var latest := Game.latest_slot()
	var cont := UI.button("Continue", _continue, 380, 24)
	cont.disabled = latest < 0
	if latest >= 0:
		var info := Game.slot_info(latest)
		cont.text = "Continue  -  %s (Lv %d)" % [info["name"], info["level"]]
	buttons.add_child(cont)
	buttons.add_child(UI.button("New Game", func(): _overlay(SlotsUI.new("new", _new_in_slot)), 380, 24))
	buttons.add_child(UI.button("Load Game", func(): _overlay(SlotsUI.new("load", _load_slot)), 380, 24))
	buttons.add_child(UI.button("Character", _character, 380, 24))
	buttons.add_child(UI.button("Settings", func(): _overlay(SettingsUI.new()), 380, 24))
	buttons.add_child(UI.button("Statistics", _stats, 380, 24))
	buttons.add_child(UI.button("Exit", func(): get_tree().quit(), 380, 24))
	(buttons.get_child(0) if latest >= 0 else buttons.get_child(1)).call_deferred("grab_focus")

func _overlay(m: Control) -> void:
	add_child(m)
	if m is MenuBase:
		m.closed.connect(_build_buttons)

func _continue() -> void:
	var s := Game.latest_slot()
	_load_slot(s)

func _load_slot(s: int) -> void:
	if Game.load_game(s):
		Sfx.stop_music()
		get_tree().change_scene_to_file("res://scenes/world.tscn")

func _new_in_slot(s: int) -> void:
	call_deferred("_overlay", CharCreator.new(s))

func _character() -> void:
	var s := Game.latest_slot()
	if s < 0:
		_overlay(DialogUI.new("Character", "You haven't created a character yet.", [["Create a character", func(): _overlay(SlotsUI.new("new", _new_in_slot))]]))
		return
	var f := FileAccess.open(Game.slot_path(s), FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	_overlay(CharacterView.new(d))

func _stats() -> void:
	var s := Game.latest_slot()
	if s < 0:
		_overlay(DialogUI.new("Statistics", "No saved games yet - start a New Game first.", []))
		return
	var f := FileAccess.open(Game.slot_path(s), FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	_overlay(StatsUI.new(d))

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var s := size
	# night sky gradient
	for i in 24:
		var f := float(i) / 24.0
		var c := Color(0.02, 0.03, 0.08).lerp(Color(0.35, 0.12, 0.2), pow(f, 2.2))
		draw_rect(Rect2(0, s.y * f, s.x, s.y / 24.0 + 1), c)
	for st in stars:
		var a := 0.4 + 0.4 * sin(t * 2.0 + st.x * 50.0)
		draw_circle(Vector2(st.x * s.x, st.y * s.y), 1.3, Color(1, 1, 1, a))
	# moon
	draw_circle(Vector2(s.x * 0.8, s.y * 0.18), 46, Color(0.95, 0.92, 0.85))
	draw_circle(Vector2(s.x * 0.8 + 16, s.y * 0.18 - 8), 44, Color(0.04, 0.05, 0.1, 0.0))
	# skyline
	var base := s.y * 0.95
	for b in bldgs:
		var x: float = b[0] * s.x
		var w: float = b[1] * s.x
		var h: float = b[2] * s.y
		draw_rect(Rect2(x, base - h, w, h), Color(0.04, 0.045, 0.07))
		var rng := RandomNumberGenerator.new()
		rng.seed = b[3]
		var wy := base - h + 10.0
		while wy < base - 8:
			var wx := x + 6.0
			while wx < x + w - 8:
				if rng.randf() < 0.32:
					var flick := 0.6 + 0.4 * sin(t * 0.7 + wx * 0.3 + wy)
					draw_rect(Rect2(wx, wy, 5, 7), Color(1.0, 0.8, 0.45, 0.65 * flick))
				wx += 11.0
			wy += 14.0
	draw_rect(Rect2(0, base, s.x, s.y - base), Color(0.02, 0.02, 0.03))
	# searchlights
	for k in 2:
		var ox := s.x * (0.35 + k * 0.3)
		var ang := sin(t * 0.4 + k * 2.0) * 0.5 - PI / 2.0
		var tip := Vector2(ox, base) + Vector2(cos(ang), sin(ang)) * s.y
		var side := Vector2(-sin(ang), cos(ang)) * 60.0
		draw_colored_polygon(PackedVector2Array([Vector2(ox, base), tip + side, tip - side]), Color(1.0, 0.85, 0.5, 0.05))
