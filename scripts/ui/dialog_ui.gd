class_name DialogUI
extends MenuBase
## Generic choice dialog: title, body text and option buttons.

var title := ""
var body := ""
var options: Array = []

func _init(t: String = "", b: String = "", opts: Array = []) -> void:
	super._init()
	title = t
	body = b
	options = opts

func build() -> void:
	var v := center_panel(Vector2(640, 0))
	v.add_child(UI.header(title))
	var l := UI.label(body, 18)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)
	v.add_child(l)
	v.add_child(UI.spacer(6))
	for o in options:
		var b := UI.button(o[0], o[1], 600)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
	v.add_child(UI.button("Close", close, 600))
	if v.get_child_count() > 3:
		(v.get_child(3) as Button).call_deferred("grab_focus")
