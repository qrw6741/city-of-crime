extends Node
## Global game state: player profile, money, progression, ownership, saving & settings.

signal money_changed
signal xp_changed
signal level_up(level: int)
signal notify(text: String, kind: String)
signal vehicles_changed
signal properties_changed
signal appearance_changed

const SAVE_DIR := "user://saves"
const SLOTS := 3
const SETTINGS_PATH := "user://settings.cfg"
const AUTOSAVE_INTERVAL := 90.0

var data: Dictionary = {}
var slot: int = -1
var playing := false
var autosave_timer := 0.0
var pending_new_game := {}   # filled by character creator before world loads

var settings := {
	"quality": 1, "mouse_sens": 1.0, "invert_y": false, "fov": 75.0, "master": 0.8, "music": 0.5, "sfx": 0.8,
	"fullscreen": false, "units": "kmh", "show_fps": false, "traffic": 1.0, "vsync": true,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	load_settings()
	apply_settings()
	get_tree().set_auto_accept_quit(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if playing:
			save_game()
		get_tree().quit()

func _process(delta: float) -> void:
	if not playing or get_tree().paused:
		return
	data["playtime"] = float(data.get("playtime", 0.0)) + delta
	autosave_timer += delta
	if autosave_timer >= AUTOSAVE_INTERVAL:
		autosave_timer = 0.0
		save_game()
		notify.emit("Autosaved", "save")

# ------------------------------------------------------------------ input
func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"sprint": [KEY_SHIFT], "jump": [KEY_SPACE], "interact": [KEY_E], "enter_vehicle": [KEY_F],
		"camera_toggle": [KEY_V], "phone": [KEY_UP, KEY_T], "map": [KEY_M], "pause": [KEY_ESCAPE],
		"horn": [KEY_H], "handbrake": [KEY_SPACE], "headlights": [KEY_L], "look_back": [KEY_C],
		"phone_back": [KEY_BACKSPACE], "cancel_job": [KEY_X], "reset_vehicle": [KEY_R],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var pads := {"jump": JOY_BUTTON_A, "enter_vehicle": JOY_BUTTON_Y, "interact": JOY_BUTTON_X, "pause": JOY_BUTTON_START, "phone": JOY_BUTTON_DPAD_UP, "handbrake": JOY_BUTTON_RIGHT_SHOULDER, "sprint": JOY_BUTTON_B, "camera_toggle": JOY_BUTTON_BACK}
	for action in pads:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pads[action]
		InputMap.action_add_event(action, jb)

# ------------------------------------------------------------------ new / load / save
func new_game(save_slot: int, player_name: String, appearance: Dictionary) -> void:
	slot = save_slot
	data = {
		"version": 1, "name": player_name, "appearance": appearance.duplicate(true),
		"cash": 500, "bank": 0, "xp": 0, "level": 1,
		"stats": {"reputation": 0, "criminal": 0, "driving": 5, "shooting": 0, "stamina": 10, "strength": 10},
		"health": 100.0, "armor": 0.0,
		"vehicles": [], "next_vehicle_uid": 1,
		"properties": {"sunrise_motel": _new_property_state()},
		"spawn_property": "sunrise_motel",
		"position": null, "yaw": 0.0, "time_of_day": 9.0, "weather": "clear",
		"playtime": 0.0, "created": Time.get_datetime_string_from_system(),
		"jobs": {"deliveries": 0, "races_won": 0, "cars_chopped": 0, "race_best": {}},
		"totals": {"earned": 0, "spent": 0, "distance_km": 0.0, "max_speed": 0.0, "deaths": 0, "stolen": 0},
		"transactions": [],
		"chop_cooldown": 0.0,
	}
	playing = true
	autosave_timer = 0.0
	save_game()

func _new_property_state() -> Dictionary:
	return {"owned": true, "decor": {"style": 0, "wall": 0, "floor": 0, "art": true, "plants": true}}

func slot_path(s: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, s]

func slot_info(s: int) -> Dictionary:
	var p := slot_path(s)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	return {"name": d.get("name", "?"), "level": d.get("level", 1), "cash": d.get("cash", 0), "bank": d.get("bank", 0),
		"playtime": d.get("playtime", 0.0), "saved": d.get("saved_at", ""), "saved_unix": d.get("saved_unix", 0.0),
		"vehicles": (d.get("vehicles", []) as Array).size(), "location": d.get("location_name", "")}

func latest_slot() -> int:
	var best := -1
	var best_t := -1.0
	for s in SLOTS:
		var info := slot_info(s)
		if info.is_empty():
			continue
		if float(info["saved_unix"]) > best_t:
			best_t = float(info["saved_unix"])
			best = s
	return best

func load_game(s: int) -> bool:
	var p := slot_path(s)
	if not FileAccess.file_exists(p):
		return false
	var f := FileAccess.open(p, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	data = d
	_migrate()
	slot = s
	playing = true
	autosave_timer = 0.0
	return true

func _migrate() -> void:
	# Fill any keys missing from older saves.
	var fresh := {"stats": {"reputation": 0, "criminal": 0, "driving": 5, "shooting": 0, "stamina": 10, "strength": 10},
		"jobs": {"deliveries": 0, "races_won": 0, "cars_chopped": 0, "race_best": {}},
		"totals": {"earned": 0, "spent": 0, "distance_km": 0.0, "max_speed": 0.0, "deaths": 0, "stolen": 0},
		"transactions": [], "health": 100.0, "armor": 0.0, "chop_cooldown": 0.0, "weather": "clear", "time_of_day": 9.0}
	for k in fresh:
		if not data.has(k):
			data[k] = fresh[k]
		elif typeof(fresh[k]) == TYPE_DICTIONARY:
			for k2 in fresh[k]:
				if not data[k].has(k2):
					data[k][k2] = fresh[k][k2]
	for v in data["vehicles"]:
		var defaults := Catalog.default_mods(Catalog.get_vehicle(v["model"]))
		for mk in defaults:
			if not v["mods"].has(mk):
				v["mods"][mk] = defaults[mk]
	# JSON turns ints into floats; normalise the important ones.
	data["cash"] = int(data["cash"])
	data["bank"] = int(data["bank"])
	data["xp"] = int(data["xp"])
	data["level"] = int(data["level"])
	data["next_vehicle_uid"] = int(data.get("next_vehicle_uid", 1))
	for k in data["appearance"]:
		if typeof(data["appearance"][k]) == TYPE_FLOAT and k not in ["jaw", "height", "build"]:
			data["appearance"][k] = int(data["appearance"][k])
	for v in data["vehicles"]:
		v["uid"] = int(v["uid"])
		for mk in v["mods"]:
			if typeof(v["mods"][mk]) == TYPE_FLOAT:
				v["mods"][mk] = int(v["mods"][mk])

func save_game() -> bool:
	if slot < 0 or data.is_empty():
		return false
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("capture_state"):
		world.capture_state(data)
	data["saved_at"] = Time.get_datetime_string_from_system().replace("T", " ")
	data["saved_unix"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		notify.emit("Save failed!", "error")
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true

func delete_slot(s: int) -> void:
	if FileAccess.file_exists(slot_path(s)):
		DirAccess.remove_absolute(slot_path(s))

# ------------------------------------------------------------------ money
func cash() -> int:
	return int(data.get("cash", 0))

func bank() -> int:
	return int(data.get("bank", 0))

func total_money() -> int:
	return cash() + bank()

func earn(amount: int, reason: String, to_bank: bool = false) -> void:
	if to_bank:
		data["bank"] = bank() + amount
	else:
		data["cash"] = cash() + amount
	data["totals"]["earned"] = int(data["totals"]["earned"]) + amount
	_log(reason, amount)
	money_changed.emit()
	Sfx.play("cash")

func can_afford(amount: int) -> bool:
	return total_money() >= amount

func spend(amount: int, reason: String) -> bool:
	## Pays from cash first, then the bank. Returns false (and charges nothing) if unaffordable.
	if amount <= 0:
		return true
	if not can_afford(amount):
		notify.emit("You can't afford that (%s needed)." % Catalog.fmt_money(amount), "error")
		Sfx.play("error")
		return false
	var from_cash: int = min(cash(), amount)
	data["cash"] = cash() - from_cash
	data["bank"] = bank() - (amount - from_cash)
	data["totals"]["spent"] = int(data["totals"]["spent"]) + amount
	_log(reason, -amount)
	money_changed.emit()
	Sfx.play("buy")
	return true

func spend_bank(amount: int, reason: String) -> bool:
	## Online purchases come straight out of the bank account.
	if bank() < amount:
		notify.emit("Insufficient bank funds (%s needed). Deposit cash at an ATM." % Catalog.fmt_money(amount), "error")
		Sfx.play("error")
		return false
	data["bank"] = bank() - amount
	data["totals"]["spent"] = int(data["totals"]["spent"]) + amount
	_log(reason, -amount)
	money_changed.emit()
	Sfx.play("buy")
	return true

func deposit(amount: int) -> bool:
	if amount <= 0 or amount > cash():
		return false
	data["cash"] = cash() - amount
	data["bank"] = bank() + amount
	_log("ATM deposit", 0, amount)
	money_changed.emit()
	Sfx.play("cash")
	return true

func withdraw(amount: int) -> bool:
	if amount <= 0 or amount > bank():
		return false
	data["bank"] = bank() - amount
	data["cash"] = cash() + amount
	_log("ATM withdrawal", 0, -amount)
	money_changed.emit()
	Sfx.play("cash")
	return true

func lose_cash(amount: int, reason: String) -> int:
	var lost: int = min(cash(), amount)
	data["cash"] = cash() - lost
	if lost > 0:
		_log(reason, -lost)
	money_changed.emit()
	return lost

func _log(reason: String, amount: int, transfer: int = 0) -> void:
	var t: Array = data["transactions"]
	t.push_front({"t": Time.get_datetime_string_from_system().replace("T", " "), "r": reason, "a": amount, "x": transfer})
	if t.size() > 60:
		t.resize(60)

# ------------------------------------------------------------------ progression
func level() -> int:
	return int(data.get("level", 1))

func add_xp(amount: int, reason: String = "") -> void:
	data["xp"] = int(data["xp"]) + amount
	if reason != "":
		notify.emit("+%d RP  %s" % [amount, reason], "xp")
	while int(data["xp"]) >= Catalog.xp_for_level(level() + 1):
		data["level"] = level() + 1
		data["stats"]["reputation"] = int(data["stats"]["reputation"]) + 5
		level_up.emit(level())
		notify.emit("LEVEL UP!  You are now level %d" % level(), "level")
		Sfx.play("levelup")
	xp_changed.emit()

func add_stat(stat: String, amount: float) -> void:
	var v: float = float(data["stats"].get(stat, 0)) + amount
	data["stats"][stat] = clamp(v, 0.0, 100.0)

func stat(stat_name: String) -> float:
	return float(data["stats"].get(stat_name, 0))

# ------------------------------------------------------------------ vehicles
func garage_capacity() -> int:
	var c := 0
	for pid in data["properties"]:
		if data["properties"][pid].get("owned", false):
			c += int(Catalog.PROPERTIES[pid]["garage"])
	return c

func property_vehicle_count(pid: String) -> int:
	var c := 0
	for v in data["vehicles"]:
		if v.get("garage", "") == pid:
			c += 1
	return c

func free_garage() -> String:
	## Returns the id of an owned property with a free garage slot, preferring bigger garages.
	var best := ""
	var best_cap := -1
	for pid in data["properties"]:
		if not data["properties"][pid].get("owned", false):
			continue
		var cap: int = Catalog.PROPERTIES[pid]["garage"]
		if property_vehicle_count(pid) < cap and cap > best_cap:
			best = pid
			best_cap = cap
	return best

func add_vehicle(model: String, mods: Dictionary = {}) -> Dictionary:
	var garage := free_garage()
	if garage == "":
		return {}
	var def := Catalog.get_vehicle(model)
	var m := Catalog.default_mods(def)
	for k in mods:
		m[k] = mods[k]
	var v := {"uid": int(data["next_vehicle_uid"]), "model": model, "name": def["brand"] + " " + def["name"], "mods": m,
		"garage": garage, "health": 1000.0, "out": false}
	data["next_vehicle_uid"] = int(data["next_vehicle_uid"]) + 1
	data["vehicles"].append(v)
	vehicles_changed.emit()
	return v

func get_owned(uid: int) -> Dictionary:
	for v in data["vehicles"]:
		if int(v["uid"]) == uid:
			return v
	return {}

func remove_vehicle(uid: int) -> void:
	for i in data["vehicles"].size():
		if int(data["vehicles"][i]["uid"]) == uid:
			data["vehicles"].remove_at(i)
			break
	vehicles_changed.emit()

func owns_property(pid: String) -> bool:
	return data["properties"].has(pid) and data["properties"][pid].get("owned", false)

func buy_property(pid: String) -> bool:
	var p: Dictionary = Catalog.PROPERTIES[pid]
	if owns_property(pid):
		return false
	if level() < int(p["level"]):
		notify.emit("Requires level %d." % p["level"], "error")
		return false
	if not spend(int(p["price"]), "Property: " + p["name"]):
		return false
	data["properties"][pid] = _new_property_state()
	data["spawn_property"] = pid
	properties_changed.emit()
	add_xp(250 + int(p["price"]) / 2000, "New property")
	save_game()
	return true

func sell_property(pid: String) -> int:
	if not owns_property(pid) or pid == "sunrise_motel":
		return 0
	var value := int(Catalog.PROPERTIES[pid]["price"] * 0.5)
	# Move vehicles out to other garages if possible, otherwise they are sold too.
	for v in data["vehicles"].duplicate():
		if v["garage"] == pid:
			v["garage"] = ""
	data["properties"].erase(pid)
	for v in data["vehicles"].duplicate():
		if v["garage"] == "":
			var g := free_garage()
			if g == "":
				value += Catalog.sell_price(v["model"])
				remove_vehicle(int(v["uid"]))
			else:
				v["garage"] = g
	if data["spawn_property"] == pid:
		data["spawn_property"] = "sunrise_motel"
	earn(value, "Sold property", true)
	properties_changed.emit()
	vehicles_changed.emit()
	save_game()
	return value

# ------------------------------------------------------------------ settings
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	for k in settings:
		settings[k] = cf.get_value("settings", k, settings[k])

func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("settings", k, settings[k])
	cf.save(SETTINGS_PATH)

func apply_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings["vsync"] else DisplayServer.VSYNC_DISABLED)
	_set_bus("Master", settings["master"])
	_set_bus("Music", settings["music"])
	_set_bus("SFX", settings["sfx"])
	var world := get_tree().get_first_node_in_group("world") if get_tree() else null
	if world and world.has_method("apply_quality"):
		world.apply_quality()

func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(v, 0.0001)))

func speed_text(mps: float) -> String:
	if settings["units"] == "mph":
		return "%d MPH" % int(mps * 2.237)
	return "%d KM/H" % int(mps * 3.6)

func fmt_time(seconds: float) -> String:
	var s := int(seconds)
	return "%dh %02dm" % [s / 3600, (s / 60) % 60]
