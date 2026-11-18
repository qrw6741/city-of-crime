shader_type spatial;
render_mode diffuse_burley;

global uniform float wetness;
varying vec3 wpos;

float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise(wpos.xz * 0.7) * 0.6 + noise(wpos.xz * 3.0) * 0.4;
	vec3 col = vec3(0.13, 0.135, 0.145) * (0.82 + 0.3 * n);
	float u = UV.x;           // across, 0..16
	float v = UV.y;           // along (m)
	float len = UV2.y;
	float kind = UV2.x;
	float rough = 0.9;
	if (kind < 0.5) {
		float d = abs(u - 8.0);
		// double yellow centre line
		if (d > 0.1 && d < 0.26 && v > 5.0 && v < len - 5.0) { col = vec3(0.85, 0.65, 0.1); rough = 0.6; }
		// dashed lane dividers (two lanes each way)
		if (abs(d - 4.0) < 0.08 && fract(v / 6.0) < 0.5 && v > 5.0 && v < len - 5.0) { col = vec3(0.85); rough = 0.6; }
		// edge lines
		if (d > 7.35 && d < 7.5) { col = vec3(0.8); rough = 0.6; }
		// crosswalks
		if ((v < 4.2 && v > 0.6) || (v > len - 4.2 && v < len - 0.6)) {
			if (fract(u / 1.2) < 0.5 && d < 7.3) { col = vec3(0.86); rough = 0.6; }
		}
		// stop line
		if (abs(v - (len - 4.8)) < 0.2 && u < 8.0) { col = vec3(0.9); }
		if (abs(v - 4.8) < 0.2 && u > 8.0) { col = vec3(0.9); }
	} else {
		col *= 0.95;
	}
	// patches and cracks
	col *= 0.92 + 0.08 * step(0.75, noise(wpos.xz * 0.15));
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.12, wetness);
	METALLIC = wetness * 0.15;
	SPECULAR = 0.4 + wetness * 0.4;
}
