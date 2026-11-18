class_name StatsUI
extends MenuBase
## Character statistics and career totals for the loaded (or given) save.

var d: Dictionary

func _init(save_data: Dictionary = {}) -> void:
	super._init()
	d = save_data

func build() -> void:
	if d.is_empty():
		d = Game.data
	var v := center_panel(Vector2(760, 0))
	v.add_child(UI.header("Statistics", str(d.get("name", ""))))
	var lvl := int(d.get("level", 1))
	var xp := int(d.get("xp", 0))
	v.add_child(UI.label("Level %d   |   %d RP   (next level at %d RP)" % [lvl, xp, Catalog.xp_for_level(lvl + 1)], 19, UI.ACCENT, true))
	v.add_child(UI.label("Cash %s   |   Bank %s   |   Net worth %s" % [Catalog.fmt_money(int(d.get("cash", 0))), Catalog.fmt_money(int(d.get("bank", 0))), Catalog.fmt_money(_net_worth())], 17, UI.GREEN))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	var st: Dictionary = d.get("stats", {})
	for k in ["reputation", "criminal", "driving", "shooting", "stamina", "strength"]:
		var label: String = {"criminal": "Criminal experience", "driving": "Driving skill", "shooting": "Shooting skill"}.get(k, k.capitalize())
		grid.add_child(UI.label(label, 17))
		grid.add_child(UI.bar(float(st.get(k, 0)) / 100.0, UI.BLUE, 300, 12))
		grid.add_child(UI.label("%d" % int(float(st.get(k, 0))), 16, UI.DIM))
	v.add_child(grid)
	var t: Dictionary = d.get("totals", {})
	var j: Dictionary = d.get("jobs", {})
	var owned_props := 0
	for pid in d.get("properties", {}):
		if d["properties"][pid].get("owned", false):
			owned_props += 1
	var lines := [
		"Play time: %s" % Game.fmt_time(float(d.get("playtime", 0.0))),
		"Money earned: %s   |   spent: %s" % [Catalog.fmt_money(int(t.get("earned", 0))), Catalog.fmt_money(int(t.get("spent", 0)))],
		"Vehicles owned: %d   |   Properties owned: %d" % [(d.get("vehicles", []) as Array).size(), owned_props],
		"Distance driven: %.1f km   |   Top speed: %s" % [float(t.get("distance_km", 0.0)), Game.speed_text(float(t.get("max_speed", 0.0)))],
		"Deliveries: %d   |   Gold race medals: %d   |   Cars chopped: %d" % [int(j.get("deliveries", 0)), int(j.get("races_won", 0)), int(j.get("cars_chopped", 0))],
		"Vehicles stolen: %d   |   Hospital visits: %d" % [int(t.get("stolen", 0)), int(t.get("deaths", 0))],
	]
	for l in lines:
		v.add_child(UI.label(l, 16))
	v.add_child(UI.button("Back [Esc]", close, 700))

func _net_worth() -> int:
	var n := int(d.get("cash", 0)) + int(d.get("bank", 0))
	for veh in d.get("vehicles", []):
		n += Catalog.sell_price(veh["model"])
	for pid in d.get("properties", {}):
		if d["properties"][pid].get("owned", false):
			n += int(Catalog.PROPERTIES[pid]["price"] * 0.5)
	return n
