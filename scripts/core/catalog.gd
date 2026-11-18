extends Node
## Static game data: vehicles, modifications, properties, clothing, shops, jobs.

const CATEGORIES := ["Sedan", "Sports", "Super", "Muscle", "SUV", "Motorcycle", "Off-Road", "Truck", "Van"]

# top: km/h, accel: 0-100 km/h seconds, brake: 0..1, grip: 0..1, mass kg
var VEHICLES := {
	# --- Sedans / compacts
	"novak_pip": {"name": "Pip", "brand": "Novak", "cat": "Sedan", "body": "compact", "price": 8900, "level": 1, "top": 155, "accel": 11.5, "brake": 0.55, "grip": 0.55, "mass": 1050, "drive": "FWD", "sound": "small", "color": Color(0.85, 0.35, 0.25)},
	"valor_cruiser": {"name": "Cruiser", "brand": "Valor", "cat": "Sedan", "body": "sedan", "price": 12500, "level": 1, "top": 175, "accel": 9.8, "brake": 0.55, "grip": 0.55, "mass": 1450, "drive": "RWD", "sound": "v6", "color": Color(0.20, 0.25, 0.35)},
	"haldane_meridian": {"name": "Meridian", "brand": "Haldane", "cat": "Sedan", "body": "sedan", "price": 19500, "level": 2, "top": 190, "accel": 8.6, "brake": 0.6, "grip": 0.6, "mass": 1400, "drive": "FWD", "sound": "v6", "color": Color(0.75, 0.75, 0.78)},
	"kestrel_avanti": {"name": "Avanti", "brand": "Kestrel", "cat": "Sedan", "body": "sedan", "price": 28000, "level": 3, "top": 205, "accel": 7.4, "brake": 0.65, "grip": 0.66, "mass": 1500, "drive": "AWD", "sound": "v6", "color": Color(0.12, 0.30, 0.55)},
	"orion_stately": {"name": "Stately", "brand": "Orion", "cat": "Sedan", "body": "luxury", "price": 64000, "level": 5, "top": 225, "accel": 6.2, "brake": 0.7, "grip": 0.68, "mass": 1900, "drive": "RWD", "sound": "v8", "color": Color(0.06, 0.06, 0.07)},
	# --- Sports
	"mirage_coupe": {"name": "Coupe", "brand": "Mirage", "cat": "Sports", "body": "sports", "price": 72000, "level": 4, "top": 245, "accel": 5.3, "brake": 0.75, "grip": 0.74, "mass": 1350, "drive": "RWD", "sound": "high", "color": Color(0.95, 0.80, 0.15)},
	"lynx_rs": {"name": "RS", "brand": "Lynx", "cat": "Sports", "body": "sports", "price": 86000, "level": 5, "top": 250, "accel": 5.0, "brake": 0.78, "grip": 0.8, "mass": 1380, "drive": "AWD", "sound": "high", "color": Color(0.15, 0.55, 0.35)},
	"zephyr_gt": {"name": "GT", "brand": "Zephyr", "cat": "Sports", "body": "sports", "price": 95000, "level": 6, "top": 260, "accel": 4.8, "brake": 0.78, "grip": 0.78, "mass": 1400, "drive": "RWD", "sound": "high", "color": Color(0.80, 0.10, 0.12)},
	"raiden_s7": {"name": "S7", "brand": "Raiden", "cat": "Sports", "body": "sports", "price": 118000, "level": 7, "top": 270, "accel": 4.4, "brake": 0.8, "grip": 0.83, "mass": 1420, "drive": "AWD", "sound": "high", "color": Color(0.92, 0.92, 0.95)},
	"corsa_vento": {"name": "Vento", "brand": "Corsa", "cat": "Sports", "body": "sports", "price": 142000, "level": 8, "top": 275, "accel": 4.2, "brake": 0.82, "grip": 0.8, "mass": 1330, "drive": "RWD", "sound": "high", "color": Color(0.10, 0.35, 0.80)},
	# --- Super
	"phantom_rx": {"name": "RX", "brand": "Phantom", "cat": "Super", "body": "super", "price": 540000, "level": 10, "top": 320, "accel": 3.0, "brake": 0.88, "grip": 0.88, "mass": 1350, "drive": "RWD", "sound": "super", "color": Color(0.08, 0.08, 0.10)},
	"vortex_x9": {"name": "X9", "brand": "Vortex", "cat": "Super", "body": "super", "price": 725000, "level": 12, "top": 335, "accel": 2.8, "brake": 0.9, "grip": 0.9, "mass": 1380, "drive": "AWD", "sound": "super", "color": Color(1.0, 0.45, 0.05)},
	"solaris_ultima": {"name": "Ultima", "brand": "Solaris", "cat": "Super", "body": "super", "price": 980000, "level": 14, "top": 345, "accel": 2.6, "brake": 0.92, "grip": 0.92, "mass": 1400, "drive": "AWD", "sound": "super", "color": Color(0.55, 0.85, 0.20)},
	"tempest_vr": {"name": "VR", "brand": "Tempest", "cat": "Super", "body": "super", "price": 1250000, "level": 16, "top": 355, "accel": 2.5, "brake": 0.93, "grip": 0.93, "mass": 1420, "drive": "AWD", "sound": "super", "color": Color(0.45, 0.10, 0.60)},
	"aurelius_one": {"name": "One", "brand": "Aurelius", "cat": "Super", "body": "super", "price": 1600000, "level": 18, "top": 365, "accel": 2.4, "brake": 0.95, "grip": 0.95, "mass": 1450, "drive": "AWD", "sound": "super", "color": Color(0.85, 0.70, 0.30)},
	# --- Muscle
	"dominus_classic": {"name": "Classic", "brand": "Dominus", "cat": "Muscle", "body": "muscle", "price": 26000, "level": 2, "top": 215, "accel": 6.4, "brake": 0.5, "grip": 0.55, "mass": 1600, "drive": "RWD", "sound": "v8", "color": Color(0.55, 0.15, 0.10)},
	"brawler_ss": {"name": "SS", "brand": "Brawler", "cat": "Muscle", "body": "muscle", "price": 32000, "level": 3, "top": 230, "accel": 5.6, "brake": 0.55, "grip": 0.58, "mass": 1650, "drive": "RWD", "sound": "v8", "color": Color(0.10, 0.12, 0.14)},
	"hammerhead_440": {"name": "440", "brand": "Hammerhead", "cat": "Muscle", "body": "muscle", "price": 45000, "level": 4, "top": 240, "accel": 5.2, "brake": 0.58, "grip": 0.6, "mass": 1700, "drive": "RWD", "sound": "v8", "color": Color(0.95, 0.55, 0.10)},
	"outlaw_stinger": {"name": "Stinger", "brand": "Outlaw", "cat": "Muscle", "body": "muscle", "price": 58000, "level": 6, "top": 250, "accel": 4.9, "brake": 0.62, "grip": 0.63, "mass": 1680, "drive": "RWD", "sound": "v8", "color": Color(0.15, 0.40, 0.75)},
	# --- SUV
	"atlas_ranger": {"name": "Ranger", "brand": "Atlas", "cat": "SUV", "body": "suv", "price": 38000, "level": 3, "top": 190, "accel": 8.0, "brake": 0.6, "grip": 0.62, "mass": 2100, "drive": "AWD", "sound": "v6", "color": Color(0.30, 0.32, 0.28)},
	"summit_lx": {"name": "LX", "brand": "Summit", "cat": "SUV", "body": "suv", "price": 82000, "level": 5, "top": 215, "accel": 6.5, "brake": 0.66, "grip": 0.66, "mass": 2300, "drive": "AWD", "sound": "v8", "color": Color(0.85, 0.85, 0.88)},
	"bastion_v8": {"name": "V8", "brand": "Bastion", "cat": "SUV", "body": "suv", "price": 135000, "level": 8, "top": 235, "accel": 5.6, "brake": 0.7, "grip": 0.7, "mass": 2400, "drive": "AWD", "sound": "v8", "color": Color(0.05, 0.05, 0.06)},
	# --- Motorcycles
	"sprite_125": {"name": "125", "brand": "Sprite", "cat": "Motorcycle", "body": "scooter", "price": 4800, "level": 1, "top": 130, "accel": 8.5, "brake": 0.6, "grip": 0.6, "mass": 220, "drive": "RWD", "sound": "bike", "color": Color(0.30, 0.70, 0.85)},
	"razor_600": {"name": "600", "brand": "Razor", "cat": "Motorcycle", "body": "bike", "price": 14000, "level": 2, "top": 230, "accel": 3.8, "brake": 0.75, "grip": 0.7, "mass": 300, "drive": "RWD", "sound": "bike", "color": Color(0.10, 0.60, 0.20)},
	"drifter_chopper": {"name": "Chopper", "brand": "Drifter", "cat": "Motorcycle", "body": "chopper", "price": 22000, "level": 3, "top": 190, "accel": 5.5, "brake": 0.55, "grip": 0.6, "mass": 340, "drive": "RWD", "sound": "v8", "color": Color(0.12, 0.10, 0.10)},
	"talon_1000r": {"name": "1000R", "brand": "Talon", "cat": "Motorcycle", "body": "bike", "price": 38000, "level": 5, "top": 285, "accel": 3.0, "brake": 0.82, "grip": 0.78, "mass": 320, "drive": "RWD", "sound": "bike", "color": Color(0.85, 0.10, 0.10)},
	# --- Off-road
	"mule_4x4": {"name": "4x4", "brand": "Mule", "cat": "Off-Road", "body": "offroad", "price": 21000, "level": 2, "top": 165, "accel": 9.0, "brake": 0.55, "grip": 0.65, "mass": 1900, "drive": "AWD", "sound": "diesel", "color": Color(0.45, 0.50, 0.30)},
	"dune_raider": {"name": "Raider", "brand": "Dune", "cat": "Off-Road", "body": "buggy", "price": 48000, "level": 4, "top": 185, "accel": 6.0, "brake": 0.6, "grip": 0.7, "mass": 900, "drive": "AWD", "sound": "v6", "color": Color(0.90, 0.60, 0.10)},
	"trailblazer_trophy": {"name": "Trophy", "brand": "Trailblazer", "cat": "Off-Road", "body": "offroad", "price": 95000, "level": 7, "top": 200, "accel": 5.4, "brake": 0.65, "grip": 0.72, "mass": 2000, "drive": "AWD", "sound": "v8", "color": Color(0.80, 0.20, 0.15)},
	# --- Trucks
	"workhorse_2500": {"name": "2500", "brand": "Workhorse", "cat": "Truck", "body": "pickup", "price": 29000, "level": 2, "top": 180, "accel": 8.4, "brake": 0.55, "grip": 0.6, "mass": 2300, "drive": "RWD", "sound": "diesel", "color": Color(0.20, 0.30, 0.50)},
	"ironclad_hauler": {"name": "Hauler", "brand": "Ironclad", "cat": "Truck", "body": "boxtruck", "price": 55000, "level": 4, "top": 130, "accel": 16.0, "brake": 0.45, "grip": 0.55, "mass": 5500, "drive": "RWD", "sound": "diesel", "color": Color(0.90, 0.90, 0.90)},
	# --- Vans
	"courier_van": {"name": "Courier", "brand": "Bramley", "cat": "Van", "body": "van", "price": 18000, "level": 1, "top": 150, "accel": 13.0, "brake": 0.5, "grip": 0.55, "mass": 2200, "drive": "RWD", "sound": "diesel", "color": Color(0.95, 0.95, 0.95)},
	"nomad_camper": {"name": "Camper", "brand": "Nomad", "cat": "Van", "body": "camper", "price": 34000, "level": 3, "top": 140, "accel": 15.0, "brake": 0.5, "grip": 0.55, "mass": 2600, "drive": "RWD", "sound": "diesel", "color": Color(0.85, 0.75, 0.55)},
}

