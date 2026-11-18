shader_type spatial;
render_mode diffuse_burley;
varying vec3 wpos;
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float g = noise(wpos.xz * 0.08) * 0.5 + noise(wpos.xz * 0.9) * 0.3 + noise(wpos.xz * 4.0) * 0.2;
	vec3 grass = mix(vec3(0.16, 0.30, 0.10), vec3(0.36, 0.42, 0.18), g);
	vec3 dirt = vec3(0.42, 0.36, 0.26) * (0.8 + 0.3 * g);
	vec3 col = mix(grass, dirt, smoothstep(0.62, 0.75, noise(wpos.xz * 0.03)));
	// beach sand toward the south coast
	float sand = smoothstep(1286.0, 1292.0, wpos.z);
	col = mix(col, vec3(0.76, 0.68, 0.5) * (0.92 + 0.1 * g), sand);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
