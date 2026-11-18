shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

global uniform float night_factor;
global uniform float wetness;

varying vec3 n_obj;

float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }

void vertex() {
	n_obj = NORMAL;
}

void fragment() {
	vec3 base = COLOR.rgb;
	float style = UV2.y;
	float seed = UV2.x;
	vec2 uv = UV;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
	if (n_obj.y > 0.5) {
		// roof: gravel / concrete with some vents
		float g = hash(floor(uv * 3.0));
		ALBEDO = mix(vec3(0.22, 0.22, 0.23), base * 0.5, 0.35) * (0.85 + 0.15 * g);
		ROUGHNESS = 0.95;
	} else if (n_obj.y < -0.5) {
		ALBEDO = base * 0.25;
	} else {
		vec2 cell = vec2(3.0, 3.4);
		vec2 win = vec2(0.6, 0.55);
		float wfloor = 1.2;
		if (style < 0.5) { cell = vec2(1.7, 3.6); win = vec2(0.94, 0.88); wfloor = 4.0; }
		else if (style < 1.5) { cell = vec2(3.0, 3.6); win = vec2(0.62, 0.55); wfloor = 4.0; }
		else if (style < 2.5) { cell = vec2(4.0, 3.0); win = vec2(0.36, 0.45); wfloor = 1.0; }
		else if (style < 3.5) { cell = vec2(6.0, 9.0); win = vec2(0.7, 0.12); wfloor = 6.0; }
		else if (style < 4.5) { cell = vec2(3.5, 3.0); win = vec2(0.3, 0.42); wfloor = 0.8; }
		else { cell = vec2(3.6, 3.2); win = vec2(0.7, 0.5); wfloor = 4.0; }
		vec2 c = floor(uv / cell);
		vec2 f = fract(uv / cell);
		bool is_win = abs(f.x - 0.5) < win.x * 0.5 && abs(f.y - 0.55) < win.y * 0.5 && uv.y > wfloor;
		vec3 wall = base * (0.92 + 0.08 * hash(c + seed));
		if (style > 2.5 && style < 3.5) {
			// corrugated metal
			wall = base * (0.82 + 0.18 * step(0.5, fract(uv.x * 1.2)));
		}
		if (style > 4.5) {
			// hotel balconies
			if (f.y < 0.12) { wall = vec3(0.95); }
		}
		// anti-aliasing: far away, blend the window grid into its average colour
		vec2 fw = fwidth(uv / cell);
		float blur = clamp(max(fw.x, fw.y) * 3.5 - 0.25, 0.0, 1.0);
		float area = win.x * win.y;
		float h = hash(c + seed * 13.0);
		vec3 glass = mix(vec3(0.05, 0.07, 0.10), vec3(0.28, 0.36, 0.45), 0.25 + 0.5 * h);
		vec3 glass_avg = vec3(0.12, 0.15, 0.19);
		if (style < 0.5) { glass = mix(glass, base * 0.6, 0.4); glass_avg = mix(glass_avg, base * 0.6, 0.4); }
		vec3 warm = mix(vec3(1.0, 0.82, 0.55), vec3(0.75, 0.85, 1.0), step(0.7, h));
		float lit = step(0.74, hash(c * 1.7 + seed)) * night_factor;
		vec3 px_col = is_win ? glass : wall;
		vec3 px_em = is_win ? warm * lit * (0.16 + 0.2 * h) : vec3(0.0);
		vec3 avg_col = mix(wall, glass_avg, area);
		vec3 avg_em = vec3(1.0, 0.85, 0.6) * night_factor * 0.26 * area * 0.25;
		ALBEDO = mix(px_col, avg_col, blur);
		EMISSION = mix(px_em, avg_em, blur);
		if (is_win && blur < 0.5) {
			ROUGHNESS = 0.06;
			METALLIC = 0.5;
			SPECULAR = 0.8;
		}
		// ground-floor storefront band for commercial styles
		if ((style < 1.5 || style > 4.5) && uv.y < 3.6) {
			float sf = fract(uv.x / 6.0);
			if (sf > 0.06 && uv.y > 0.25 && uv.y < 3.0) {
				ALBEDO = vec3(0.07, 0.09, 0.11);
				ROUGHNESS = 0.05;
				METALLIC = 0.4;
				EMISSION = vec3(1.0, 0.9, 0.7) * night_factor * 0.3 * step(0.35, hash(vec2(floor(uv.x / 6.0), seed)));
			} else {
				ALBEDO = base * 0.6;
			}
		}
	}
	ROUGHNESS = mix(ROUGHNESS, ROUGHNESS * 0.4, wetness * 0.6);
}