# Vehicles that only appear in traffic / jobs (not sold).
var SPECIAL_VEHICLES := {
	"taxi": {"name": "Taxi", "brand": "Valor", "cat": "Sedan", "body": "sedan", "price": 12500, "level": 1, "top": 175, "accel": 9.8, "brake": 0.55, "grip": 0.55, "mass": 1450, "drive": "RWD", "sound": "v6", "color": Color(1.0, 0.78, 0.1), "taxi": true},
	"job_van": {"name": "QuickShip Van", "brand": "Bramley", "cat": "Van", "body": "van", "price": 18000, "level": 1, "top": 150, "accel": 12.0, "brake": 0.5, "grip": 0.55, "mass": 2200, "drive": "RWD", "sound": "diesel", "color": Color(0.95, 0.45, 0.10)},
}

const PAINTS := [
	["Arctic White", Color(0.93, 0.93, 0.95)], ["Jet Black", Color(0.04, 0.04, 0.05)], ["Gunmetal", Color(0.22, 0.24, 0.27)],
	["Silver", Color(0.70, 0.71, 0.74)], ["Racing Red", Color(0.80, 0.08, 0.08)], ["Wine", Color(0.40, 0.05, 0.10)],
	["Sunset Orange", Color(1.0, 0.45, 0.08)], ["Taxi Yellow", Color(1.0, 0.80, 0.10)], ["Lime", Color(0.55, 0.85, 0.15)],
	["Forest Green", Color(0.10, 0.35, 0.18)], ["Teal", Color(0.05, 0.55, 0.55)], ["Sky Blue", Color(0.35, 0.65, 0.95)],
	["Royal Blue", Color(0.08, 0.20, 0.70)], ["Midnight Blue", Color(0.05, 0.07, 0.20)], ["Purple", Color(0.40, 0.12, 0.60)],
	["Hot Pink", Color(0.95, 0.25, 0.60)], ["Bronze", Color(0.55, 0.38, 0.20)], ["Gold", Color(0.85, 0.68, 0.25)],
	["Sand", Color(0.80, 0.72, 0.55)], ["Olive", Color(0.35, 0.38, 0.20)],
]
const FINISHES := [["Gloss", 0.15, 0.3], ["Metallic", 0.08, 0.75], ["Matte", 0.75, 0.0], ["Chrome", 0.02, 1.0]]
const WHEEL_STYLES := ["Stock", "Sport Five", "Mesh", "Deep Dish", "Turbine", "Off-Road"]

