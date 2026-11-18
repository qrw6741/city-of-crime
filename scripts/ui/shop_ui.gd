class_name ShopUI
extends MenuBase
## Clothing store, barber and tattoo parlour. Preview on your character, pay to keep.

var kind := "clothing"
var app: Dictionary
var preview: Preview3D
var opt_box: VBoxContainer
var cat := ""
var cart_l: Label

const SHOP_CATS := {
	"clothing": [["Tops", "top", "TOPS"], ["Top Colour", "top_color", "CLOTH_COLORS"], ["Bottoms", "bottom", "BOTTOMS"], ["Bottom Colour", "bottom_color", "CLOTH_COLORS"],
		["Shoes", "shoes", "SHOES"], ["Shoe Colour", "shoe_color", "CLOTH_COLORS"], ["Hats", "hat", "HATS"], ["Hat Colour", "hat_color", "CLOTH_COLORS"],
		["Glasses", "glasses", "GLASSES"], ["Watches", "watch", "WATCHES"], ["Chains", "chain", "CHAINS"]],
	"barber": [["Hairstyle", "hair", "HAIR_STYLES"], ["Hair Colour", "hair_color", "HAIR_COLORS"], ["Facial Hair", "beard", "BEARDS"]],
	"tattoo": [["Tattoos", "tattoo", "TATTOOS"]],
}
const TITLES := {"clothing": ["Thread & Needle", "Fresh fits for every budget."], "barber": ["Sharp Edge Barbers", "Cuts, colours and beard work."], "tattoo": ["Ink Republic", "Permanent art. Choose wisely."]}

func _init(k: String = "clothing") -> void:
	super._init()
	kind = k

func build() -> void:
	app = Game.data["appearance"].duplicate(true)
	var outer := UI.panel(Vector2(1300, 780))
	UI.centered(self, outer)
	var vb := UI.vbox(10)
	outer.add_child(vb)
	var top := UI.hbox()
	var hd := UI.header(TITLES[kind][0], TITLES[kind][1])
	hd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hd)
	top.add_child(UI.button("Done [Esc]", close, 160))
	vb.add_child(top)
	var h := UI.hbox(14)
	vb.add_child(h)
	var cats := UI.vbox(4)
	cats.custom_minimum_size = Vector2(200, 0)
	h.add_child(cats)
	for c in SHOP_CATS[kind]:
		var cc: Array = c
		cats.add_child(UI.button(cc[0], func(): _set_cat(cc), 200, 17))
	var sc := UI.scroll(Vector2(420, 660))
	h.add_child(sc)
	opt_box = UI.vbox(5)
	opt_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(opt_box)
	var right := UI.vbox(8)
	h.add_child(right)
	preview = Preview3D.new(Vector2(560, 600))
	right.add_child(preview)
	cart_l = UI.label("", 16, UI.DIM)
	right.add_child(cart_l)
	preview.set_humanoid(app)
	if kind != "clothing":
		preview.focus_head()
	_set_cat(SHOP_CATS[kind][0])

func _price(key: String, idx: int) -> int:
	var p = Catalog.SHOP_PRICES.get(key)
	if key.ends_with("_color"):
		return int(Catalog.SHOP_PRICES["hair_color"]) if key == "hair_color" else int(Catalog.SHOP_PRICES["color"])
	if p is Array:
		return int(p[clampi(idx, 0, p.size() - 1)])
	return 0

func _set_cat(c: Array) -> void:
	cat = c[1]
	app = Game.data["appearance"].duplicate(true)
	preview.set_humanoid(app)
	if kind != "clothing":
		preview.focus_head()
	UI.clear(opt_box)
	opt_box.add_child(UI.label(str(c[0]).to_upper(), 20, UI.ACCENT, true))
	var list: Array = _list(c[2])
	var cur: int = int(Game.data["appearance"].get(cat, 0))
	for i in list.size():
		var idx := i
		var h := UI.hbox(6)
		if list[i] is Color:
			h.add_child(UI.swatch(list[i], Vector2(28, 36)))
		var label: String = list[i] if list[i] is String else "Colour %d" % (i + 1)
		var b := UI.button(label + ("   (wearing)" if i == cur else ""), func(): _try(idx), 260, 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == cur:
			b.add_theme_color_override("font_color", UI.GREEN)
		h.add_child(b)
		var pr := _price(cat, i)
		h.add_child(UI.label(Catalog.fmt_money(pr) if pr > 0 else "Free", 16, UI.DIM))
		var buy := UI.button("Buy", func(): _buy(idx), 70, 15)
		buy.disabled = i == cur
		h.add_child(buy)
		opt_box.add_child(h)
	cart_l.text = "Click an item to try it on, then Buy to keep it.  Cash %s  |  Bank %s" % [Catalog.fmt_money(Game.cash()), Catalog.fmt_money(Game.bank())]

func _try(idx: int) -> void:
	app = Game.data["appearance"].duplicate(true)
	app[cat] = idx
	preview.set_humanoid(app)
	if kind != "clothing":
		preview.focus_head()

func _buy(idx: int) -> void:
	var pr := _price(cat, idx)
	if not Game.spend(pr, "%s purchase" % TITLES[kind][0]):
		return
	Game.data["appearance"][cat] = idx
	Game.appearance_changed.emit()
	if world:
		world.player.rebuild_visual()
	Game.save_game()
	for c in SHOP_CATS[kind]:
		if c[1] == cat:
			_set_cat(c)
			break

func _list(n: String) -> Array:
	match n:
		"TOPS": return Catalog.TOPS
		"BOTTOMS": return Catalog.BOTTOMS
		"SHOES": return Catalog.SHOES
		"HATS": return Catalog.HATS
		"GLASSES": return Catalog.GLASSES
		"WATCHES": return Catalog.WATCHES
		"CHAINS": return Catalog.CHAINS
		"HAIR_STYLES": return Catalog.HAIR_STYLES
		"HAIR_COLORS": return Catalog.HAIR_COLORS
		"BEARDS": return Catalog.BEARDS
		"TATTOOS": return Catalog.TATTOOS
		"SKIN_TONES": return Catalog.SKIN_TONES
		"EYE_COLORS": return Catalog.EYE_COLORS
	return Catalog.CLOTH_COLORS
