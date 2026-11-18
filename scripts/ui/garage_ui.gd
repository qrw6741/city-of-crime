class_name GarageUI
extends MenuBase
## Vehicle collection: thumbnails, rename, customise, move, retrieve/deliver and sell.

var filter := ""
var grid: GridContainer
var detail: VBoxContainer
var selected := -1
var tabs: HBoxContainer

func _init(property_filter: String = "") -> void:
	super._init()
	filter = property_filter

func build() -> void:
	var outer := UI.panel(Vector2(1400, 800))
	UI.centered(self, outer)
	var vb := UI.vbox(10)
	outer.add_child(vb)
	var top := UI.hbox()
	var hd := UI.header("Vehicle Collection", "%d vehicles  |  %d garage spaces" % [Game.data["vehicles"].size(), Game.garage_capacity()])
	hd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hd)
	top.add_child(UI.button("Close [Esc]", close, 160))
	vb.add_child(top)
	tabs = UI.hbox(6)
	vb.add_child(tabs)
	var h := UI.hbox(14)
	vb.add_child(h)
	var sc := UI.scroll(Vector2(860, 640))
	h.add_child(sc)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	detail = UI.vbox(8)
	detail.custom_minimum_size = Vector2(460, 0)
	h.add_child(detail)
	_refresh()

func _wd():
	if world:
		return world
	var w := get_tree().get_first_node_in_group("world")
	return w

func _refresh() -> void:
	UI.clear(tabs)
	tabs.add_child(UI.button("All", func():
		filter = ""
		_refresh(), 0, 15))
	for pid in Game.data["properties"]:
		if Game.owns_property(pid):
			var p: String = pid
			var b := UI.button("%s (%d/%d)" % [Catalog.PROPERTIES[p]["name"], Game.property_vehicle_count(p), Catalog.PROPERTIES[p]["garage"]], func():
				filter = p
				_refresh(), 0, 15)
			if p == filter:
				b.add_theme_color_override("font_color", UI.ACCENT)
			tabs.add_child(b)
	UI.clear(grid)
	var vs := []
	for v in Game.data["vehicles"]:
		if filter == "" or v["garage"] == filter:
			vs.append(v)
	if vs.is_empty():
		grid.add_child(UI.label("No vehicles here yet. Buy one at Apex Motors (in person or via the phone's Internet app).", 17, UI.DIM))
	var w = _wd()
	for v in vs:
		var vv: Dictionary = v
		var card := Button.new()
		card.custom_minimum_size = Vector2(270, 200)
		card.add_theme_stylebox_override("normal", UI.box(UI.PANEL_LIGHT, 8, UI.ACCENT if int(vv["uid"]) == selected else Color(1, 1, 1, 0.08)))
		card.add_theme_stylebox_override("hover", UI.box(UI.PANEL_LIGHT.lightened(0.05), 8, UI.ACCENT))
		card.pressed.connect(func():
			Sfx.play("click")
			selected = int(vv["uid"])
			_refresh())
		var cv := UI.vbox(2)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.position = Vector2(8, 6)
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(254, 148)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(tex)
		if w and w.thumbs:
			w.thumbs.request(vv, tex.set_texture)
		var nl := UI.label(str(vv["name"]), 16, Color.WHITE, true)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(nl)
		var sub := UI.label(Catalog.PROPERTIES[vv["garage"]]["name"], 13, UI.DIM)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(sub)
		card.add_child(cv)
		grid.add_child(card)
	_detail()

