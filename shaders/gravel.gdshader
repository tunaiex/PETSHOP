shader_type spatial;

// Çakıl zemin + akvaryum lambasından süzülen kostik ışık.
uniform vec3 color_a : source_color = vec3(0.62, 0.6, 0.55);
uniform vec3 color_b : source_color = vec3(0.32, 0.31, 0.3);
uniform float scale = 70.0;
uniform float caustic_strength = 0.35;
uniform float dirt = 0.0;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Voronoi: x = en yakın uzaklık, y = hücre rastgele değeri
vec2 voronoi(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float md = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j));
		vec2 o = hash2(n + g);
		vec2 r = g + o - f;
		float d = dot(r, r);
		if (d < md) { md = d; id = o.x; }
	}
	return vec2(sqrt(md), id);
}

float caustic(vec2 p, float t) {
	float c = 0.0;
	vec2 v1 = voronoi(p * 6.0 + vec2(t * 0.3, t * 0.2));
	vec2 v2 = voronoi(p * 7.5 - vec2(t * 0.25, -t * 0.15));
	c = pow(1.0 - v1.x, 6.0) + pow(1.0 - v2.x, 6.0);
	return c;
}

varying vec3 v_wp;
varying vec3 v_wn;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Dünya uzayında çizildiği için kutu yüzeylerinde uzama olmaz.
	vec2 wuv = abs(v_wn.y) > 0.5 ? v_wp.xz : vec2(v_wp.x + v_wp.z, v_wp.y);
	vec2 p = wuv * scale;
	vec2 v = voronoi(p);
	float stone = smoothstep(0.55, 0.25, v.x);
	vec3 col = mix(color_b, color_a, v.y);
	col = mix(color_b * 0.55, col, stone);
	col = mix(col, vec3(0.28, 0.33, 0.15), clamp(dirt / 100.0, 0.0, 1.0) * 0.5);
	ALBEDO = col;
	ROUGHNESS = 0.75;
	NORMAL_MAP = vec3(0.5, 0.5, 1.0) + vec3(dFdx(stone), dFdy(stone), 0.0) * 2.0;
	float cs = caustic(wuv * 1.5, TIME) * step(0.5, v_wn.y) * caustic_strength * (1.0 - clamp(dirt / 100.0, 0.0, 1.0) * 0.8);
	EMISSION = vec3(0.7, 0.9, 1.0) * cs;
}
