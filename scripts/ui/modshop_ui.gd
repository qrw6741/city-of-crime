class_name ModShopUI
extends MenuBase
## Torque Customs: repairs, paint, wheels and performance/visual upgrades with live 3D preview.

var car: Car = null
var uid := -1
var mode := "shop"
var v: Dictionary = {}       # owned vehicle record (empty for stolen cars)
var def: Dictionary
var preview_mods: Dictionary
var cat := ""
var pending := {}
var changed := false
var cat_box: VBoxContainer
var opt_box: VBoxContainer
var preview: Preview3D
var side: VBoxContainer

const CATS := ["Repair", "Respray", "Finish", "Wheels", "Wheel Colour", "Tires", "Engine", "Turbo", "Brakes", "Suspension", "Spoiler", "Body Kit", "Window Tint", "Plate"]
const KEYS := {"Tires": "tires", "Engine": "engine", "Turbo": "turbo", "Brakes": "brakes", "Suspension": "suspension", "Spoiler": "spoiler", "Body Kit": "bodykit", "Window Tint": "tint", "Wheels": "wheels"}

func _init(c: Car = null, m: String = "shop", owned_uid: int = -1) -> void:
	super._init()
	car = c
	mode = m
	uid = owned_uid
	if car and car.owned_uid > 0:
		uid = car.owned_uid

func build() -> void:
	if uid > 0:
		v = Game.get_owned(uid)
		def = Catalog.get_vehicle(v["model"])
		preview_mods = v["mods"].duplicate(true)
	elif car:
		def = car.def
		preview_mods = car.mods.duplicate(true)
	else:
		close()
		return
	var outer := UI.panel(Vector2(1460, 820))
	UI.centered(self, outer)
	var vb := UI.vbox(10)
	outer.add_child(vb)
	var top := UI.hbox()
	var hd := UI.header("Torque Customs", "%s  |  Cash %s  |  Bank %s" % [_name(), Catalog.fmt_money(Game.cash()), Catalog.fmt_money(Game.bank())])
	hd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hd)
	top.add_child(UI.button("Done [Esc]", close, 160))
	vb.add_child(top)
	var h := UI.hbox(14)
	vb.add_child(h)
	cat_box = UI.vbox(4)
	cat_box.custom_minimum_size = Vector2(190, 0)
	h.add_child(cat_box)
	for c in CATS:
		var cc: String = c
		var b := UI.button(cc, func(): _set_cat(cc), 190, 17)
		b.custom_minimum_size.y = 36
		if v.is_empty() and cc != "Repair":
			b.disabled = true
		cat_box.add_child(b)
	var sc := UI.scroll(Vector2(400, 700))
	h.add_child(sc)
	opt_box = UI.vbox(6)
	opt_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(opt_box)
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	preview = Preview3D.new(Vector2(780, 440))
	right.add_child(preview)
	side = UI.vbox(6)
	right.add_child(side)
	preview.set_car(def, preview_mods)
	_set_cat("Repair")

func _name() -> String:
	if not v.is_empty():
		return str(v["name"])
	return "%s %s (not your vehicle - repairs only)" % [def["brand"], def["name"]]

func _health() -> float:
	if car:
		return car.health
	return float(v.get("health", 1000.0))

func _set_cat(c: String) -> void:
	cat = c
	pending = {}
	preview_mods = (v["mods"] if not v.is_empty() else car.mods).duplicate(true)
	preview.set_car(def, preview_mods)
	UI.clear(opt_box)
	opt_box.add_child(UI.label(c.to_upper(), 20, UI.ACCENT, true))
	var price_base: int = def["price"]
	match c:
		"Repair":
			var dmg := 1000.0 - _health()
			var cost := int(dmg * Catalog.REPAIR_COST_PER_HP)
			opt_box.add_child(UI.label("Condition: %d%%" % int(_health() / 10.0), 18))
			if dmg < 1.0:
				opt_box.add_child(UI.label("This vehicle is in perfect condition.", 16, UI.DIM))
			else:
				opt_box.add_child(UI.button("Repair - %s" % Catalog.fmt_money(cost), func(): _repair(cost), 380))
		"Respray":
			for i in Catalog.PAINTS.size():
				var idx := i
				var col: Color = Catalog.PAINTS[i][1]
				var cur := col.to_html(false) == str(v["mods"]["paint"])
				_option_row(Catalog.PAINTS[i][0], Catalog.PAINT_PRICE, cur, func(): _preview("paint", col.to_html(false), Catalog.PAINT_PRICE, Catalog.PAINTS[idx][0]), col)
		"Finish":
			for i in Catalog.FINISHES.size():
				var idx2 := i
				_option_row(Catalog.FINISHES[i][0], 800 if i > 0 else 0, int(v["mods"]["finish"]) == i, func(): _preview("finish", idx2, 800 if idx2 > 0 else 0, Catalog.FINISHES[idx2][0]))
		"Wheel Colour":
			for i in Catalog.PAINTS.size():
				var col2: Color = Catalog.PAINTS[i][1]
				var nm: String = Catalog.PAINTS[i][0]
				_option_row(nm, Catalog.WHEEL_PAINT_PRICE, col2.to_html(false) == str(v["mods"]["wheel_color"]), func(): _preview("wheel_color", col2.to_html(false), Catalog.WHEEL_PAINT_PRICE, nm), col2)
		"Plate":
			var opts: Array = Catalog.MODS["plate_style"]["options"]
			for i in opts.size():
				var idx3 := i
				var pr := Catalog.mod_price("plate_style", i, price_base)
				_option_row(opts[i][0], pr, int(v["mods"]["plate_style"]) == i, func(): _preview("plate_style", idx3, pr, opts[idx3][0]))
			opt_box.add_child(UI.spacer(10))
			opt_box.add_child(UI.label("Custom plate text (%s):" % Catalog.fmt_money(Catalog.PLATE_TEXT_PRICE), 16, UI.DIM))
			var le := LineEdit.new()
			le.max_length = 8
			le.text = str(v["mods"]["plate"])
			le.custom_minimum_size = Vector2(380, 40)
			opt_box.add_child(le)
			opt_box.add_child(UI.button("Preview plate", func(): _preview("plate", le.text.to_upper().strip_edges(), Catalog.PLATE_TEXT_PRICE, "Plate \"%s\"" % le.text.to_upper()), 380))
		_:
			var key: String = KEYS[c]
			var opts2: Array = Catalog.MODS[key]["options"]
			for i in opts2.size():
				var idx4 := i
				var pr2 := Catalog.mod_price(key, i, price_base)
				_option_row(opts2[i][0], pr2, int(v["mods"][key]) == i, func(): _preview(key, idx4, pr2, opts2[idx4][0]))
	_update_side()

