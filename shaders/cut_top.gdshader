shader_type spatial;
// Civciv kafesi kapağının ortasını açar: üst kısımda, kenar halkası dışında kalan yüzeyleri çizmez.
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform bool has_tex = true;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float cut_y = 0.95;   // mesh yerel uzayında bu yükseklikten yukarısı
uniform float keep_r = 0.88;  // bu yarıçapın dışı (kenar halkası) kalır
uniform vec2 center = vec2(0.0);
uniform float core_r = 0.0;    // ortadaki direk: bu yarıçapın içi ve core_y üstü çizilmez
uniform float core_y = 0.0;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float r = length(lpos.xz - center);
	if (lpos.y > cut_y && r < keep_r) {
		discard;
	}
	if (r < core_r && lpos.y > core_y) {
		discard;
	}
	vec4 c = has_tex ? texture(albedo_tex, UV) : vec4(1.0);
	ALBEDO = c.rgb * albedo_color.rgb;
	ROUGHNESS = 0.75;
}
