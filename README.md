# City of Crime

An original open-world crime sandbox built in **Godot 4.3**. You arrive in the coastal city of
**Port Calloway** with $500 and a motel room. Steal and buy cars, earn money, buy apartments and
mansions, customise your ride and your look, and build up from nothing.

> Everything (city, cars, characters, music, sounds) is generated in code. There are no imported
> assets, so the whole game is easy to read and edit.

## Play it (Windows)

1. Download **`dist/CityOfCrime-Windows.zip`** from this repo.
2. Unzip it and run **`CityOfCrime.exe`**. It's a single file with nothing to install.
3. If Windows SmartScreen warns you, click *More info → Run anyway* (the exe isn't code-signed).

Saves go to `%APPDATA%\Godot\app_userdata\City of Crime\saves` (3 slots).

## Controls

| Action | Key |
|---|---|
| Move / sprint / jump | W A S D / Shift / Space |
| Camera / zoom | Mouse / wheel |
| First ↔ third person | V |
| Interact (shops, doors, ATMs, jobs) | E |
| Enter / exit / **steal** a vehicle | F |
| Drive / brake & reverse | W / S |
| Handbrake (drift) | Space |
| Horn / headlights / look back / flip car | H / L / C / R |
| Phone | T or ↑ |
| Map (click to set a GPS waypoint) | M |
| Cancel current job | X |
| Pause menu | Esc |

## What's in this build (Stages 1–4)

**The city:** a 1.3 × 1.3 km procedurally built city on a 16×16 road grid with six districts:
Downtown skyscrapers, Crestwood Hills mansions and golf club, Maplewood suburbs, Ironside industry,
Port Calloway docks with cranes and a cargo ship, and Coral Beach with hotels and a pier with a Ferris wheel.
It also has forests and mountains on the outskirts, a day/night cycle (24 minutes per day),
and dynamic weather (clear, cloudy, overcast, rain, storm, fog) with wet roads and lightning.

**Living city:** lane-following traffic with intersection management, car-following and honking.
Pedestrians walk the sidewalks, react to danger, can be greeted, and get knocked down.
Hard crashes turn traffic into physics wrecks.

**Character:** full character creator (gender, face, skin, eyes, hair, beard, body, outfit,
hats, glasses, watches, chains, tattoos) with a 3D preview. You can restyle in-game at
**Thread & Needle** (clothes), **Sharp Edge Barbers** and **Ink Republic** (tattoos).

**Progression:** level/RP system, reputation, criminal experience, driving, shooting, stamina
and strength stats. Vehicles and properties unlock by level.

**Vehicles (33 original models):** sedans, sports, super, muscle, SUVs, motorcycles, off-road,
trucks and vans. Each has its own acceleration, top speed, braking, grip, mass, drivetrain and
engine sound. Driving includes drifting, collisions, damage, smoke, fire and explosions.
- **Apex Motors** dealership: browse by category, 3D preview, spec bars, colour choice, buy.
- **Torque Customs**: repair, respray (20 colours × 4 finishes), wheels, wheel colour, tyres,
  engine, turbo, brakes, suspension, spoilers, body kits, window tint, plate style and custom
  plate text. All with live preview and real stat changes.
- **Garages**: drive into your property's garage marker to park. Walk among your cars inside
  and drive any of them out. The collection screen has thumbnails, rename, customise, move
  between garages, mechanic delivery and selling.

**Economy:** separate cash and bank, ATMs and Meridian Bank (deposit, withdraw, statement).
Purchases take cash first, then bank. Online purchases use the bank. Hospital bills and
insurance deductibles also cost money.

**Properties (11):** Sunrise Motel (free starter), 3 low-end apartments, 3 mid-range,
2 luxury penthouses and 2 mansions. Each has a unique walk-in interior with a bed (sleep &
save), an interior designer (furniture style, walls, floors, art, plants), a garage of
2/6/10/20 spaces, and a spawn-location setting. The penthouses and mansions have big windows
looking out over the city. Mansions add a pool terrace, gardens and a security post.

**Ways to earn:** QuickShip timed van deliveries, 3 street races with gold, silver and bronze
medals and best times, and selling stolen cars at Rusty's Salvage.

**Phone:** Contacts (mechanic delivery, dispatch, Rusty), Map, Internet (buy cars and property
online), Banking, Properties, Vehicles, Jobs, Stats, Save.

**Saving:** 3 save slots, autosave every 90 s plus after purchases and jobs, and a save on quit.
Saves store appearance, level, stats, money, vehicles and mods, properties and decor, job
progress, location (including the car you're driving), time and weather.

**Menus:** main menu (Continue, New Game, Load, Character, Settings, Statistics, Exit) and a
pause menu. Settings cover graphics quality, fullscreen, V-Sync, FOV, mouse, units, FPS
counter, traffic density and volumes.

## Roadmap

| Stage | Content | Status |
|---|---|---|
| 1 | Playable district, character, camera, driving | ✅ |
| 2 | Dealership, purchasing, garages | ✅ |
| 3 | Economy, banking, levelling, save system | ✅ |
| 4 | Apartments, property purchasing, interiors | ✅ |
| 5 | Story missions, police & wanted levels, weapons & combat | next |
| 6 | Heists (planning board, preps, approaches) & criminal businesses | planned |
| 7 | Desert, countryside, airport; boats, helicopters, planes; more activities | planned |
| 8 | Polish: animation, audio, optimisation | planned |

## Editing the game

1. Install **Godot 4.3** (standard version) from godotengine.org.
2. Open Godot → *Import* → select this folder's `project.godot`.
3. Press **F5** to play.

Where things live:

| What | File |
|---|---|
| Vehicles, prices, mods, properties, shops, races, clothing | `scripts/core/catalog.gd` |
| Money, XP, saving/loading, settings, key bindings | `scripts/core/game.gd` |
| City layout & districts | `scripts/core/city_layout.gd`, `scripts/world/city.gd` |
| Driving physics | `scripts/world/car.gd` |
| Vehicle models | `scripts/world/car_model.gd` |
| Character model & animation | `scripts/world/humanoid.gd` |
| Traffic / pedestrians | `scripts/world/traffic.gd`, `scripts/world/peds.gd` |
| Interiors | `scripts/world/interiors.gd` |
| Jobs (deliveries, races, chop shop) | `scripts/gameplay/jobs.gd` |
| Day/night & weather | `scripts/world/sky_weather.gd` |
| All menus, HUD, phone | `scripts/ui/` |
| Sounds & music (generated) | `scripts/core/sfx.gd` |
| Shaders (buildings, roads, water…) | `shaders/` |

Some easy tweaks: change a car's `price`, `top` or `accel` in `catalog.gd`. Add a new
property by adding an entry to `PROPERTIES` with a free city block. Change the starting cash
in `Game.new_game()`.

To rebuild the Windows exe: *Project → Export → Windows Desktop* (export templates required),
or from the command line:
`godot --headless --export-release "Windows Desktop" build/CityOfCrime.exe`.

`tests/` contains headless smoke tests (world build, every menu, the full job/garage/save flow,
and a car physics bench).