func _option_row(label: String, price: int, current: bool, cb: Callable, swatch = null) -> void:
	var h := UI.hbox(6)
	if swatch != null:
		h.add_child(UI.swatch(swatch, Vector2(24, 36)))
	var b := UI.button("%s%s" % [label, "   (installed)" if current else ""], cb, 250, 16)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if current:
		b.add_theme_color_override("font_color", UI.GREEN)
	h.add_child(b)
	h.add_child(UI.label(Catalog.fmt_money(price) if price > 0 else "Free", 16, UI.DIM))
	opt_box.add_child(h)

func _preview(key: String, value, price: int, label: String) -> void:
	preview_mods = v["mods"].duplicate(true)
	preview_mods[key] = value
	preview.set_car(def, preview_mods)
	if str(v["mods"][key]) == str(value):
		pending = {}
	else:
		pending = {"key": key, "value": value, "price": price, "label": label}
	_update_side()

func _update_side() -> void:
	UI.clear(side)
	if v.is_empty():
		side.add_child(UI.label("Stolen or borrowed vehicles can only be repaired here.", 16, UI.DIM))
		return
	var tmp := Car.new()
	tmp.def = def
	tmp.mods = preview_mods
	tmp.mass = def["mass"]
	tmp.spec = CarModel.spec(def["body"])
	tmp.is_bike = tmp.spec.get("two", false)
	tmp._compute_stats()
	var perf := tmp.performance()
	tmp.mods = v["mods"]
	tmp._compute_stats()
	var base := tmp.performance()
	tmp.free()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	for k in ["speed", "accel", "braking", "handling"]:
		grid.add_child(UI.label(k.capitalize(), 16, UI.DIM))
		grid.add_child(UI.bar(perf[k], UI.GREEN if perf[k] > base[k] + 0.001 else (UI.RED if perf[k] < base[k] - 0.001 else UI.ACCENT), 300, 10))
		var diff: float = (perf[k] - base[k]) * 100.0
		grid.add_child(UI.label(("%+.0f" % diff) if abs(diff) > 0.5 else "", 14, UI.GREEN if diff > 0 else UI.RED))
	side.add_child(grid)
	if not pending.is_empty():
		var row := UI.hbox()
		row.add_child(UI.label("Selected: %s" % pending["label"], 18, Color.WHITE, true))
		row.add_child(UI.hfill())
		row.add_child(UI.button("Purchase - %s" % Catalog.fmt_money(pending["price"]), _buy, 300, 19))
		side.add_child(row)

func _buy() -> void:
	if pending.is_empty():
		return
	if not Game.spend(int(pending["price"]), "Mod: %s (%s)" % [pending["label"], v["name"]]):
		return
	v["mods"][pending["key"]] = pending["value"]
	changed = true
	Game.add_xp(20, "Vehicle modified")
	Game.save_game()
	_set_cat(cat)

func _repair(cost: int) -> void:
	if not Game.spend(cost, "Vehicle repair"):
		return
	if car:
		car.repair()
	if not v.is_empty():
		v["health"] = 1000.0
	Game.save_game()
	_set_cat("Repair")

func close() -> void:
	if changed and car and is_instance_valid(car) and world and car.owned_uid > 0:
		var xf := car.global_transform
		var w = world
		var id := uid
		super.close()
		var nc: Car = w.retrieve_owned(id, xf)
		if nc:
			w.player.enter_vehicle(nc)
		return
	super.close()
