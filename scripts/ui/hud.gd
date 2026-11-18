class_name HUD
extends CanvasLayer
## In-game heads-up display.

var world: World
var root: Control
var minimap: Minimap
var health_bar: ColorRect
var armor_bar: ColorRect
var stamina_bar: ColorRect
var cash_l: Label
var bank_l: Label
var clock_l: Label
var weapon_l: Label
var stars: HBoxContainer
var level_l: Label
var xp_fill: ColorRect
var xp_box: Control
var prompt_l: Label
var objective_l: Label
var timer_l: Label
var big_title: Label
var big_sub: Label
var big_box: VBoxContainer
var area_l: Label
var feed: VBoxContainer
var speedo: PanelContainer
var speed_l: Label
var gear_l: Label
var car_name_l: Label
var car_hp: ColorRect
var fps_l: Label
var _big_t := 0.0
var _area_t := 0.0
var _xp_show := 0.0
var _last_cash := -1
var _cash_delta_l: Label
var _cash_delta_t := 0.0

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	# --- minimap bottom-left
	var mm_frame := Control.new()
	mm_frame.anchor_top = 1.0
	mm_frame.anchor_bottom = 1.0
	mm_frame.position = Vector2(24, -262)
	mm_frame.size = Vector2(330, 238)
	mm_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mm_frame)
	minimap = Minimap.new()
	minimap.world = world
	minimap.size = Vector2(330, 210)
	mm_frame.add_child(minimap)
	health_bar = _bar(mm_frame, Vector2(0, 216), Vector2(162, 9), Color(0.35, 0.8, 0.35))
	armor_bar = _bar(mm_frame, Vector2(168, 216), Vector2(162, 9), Color(0.35, 0.6, 1.0))
	stamina_bar = _bar(mm_frame, Vector2(0, 229), Vector2(330, 4), Color(1.0, 0.85, 0.3))
	# --- top right money / wanted / weapon
	var tr := VBoxContainer.new()
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.position = Vector2(-330, 18)
	tr.size = Vector2(310, 200)
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	tr.add_theme_constant_override("separation", 0)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)
	clock_l = _rlabel(tr, "", 18, UI.DIM)
	cash_l = _rlabel(tr, "$0", 34, Color(0.45, 0.9, 0.5))
	_cash_delta_l = _rlabel(tr, "", 20, Color(0.45, 0.9, 0.5))
	bank_l = _rlabel(tr, "Bank $0", 20, Color(0.75, 0.9, 0.8))
	stars = HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_END
	tr.add_child(stars)
	weapon_l = _rlabel(tr, "FISTS", 18, UI.TEXT)
	# --- XP bar top centre
	xp_box = Control.new()
	xp_box.anchor_left = 0.5
	xp_box.anchor_right = 0.5
	xp_box.position = Vector2(-200, 16)
	xp_box.size = Vector2(400, 40)
	xp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(xp_box)
	var lvl_bg := ColorRect.new()
	lvl_bg.color = Color(0.1, 0.35, 0.75)
	lvl_bg.size = Vector2(44, 34)
	xp_box.add_child(lvl_bg)
	level_l = UI.shadow_label("1", 20)
	level_l.size = Vector2(44, 34)
	level_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_box.add_child(level_l)
	var xbg := ColorRect.new()
	xbg.color = Color(0, 0, 0, 0.55)
	xbg.position = Vector2(50, 12)
	xbg.size = Vector2(350, 10)
	xp_box.add_child(xbg)
	xp_fill = ColorRect.new()
	xp_fill.color = Color(0.3, 0.65, 1.0)
	xp_fill.position = Vector2(50, 12)
	xp_fill.size = Vector2(0, 10)
	xp_box.add_child(xp_fill)
	timer_l = UI.shadow_label("", 34, Color.WHITE)
	timer_l.anchor_left = 0.5
	timer_l.anchor_right = 0.5
	timer_l.position = Vector2(-150, 60)
	timer_l.size = Vector2(300, 40)
	timer_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(timer_l)
	# --- notification feed top-left
	feed = VBoxContainer.new()
	feed.position = Vector2(22, 20)
	feed.size = Vector2(440, 300)
	feed.add_theme_constant_override("separation", 6)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feed)
	# --- objective + prompt bottom centre
	objective_l = UI.shadow_label("", 22, Color(1, 1, 1))
	objective_l.anchor_left = 0.5
	objective_l.anchor_right = 0.5
	objective_l.anchor_top = 1.0
	objective_l.anchor_bottom = 1.0
	objective_l.position = Vector2(-450, -185)
	objective_l.size = Vector2(900, 34)
	objective_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(objective_l)
	prompt_l = UI.shadow_label("", 22, UI.ACCENT)
	prompt_l.anchor_left = 0.5
	prompt_l.anchor_right = 0.5
	prompt_l.anchor_top = 1.0
	prompt_l.anchor_bottom = 1.0
	prompt_l.position = Vector2(-400, -95)
	prompt_l.size = Vector2(800, 34)
	prompt_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt_l)
	# --- big centre message
	big_box = VBoxContainer.new()
	big_box.anchor_left = 0.5
	big_box.anchor_right = 0.5
	big_box.anchor_top = 0.3
	big_box.anchor_bottom = 0.3
	big_box.position = Vector2(-500, -40)
	big_box.size = Vector2(1000, 120)
	big_box.alignment = BoxContainer.ALIGNMENT_CENTER
	big_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(big_box)
	big_title = UI.shadow_label("", 64, UI.ACCENT)
	big_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_box.add_child(big_title)
	big_sub = UI.shadow_label("", 22, Color.WHITE, false)
	big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	big_box.add_child(big_sub)
	big_box.visible = false
	# --- area name bottom-right
	area_l = UI.shadow_label("", 30, Color.WHITE)
	area_l.anchor_left = 1.0
	area_l.anchor_right = 1.0
	area_l.anchor_top = 1.0
	area_l.anchor_bottom = 1.0
	area_l.position = Vector2(-620, -60)
	area_l.size = Vector2(600, 40)
	area_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(area_l)
	# --- speedometer
	speedo = UI.panel(Vector2(260, 0), Color(0, 0, 0, 0.55))
	speedo.anchor_left = 1.0
	speedo.anchor_right = 1.0
	speedo.anchor_top = 1.0
	speedo.anchor_bottom = 1.0
	speedo.position = Vector2(-290, -210)
	var sv := UI.vbox(2)
	speedo.add_child(sv)
	car_name_l = UI.label("", 16, UI.DIM)
	sv.add_child(car_name_l)
	var sh := UI.hbox(10)
	sv.add_child(sh)
	speed_l = UI.label("0 KM/H", 36, Color.WHITE, true)
	sh.add_child(speed_l)
	gear_l = UI.label("1", 26, UI.ACCENT, true)
	sh.add_child(gear_l)
	car_hp = ColorRect.new()
	car_hp.custom_minimum_size = Vector2(216, 6)
	car_hp.color = Color(0.4, 0.85, 0.4)
	sv.add_child(car_hp)
	root.add_child(speedo)
	speedo.visible = false
	fps_l = UI.shadow_label("", 14, Color.WHITE, false)
	fps_l.position = Vector2(4, 4)
	root.add_child(fps_l)
	Game.notify.connect(notify)
	Game.money_changed.connect(_on_money)
	Game.xp_changed.connect(func(): _xp_show = 4.0)
	_on_money()

