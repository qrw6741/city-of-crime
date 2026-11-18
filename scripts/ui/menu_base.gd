class_name MenuBase
extends Control
## Base for full-screen menus. Esc closes. Works in-game (world set) or standalone (main menu).

signal closed
var world = null
var dim := 0.6
var content: Control

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	build()

func build() -> void:
	pass

func close() -> void:
	Sfx.play("back")
	closed.emit()
	if world and world.menu == self:
		world.close_menu()
	else:
		queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("phone_back"):
		get_viewport().set_input_as_handled()
		close()

func overlay(m: MenuBase) -> void:
	## Opens another menu on top of this one (not registered with the world).
	add_child(m)

func center_panel(min_size: Vector2) -> VBoxContainer:
	var p := UI.panel(min_size)
	var v := UI.vbox(10)
	p.add_child(v)
	UI.centered(self, p)
	content = v
	return v
