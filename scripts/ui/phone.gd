class_name Phone
extends Control
## In-game smartphone with working apps.

var world: World
var screen: VBoxContainer
var status_l: Label
var app := "home"
var history: Array = []

func _init() -> void:
	theme = UI.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	position = Vector2(-410, -720)
	size = Vector2(380, 690)

func _ready() -> void:
	var body := Panel.new()
	body.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.03, 0.04), 34, Color(0.25, 0.25, 0.28), 4))
	body.size = size
	add_child(body)
	var scr := Panel.new()
	scr.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.1, 0.16), 18))
	scr.position = Vector2(16, 40)
	scr.size = Vector2(size.x - 32, size.y - 100)
	add_child(scr)
	status_l = UI.label("", 14, UI.DIM)
	status_l.position = Vector2(34, 12)
	add_child(status_l)
	var sc := ScrollContainer.new()
	sc.position = Vector2(26, 52)
	sc.size = Vector2(size.x - 52, size.y - 124)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	screen = UI.vbox(8)
	screen.custom_minimum_size = Vector2(size.x - 64, 0)
	sc.add_child(screen)
	var home := UI.button("●", func(): _open("home"), 60, 20)
	home.position = Vector2(size.x / 2 - 30, size.y - 52)
	add_child(home)
	var back := UI.button("‹ Back", _back, 90, 15)
	back.position = Vector2(30, size.y - 52)
	add_child(back)
	var close_b := UI.button("Close", func(): world.close_phone(), 90, 15)
	close_b.position = Vector2(size.x - 120, size.y - 52)
	add_child(close_b)
	_open("home")

func _process(_d: float) -> void:
	if world and world.sky:
		status_l.text = "%s     %s     Bank %s" % [world.sky.clock_text(), Catalog.fmt_money(Game.cash()), Catalog.fmt_money(Game.bank())]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phone_back"):
		get_viewport().set_input_as_handled()
		_back()

func _back() -> void:
	Sfx.play("back")
	if history.is_empty():
		world.close_phone()
		return
	var a: String = history.pop_back()
	app = a
	_render()

func _open(a: String) -> void:
	Sfx.play("click")
	if a == "home":
		history.clear()
	elif app != a:
		history.append(app)
	app = a
	_render()

func _title(t: String) -> void:
	screen.add_child(UI.label(t, 24, UI.ACCENT, true))

func _btn(t: String, cb: Callable, size_px: int = 16) -> Button:
	var b := UI.button(t, cb, 0, size_px)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(b)
	return b

