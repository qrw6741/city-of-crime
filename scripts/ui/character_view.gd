class_name CharacterView
extends MenuBase
## Shows a saved character (from the main menu).

var d: Dictionary

func _init(save_data: Dictionary = {}) -> void:
	super._init()
	d = save_data

func build() -> void:
	var outer := UI.panel(Vector2(1000, 700))
	UI.centered(self, outer)
	var h := UI.hbox(20)
	outer.add_child(h)
	var p := Preview3D.new(Vector2(460, 640))
	h.add_child(p)
	p.set_humanoid(d.get("appearance", Catalog.default_appearance()))
	var v := UI.vbox(8)
	h.add_child(v)
	v.add_child(UI.header(str(d.get("name", "?")), "Level %d  |  %s" % [int(d.get("level", 1)), str(d.get("location_name", ""))]))
	var a: Dictionary = d.get("appearance", {})
	var lines := [
		"Gender: %s" % str(a.get("gender", "male")).capitalize(),
		"Hair: %s" % Catalog.HAIR_STYLES[int(a.get("hair", 0)) % Catalog.HAIR_STYLES.size()],
		"Facial hair: %s" % Catalog.BEARDS[int(a.get("beard", 0)) % Catalog.BEARDS.size()],
		"Top: %s  |  Bottoms: %s  |  Shoes: %s" % [Catalog.TOPS[int(a.get("top", 0)) % Catalog.TOPS.size()], Catalog.BOTTOMS[int(a.get("bottom", 0)) % Catalog.BOTTOMS.size()], Catalog.SHOES[int(a.get("shoes", 0)) % Catalog.SHOES.size()]],
		"Accessories: %s, %s, %s, %s" % [Catalog.HATS[int(a.get("hat", 0)) % 5], Catalog.GLASSES[int(a.get("glasses", 0)) % 4], Catalog.WATCHES[int(a.get("watch", 0)) % 4], Catalog.CHAINS[int(a.get("chain", 0)) % 3]],
		"Tattoos: %s" % Catalog.TATTOOS[int(a.get("tattoo", 0)) % Catalog.TATTOOS.size()],
		"",
		"Cash %s  |  Bank %s" % [Catalog.fmt_money(int(d.get("cash", 0))), Catalog.fmt_money(int(d.get("bank", 0)))],
		"Vehicles: %d" % (d.get("vehicles", []) as Array).size(),
		"",
		"Change your look in-game at Thread & Needle (clothes),\nSharp Edge (hair) and Ink Republic (tattoos).",
	]
	for l in lines:
		v.add_child(UI.label(l, 17, UI.TEXT if l.find("Change") < 0 else UI.DIM))
	v.add_child(UI.hfill())
	v.add_child(UI.button("Back [Esc]", close, 460))
