shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Prosedürel balık: yüzerken gövde dalgalanır, desen UV ile çizilir.
// UV.x: burun(0) -> kuyruk ucu(1)  UV.y: alt(0) -> üst(1)
// UV2.x: 0 gövde, 1 yüzgeç

uniform vec3 body_color : source_color = vec3(0.6);
uniform vec3 belly_color : source_color = vec3(0.9);
uniform vec3 accent_color : source_color = vec3(1.0, 0.4, 0.1);
uniform vec3 fin_color : source_color = vec3(1.0, 0.5, 0.3);
uniform float fin_alpha = 0.8;
uniform int pattern = 0;
uniform float fish_len = 0.1;
uniform float swim = 1.0;          // salınım şiddeti (hız)
uniform float phase = 0.0;
uniform float health = 1.0;        // 0 ölü -> gri ve hareketsiz
uniform float sick = 0.0;          // beyaz benekler

varying float v_fin;
varying vec3 v_local;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	v_fin = UV2.x;
	v_local = VERTEX;
	float t = clamp(UV.x, 0.0, 1.0);
	float amp = 0.10 * fish_len * swim * health;
	float w = sin(TIME * (6.0 + 6.0 * swim) + phase - t * 5.5);
	// Baş az, kuyruk çok sallanır
	VERTEX.x += w * amp * (0.15 + t * t * 1.6);
	// Yüzgeçlerde hafif dalga
	VERTEX.y += v_fin * sin(TIME * 4.0 + phase + VERTEX.z * 60.0) * 0.06 * fish_len * health;
}

void fragment() {
	float t = UV.x;
	float h = UV.y;
	vec3 col;
	float a = 1.0;
	if (v_fin > 0.5) {
		col = fin_color;
		// yüzgeç ışınları
		float rays = 0.85 + 0.15 * sin(h * 80.0 + t * 20.0);
		col *= rays;
		if (pattern == 3) col = mix(fin_color, accent_color, smoothstep(0.2, 0.9, t + 0.2 * sin(h * 30.0)));
		a = fin_alpha * (0.75 + 0.25 * (1.0 - t));
	} else {
		// sırt koyu, karın açık
		col = mix(belly_color, body_color, smoothstep(0.25, 0.75, h));
		col *= mix(0.8, 1.05, smoothstep(0.9, 0.5, h));
		if (pattern == 1) { // dikey çizgiler (melek)
			float s = smoothstep(0.55, 0.62, abs(sin(t * 15.0 + 0.6)));
			col = mix(col, accent_color, s * step(0.12, t) * step(t, 0.85) * 0.9);
		} else if (pattern == 2) { // neon şeridi
			float band = smoothstep(0.08, 0.02, abs(h - 0.62)) * step(0.15, t) * step(t, 0.8);
			col = mix(col, accent_color * 1.6, band);
			float red = smoothstep(0.45, 0.55, t) * smoothstep(0.6, 0.35, h) * step(t, 0.82);
			col = mix(col, vec3(0.85, 0.08, 0.06), red * 0.9);
		} else if (pattern == 3) { // renkli arka gövde
			float g = smoothstep(0.45, 0.8, t);
			col = mix(col, accent_color, g * 0.8);
			float blot = smoothstep(0.55, 0.85, sin(t * 47.0) * sin(h * 23.0 + t * 9.0));
			col = mix(col, accent_color * 0.35, blot * g * 0.6);
		} else if (pattern == 4) { // japon: beyaz lekeler
			float n = sin(t * 9.0 + h * 4.0) * sin(h * 7.0 - t * 3.0);
			col = mix(col, accent_color, smoothstep(0.35, 0.5, n) * 0.85);
		} else if (pattern == 5) { // zebra yatay çizgiler
			float s = smoothstep(0.6, 0.7, sin(h * 38.0));
			col = mix(col, accent_color, s * step(0.12, t) * step(h, 0.85) * step(0.2, h));
		} else if (pattern == 6) { // diskus dalgalı çizgiler
			float s = smoothstep(0.55, 0.75, sin(h * 30.0 + sin(t * 18.0) * 1.8));
			col = mix(col, accent_color, s * 0.85);
		}
		// göz
		vec2 eye = vec2(0.09, 0.6);
		float d = length(vec2((t - eye.x) * 2.4, h - eye.y));
		if (d < 0.07) col = mix(vec3(0.9, 0.85, 0.6), vec3(0.01), smoothstep(0.065, 0.035, d));
	}
	// hastalık benekleri
	if (sick > 0.0) {
		float sp = step(1.0 - sick * 0.12, hash(floor(vec2(t * 60.0, h * 25.0))));
		col = mix(col, vec3(1.0), sp);
	}
	vec3 grey = vec3(dot(col, vec3(0.3, 0.59, 0.11)));
	col = mix(grey * 0.7, col, clamp(health * 1.5, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.2;
	ROUGHNESS = v_fin > 0.5 ? 0.6 : 0.32;
	SPECULAR = 0.6;
	// yanardönerlik (pul parlaması)
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = col * fres * 0.25 * (1.0 - v_fin);
	if (pattern == 2) EMISSION += accent_color * 0.5 * smoothstep(0.08, 0.02, abs(h - 0.62)) * step(0.15, t) * step(t, 0.8) * (1.0 - v_fin);
}
