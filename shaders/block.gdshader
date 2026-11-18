shader_type spatial;
render_mode diffuse_burley;

global uniform float wetness;
varying vec3 wpos;
varying vec3 n_obj;

float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_obj = NORMAL;
}

void fragment() {
	vec2 uv = UV;                 // local metres from block corner
	float sz = UV2.y;             // block size
	float kind = UV2.x;           // 0 grass, 1 concrete, 2 plaza, 3 sand, 4 dirt/asphalt
	float edge = min(min(uv.x, uv.y), min(sz - uv.x, sz - uv.y));
	vec3 col;
	float rough = 0.9;
	float n = noise(wpos.xz * 0.4);
	if (n_obj.y < 0.5) {
		col = vec3(0.5, 0.5, 0.49);
	} else if (edge < 0.35) {
		col = vec3(0.56, 0.56, 0.55);
	} else if (edge < 4.0) {
		vec2 t = fract(wpos.xz / 2.0);
		float line = step(t.x, 0.03) + step(t.y, 0.03);
		col = vec3(0.44, 0.44, 0.43) * (0.9 + 0.1 * n) * (1.0 - 0.18 * clamp(line, 0.0, 1.0));
	} else if (kind < 0.5) {
		float g = noise(wpos.xz * 1.3) * 0.5 + noise(wpos.xz * 0.2) * 0.5;
		col = mix(vec3(0.17, 0.32, 0.12), vec3(0.28, 0.42, 0.16), g);
		rough = 1.0;
	} else if (kind < 1.5) {
		col = vec3(0.42, 0.42, 0.41) * (0.85 + 0.2 * n);
	} else if (kind < 2.5) {
		vec2 t = fract(wpos.xz / 3.0);
		float line = step(t.x, 0.04) + step(t.y, 0.04);
		col = mix(vec3(0.62, 0.58, 0.52), vec3(0.5, 0.47, 0.43), step(0.5, hash(floor(wpos.xz / 3.0)))) * (1.0 - 0.2 * clamp(line, 0.0, 1.0));
	} else if (kind < 3.5) {
		col = vec3(0.76, 0.68, 0.5) * (0.9 + 0.12 * noise(wpos.xz * 2.0));
		rough = 1.0;
	} else {
		col = vec3(0.2, 0.2, 0.21) * (0.85 + 0.25 * n);
	}
	ALBEDO = col * COLOR.rgb;
	ROUGHNESS = mix(rough, 0.3, wetness * 0.7);
}
