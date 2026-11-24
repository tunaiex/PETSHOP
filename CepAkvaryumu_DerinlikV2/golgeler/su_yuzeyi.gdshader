shader_type canvas_item;
// Arka plandaki su yuzeyini hafifce dalgalandirir. Yalnizca ust bantta
// (UV.y < bant_sonu) etkili; altinda resim oldugu gibi kalir.
// Piksel basina tek doku okumasi + birkac sin: saat icin ucuz.

uniform float bant_sonu = 0.27;   // resmin ust %27'si (su yuzeyi)
uniform float guc = 0.0045;       // kirilma miktari (UV)
uniform float hiz = 0.55;
uniform float isilti = 0.07;      // gezinen parlak beneklerin gucu

void fragment() {
	vec2 uv = UV;
	// En ustte tam, bandin sonuna dogru sifira iner
	float w = 1.0 - smoothstep(bant_sonu * 0.45, bant_sonu, uv.y);
	if (w > 0.001) {
		float t = TIME * hiz;
		vec2 o = vec2(
			sin(uv.y * 70.0 + t * 2.3) + 0.6 * sin(uv.x * 23.0 - t * 1.7),
			cos(uv.x * 41.0 + t * 1.9) + 0.5 * sin((uv.x + uv.y) * 31.0 + t * 1.3)
		);
		uv += o * guc * w;
	}
	vec4 c = texture(TEXTURE, uv);
	if (w > 0.001) {
		// Dalga tepelerinde gezinen yumusak isiltilar
		float s = sin(uv.x * 38.0 + TIME * 1.3) * sin(uv.y * 90.0 - TIME * 1.05 + sin(uv.x * 12.0 + TIME * 0.7) * 2.0);
		c.rgb += vec3(0.75, 0.95, 1.0) * pow(max(s, 0.0), 3.0) * isilti * w;
	}
	COLOR = c;
}
