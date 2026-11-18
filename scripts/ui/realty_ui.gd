class_name RealtyUI
extends MenuBase
## Calloway Realty website: every property, with remote purchase (bank funds) and GPS.

var body: VBoxContainer

func build() -> void:
	var outer := UI.panel(Vector2(1100, 780))
	UI.centered(self, outer)
	var v := UI.vbox(8)
	outer.add_child(v)
	var top := UI.hbox()
	var hd := UI.header("Calloway Realty", "Online purchases are paid from your bank account. Bank: %s" % Catalog.fmt_money(Game.bank()))
	hd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hd)
	top.add_child(UI.button("Close [Esc]", close, 160))
	v.add_child(top)
	var sc := UI.scroll(Vector2(1050, 660))
	v.add_child(sc)
	body = UI.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	_refresh()

func _refresh() -> void:
	UI.clear(body)
	var ids := Catalog.PROPERTIES.keys()
	ids.sort_custom(func(a, b): return Catalog.PROPERTIES[a]["price"] < Catalog.PROPERTIES[b]["price"])
	for pid in ids:
		var p: Dictionary = Catalog.PROPERTIES[pid]
		var id: String = pid
		var card := UI.panel(Vector2(1020, 0), UI.PANEL_LIGHT)
		var h := UI.hbox(14)
		card.add_child(h)
		var info := UI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b: Vector2i = p["block"]
		info.add_child(UI.label(p["name"], 20, Color.WHITE, true))
		info.add_child(UI.label("%s  |  %s  |  Garage: %d vehicles  |  Level %d" % [Catalog.TIER_NAMES[p["tier"]], CityLayout.DISTRICTS[CityLayout.district(b.x, b.y)]["name"], p["garage"], p["level"]], 15, UI.DIM))
		h.add_child(info)
		h.add_child(UI.label(Catalog.fmt_money(p["price"]) if p["price"] > 0 else "Free", 22, UI.GREEN, true))
		if Game.owns_property(id):
			h.add_child(UI.label("OWNED", 18, UI.ACCENT, true))
		elif Game.level() < int(p["level"]):
			h.add_child(UI.label("Level %d" % p["level"], 16, UI.RED))
		else:
			h.add_child(UI.button("Buy", func(): _buy(id), 90))
		h.add_child(UI.button("GPS", func():
			var w = get_tree().get_first_node_in_group("world")
			if w:
				w.set_waypoint(w.city.property_door(id))
				Sfx.play("click"), 80))
		body.add_child(card)

func _buy(id: String) -> void:
	var p: Dictionary = Catalog.PROPERTIES[id]
	if Game.bank() < int(p["price"]):
		Game.notify.emit("Insufficient bank funds. Deposit cash at an ATM first.", "error")
		Sfx.play("error")
		return
	# move cash out of the way so buy_property() charges the bank
	var cash := Game.cash()
	Game.data["cash"] = 0
	var ok := Game.buy_property(id)
	Game.data["cash"] = int(Game.data["cash"]) + cash
	Game.money_changed.emit()
	if ok:
		Game.notify.emit("You bought %s!" % p["name"], "level")
	_refresh()
