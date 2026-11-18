class_name MapView
extends MenuBase
## Full-screen city map. Left-click sets a GPS waypoint, right-click clears it, wheel zooms, drag pans.

var map: Minimap
var center := Vector3(640, 0, 640)
var dragging := false
var legend: VBoxContainer

func build() -> void:
	dim = 0.85
	var w = world if world else get_tree().get_first_node_in_group("world")
	map = Minimap.new()
	map.world = w
	map.big = true
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.offset_left = 30
	map.offset_top = 70
	map.offset_right = -330
	map.offset_bottom = -30
	center = w.player.global_position
	map.center_override = center
	map.zoom = 0.6
	map.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(map)
	map.gui_input.connect(_map_input)
	var title := UI.label("MAP OF PORT CALLOWAY", 28, UI.ACCENT, true)
	title.position = Vector2(30, 22)
	add_child(title)
	legend = UI.vbox(6)
	legend.anchor_left = 1.0
	legend.anchor_right = 1.0
	legend.position = Vector2(-300, 70)
	legend.size = Vector2(280, 700)
	add_child(legend)
	var items := [["$", "Apex Motors (cars)", UI.ACCENT], ["M", "Torque Customs (mods)", Color(0.95, 0.35, 0.2)], ["C", "Rusty's Salvage (chop shop)", Color(0.9, 0.6, 0.2)],
		["B", "Bank / ATM", UI.GREEN], ["J", "QuickShip jobs", Color(1.0, 0.55, 0.15)], ["R", "Street races", Color(0.7, 0.4, 1.0)],
		["T", "Clothing", Color(1.0, 0.6, 0.85)], ["H", "Barber / Properties", Color(0.4, 0.7, 1.0)], ["I", "Tattoos", Color(0.9, 0.25, 0.35)]]
	for it in items:
		var h := UI.hbox()
		h.add_child(UI.swatch(it[2], Vector2(18, 18)))
		h.add_child(UI.label("%s  %s" % [it[0], it[1]], 16))
		legend.add_child(h)
	legend.add_child(UI.spacer(10))
	legend.add_child(UI.label("Left click: set waypoint\nRight click: clear waypoint\nWheel: zoom   Drag: pan\nSquare blips: your homes", 15, UI.DIM))
	legend.add_child(UI.spacer(10))
	for d in ["downtown", "rich", "suburbs", "industrial", "port", "beach"]:
		var h2 := UI.hbox()
		h2.add_child(UI.swatch(CityLayout.DISTRICTS[d]["color"].darkened(0.2), Vector2(18, 18)))
		h2.add_child(UI.label(CityLayout.DISTRICTS[d]["name"], 15))
		legend.add_child(h2)
	legend.add_child(UI.spacer(10))
	legend.add_child(UI.button("Close [Esc / M]", close, 260))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		close()
		return
	super._unhandled_input(event)

func _map_input(event: InputEvent) -> void:
	var w = map.world
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var s := map.map_scale()
				var off: Vector2 = (event.position - map.size / 2.0) / s
				var p := Vector3(center.x + off.x, 0, center.z + off.y)
				w.set_waypoint(p)
				Sfx.play("click")
			MOUSE_BUTTON_RIGHT:
				w.set_waypoint(null)
				Sfx.play("back")
			MOUSE_BUTTON_WHEEL_UP:
				map.zoom = min(3.0, map.zoom * 1.15)
			MOUSE_BUTTON_WHEEL_DOWN:
				map.zoom = max(0.25, map.zoom / 1.15)
			MOUSE_BUTTON_MIDDLE:
				dragging = true
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		dragging = false
	elif event is InputEventMouseMotion and (dragging or event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var s2 := map.map_scale()
		center -= Vector3(event.relative.x, 0, event.relative.y) / s2
		map.center_override = center