# mods: key -> {label, options:[ [name, price, effects] ]}
var MODS := {
	"engine": {"label": "Engine", "options": [["Stock", 0], ["Street Tune", 4500], ["Sport Tune", 9500], ["Race Tune", 18000], ["Elite Tune", 32000]]},
	"turbo": {"label": "Turbo", "options": [["None", 0], ["Turbo Kit", 15000]]},
	"brakes": {"label": "Brakes", "options": [["Stock", 0], ["Street", 3000], ["Sport", 7000], ["Race", 14000]]},
	"suspension": {"label": "Suspension", "options": [["Stock", 0], ["Lowered", 2500], ["Sport", 5500], ["Competition", 11000]]},
	"tires": {"label": "Tires", "options": [["Stock", 0], ["Performance", 2500], ["Drift", 2000], ["All-Terrain", 2200]]},
	"spoiler": {"label": "Spoiler", "options": [["None", 0], ["Lip Spoiler", 1500], ["Street Wing", 3500], ["GT Wing", 7500]]},
	"bodykit": {"label": "Body Kit", "options": [["Stock", 0], ["Street Kit", 4000], ["Wide Body", 9000], ["Track Aero", 14000]]},
	"tint": {"label": "Window Tint", "options": [["None", 0], ["Light Smoke", 600], ["Dark Smoke", 900], ["Limo", 1400]]},
	"wheels": {"label": "Wheels", "options": [["Stock", 0], ["Sport Five", 2200], ["Mesh", 3200], ["Deep Dish", 4100], ["Turbine", 5200], ["Off-Road", 2800]]},
	"plate_style": {"label": "Plate Style", "options": [["Standard White", 0], ["Sunset Yellow", 300], ["Black Classic", 500], ["Blue Coastal", 400]]},
}
const PAINT_PRICE := 1200
const WHEEL_PAINT_PRICE := 500
const PLATE_TEXT_PRICE := 800
const REPAIR_COST_PER_HP := 4

