shader_type spatial;

// Duvar: gerçek sıva dokusu (boya rengiyle çarpılır) + alt kısımda ahşap lambri.
uniform vec3 paint : source_color = vec3(0.86, 0.88, 0.84);
uniform vec3 panel : source_color = vec3(0.50, 0.36, 0.24);
uniform float panel_height = 1.0;
uniform sampler2D plaster_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D plaster_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D plaster_rgh : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 0.6;

varying vec3 v_wp;
varying vec3 v_wn;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Dikey yüzeyde yatay koordinat: duvar yönüne göre x ya da z
	float u = abs(v_wn.x) > 0.5 ? v_wp.z : v_wp.x;
	vec2 uv = vec2(u, v_wp.y) * tex_scale;
	vec3 tex = texture(plaster_tex, uv).rgb;
	vec3 col = paint * (0.72 + 0.4 * tex);
	float rough = mix(0.75, 0.95, texture(plaster_rgh, uv).r);
	vec3 nrm = texture(plaster_nrm, uv).rgb;
	if (v_wp.y < panel_height) {
		float slat = smoothstep(0.0, 0.01, fract(u / 0.12)) * smoothstep(1.0, 0.97, fract(u / 0.12));
		float grain = hash(vec2(floor(u / 0.12), floor(v_wp.y * 40.0))) * 0.06;
		col = panel * mix(0.62, 1.0, slat) * (0.9 + hash(vec2(floor(u / 0.12), 1.0)) * 0.15 - grain);
		rough = 0.5;
		nrm = vec3(0.5 + (1.0 - slat) * 0.3, 0.5, 1.0);
	}
	// Lambri üst pervazı ve süpürgelik
	float trim = smoothstep(0.03, 0.0, abs(v_wp.y - panel_height));
	col = mix(col, panel * 1.3, trim);
	float skirt = step(v_wp.y, 0.1);
	col = mix(col, panel * 0.55, skirt);
	ALBEDO = col;
	ROUGHNESS = rough;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 0.45;
}
