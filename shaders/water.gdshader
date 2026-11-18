shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
global uniform float night_factor;
varying vec3 wpos;
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 0.12;
	float t = TIME * 0.35;
	float h1 = noise(p + vec2(t, t * 0.6));
	float h2 = noise(p * 2.3 - vec2(t * 0.8, -t));
	float hx = noise(p + vec2(t, t * 0.6) + vec2(0.05, 0.0)) - h1;
	float hz = noise(p + vec2(t, t * 0.6) + vec2(0.0, 0.05)) - h1;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-hx * 6.0, 1.0, -hz * 6.0)), 0.0)).xyz);
	float shore = smoothstep(1300.0, 1360.0, wpos.z) * 0.0;
	vec3 deep = vec3(0.02, 0.12, 0.2);
	vec3 shallow = vec3(0.05, 0.32, 0.38);
	ALBEDO = mix(deep, shallow, h2 * 0.5) * (1.0 - night_factor * 0.6);
	ROUGHNESS = 0.06;
	METALLIC = 0.2;
	SPECULAR = 0.9;
}