func default_mods(def: Dictionary) -> Dictionary:
	return {"engine": 0, "turbo": 0, "brakes": 0, "suspension": 0, "tires": 0, "spoiler": 0, "bodykit": 0, "tint": 0,
		"wheels": 0, "plate_style": 0, "paint": def.get("color", Color.WHITE).to_html(false), "paint2": "1b1d22",
		"finish": 1, "wheel_color": "c0c0c8", "plate": random_plate()}

func random_plate() -> String:
	var letters := "ABCDEFGHJKLMNPRSTUVWXYZ"
	var s := ""
	for i in 3:
		s += letters[randi() % letters.length()]
	return s + " " + str(randi_range(100, 999))

func get_vehicle(id: String) -> Dictionary:
	if VEHICLES.has(id):
		return VEHICLES[id]
	return SPECIAL_VEHICLES.get(id, VEHICLES["valor_cruiser"])

func mod_price(key: String, option: int, vehicle_price: int) -> int:
	var base: int = MODS[key]["options"][option][1]
	# Pricier cars cost more to modify.
	return int(round(base * (1.0 + clamp(vehicle_price / 400000.0, 0.0, 3.0)) / 50.0) * 50)

func sell_price(vehicle_id: String) -> int:
	return int(get_vehicle(vehicle_id)["price"] * 0.5)

