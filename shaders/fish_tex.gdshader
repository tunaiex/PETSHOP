shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Hazır (dokulu) balık modelleri için yüzme hareketi.
// Model animasyonsuz geldiği için gövde, baştan kuyruğa doğru artan bir dalga ile kıvrılır.
// Eksenler modelin kendi (mesh) uzayındadır.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool has_tex = true;
uniform float roughness = 0.45;
uniform vec3 tail_axis = vec3(0.0, 0.0, -1.0);  // baştan kuyruğa
uniform vec3 side_axis = vec3(1.0, 0.0, 0.0);   // sağa-sola salınım yönü
uniform vec3 center = vec3(0.0);
uniform float half_len = 0.5;
uniform float swim = 1.0;
uniform float phase = 0.0;
uniform float health = 1.0;
uniform float sick = 0.0;
uniform float rare = 0.0;          // nadir mutasyon: altın/sedef parıltı
uniform float upright = 0.0;   // deniz atı: yan salınım yerine hafif sallanma

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

varying vec3 v_obj;

void vertex() {
	v_obj = VERTEX;
	float t = clamp(0.5 + dot(VERTEX - center, tail_axis) / (2.0 * half_len), 0.0, 1.0);
	float amp = 0.11 * half_len * 2.0 * swim * health * (1.0 - upright * 0.7);
	float w = sin(TIME * (6.0 + 6.0 * swim) + phase - t * 5.5);
	VERTEX += side_axis * w * amp * (0.12 + t * t * 1.5);
}

void fragment() {
	vec4 c = albedo_color;
	if (has_tex) c *= texture(albedo_tex, UV);
	vec3 col = c.rgb;
	if (sick > 0.0) {
		float sp = step(1.0 - sick * 0.12, hash(floor(v_obj.xy * 90.0 + v_obj.zz * 45.0)));
		col = mix(col, vec3(1.0), sp);
	}
	if (rare > 0.0) {
		float lum = dot(col, vec3(0.3, 0.59, 0.11));
		col = mix(col, vec3(1.0, 0.82, 0.35) * (0.6 + lum), 0.65);
	}
	vec3 grey = vec3(dot(col, vec3(0.3, 0.59, 0.11)));
	col = mix(grey * 0.7, col, clamp(health * 1.5, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = roughness;
	SPECULAR = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = col * fres * 0.2 + rare * vec3(1.0, 0.8, 0.4) * (0.15 + 0.15 * sin(TIME * 3.0 + v_obj.x * 20.0));
}
