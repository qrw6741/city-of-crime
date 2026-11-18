class_name ControlsUI
extends MenuBase
## Key bindings reference.

func build() -> void:
	var v := center_panel(Vector2(700, 0))
	v.add_child(UI.header("Controls"))
	var rows := [
		["Move", "W A S D"], ["Sprint", "Shift"], ["Jump", "Space"], ["Look / steer camera", "Mouse"], ["Zoom camera", "Mouse wheel"],
		["Interact / shops / doors", "E"], ["Enter / exit / steal vehicle", "F"], ["Accelerate / brake / reverse", "W / S"], ["Handbrake (drift)", "Space"],
		["Horn", "H"], ["Headlights", "L"], ["Look behind", "C"], ["Flip vehicle", "R"], ["First / third person", "V"],
		["Phone", "T or Up arrow"], ["Map", "M"], ["Cancel job", "X"], ["Show RP bar", "Z (hold)"], ["Pause", "Esc"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	for r in rows:
		grid.add_child(UI.label(r[0], 17))
		grid.add_child(UI.label(r[1], 17, UI.ACCENT, true))
	v.add_child(grid)
	v.add_child(UI.label("Gamepads are supported for the basics (A jump, Y vehicle, X interact, RB handbrake, Start pause).", 14, UI.DIM))
	v.add_child(UI.button("Back [Esc]", close, 640))
