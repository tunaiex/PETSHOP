shader_type spatial;
// Iskeletsiz betta modeline yuzme hareketi: govde dalgasi + yuzgec titremesi.
// Model yerel ekseni: bas -Z (z = -0.5), kuyruk +Z (z = +0.5), yukari +Y.
render_mode cull_disabled;

uniform sampler2D doku : source_color, filter_linear_mipmap;
uniform float faz = 0.0;        // betikten ilerletilir; hiz artinca hizlanir
uniform float genlik = 0.05;    // govde kivrilma miktari
uniform float yuzgec = 0.025;   // yuzgec dalgalanmasi

void vertex() {
	// 0 = bas/govde onu, 1 = kuyruk ucu
	float kuyruk = clamp((VERTEX.z + 0.2) / 0.7, 0.0, 1.0);
	VERTEX.x += sin(faz - VERTEX.z * 7.0) * genlik * kuyruk * kuyruk;
	// Bas, kuyruga ters yonde hafifce salinir
	VERTEX.x -= sin(faz) * genlik * 0.2 * (1.0 - kuyruk);
	// Govde ekseninden uzak noktalar (sirt / karin / kuyruk yuzgecleri)
	float kanat = smoothstep(0.12, 0.45, abs(VERTEX.y)) + kuyruk * 0.5;
	VERTEX.x += sin(faz * 0.6 + VERTEX.z * 9.0 + VERTEX.y * 6.0) * yuzgec * kanat;
}

void fragment() {
	ALBEDO = texture(doku, UV).rgb;
	ROUGHNESS = 0.45;
	SPECULAR = 0.6;
	// Pul parlamasi: kenara bakan yuzeylerde hafif mavi isilti
	float kenar = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.05, 0.18, 0.3) * kenar;
}
