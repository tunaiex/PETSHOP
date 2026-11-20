shader_type spatial;

// Prosedürel ahşap parke.
uniform vec3 wood_a : source_color = vec3(0.62, 0.45, 0.30);
uniform vec3 wood_b : source_color = vec3(0.48, 0.33, 0.21);
uniform vec2 plank = vec2(1.2, 0.18);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = wp.xz;
	float row = floor(p.y / plank.y);
	float off = hash(vec2(row, 3.0)) * plank.x;
	float col_i = floor((p.x + off) / plank.x);
	vec2 local = vec2(fract((p.x + off) / plank.x), fract(p.y / plank.y));
	float id = hash(vec2(col_i, row));
	float grain = noise(vec2(p.x * 2.0, p.y * 60.0 + id * 10.0)) * 0.6 + noise(vec2(p.x * 9.0, p.y * 140.0)) * 0.4;
	vec3 col = mix(wood_b, wood_a, grain * 0.7 + id * 0.3);
	float seam = smoothstep(0.0, 0.02, local.y) * smoothstep(1.0, 0.98, local.y) * smoothstep(0.0, 0.004, local.x) * smoothstep(1.0, 0.996, local.x);
	col *= mix(0.55, 1.0, seam);
	ALBEDO = col;
	ROUGHNESS = mix(0.45, 0.65, grain);
	SPECULAR = 0.45;
}
