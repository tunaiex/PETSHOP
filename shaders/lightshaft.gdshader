shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Akvaryum lambasından suya süzülen ışık hüzmeleri.
uniform vec3 color : source_color = vec3(0.7, 0.9, 1.0);
uniform float strength = 0.18;
uniform float seed = 0.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }
float noise(float x) {
	float i = floor(x); float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	float x = UV.x;
	float rays = noise(x * 9.0 + seed + TIME * 0.25) * noise(x * 23.0 - seed * 2.0 - TIME * 0.4);
	float fade = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.6, UV.y);
	float edge = smoothstep(0.0, 0.15, x) * smoothstep(1.0, 0.85, x);
	ALBEDO = color * rays * fade * edge * strength;
}
