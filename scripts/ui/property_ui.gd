class_name PropertyUI
extends MenuBase
## Property purchase / management and interior designer.

var pid := ""
var inside := false
var body: VBoxContainer

const FEATURES := {
	"motel": ["Single room with bed", "1 parking space", "Free starter home"],
	"cheap": ["Studio with kitchen, bedroom and bathroom", "Small garage: 2 vehicles", "Save point & spawn location"],
	"medium": ["Modern open-plan interior", "Floor-to-ceiling city views", "Medium garage: 6 vehicles", "Dining area & kitchen island"],
	"luxury": ["Penthouse-level views", "Bar, pool table and premium furniture", "Large garage: 10 vehicles", "Private parking"],
	"mansion": ["Grand hall with chandelier", "Terrace with swimming pool & gardens", "Private security post", "Luxury garage: 20 vehicles"],
}

func _init(property_id: String = "", from_inside: bool = false) -> void:
	super._init()
	pid = property_id
	inside = from_inside

func build() -> void:
	body = center_panel(Vector2(780, 0))
	_refresh()

func _refresh() -> void:
	UI.clear(body)
	var p: Dictionary = Catalog.PROPERTIES[pid]
	var owned := Game.owns_property(pid)
	var b: Vector2i = p["block"]
	body.add_child(UI.header(p["name"], "%s  |  %s" % [Catalog.TIER_NAMES[p["tier"]], CityLayout.DISTRICTS[CityLayout.district(b.x, b.y)]["name"]]))
	if inside:
		_designer()
		return
	for f in FEATURES[p["tier"]]:
		body.add_child(UI.label("•  " + f, 17))
	body.add_child(UI.spacer(6))
	if owned:
		body.add_child(UI.label("You own this property.  Garage: %d / %d vehicles%s" % [Game.property_vehicle_count(pid), p["garage"], "   |   SPAWN LOCATION" if Game.data["spawn_property"] == pid else ""], 17, UI.GREEN))
		body.add_child(UI.button("Enter apartment", func(): _enter("apartment"), 720))
		body.add_child(UI.button("Enter garage", func(): _enter("garage"), 720))
		body.add_child(UI.button("Manage vehicles", func(): overlay(GarageUI.new(pid)), 720))
		if Game.data["spawn_property"] != pid:
			body.add_child(UI.button("Set as spawn location", _set_spawn, 720))
		if pid != "sunrise_motel":
			body.add_child(UI.button("Sell property (%s)" % Catalog.fmt_money(int(p["price"] * 0.5)), _sell_confirm, 720))
	else:
		var row := UI.hbox()
		row.add_child(UI.label("Price", 18, UI.DIM))
		row.add_child(UI.hfill())
		row.add_child(UI.label(Catalog.fmt_money(p["price"]), 30, UI.GREEN, true))
		body.add_child(row)
		if Game.level() < int(p["level"]):
			body.add_child(UI.label("Requires level %d (you are level %d)." % [p["level"], Game.level()], 18, UI.RED))
		else:
			body.add_child(UI.button("Buy property - %s" % Catalog.fmt_money(p["price"]), _buy, 720, 20))
			body.add_child(UI.label("Cash %s  |  Bank %s" % [Catalog.fmt_money(Game.cash()), Catalog.fmt_money(Game.bank())], 15, UI.DIM))
	body.add_child(UI.button("Close [Esc]", close, 720))

func _buy() -> void:
	if Game.buy_property(pid):
		var t := UI.label("Welcome home! %s is now your spawn location." % Catalog.PROPERTIES[pid]["name"], 18, UI.GREEN, true)
		_refresh()
		body.add_child(t)

func _enter(where: String) -> void:
	var w = world
	var id := pid
	close()
	if w:
		w.enter_property(id, where)

func _set_spawn() -> void:
	Game.data["spawn_property"] = pid
	Game.save_game()
	Sfx.play("buy")
	_refresh()

func _sell_confirm() -> void:
	var p: Dictionary = Catalog.PROPERTIES[pid]
	var d := DialogUI.new("Sell %s?" % p["name"], "You will receive %s. Vehicles stored here will be moved to your other garages; any that don't fit are sold." % Catalog.fmt_money(int(p["price"] * 0.5)),
		[["Yes, sell it", func():
			Game.sell_property(pid)
			close()]])
	overlay(d)

func _designer() -> void:
	var decor: Dictionary = Game.data["properties"][pid]["decor"]
	body.add_child(UI.label("Interior Designer", 20, UI.ACCENT, true))
	body.add_child(_row("Furniture style", Catalog.DECOR_STYLES, int(decor["style"]), "style", Catalog.DECOR_PRICE["style"]))
	var walls := []
	for w in Catalog.WALL_COLORS:
		walls.append(w[0])
	body.add_child(_row("Wall colour", walls, int(decor["wall"]), "wall", Catalog.DECOR_PRICE["wall"]))
	var floors := []
	for f in Catalog.FLOORS:
		floors.append(f[0])
	body.add_child(_row("Flooring", floors, int(decor["floor"]), "floor", Catalog.DECOR_PRICE["floor"]))
	body.add_child(_toggle("Artwork", bool(decor["art"]), "art", Catalog.DECOR_PRICE["art"]))
	body.add_child(_toggle("Plants", bool(decor["plants"]), "plants", Catalog.DECOR_PRICE["plants"]))
	body.add_child(UI.spacer(8))
	if Game.data["spawn_property"] != pid:
		body.add_child(UI.button("Set as spawn location", _set_spawn, 720))
	else:
		body.add_child(UI.label("This is your spawn location.", 16, UI.GREEN))
	body.add_child(UI.button("Manage vehicles", func(): overlay(GarageUI.new(pid)), 720))
	body.add_child(UI.button("Close [Esc]", close, 720))

func _row(label: String, names: Array, cur: int, key: String, price: int) -> Control:
	var v := UI.vbox(4)
	v.add_child(UI.label("%s  (%s each change)" % [label, Catalog.fmt_money(price)], 16, UI.DIM))
	var flow := HFlowContainer.new()
	for i in names.size():
		var idx := i
		var b := UI.button(names[i], func(): _decor(key, idx, price), 0, 15)
		if i == cur:
			b.add_theme_color_override("font_color", UI.GREEN)
			b.disabled = true
		flow.add_child(b)
	v.add_child(flow)
	return v

func _toggle(label: String, cur: bool, key: String, price: int) -> Control:
	var h := UI.hbox()
	h.add_child(UI.label("%s: %s" % [label, "On" if cur else "Off"], 17))
	h.add_child(UI.hfill())
	h.add_child(UI.button(("Remove" if cur else "Add (%s)" % Catalog.fmt_money(price)), func(): _decor(key, not cur, 0 if cur else price), 200, 15))
	return h

func _decor(key: String, value, price: int) -> void:
	if not Game.spend(price, "Interior design"):
		return
	Game.data["properties"][pid]["decor"][key] = value
	Game.save_game()
	if world:
		world.rebuild_interior()
	_refresh()