func _bar(parent: Control, pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.position = pos
	bg.size = sz
	parent.add_child(bg)
	var fg := ColorRect.new()
	fg.color = col
	fg.size = sz
	bg.add_child(fg)
	return fg

func _rlabel(parent: Control, text: String, sz: int, col: Color) -> Label:
	var l := UI.shadow_label(text, sz, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(l)
	return l

func _on_money() -> void:
	var c := Game.cash()
	cash_l.text = Catalog.fmt_money(c)
	bank_l.text = "Bank " + Catalog.fmt_money(Game.bank())
	if _last_cash >= 0 and c != _last_cash:
		var d := c - _last_cash
		_cash_delta_l.text = ("+" if d > 0 else "-") + Catalog.fmt_money(abs(d))
		_cash_delta_l.add_theme_color_override("font_color", UI.GREEN if d > 0 else UI.RED)
		_cash_delta_t = 3.0
	_last_cash = c

func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	var p := world.player
	health_bar.size.x = 162.0 * clamp(p.health / 100.0, 0.0, 1.0)
	health_bar.color = Color(0.35, 0.8, 0.35) if p.health > 30.0 else Color(0.95, 0.25, 0.25)
	armor_bar.size.x = 162.0 * clamp(p.armor / 100.0, 0.0, 1.0)
	stamina_bar.size.x = 330.0 * clamp(p.stamina / p.max_stamina(), 0.0, 1.0)
	stamina_bar.get_parent().visible = p.stamina < p.max_stamina() - 0.5
	clock_l.text = "%s  %s" % [world.sky.clock_text(), world.sky.weather_name()]
	weapon_l.text = "FISTS"
	stars.visible = false
	# xp bar
	var lvl := Game.level()
	var a := Catalog.xp_for_level(lvl)
	var b := Catalog.xp_for_level(lvl + 1)
	level_l.text = str(lvl)
	xp_fill.size.x = 350.0 * clamp(float(int(Game.data["xp"]) - a) / max(1.0, float(b - a)), 0.0, 1.0)
	_xp_show -= delta
	xp_box.modulate.a = lerp(xp_box.modulate.a, 1.0 if (_xp_show > 0.0 or Input.is_key_pressed(KEY_Z)) else 0.35, delta * 4.0)
	# cash delta fade
	_cash_delta_t -= delta
	_cash_delta_l.modulate.a = clamp(_cash_delta_t, 0.0, 1.0)
	# big message
	if _big_t > 0.0:
		_big_t -= delta
		big_box.modulate.a = clamp(_big_t * 2.0, 0.0, 1.0)
		if _big_t <= 0.0:
			big_box.visible = false
	_area_t -= delta
	area_l.modulate.a = clamp(_area_t, 0.0, 1.0)
	# speedometer
	var car := p.vehicle
	speedo.visible = car != null
	if car:
		speed_l.text = Game.speed_text(abs(car.speed()))
		gear_l.text = "R" if car.speed() < -0.5 else str(car.gear)
		car_name_l.text = world._car_label(car) + ("  (STOLEN)" if car.stolen else "")
		car_hp.custom_minimum_size.x = 216.0 * clamp(car.health / 1000.0, 0.0, 1.0)
		car_hp.color = Color(0.4, 0.85, 0.4) if car.health > 450 else (Color(0.95, 0.7, 0.2) if car.health > 150 else UI.RED)
	fps_l.text = ("%d FPS" % Engine.get_frames_per_second()) if Game.settings["show_fps"] else ""
	# feed cleanup
	for c in feed.get_children():
		var t: float = c.get_meta("t", 0.0) - delta
		c.set_meta("t", t)
		c.modulate.a = clamp(t, 0.0, 1.0)
		if t <= 0.0:
			c.queue_free()

func notify(text: String, kind: String = "info") -> void:
	if feed == null:
		return
	var col := UI.TEXT
	match kind:
		"error": col = Color(1.0, 0.55, 0.5)
		"xp": col = Color(0.5, 0.8, 1.0)
		"level": col = UI.ACCENT
		"save": col = UI.DIM
	var p := UI.panel(Vector2(0, 0), Color(0, 0, 0, 0.6))
	var l := UI.label(text, 17, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(380, 0)
	p.add_child(l)
	p.set_meta("t", 5.5 if kind != "xp" else 3.0)
	feed.add_child(p)
	while feed.get_child_count() > 6:
		feed.get_child(0).free()

func set_prompt(t: String) -> void:
	if prompt_l:
		prompt_l.text = t

func set_objective(t: String) -> void:
	if objective_l:
		objective_l.text = t

func set_timer(t: String) -> void:
	if timer_l:
		timer_l.text = t

func big_message(title: String, sub: String = "", col: Color = UI.ACCENT, dur: float = 3.0) -> void:
	big_title.text = title
	big_title.add_theme_color_override("font_color", col)
	big_sub.text = sub
	big_box.visible = true
	big_box.modulate.a = 1.0
	_big_t = dur

func toast_area(name_text: String) -> void:
	area_l.text = name_text
	_area_t = 4.0
