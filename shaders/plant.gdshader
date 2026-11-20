shader_type spatial;
render_mode cull_disabled;

// Su bitkisi: uca doğru akıntıda sallanır.
uniform vec3 base_color : source_color = vec3(0.1, 0.35, 0.1);
uniform vec3 tip_color : source_color = vec3(0.45, 0.8, 0.25);
uniform float sway = 1.0;

void vertex() {
	float h = UV.y; // 0 dip, 1 uç
	vec3 wp = NODE_POSITION_WORLD;
	float s = sin(TIME * 1.3 + wp.x * 3.0 + wp.z * 2.0 + VERTEX.y * 6.0);
	VERTEX.x += s * 0.025 * h * h * sway;
	VERTEX.z += cos(TIME * 1.1 + wp.x * 2.0 + VERTEX.y * 5.0) * 0.015 * h * h * sway;
}

void fragment() {
	float h = UV.y;
	vec3 col = mix(base_color, tip_color, h);
	// orta damar
	col *= 0.85 + 0.25 * smoothstep(0.1, 0.0, abs(UV.x - 0.5));
	ALBEDO = col;
	ROUGHNESS = 0.55;
	BACKLIGHT = col * 0.6;
}
