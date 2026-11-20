shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

// Su hacmi: kirlendikçe bulanıklaşır ve yeşile/kahveye döner.
uniform vec3 clean_color : source_color = vec3(0.55, 0.85, 0.9);
uniform vec3 dirty_color : source_color = vec3(0.35, 0.42, 0.18);
uniform float dirt = 0.0;
uniform bool is_surface = false;

void vertex() {
	if (is_surface) {
		VERTEX.y += sin(VERTEX.x * 18.0 + TIME * 1.6) * 0.004 + cos(VERTEX.z * 22.0 + TIME * 1.3) * 0.004;
	}
}

void fragment() {
	float d = clamp(dirt / 100.0, 0.0, 1.0);
	vec3 col = mix(clean_color, dirty_color, smoothstep(0.2, 0.9, d));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = col;
	if (is_surface) {
		ALPHA = 0.18 + 0.32 * fres;
		ROUGHNESS = 0.02;
		SPECULAR = 1.0;
		NORMAL_MAP = vec3(0.5 + 0.08 * sin(UV.x * 40.0 + TIME * 2.0), 0.5 + 0.08 * cos(UV.y * 35.0 + TIME * 1.7), 1.0);
	} else {
		ALPHA = 0.05 + d * 0.55 + fres * 0.06;
		ROUGHNESS = 0.1;
		SPECULAR = 0.3;
	}
	EMISSION = col * 0.04;
}