func chop_value(vehicle_id: String) -> int:
	return clampi(int(get_vehicle(vehicle_id)["price"] * 0.08), 600, 12000)

# ---------------------------------------------------------------- properties
# tier: motel, cheap, medium, luxury, mansion; block (i,j) & side for the entrance.
var PROPERTIES := {
	"sunrise_motel": {"name": "Sunrise Motel, Room 6", "tier": "motel", "price": 0, "level": 1, "garage": 1, "block": Vector2i(1, 12), "side": "e", "style": 0},
	"ridgeway_3b": {"name": "Ridgeway Apartments 3B", "tier": "cheap", "price": 28000, "level": 1, "garage": 2, "block": Vector2i(1, 5), "side": "e", "style": 1},
	"elm_street_14": {"name": "14 Elm Street", "tier": "cheap", "price": 45000, "level": 2, "garage": 2, "block": Vector2i(3, 11), "side": "n", "style": 2},
	"dockside_lofts": {"name": "Dockside Lofts 12", "tier": "cheap", "price": 36000, "level": 2, "garage": 2, "block": Vector2i(10, 11), "side": "w", "style": 3},
	"midtown_14": {"name": "Midtown Residences 14", "tier": "medium", "price": 180000, "level": 4, "garage": 6, "block": Vector2i(5, 4), "side": "s", "style": 1},
	"harbor_view": {"name": "Harbor View Condo", "tier": "medium", "price": 120000, "level": 3, "garage": 6, "block": Vector2i(7, 14), "side": "n", "style": 2},
	"palm_court_7": {"name": "Palm Court 7", "tier": "medium", "price": 150000, "level": 4, "garage": 6, "block": Vector2i(3, 14), "side": "n", "style": 3},
	"skyline_ph": {"name": "Skyline Tower Penthouse", "tier": "luxury", "price": 450000, "level": 7, "garage": 10, "block": Vector2i(7, 5), "side": "s", "style": 1},
	"meridian_heights": {"name": "Meridian Heights 32", "tier": "luxury", "price": 520000, "level": 8, "garage": 10, "block": Vector2i(9, 8), "side": "w", "style": 2},
	"crestwood_estate": {"name": "Crestwood Estate", "tier": "mansion", "price": 1800000, "level": 10, "garage": 20, "block": Vector2i(3, 1), "side": "s", "style": 1},
	"bellmont_villa": {"name": "Bellmont Villa", "tier": "mansion", "price": 2500000, "level": 12, "garage": 20, "block": Vector2i(6, 2), "side": "s", "style": 2},
}

