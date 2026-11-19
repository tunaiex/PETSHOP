shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, shadows_disabled, cull_back;

// Eşya ve karakterlerin altındaki yumuşak temas gölgesi (zemine yatay düzlem).
uniform float strength = 0.45;
uniform float softness = 0.6;

void fragment() {
	vec2 d = abs(UV - vec2(0.5)) * 2.0;
	// yuvarlatılmış dikdörtgen mesafesi
	vec2 q = max(d - vec2(1.0 - softness), vec2(0.0)) / softness;
	float a = 1.0 - clamp(length(q), 0.0, 1.0);
	ALBEDO = vec3(0.0);
	ALPHA = a * a * strength;
}
