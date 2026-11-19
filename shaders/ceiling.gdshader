shader_type spatial;

// Asma tavan: 60x60 cm karolar, ince metal ızgara, hafif delikli doku.
uniform vec3 tile_color : source_color = vec3(0.93, 0.93, 0.91);
uniform vec3 grid_color : source_color = vec3(0.78, 0.78, 0.8);
uniform float bounce = 0.32;

varying vec3 v_wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_wp.xz / 0.6;
	vec2 f = fract(p);
	float grid = 1.0 - smoothstep(0.0, 0.02, f.x) * smoothstep(1.0, 0.98, f.x) * smoothstep(0.0, 0.02, f.y) * smoothstep(1.0, 0.98, f.y);
	float dots = step(0.86, hash(floor(v_wp.xz * 90.0)));
	vec3 col = tile_color * (0.97 + hash(floor(p)) * 0.05) - dots * 0.05;
	col = mix(col, grid_color, grid);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.4, grid);
	METALLIC = grid * 0.6;
	// Tavan, aşağı bakan spotlardan doğrudan ışık almaz; gerçekte zeminden seken ışığı taklit et
	EMISSION = col * bounce;
}
