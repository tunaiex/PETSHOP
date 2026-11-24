shader_type canvas_item;
// Arka plan (Blender render'i) uzerindeki canli su efektleri:
//  1) Ustte su yuzeyi hafifce dalgalanir ve isildar (UV.y < bant_sonu).
//  2) Bitki bandi (vallisneria) akintida sallanir: dipte sabit, uclara
//     dogru artan, yavas ve dalgali yatay kayma. Bilek donusu (akinti) eger.
//  3) Kum zemine su yuzeyinden suzulen hareketli isik (kostik) duser.
#include "res://golgeler/kostik.gdshaderinc"

uniform float bant_sonu = 0.27;   // resmin ust %27'si (su yuzeyi)
uniform float guc = 0.0045;       // yuzey kirilma miktari (UV)
uniform float hiz = 0.55;
uniform float isilti = 0.07;      // yuzeyde gezinen parlak benekler

uniform float bitki_dip = 0.60;   // bitkilerin dibi (burada sallanma 0)
uniform float bitki_uc = 0.16;    // bitkilerin ucu (en cok sallanan yer)
uniform float sallanma = 0.016;   // en fazla yatay kayma (UV, uclarda ~7 px)
uniform float akinti = 0.0;       // betikten: bilek donusu akintisi (-1..1)

void fragment() {
	vec2 uv = UV;
	float t = TIME * hiz;

	// --- Bitkiler: dipten uca artan sallanma ---
	float boy = smoothstep(bitki_dip, bitki_uc, uv.y) * smoothstep(0.05, bitki_uc, uv.y);
	if (boy > 0.001) {
		float dalga = sin(TIME * 1.1 + uv.y * 6.0 + uv.x * 2.5) * 0.7
			+ sin(TIME * 1.9 + uv.y * 11.0 - uv.x * 4.0) * 0.3;
		uv.x += (dalga + akinti * 1.5) * sallanma * pow(boy, 1.5);
	}

	// --- Su yuzeyi ---
	float w = 1.0 - smoothstep(bant_sonu * 0.45, bant_sonu, uv.y);
	if (w > 0.001) {
		vec2 o = vec2(
			sin(uv.y * 70.0 + t * 2.3) + 0.6 * sin(uv.x * 23.0 - t * 1.7),
			cos(uv.x * 41.0 + t * 1.9) + 0.5 * sin((uv.x + uv.y) * 31.0 + t * 1.3)
		);
		uv += o * guc * w;
	}
	vec4 c = texture(TEXTURE, uv);
	if (w > 0.001) {
		float s = sin(uv.x * 38.0 + TIME * 1.3) * sin(uv.y * 90.0 - TIME * 1.05 + sin(uv.x * 12.0 + TIME * 0.7) * 2.0);
		c.rgb += vec3(0.75, 0.95, 1.0) * pow(max(s, 0.0), 3.0) * isilti * w;
	}

	// --- Kumda kostik ---
	c.rgb += kostik(SCREEN_UV, UV, c.rgb) * c.a;
	COLOR = c;
}
