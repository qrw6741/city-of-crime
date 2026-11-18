class_name CharCreator
extends MenuBase
## Character creation: appearance, body and starting outfit.

var slot := 0
var app: Dictionary
var preview: Preview3D
var name_edit: LineEdit
var rows: VBoxContainer

const STEPPERS := [
	["Skin tone", "skin", "SKIN_TONES"], ["Eye colour", "eyes", "EYE_COLORS"], ["Hairstyle", "hair", "HAIR_STYLES"], ["Hair colour", "hair_color", "HAIR_COLORS"],
	["Facial hair", "beard", "BEARDS"], ["Top", "top", "TOPS"], ["Top colour", "top_color", "CLOTH_COLORS"], ["Bottoms", "bottom", "BOTTOMS"],
	["Bottoms colour", "bottom_color", "CLOTH_COLORS"], ["Shoes", "shoes", "SHOES"], ["Shoe colour", "shoe_color", "CLOTH_COLORS"], ["Hat", "hat", "HATS"],
	["Hat colour", "hat_color", "CLOTH_COLORS"], ["Glasses", "glasses", "GLASSES"], ["Watch", "watch", "WATCHES"], ["Chain", "chain", "CHAINS"], ["Tattoos", "tattoo", "TATTOOS"],
]

func _init(s: int = 0) -> void:
	super._init()
	slot = s
	dim = 0.9

func build() -> void:
	app = Catalog.default_appearance("male")
	var outer := UI.panel(Vector2(1400, 830))
	UI.centered(self, outer)
	var h := UI.hbox(20)
	outer.add_child(h)
	var left := UI.vbox(8)
	left.custom_minimum_size = Vector2(640, 0)
	h.add_child(left)
	left.add_child(UI.header("Create your character", "You arrive in Port Calloway with $500 and big plans. You can restyle later at shops in the city."))
	var nr := UI.hbox()
	nr.add_child(UI.label("Name", 17))
	name_edit = LineEdit.new()
	name_edit.text = "Newcomer"
	name_edit.max_length = 20
	name_edit.custom_minimum_size = Vector2(300, 40)
	nr.add_child(name_edit)
	nr.add_child(UI.button("Male", func(): _gender("male"), 100))
	nr.add_child(UI.button("Female", func(): _gender("female"), 100))
	left.add_child(nr)
	var sc := UI.scroll(Vector2(640, 560))
	left.add_child(sc)
	rows = UI.vbox(4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rows)
	var bottom := UI.hbox()
	bottom.add_child(UI.button("Randomise", _randomise, 200))
	bottom.add_child(UI.button("Back", close, 140))
	bottom.add_child(UI.hfill())
	bottom.add_child(UI.button("START GAME", _start, 240, 22))
	left.add_child(bottom)
	preview = Preview3D.new(Vector2(680, 780))
	h.add_child(preview)
	_refresh()

func _list(n: String) -> Array:
	match n:
		"SKIN_TONES": return Catalog.SKIN_TONES
		"EYE_COLORS": return Catalog.EYE_COLORS
		"HAIR_STYLES": return Catalog.HAIR_STYLES
		"HAIR_COLORS": return Catalog.HAIR_COLORS
		"BEARDS": return Catalog.BEARDS
		"TOPS": return Catalog.TOPS
		"BOTTOMS": return Catalog.BOTTOMS
		"SHOES": return Catalog.SHOES
		"HATS": return Catalog.HATS
		"GLASSES": return Catalog.GLASSES
		"WATCHES": return Catalog.WATCHES
		"CHAINS": return Catalog.CHAINS
		"TATTOOS": return Catalog.TATTOOS
	return Catalog.CLOTH_COLORS

func _refresh() -> void:
	UI.clear(rows)
	rows.add_child(_slider("Face shape", "jaw", 0.0, 1.0))
	rows.add_child(_slider("Height", "height", 0.9, 1.1))
	rows.add_child(_slider("Build", "build", 0.0, 1.0))
	for s in STEPPERS:
		rows.add_child(_stepper(s[0], s[1], _list(s[2])))
	preview.set_humanoid(app)

func _stepper(label: String, key: String, list: Array) -> Control:
	var h := UI.hbox(6)
	var l := UI.label(label, 16)
	l.custom_minimum_size.x = 170
	h.add_child(l)
	var cur: int = int(app.get(key, 0))
	h.add_child(UI.button("<", func(): _step(key, -1, list.size()), 44))
	var val = list[cur % list.size()]
	if val is Color:
		h.add_child(UI.swatch(val, Vector2(150, 30)))
	else:
		var vl := UI.label(str(val), 16, UI.ACCENT, true)
		vl.custom_minimum_size.x = 150
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(vl)
	h.add_child(UI.button(">", func(): _step(key, 1, list.size()), 44))
	h.add_child(UI.label("%d / %d" % [cur + 1, list.size()], 14, UI.DIM))
	return h

func _slider(label: String, key: String, mn: float, mx: float) -> Control:
	var h := UI.hbox(6)
	var l := UI.label(label, 16)
	l.custom_minimum_size.x = 170
	h.add_child(l)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = 0.01
	sl.value = float(app.get(key, (mn + mx) / 2.0))
	sl.custom_minimum_size = Vector2(300, 30)
	sl.value_changed.connect(func(x):
		app[key] = x
		preview.set_humanoid(app))
	h.add_child(sl)
	return h

func _step(key: String, d: int, n: int) -> void:
	app[key] = posmod(int(app.get(key, 0)) + d, n)
	_refresh()

func _gender(g: String) -> void:
	app["gender"] = g
	if g == "female" and int(app["beard"]) > 0:
		app["beard"] = 0
	_refresh()

func _randomise() -> void:
	app = Catalog.random_appearance()
	_refresh()

func _start() -> void:
	var n := name_edit.text.strip_edges()
	if n == "":
		n = "Newcomer"
	Game.new_game(slot, n, app)
	get_tree().change_scene_to_file("res://scenes/world.tscn")
