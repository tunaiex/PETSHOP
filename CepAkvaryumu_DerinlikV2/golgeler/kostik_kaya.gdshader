shader_type canvas_item;
// Kaya katmanlari: arka planla ayni kostik deseni ustlerine duser.
#include "res://golgeler/kostik.gdshaderinc"

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb += kostik(SCREEN_UV, c.rgb) * c.a;
	COLOR = c;
}
