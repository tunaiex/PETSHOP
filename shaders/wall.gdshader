shader_type spatial;

// Duvar: hafif dokulu boya, alt kısımda ahşap lambri.
uniform vec3 paint : source_color = vec3(0.86, 0.88, 0.84);
uniform vec3 panel : source_color = vec3(0.50, 0.36, 0.24);
uniform float panel_height = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = hash(floor(wp.xy * 300.0) + floor(wp.zy * 300.0)) * 0.03;
	vec3 col = paint - n;
	float rough = 0.9;
	if (wp.y < panel_height) {
		float u = wp.x + wp.z;
		float slat = smoothstep(0.0, 0.01, fract(u / 0.12)) * smoothstep(1.0, 0.97, fract(u / 0.12));
		col = panel * mix(0.6, 1.0, slat) * (0.9 + hash(vec2(floor(u / 0.12), 1.0)) * 0.15);
		rough = 0.55;
	}
	// lambri üst pervazı
	float trim = smoothstep(0.03, 0.0, abs(wp.y - panel_height));
	col = mix(col, panel * 1.25, trim);
	ALBEDO = col;
	ROUGHNESS = rough;
}
