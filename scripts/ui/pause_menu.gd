class_name PauseMenu
extends MenuBase
## In-game pause menu.

func build() -> void:
	var v := center_panel(Vector2(520, 0))
	v.add_child(UI.label("CITY OF CRIME", 40, UI.ACCENT, true))
	v.add_child(UI.label("%s  |  Level %d  |  %s" % [Game.data["name"], Game.level(), CityLayout.district_name_at(world.player.global_position)], 16, UI.DIM))
	v.add_child(UI.spacer(6))
	var resume := UI.button("Resume", close, 460)
	v.add_child(resume)
	v.add_child(UI.button("Map", func():
		var w = world
		w.close_menu()
		w.open_menu(MapView.new()), 460))
	v.add_child(UI.button("Save Game", func():
		if Game.save_game():
			world.hud.notify("Game saved to slot %d." % (Game.slot + 1), "save")
			Sfx.play("buy")
		close(), 460))
	v.add_child(UI.button("Save to another slot", func(): overlay(SlotsUI.new("save", func(s):
		Game.slot = s
		Game.save_game())), 460))
	v.add_child(UI.button("Load Game", func(): overlay(SlotsUI.new("load", func(s):
		if Game.load_game(s):
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/world.tscn"))), 460))
	v.add_child(UI.button("Statistics", func(): overlay(StatsUI.new()), 460))
	v.add_child(UI.button("Settings", func(): overlay(SettingsUI.new()), 460))
	v.add_child(UI.button("Controls", func(): overlay(ControlsUI.new()), 460))
	v.add_child(UI.button("Quit to Main Menu", func(): world.quit_to_menu(), 460))
	v.add_child(UI.button("Exit Game", func():
		Game.save_game()
		get_tree().quit(), 460))
	resume.call_deferred("grab_focus")
