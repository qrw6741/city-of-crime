class_name CityLayout
## Static description of the city grid. Shared by generator, AI, minimap and gameplay.

const P := 80.0          # block pitch (block + road)
const N := 16            # blocks per side
const ROAD_W := 16.0     # road width
const HALF_ROAD := 8.0
const SIDEWALK := 4.0
const LANE_OFF := 4.0    # traffic lane offset from road centre (right-hand traffic)
const CURB_H := 0.15
const SIZE := P * N      # 1280 m
const LAND_MIN := Vector2(-320.0, -320.0)
const LAND_MAX := Vector2(1300.0, 1345.0)
const WATER_Y := -2.2

const DISTRICTS := {
	"downtown": {"name": "Downtown", "color": Color(0.36, 0.40, 0.50)},
	"rich": {"name": "Crestwood Hills", "color": Color(0.30, 0.48, 0.30)},
	"suburbs": {"name": "Maplewood", "color": Color(0.42, 0.46, 0.36)},
	"industrial": {"name": "Ironside", "color": Color(0.45, 0.40, 0.33)},
	"port": {"name": "Port Calloway", "color": Color(0.38, 0.38, 0.42)},
	"beach": {"name": "Coral Beach", "color": Color(0.80, 0.74, 0.55)},
	"park": {"name": "Central Park", "color": Color(0.25, 0.50, 0.25)},
	"golf": {"name": "Crestwood Golf Club", "color": Color(0.30, 0.60, 0.30)},
	"outskirts": {"name": "Outskirts", "color": Color(0.30, 0.42, 0.26)},
}

static func district(i: int, j: int) -> String:
	if i < 0 or j < 0 or i >= N or j >= N:
		return "outskirts"
	if (i <= 1 and j <= 1):
		return "golf"
	if i == 7 and j == 7:
		return "park"
	if i >= 5 and i <= 10 and j >= 4 and j <= 9:
		return "downtown"
	if j <= 3 and i <= 9:
		return "rich"
	if i >= 11 and j <= 8:
		return "industrial"
	if i >= 11 and j >= 9:
		return "port"
	if j >= 13:
		return "beach"
	return "suburbs"

static func district_at(pos: Vector3) -> String:
	var i := int(floor(pos.x / P))
	var j := int(floor(pos.z / P))
	if pos.z > SIZE and pos.x < SIZE:
		return "beach"
	if pos.x > SIZE - 4:
		return "port"
	return district(i, j)

static func district_name_at(pos: Vector3) -> String:
	return DISTRICTS[district_at(pos)]["name"]

static func node_pos(i: int, j: int) -> Vector3:
	return Vector3(i * P, 0.0, j * P)

static func block_center(i: int, j: int) -> Vector3:
	return Vector3((i + 0.5) * P, 0.0, (j + 0.5) * P)

static func block_rect(i: int, j: int) -> Rect2:
	## Raised slab area including sidewalk.
	return Rect2(i * P + HALF_ROAD, j * P + HALF_ROAD, P - ROAD_W, P - ROAD_W)

static func lot_rect(i: int, j: int) -> Rect2:
	## Buildable area inside the sidewalk.
	var r := block_rect(i, j)
	return r.grow(-SIDEWALK)

static func front_point(i: int, j: int, side: String, along: float = 0.5) -> Vector3:
	## A point on the sidewalk on the given side of block (i,j). side: n,s,e,w.
	var r := block_rect(i, j)
	match side:
		"n": return Vector3(r.position.x + r.size.x * along, CURB_H, r.position.y + 2.0)
		"s": return Vector3(r.position.x + r.size.x * along, CURB_H, r.end.y - 2.0)
		"w": return Vector3(r.position.x + 2.0, CURB_H, r.position.y + r.size.y * along)
		_: return Vector3(r.end.x - 2.0, CURB_H, r.position.y + r.size.y * along)

static func road_point(i: int, j: int, side: String, along: float = 0.5) -> Vector3:
	## Point in the curb lane of the road next to the block side.
	var r := block_rect(i, j)
	match side:
		"n": return Vector3(r.position.x + r.size.x * along, 0.0, r.position.y - 4.5)
		"s": return Vector3(r.position.x + r.size.x * along, 0.0, r.end.y + 4.5)
		"w": return Vector3(r.position.x - 4.5, 0.0, r.position.y + r.size.y * along)
		_: return Vector3(r.end.x + 4.5, 0.0, r.position.y + r.size.y * along)

static func side_yaw(side: String) -> float:
	## Yaw (rotation.y) so that an object faces outward toward that side's road.
	match side:
		"n": return 0.0
		"s": return PI
		"w": return PI / 2.0
		_: return -PI / 2.0

static func on_road(pos: Vector3) -> bool:
	var lx := fposmod(pos.x, P)
	var lz := fposmod(pos.z, P)
	return lx < HALF_ROAD or lx > P - HALF_ROAD or lz < HALF_ROAD or lz > P - HALF_ROAD

static func nearest_node(pos: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi(pos.x / P), 0, N), clampi(roundi(pos.z / P), 0, N))

static func nearest_road_spot(pos: Vector3) -> Dictionary:
	## Returns {pos, yaw} of nearest lane position on a road (for spawning vehicles).
	var nx: float = clamp(round(pos.x / P) * P, 0.0, SIZE)
	var nz: float = clamp(round(pos.z / P) * P, 0.0, SIZE)
	var dx: float = abs(pos.x - nx)
	var dz: float = abs(pos.z - nz)
	var p := Vector3()
	var yaw := 0.0
	if dx < dz:
		# vertical road at x = nx ; travel along z
		var z: float = clamp(pos.z, 0.0, SIZE)
		if fposmod(z, P) < 14.0 or fposmod(z, P) > P - 14.0:
			z = (floor(z / P) + 0.5) * P
		p = Vector3(nx - LANE_OFF, 0.6, z)
		yaw = PI  # facing +z
	else:
		var x: float = clamp(pos.x, 0.0, SIZE)
		if fposmod(x, P) < 14.0 or fposmod(x, P) > P - 14.0:
			x = (floor(x / P) + 0.5) * P
		p = Vector3(x, 0.6, nz + LANE_OFF)
		yaw = -PI / 2.0  # facing +x
	return {"pos": p, "yaw": yaw}

static func is_land(x: float, z: float) -> bool:
	return x > LAND_MIN.x and x < LAND_MAX.x and z > LAND_MIN.y and z < LAND_MAX.y
