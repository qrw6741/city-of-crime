class_name SlotsUI
extends MenuBase
## Save slot picker for New Game / Load Game / Save As.

var mode := "load"     # load, new, save
var on_pick: Callable
var body: VBoxContainer

func _init(m: String = "load", cb: Callable = Callable()) -> void:
	super._init()
	mode = m
	on_pick = cb

func build() -> void:
	body = center_panel(Vector2(760, 0))
	_refresh()

func _refresh() -> void:
	UI.clear(body)
	var titles := {"load": "Load Game", "new": "New Game - choose a slot", "save": "Save Game"}
	body.add_child(UI.header(titles[mode], "Progress is saved automatically every 90 seconds, after purchases and jobs, and when you quit."))
	for s in Game.SLOTS:
		var info := Game.slot_info(s)
		var slot_i: int = s
		var row := UI.hbox()
		var txt := ""
		if info.is_empty():
			txt = "Slot %d  -  Empty" % (s + 1)
		else:
			txt = "Slot %d  -  %s  |  Level %d  |  %s  |  %s\n%s  |  %s" % [s + 1, info["name"], info["level"], Catalog.fmt_money(int(info["cash"]) + int(info["bank"])), Game.fmt_time(float(info["playtime"])), info["location"], info["saved"]]
		var b := UI.button(txt, func(): _pick(slot_i, info.is_empty()), 560, 16)
		b.custom_minimum_size.y = 64
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if mode == "load" and info.is_empty():
			b.disabled = true
		row.add_child(b)
		if not info.is_empty() and mode != "save":
			row.add_child(UI.button("Delete", func(): _delete(slot_i), 120, 15))
		body.add_child(row)
	body.add_child(UI.button("Back [Esc]", close, 700))

func _pick(s: int, empty: bool) -> void:
	if (mode == "new" or mode == "save") and not empty and s != Game.slot:
		var d := DialogUI.new("Overwrite slot %d?" % (s + 1), "The existing save in this slot will be replaced.", [["Overwrite", func():
			on_pick.call(s)
			close()]])
		overlay(d)
		return
	on_pick.call(s)
	close()

func _delete(s: int) -> void:
	var d := DialogUI.new("Delete slot %d?" % (s + 1), "This cannot be undone.", [["Delete save", func():
		Game.delete_slot(s)
		for c in get_children():
			if c is DialogUI:
				c.queue_free()
		_refresh()]])
	overlay(d)