func _text(t: String, col: Color = UI.TEXT, sz: int = 15) -> void:
	var l := UI.label(t, sz, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = size.x - 70
	screen.add_child(l)

func _render() -> void:
	UI.clear(screen)
	match app:
		"home": _home()
		"contacts": _contacts()
		"mechanic": _mechanic()
		"internet": _internet()
		"bank": _bank()
		"properties": _properties()
		"vehicles": _vehicles()
		"jobs": _jobs()

func _home() -> void:
	_title("Calloway OS")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	screen.add_child(grid)
	var apps := [["Contacts", "contacts", Color(0.3, 0.75, 0.4)], ["Map", "map", Color(0.3, 0.6, 1.0)], ["Internet", "internet", Color(0.9, 0.5, 0.2)],
		["Banking", "bank", Color(0.2, 0.7, 0.5)], ["Properties", "properties", Color(0.3, 0.85, 1.0)], ["Vehicles", "vehicles", Color(0.95, 0.35, 0.35)],
		["Jobs", "jobs", Color(1.0, 0.7, 0.15)], ["Stats", "stats", Color(0.6, 0.5, 0.95)], ["Save", "save", Color(0.7, 0.7, 0.75)]]
	for a in apps:
		var id: String = a[1]
		var b := Button.new()
		b.text = a[0]
		b.custom_minimum_size = Vector2(98, 92)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_stylebox_override("normal", UI.box((a[2] as Color).darkened(0.35), 16))
		b.add_theme_stylebox_override("hover", UI.box(a[2], 16))
		b.pressed.connect(func(): _app_pressed(id))
		grid.add_child(b)

func _app_pressed(id: String) -> void:
	match id:
		"map":
			var w := world
			w.close_phone()
			w.open_menu(MapView.new())
		"stats":
			var w2 := world
			w2.close_phone()
			w2.open_menu(StatsUI.new())
		"save":
			if Game.save_game():
				world.hud.notify("Game saved to slot %d." % (Game.slot + 1), "save")
				Sfx.play("buy")
		_:
			_open(id)

func _contacts() -> void:
	_title("Contacts")
	_btn("Lou - Mechanic\nDelivers your vehicles ($200)", func(): _open("mechanic"))
	_btn("QuickShip Dispatch\nDelivery work - sets GPS to the depot", func():
		world.set_waypoint(world.city.poi_pos("quickship"))
		world.hud.notify("Dispatch: \"Come by the depot in Ironside, we've got loads waiting.\"", "info"))
	_btn("Rusty - Salvage\nBuys stolen cars, no questions asked", func():
		world.set_waypoint(world.city.poi_pos("rustys"))
		var cd := float(Game.data.get("chop_cooldown", 0.0)) - Time.get_unix_time_from_system()
		world.hud.notify("Rusty: \"%s\"" % ("Bring me something shiny." if cd <= 0 else "Lay low for %ds." % int(cd)), "info"))
	_btn("Meridian Bank", func(): _open("bank"))
	_btn("Apex Motors", func():
		world.set_waypoint(world.city.poi_pos("apex_motors"))
		world.hud.notify("GPS set to Apex Motors.", "info"))

func _mechanic() -> void:
	_title("Lou - Mechanic")
	if Game.data["vehicles"].is_empty():
		_text("\"You don't own anything I can bring you, pal.\"", UI.DIM)
		return
	_text("Pick a vehicle to deliver to the nearest road ($200).", UI.DIM)
	for v in Game.data["vehicles"]:
		var uid := int(v["uid"])
		_btn("%s\n%s" % [v["name"], Catalog.PROPERTIES[v["garage"]]["name"]], func():
			if Game.spend(200, "Mechanic delivery"):
				if not world.deliver_vehicle(uid):
					Game.earn(200, "Mechanic refund")
				world.close_phone())

func _internet() -> void:
	_title("Internet")
	_btn("apexmotors.cc\nBuy vehicles online", func():
		var w := world
		w.close_phone()
		w.open_menu(DealershipUI.new(true)))
	_btn("callowayrealty.cc\nBrowse & buy property", func():
		var w := world
		w.close_phone()
		w.open_menu(RealtyUI.new()))
	_btn("meridianbank.cc\nOnline banking", func(): _open("bank"))

func _bank() -> void:
	_title("Meridian Bank")
	_text("Cash: %s" % Catalog.fmt_money(Game.cash()), UI.GREEN, 20)
	_text("Bank: %s" % Catalog.fmt_money(Game.bank()), Color(0.7, 0.9, 1.0), 20)
	_btn("Deposit all cash", func():
		Game.deposit(Game.cash())
		_render())
	_text("Recent activity", UI.DIM)
	var n := 0
	for t in Game.data["transactions"]:
		if n >= 8:
			break
		var a := int(t["a"])
		_text("%s  %s" % [str(t["r"]), (Catalog.fmt_money(a) if a != 0 else "transfer")], UI.GREEN if a > 0 else (UI.RED if a < 0 else UI.DIM), 14)
		n += 1

func _properties() -> void:
	_title("Properties")
	for pid in Game.data["properties"]:
		if not Game.owns_property(pid):
			continue
		var id: String = pid
		var p: Dictionary = Catalog.PROPERTIES[id]
		_text("%s%s\nGarage %d/%d" % [p["name"], "  (spawn)" if Game.data["spawn_property"] == id else "", Game.property_vehicle_count(id), p["garage"]], Color.WHITE)
		var h := UI.hbox()
		h.add_child(UI.button("GPS", func():
			world.set_waypoint(world.city.property_door(id))
			world.hud.notify("GPS set to %s." % p["name"], "info"), 90, 14))
		if Game.data["spawn_property"] != id:
			h.add_child(UI.button("Set spawn", func():
				Game.data["spawn_property"] = id
				Game.save_game()
				_render(), 120, 14))
		screen.add_child(h)
	_btn("Browse properties for sale", func():
		var w := world
		w.close_phone()
		w.open_menu(RealtyUI.new()))

func _vehicles() -> void:
	_title("Vehicles")
	if Game.data["vehicles"].is_empty():
		_text("You don't own any vehicles yet. Visit Apex Motors or buy online.", UI.DIM)
	for v in Game.data["vehicles"]:
		var uid := int(v["uid"])
		var out: bool = world.owned_cars.has(uid) and is_instance_valid(world.owned_cars[uid])
		_text("%s\n%s%s" % [v["name"], Catalog.PROPERTIES[v["garage"]]["name"], "  (out)" if out else ""], Color.WHITE)
		var h := UI.hbox()
		if out:
			h.add_child(UI.button("GPS", func():
				world.set_waypoint(world.owned_cars[uid].global_position), 80, 14))
		h.add_child(UI.button("Deliver ($200)", func():
			if Game.spend(200, "Mechanic delivery"):
				world.deliver_vehicle(uid)
				world.close_phone(), 150, 14))
		screen.add_child(h)
	_btn("Manage collection", func():
		var w := world
		w.close_phone()
		w.open_menu(GarageUI.new()))

func _jobs() -> void:
	_title("Jobs")
	if world.jobs.active != "":
		_text("Active: %s  (press X to cancel)" % world.jobs.active.capitalize(), UI.ACCENT)
	for j in world.jobs.job_list():
		var jj: Dictionary = j
		_btn("%s\n%s" % [jj["name"], jj["desc"]], func():
			world.set_waypoint(jj["pos"])
			world.hud.notify("GPS set: %s" % jj["name"], "info"))
