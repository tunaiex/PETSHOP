// Kumda / kayalarda kayan su isigi desenleri (kostik). Arka plan ve kaya
// katmanlari ayni fonksiyonu kullanir; konum ekran koordinatindan (SCREEN_UV)
// zemin duzlemine perspektifle izdusurulur: yakinda iri, uzakta sik desen.
// Maliyet: piksel basina 2 doku okumasi.

uniform sampler2D kostik_dokusu : repeat_enable, filter_linear_mipmap;
uniform float kostik_guc = 0.35;   // betikten: isik kapali = 0, kirli su = zayif
uniform float ufuk = 0.50;         // ekranda zeminin ufuk cizgisi (SCREEN_UV.y)
uniform float kostik_olcek = 2.6;
uniform float katman_carpani = 1.0; // kayalarda daha zayif (dik yuzeyler)

vec3 kostik(vec2 suv, vec3 alt_renk) {
	float dv = suv.y - ufuk;
	if (dv < 0.02 || kostik_guc <= 0.001) {
		return vec3(0.0);
	}
	float gz = 0.35 / dv;                              // zemin derinligi
	vec2 g = vec2((suv.x - 0.5) * gz, gz) * kostik_olcek;
	// Cizgileri kivir: koseli hucreler yerine akiskan desen
	g += vec2(sin(g.y * 2.3 + TIME * 0.8), cos(g.x * 1.9 + TIME * 0.6)) * 0.05;
	float t1 = texture(kostik_dokusu, g + vec2(TIME * 0.030, TIME * 0.018)).r;
	float t2 = texture(kostik_dokusu, g * 1.37 + vec2(-TIME * 0.024, TIME * 0.029)).r;
	// Iki desenin kesistigi yerler parlak benekler, digerleri ince ag
	float k = min(t1, t2) * 1.7 + t1 * t2 * 1.3 + max(t1, t2) * 0.12;
	float uzak = smoothstep(0.02, 0.15, dv);           // ufukta, siste soner
	// Golgede ve bitkilerin koyu yerlerinde zayif, gunes alan kumda guclu
	float aydinlik = clamp(dot(alt_renk, vec3(0.35, 0.5, 0.15)) * 2.4, 0.0, 1.0);
	return vec3(1.0, 0.97, 0.86) * k * kostik_guc * uzak * aydinlik * katman_carpani;
}
