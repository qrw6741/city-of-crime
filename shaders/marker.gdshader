shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec4 color : source_color = vec4(1.0, 0.7, 0.1, 1.0);
void fragment() {
	float a = UV.y * (0.55 + 0.25 * sin(TIME * 3.0 + UV.y * 6.0));
	ALBEDO = color.rgb;
	ALPHA = a * color.a;
}
