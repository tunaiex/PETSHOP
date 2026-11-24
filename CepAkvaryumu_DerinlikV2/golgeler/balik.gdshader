shader_type canvas_item;
// 3B baligin 2B goruntusu (SubViewport dokusu, onceden carpilmis alfa).
// Yasam durumuna gore: renk doygunlugu (yavru soluk, halfmoon canli),
// parlaklik (yasli), nesilden gelen renk tonu, hastalikta beyaz benekler.
render_mode blend_premul_alpha;

uniform float doygunluk = 1.0;
uniform float parlaklik = 1.0;
uniform float ton = 0.0;      // -0.5..0.5 tur
uniform float benek = 0.0;    // 0..1 beyaz benek (ich) hastaligi

float karma(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 r = c.rgb / max(c.a, 0.0001);
	// Renk tonu kaydirma (YIQ uzayinda dondurme)
	if (abs(ton) > 0.001) {
		float y = dot(r, vec3(0.299, 0.587, 0.114));
		float i = dot(r, vec3(0.596, -0.274, -0.322));
		float q = dot(r, vec3(0.211, -0.523, 0.312));
		float a = ton * 6.2831853;
		float i2 = i * cos(a) - q * sin(a);
		float q2 = i * sin(a) + q * cos(a);
		r = vec3(y + 0.956 * i2 + 0.621 * q2, y - 0.272 * i2 - 0.647 * q2, y - 1.106 * i2 + 1.703 * q2);
	}
	float l = dot(r, vec3(0.299, 0.587, 0.114));
	r = mix(vec3(l), r, doygunluk) * parlaklik;
	// Beyaz benekler: yalnizca baligin govdesi / yuzgeci uzerinde
	if (benek > 0.001 && c.a > 0.6) {
		vec2 h = UV * 18.0;
		vec2 hucre = floor(h);
		float k = karma(hucre);
		if (k > 0.5) {
			vec2 m = vec2(karma(hucre + 7.1), karma(hucre + 3.3)) * 0.6 + 0.2;
			float d = length(fract(h) - m);
			r = mix(r, vec3(1.0), smoothstep(0.24, 0.10, d) * benek);
		}
	}
	COLOR = vec4(clamp(r, 0.0, 1.5) * c.a, c.a) * COLOR;
}
