class_name DealershipUI
extends MenuBase
## Apex Motors: browse by category, preview in 3D, compare specs, choose a colour and buy.

var online := false     # bought through the phone's internet (bank funds only)
var cat := "Sedan"
var selected := ""
var paint_idx := -1
var list_box: VBoxContainer
var preview: Preview3D
var info: VBoxContainer
var cat_box: VBoxContainer

func _init(is_online: bool = false) -> void:
	super._init()
	online = is_online

func build() -> void:
	var outer := UI.panel(Vector2(1460, 820))
	UI.centered(self, outer)
	var v := UI.vbox(10)
	outer.add_child(v)
	var top := UI.hbox()
	top.add_child(UI.header("Apex Motors" + (" Online" if online else ""), "Premium and everyday vehicles. %s  |  Cash %s  |  Bank %s  |  Garage space: %d free" % ["Online purchases are paid from your bank account." if online else "Payment: cash first, then bank.", Catalog.fmt_money(Game.cash()), Catalog.fmt_money(Game.bank()), Game.garage_capacity() - Game.data["vehicles"].size()]))
	top.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(UI.button("Close [Esc]", close, 160))
	v.add_child(top)
	var h := UI.hbox(14)
	v.add_child(h)
	cat_box = UI.vbox(6)
	cat_box.custom_minimum_size = Vector2(180, 0)
	h.add_child(cat_box)
	for c in Catalog.CATEGORIES:
		var cc: String = c
		var count := 0
		for id in Catalog.VEHICLES:
			if Catalog.VEHICLES[id]["cat"] == cc:
				count += 1
		cat_box.add_child(UI.button("%s (%d)" % [cc, count], func(): _set_cat(cc), 180))
	var sc := UI.scroll(Vector2(400, 700))
	h.add_child(sc)
	list_box = UI.vbox(6)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list_box)
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	preview = Preview3D.new(Vector2(780, 400))
	right.add_child(preview)
	info = UI.vbox(6)
	right.add_child(info)
	_set_cat("Sedan")

func _set_cat(c: String) -> void:
	cat = c
	UI.clear(list_box)
	var first := ""
	var ids := []
	for id in Catalog.VEHICLES:
		if Catalog.VEHICLES[id]["cat"] == c:
			ids.append(id)
	ids.sort_custom(func(a, b): return Catalog.VEHICLES[a]["price"] < Catalog.VEHICLES[b]["price"])
	for id in ids:
		var d: Dictionary = Catalog.VEHICLES[id]
		var locked: bool = Game.level() < int(d["level"])
		var txt := "%s %s\n%s%s" % [d["brand"], d["name"], Catalog.fmt_money(d["price"]), ("   LOCKED - Level %d" % d["level"]) if locked else ""]
		var vid: String = id
		var b := UI.button(txt, func(): _select(vid), 380, 17)
		b.custom_minimum_size.y = 62
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if locked:
			b.add_theme_color_override("font_color", UI.DIM)
		list_box.add_child(b)
		if first == "":
			first = id
	if first != "":
		_select(first)

func _select(id: String) -> void:
	selected = id
	paint_idx = -1
	_refresh()

func _mods() -> Dictionary:
	var def := Catalog.get_vehicle(selected)
	var m := Catalog.default_mods(def)
	if paint_idx >= 0:
		m["paint"] = (Catalog.PAINTS[paint_idx][1] as Color).to_html(false)
	return m

func _refresh() -> void:
	var def := Catalog.get_vehicle(selected)
	preview.set_car(def, _mods())
	UI.clear(info)
	var title := UI.hbox()
	title.add_child(UI.label("%s %s" % [def["brand"], def["name"]], 28, Color.WHITE, true))
	title.add_child(UI.hfill())
	title.add_child(UI.label(Catalog.fmt_money(def["price"]), 28, UI.GREEN, true))
	info.add_child(title)
	# specs
	var tmp := Car.new()
	tmp.def = def
	tmp.mods = Catalog.default_mods(def)
	tmp.mass = def["mass"]
	tmp.spec = CarModel.spec(def["body"])
	tmp.is_bike = tmp.spec.get("two", false)
	tmp._compute_stats()
	var perf := tmp.performance()
	tmp.free()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	for k in ["speed", "accel", "braking", "handling"]:
		grid.add_child(UI.label(k.capitalize(), 16, UI.DIM))
		grid.add_child(UI.bar(perf[k], UI.ACCENT, 220, 10))
	info.add_child(grid)
	info.add_child(UI.label("Top speed %s   |   0-100 km/h %.1fs   |   %s   |   %d kg   |   %s" % [Game.speed_text(float(def["top"]) / 3.6), def["accel"], def["drive"], def["mass"], def["cat"]], 16, UI.TEXT))
	# colours
	var colors := HFlowContainer.new()
	colors.add_theme_constant_override("h_separation", 4)
	colors.add_child(UI.label("Colour:", 16, UI.DIM))
	var fac := Button.new()
	fac.text = "Factory"
	fac.pressed.connect(func():
		paint_idx = -1
		_refresh())
	colors.add_child(fac)
	for i in Catalog.PAINTS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 30)
		b.tooltip_text = Catalog.PAINTS[i][0]
		var sb := UI.box(Catalog.PAINTS[i][1], 4, Color.WHITE if i == paint_idx else Color(0, 0, 0, 0.5))
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", UI.box(Catalog.PAINTS[i][1], 4, UI.ACCENT))
		var idx := i
		b.pressed.connect(func():
			Sfx.play("click")
			paint_idx = idx
			_refresh())
		colors.add_child(b)
	info.add_child(colors)
	# buy
	var row := UI.hbox()
	var locked: bool = Game.level() < int(def["level"])
	var owned := 0
	for v in Game.data["vehicles"]:
		if v["model"] == selected:
			owned += 1
	row.add_child(UI.label(("Owned: %d   " % owned) if owned > 0 else "", 16, UI.DIM))
	row.add_child(UI.hfill())
	if locked:
		row.add_child(UI.label("Reach level %d to unlock this vehicle." % def["level"], 18, UI.RED))
	else:
		var buy := UI.button("Buy for %s" % Catalog.fmt_money(def["price"]), _buy, 300, 20)
		row.add_child(buy)
	info.add_child(row)

func _buy() -> void:
	var def := Catalog.get_vehicle(selected)
	if Game.free_garage() == "":
		Game.notify.emit("No free garage space. Buy a property with a bigger garage or sell a vehicle.", "error")
		Sfx.play("error")
		_flash("No free garage space - buy a property or sell a vehicle first.")
		return
	var price: int = def["price"]
	var ok := Game.spend_bank(price, "Vehicle: %s %s" % [def["brand"], def["name"]]) if online else Game.spend(price, "Vehicle: %s %s" % [def["brand"], def["name"]])
	if not ok:
		_flash("You can't afford this vehicle.")
		return
	var v := Game.add_vehicle(selected, _mods())
	Game.add_xp(100 + price / 5000, "New vehicle")
	Game.save_game()
	var pname: String = Catalog.PROPERTIES[v["garage"]]["name"]
	_flash("Purchased! Your %s was delivered to %s." % [v["name"], pname], UI.GREEN)
	_refresh()

func _flash(t: String, col: Color = UI.RED) -> void:
	var l := UI.label(t, 18, col, true)
	info.add_child(l)
	get_tree().create_timer(4.0).timeout.connect(l.queue_free)
