shader_type spatial;
// Kafes teli: ince ızgara, aralar tamamen şeffaf (alpha scissor, sıralama derdi yok)
render_mode cull_disabled;

uniform vec3 wire_color : source_color = vec3(0.12, 0.12, 0.13);
uniform float cells_u = 160.0;
uniform float cells_v = 22.0;
uniform float thickness = 0.12;

void fragment() {
	vec2 g = fract(UV * vec2(cells_u, cells_v));
	float lx = step(g.x, thickness);
	float ly = step(g.y, thickness * 0.7);
	float wire = max(lx, ly);
	if (wire < 0.5) {
		discard;
	}
	ALBEDO = wire_color;
	METALLIC = 0.6;
	ROUGHNESS = 0.4;
}