const TIER_NAMES := {"motel": "Motel", "cheap": "Low-End Apartment", "medium": "Mid-Range Apartment", "luxury": "Luxury Apartment", "mansion": "Mansion"}
const DECOR_STYLES := ["Modern", "Classic", "Industrial", "Coastal"]
const WALL_COLORS := [["Warm White", Color(0.92, 0.90, 0.85)], ["Slate", Color(0.35, 0.38, 0.42)], ["Sage", Color(0.60, 0.68, 0.58)], ["Terracotta", Color(0.72, 0.42, 0.32)], ["Navy", Color(0.15, 0.20, 0.32)], ["Blush", Color(0.88, 0.72, 0.70)]]
const FLOORS := [["Oak", Color(0.55, 0.38, 0.22)], ["Walnut", Color(0.32, 0.20, 0.12)], ["Marble", Color(0.90, 0.90, 0.88)], ["Concrete", Color(0.50, 0.50, 0.50)], ["Carpet Grey", Color(0.40, 0.40, 0.44)]]
const DECOR_PRICE := {"style": 5000, "wall": 1500, "floor": 2500, "art": 2000, "plants": 800}

# ---------------------------------------------------------------- shops & POIs
# kind: dealership, modshop, chopshop, bank, atm, clothing, barber, tattoo, jobs, race, hospital, police
var POIS := [
	{"id": "apex_motors", "kind": "dealership", "name": "Apex Motors", "block": Vector2i(4, 6), "side": "e"},
	{"id": "torque_customs", "kind": "modshop", "name": "Torque Customs", "block": Vector2i(11, 3), "side": "w"},
	{"id": "torque_customs_2", "kind": "modshop", "name": "Torque Customs Beach", "block": Vector2i(5, 13), "side": "n"},
	{"id": "rustys", "kind": "chopshop", "name": "Rusty's Salvage", "block": Vector2i(13, 6), "side": "w"},
	{"id": "meridian_bank", "kind": "bank", "name": "Meridian Bank", "block": Vector2i(8, 5), "side": "w"},
	{"id": "quickship", "kind": "jobs", "name": "QuickShip Depot", "block": Vector2i(12, 1), "side": "w"},
	{"id": "threads", "kind": "clothing", "name": "Thread & Needle", "block": Vector2i(3, 9), "side": "e"},
	{"id": "sharp_edge", "kind": "barber", "name": "Sharp Edge Barbers", "block": Vector2i(2, 10), "side": "e"},
	{"id": "ink_republic", "kind": "tattoo", "name": "Ink Republic", "block": Vector2i(9, 13), "side": "n"},
	{"id": "hospital", "kind": "hospital", "name": "St. Helena Medical", "block": Vector2i(2, 7), "side": "e"},
	{"id": "race_downtown", "kind": "race", "name": "Downtown Sprint", "block": Vector2i(6, 8), "side": "s", "race": "downtown"},
	{"id": "race_coast", "kind": "race", "name": "Coastal Run", "block": Vector2i(1, 13), "side": "s", "race": "coast"},
	{"id": "race_industrial", "kind": "race", "name": "Ironside Circuit", "block": Vector2i(12, 5), "side": "s", "race": "industrial"},
	{"id": "atm_1", "kind": "atm", "name": "ATM", "block": Vector2i(1, 12), "side": "n"},
	{"id": "atm_2", "kind": "atm", "name": "ATM", "block": Vector2i(6, 6), "side": "w"},
	{"id": "atm_3", "kind": "atm", "name": "ATM", "block": Vector2i(10, 2), "side": "s"},
	{"id": "atm_4", "kind": "atm", "name": "ATM", "block": Vector2i(4, 9), "side": "e"},
	{"id": "atm_5", "kind": "atm", "name": "ATM", "block": Vector2i(8, 13), "side": "n"},
	{"id": "atm_6", "kind": "atm", "name": "ATM", "block": Vector2i(12, 10), "side": "w"},
	{"id": "atm_7", "kind": "atm", "name": "ATM", "block": Vector2i(4, 2), "side": "s"},
]

