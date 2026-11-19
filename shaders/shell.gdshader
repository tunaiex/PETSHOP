shader_type spatial;

// Kaplumbağa kabuğu: pul plakaları ve koyu çizgiler.
uniform vec3 base_color : source_color = vec3(0.24, 0.27, 0.14);
uniform vec3 plate_color : source_color = vec3(0.36, 0.38, 0.2);

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

void fragment() {
	vec2 p = UV * vec2(6.0, 4.0);
	vec2 n = floor(p);
	vec2 f = fract(p);
	float md = 8.0;
	float md2 = 8.0;
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j));
		vec2 r = g + hash2(n + g) * 0.7 - f;
		float d = dot(r, r);
		if (d < md) { md2 = md; md = d; } else if (d < md2) { md2 = d; }
	}
	float edge = smoothstep(0.02, 0.12, sqrt(md2) - sqrt(md));
	vec3 col = mix(base_color * 0.45, mix(plate_color, base_color, sqrt(md)), edge);
	ALBEDO = col;
	ROUGHNESS = 0.45;
	SPECULAR = 0.6;
}