func _detail() -> void:
	UI.clear(detail)
	var v := Game.get_owned(selected)
	if v.is_empty():
		detail.add_child(UI.label("Select a vehicle.", 18, UI.DIM))
		return
	var def := Catalog.get_vehicle(v["model"])
	detail.add_child(UI.label(str(v["name"]), 26, Color.WHITE, true))
	detail.add_child(UI.label("%s %s  |  %s  |  Plate %s" % [def["brand"], def["name"], def["cat"], v["mods"]["plate"]], 15, UI.DIM))
	detail.add_child(UI.label("Stored at: %s" % Catalog.PROPERTIES[v["garage"]]["name"], 16))
	detail.add_child(UI.label("Condition: %d%%" % int(float(v.get("health", 1000.0)) / 10.0), 16))
	var mods_txt := []
	for k in ["engine", "turbo", "brakes", "suspension", "tires", "spoiler", "bodykit", "tint", "wheels"]:
		if int(v["mods"][k]) > 0:
			mods_txt.append(Catalog.MODS[k]["options"][int(v["mods"][k])][0])
	var ml := UI.label("Mods: " + (", ".join(mods_txt) if not mods_txt.is_empty() else "stock"), 15, UI.DIM)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.custom_minimum_size.x = 440
	detail.add_child(ml)
	var rn := UI.hbox()
	var le := LineEdit.new()
	le.text = str(v["name"])
	le.max_length = 24
	le.custom_minimum_size = Vector2(300, 40)
	rn.add_child(le)
	rn.add_child(UI.button("Rename", func():
		var n := le.text.strip_edges()
		if n != "":
			v["name"] = n
			Game.save_game()
			_refresh(), 130))
	detail.add_child(rn)
	var w = _wd()
	var here := false
	if w and w.player:
		here = w.player.interior == v["garage"] or (w.player.interior == "" and w.player.global_position.distance_to(w.city.property_door(v["garage"])) < 15.0)
	if here:
		detail.add_child(UI.button("Drive it out", func():
			var ww = _wd()
			var uid := selected
			var g: String = v["garage"]
			_close_all()
			ww.take_out_vehicle(uid, g), 440))
	else:
		detail.add_child(UI.button("Mechanic delivery to your location ($200)", func():
			var ww = _wd()
			if ww and Game.spend(200, "Mechanic delivery"):
				var uid := selected
				_close_all()
				ww.deliver_vehicle(uid), 440))
	detail.add_child(UI.button("Customise", func():
		var m := ModShopUI.new(null, "garage", selected)
		m.closed.connect(_refresh)
		overlay(m), 440))
	var move_row := HFlowContainer.new()
	for pid in Game.data["properties"]:
		if Game.owns_property(pid) and pid != v["garage"] and Game.property_vehicle_count(pid) < int(Catalog.PROPERTIES[pid]["garage"]):
			var p: String = pid
			move_row.add_child(UI.button("Move to %s" % Catalog.PROPERTIES[p]["name"], func():
				v["garage"] = p
				Game.save_game()
				_refresh(), 0, 14))
	if move_row.get_child_count() > 0:
		detail.add_child(move_row)
	var sell := Catalog.sell_price(v["model"])
	detail.add_child(UI.button("Sell for %s" % Catalog.fmt_money(sell), func():
		var d := DialogUI.new("Sell %s?" % v["name"], "You'll receive %s (paid into your bank). Modifications are not refunded." % Catalog.fmt_money(sell), [["Sell vehicle", func():
			var ww = _wd()
			var uid := int(v["uid"])
			if ww and ww.owned_cars.has(uid) and is_instance_valid(ww.owned_cars[uid]):
				if ww.player.vehicle == ww.owned_cars[uid]:
					ww.player.exit_vehicle()
				ww.owned_cars[uid].queue_free()
				ww.owned_cars.erase(uid)
			Game.remove_vehicle(uid)
			Game.earn(sell, "Sold vehicle", true)
			Game.save_game()
			selected = -1
			d_close_refresh()]])
		overlay(d), 440))

func d_close_refresh() -> void:
	for c in get_children():
		if c is DialogUI:
			c.queue_free()
	_refresh()

func _close_all() -> void:
	# Closes this menu and any menu that opened it.
	var w = _wd()
	if w and w.menu:
		w.close_menu()
	else:
		queue_free()