# Races are described as sequences of road intersections (grid nodes).
var RACES := {
	"downtown": {"name": "Downtown Sprint", "nodes": [Vector2i(6, 9), Vector2i(6, 5), Vector2i(10, 5), Vector2i(10, 8), Vector2i(8, 8), Vector2i(8, 10), Vector2i(5, 10)], "gold": 55.0, "silver": 65.0, "bronze": 80.0, "pay": 2500, "xp": 400},
	"coast": {"name": "Coastal Run", "nodes": [Vector2i(1, 14), Vector2i(11, 14), Vector2i(11, 16), Vector2i(0, 16), Vector2i(0, 13)], "gold": 62.0, "silver": 72.0, "bronze": 88.0, "pay": 3500, "xp": 500},
	"industrial": {"name": "Ironside Circuit", "nodes": [Vector2i(12, 6), Vector2i(16, 6), Vector2i(16, 0), Vector2i(11, 0), Vector2i(11, 4), Vector2i(14, 4), Vector2i(14, 8), Vector2i(12, 8)], "gold": 70.0, "silver": 80.0, "bronze": 95.0, "pay": 4000, "xp": 600},
}

# ---------------------------------------------------------------- appearance
const SKIN_TONES := [Color(0.98, 0.84, 0.72), Color(0.93, 0.76, 0.62), Color(0.86, 0.66, 0.50), Color(0.76, 0.56, 0.40), Color(0.62, 0.43, 0.30), Color(0.48, 0.32, 0.22), Color(0.36, 0.24, 0.16), Color(0.26, 0.17, 0.12)]
const HAIR_COLORS := [Color(0.06, 0.05, 0.05), Color(0.22, 0.14, 0.08), Color(0.40, 0.25, 0.12), Color(0.70, 0.52, 0.28), Color(0.92, 0.82, 0.55), Color(0.60, 0.20, 0.08), Color(0.75, 0.75, 0.78), Color(0.85, 0.20, 0.45), Color(0.20, 0.45, 0.85)]
const HAIR_STYLES := ["Bald", "Buzz Cut", "Short", "Slick Back", "Mohawk", "Afro", "Long", "Ponytail", "Bun", "Bob"]
const BEARDS := ["None", "Stubble", "Goatee", "Full Beard", "Moustache"]
const EYE_COLORS := [Color(0.25, 0.15, 0.08), Color(0.15, 0.35, 0.65), Color(0.25, 0.50, 0.25), Color(0.45, 0.45, 0.45)]
const TOPS := ["T-Shirt", "Hoodie", "Tank Top", "Leather Jacket", "Suit Jacket", "Polo"]
const BOTTOMS := ["Jeans", "Shorts", "Cargo Pants", "Suit Trousers", "Track Pants"]
const SHOES := ["Sneakers", "Boots", "Dress Shoes", "Sandals"]
const HATS := ["None", "Cap", "Beanie", "Fedora", "Bucket Hat"]
const GLASSES := ["None", "Aviators", "Square Frames", "Sport Shades"]
const WATCHES := ["None", "Steel Watch", "Gold Watch", "Smart Watch"]
const CHAINS := ["None", "Silver Chain", "Gold Chain"]
const TATTOOS := ["None", "Left Sleeve", "Right Sleeve", "Both Sleeves", "Neck Script", "Full Set"]
const CLOTH_COLORS := [Color(0.92, 0.92, 0.92), Color(0.08, 0.08, 0.09), Color(0.35, 0.36, 0.40), Color(0.15, 0.22, 0.42), Color(0.20, 0.35, 0.60), Color(0.60, 0.10, 0.12), Color(0.15, 0.35, 0.20), Color(0.55, 0.45, 0.30), Color(0.85, 0.65, 0.20), Color(0.55, 0.25, 0.55), Color(0.95, 0.45, 0.15), Color(0.40, 0.25, 0.15)]

