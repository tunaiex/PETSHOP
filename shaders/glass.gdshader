shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

// Akvaryum camı: kenardan bakınca daha yeşil ve yansıtıcı.
uniform vec3 tint : source_color = vec3(0.75, 0.9, 0.88);
uniform float algae = 0.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 alg = vec3(0.35, 0.5, 0.2);
	ALBEDO = mix(tint, alg, algae * 0.6);
	ALPHA = clamp(0.04 + fres * 0.55 + algae * 0.25, 0.0, 0.9);
	METALLIC = 0.0;
	ROUGHNESS = 0.03;
	SPECULAR = 0.9;
}
