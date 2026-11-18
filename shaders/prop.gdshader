shader_type spatial;
render_mode diffuse_burley;
global uniform float night_factor;
// Vertex colour = albedo. Alpha < 0.5 marks a light that glows at night.
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
	if (COLOR.a < 0.5) {
		EMISSION = COLOR.rgb * (0.3 + night_factor * 4.0);
	}
}