# shop prices
const SHOP_PRICES := {
	"top": [60, 120, 35, 650, 900, 85], "bottom": [80, 45, 95, 450, 60], "shoes": [110, 260, 380, 30],
	"hat": [0, 45, 30, 220, 55], "glasses": [0, 180, 120, 150], "watch": [0, 750, 4500, 400], "chain": [0, 350, 2400],
	"hair": [15, 25, 35, 45, 60, 55, 70, 50, 50, 45], "beard": [10, 15, 30, 40, 25], "hair_color": 40,
	"tattoo": [0, 600, 600, 1100, 450, 2200], "color": 25,
}

func default_appearance(gender: String = "male") -> Dictionary:
	return {"gender": gender, "skin": 2, "hair": 2 if gender == "male" else 6, "hair_color": 1, "beard": 0, "eyes": 0,
		"jaw": 0.5, "height": 1.0, "build": 0.5, "top": 0, "top_color": 4, "bottom": 0, "bottom_color": 3, "shoes": 0,
		"shoe_color": 0, "hat": 0, "hat_color": 1, "glasses": 0, "watch": 0, "chain": 0, "tattoo": 0}

func random_appearance() -> Dictionary:
	var g := "male" if randf() < 0.5 else "female"
	var a := default_appearance(g)
	a["skin"] = randi() % SKIN_TONES.size()
	a["hair"] = (randi() % HAIR_STYLES.size()) if g == "male" else [2, 5, 6, 7, 8, 9][randi() % 6]
	a["hair_color"] = randi() % 6
	a["beard"] = (randi() % BEARDS.size()) if (g == "male" and randf() < 0.5) else 0
	a["top"] = randi() % TOPS.size()
	a["top_color"] = randi() % CLOTH_COLORS.size()
	a["bottom"] = randi() % BOTTOMS.size()
	a["bottom_color"] = randi() % CLOTH_COLORS.size()
	a["shoe_color"] = randi() % CLOTH_COLORS.size()
	a["hat"] = (randi() % HATS.size()) if randf() < 0.25 else 0
	a["glasses"] = (randi() % GLASSES.size()) if randf() < 0.25 else 0
	a["height"] = randf_range(0.93, 1.07)
	a["build"] = randf_range(0.2, 0.8)
	return a

# ---------------------------------------------------------------- progression
func xp_for_level(level: int) -> int:
	## Total XP required to reach `level`.
	if level <= 1:
		return 0
	var l := level - 1
	return 800 * l + 120 * l * l

func fmt_money(v: int) -> String:
	var neg := v < 0
	var s := str(abs(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if neg else "$") + s + out
