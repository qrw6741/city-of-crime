extends Node
var frames := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
func _process(_d):
	frames += 1
	if frames == 15:
		get_viewport().get_texture().get_image().save_png("/home/claude/shots/m_menu.png")
		var cc := CharCreator.new(2)
		get_tree().root.add_child(cc)
	if frames == 30:
		get_viewport().get_texture().get_image().save_png("/home/claude/shots/m_creator.png")
		get_tree().quit()
