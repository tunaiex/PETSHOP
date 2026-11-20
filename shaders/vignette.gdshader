shader_type canvas_item;

// Ekran kenarlarını hafifçe karartır (sinematik his).
uniform float strength = 0.35;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float v = smoothstep(0.45, 0.95, length(d * vec2(1.0, 0.85)) * 1.25);
	COLOR = vec4(0.0, 0.0, 0.0, v * strength);
}
