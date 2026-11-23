extends SubViewport
## Gercek 3B betta: GLB modeli bu kucuk SubViewport'ta cizilir, sonuc
## 2B sahnedeki "Balik" Sprite2D'sine doku olarak verilir. Boylece kaya /
## kutuk / yaprak arkasina gecme (z_index) sistemi aynen calismaya devam eder.

const MODEL := preload("res://modeller/beta3d.glb")
const YUZME := preload("res://golgeler/yuzme.gdshader")

var pivot := Node3D.new()
var malzeme := ShaderMaterial.new()
var faz := 0.0
var yalpa := 0.0
var onceki_sapma := 0.0


func _ready() -> void:
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var ortam := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.75, 0.9)
	env.ambient_light_energy = 0.75
	ortam.environment = env
	add_child(ortam)

	# Yukaridan gelen gunes isigi (arka plandaki isik huzmeleriyle uyumlu)
	var isik := DirectionalLight3D.new()
	isik.rotation_degrees = Vector3(-62.0, 20.0, 0.0)
	isik.light_energy = 1.15
	isik.light_color = Color(1.0, 0.97, 0.9)
	add_child(isik)

	var kamera := Camera3D.new()
	kamera.fov = 25.0
	kamera.position = Vector3(0.0, 0.0, 2.9)
	add_child(kamera)

	add_child(pivot)
	var model := MODEL.instantiate()
	pivot.add_child(model)
	_malzemeyi_degistir(model)


func _malzemeyi_degistir(dugum: Node) -> void:
	if dugum is MeshInstance3D:
		var eski := (dugum as MeshInstance3D).get_active_material(0)
		if eski is BaseMaterial3D:
			malzeme.set_shader_parameter("doku", eski.albedo_texture)
		malzeme.shader = YUZME
		dugum.material_override = malzeme
	for cocuk in dugum.get_children():
		_malzemeyi_degistir(cocuk)


## yon: oyunun koordinatinda (x saga, y asagi, z derine). hiz: piksel/sn.
func guncelle(yon: Vector3, hiz: float, delta: float, uyuyor: bool) -> void:
	# Oyun -> 3B: ekran asagisi = -Y, derinlik (cama uzak) = -Z
	var d := Vector3(yon.x, -yon.y, -yon.z)
	if d.length_squared() < 0.0001:
		return
	d = d.normalized()
	var sapma := atan2(-d.x, -d.z)
	var egim := clampf(asin(clampf(d.y, -1.0, 1.0)), -0.45, 0.45)

	# Donerken hafif yana yatma
	var donus := wrapf(sapma - onceki_sapma, -PI, PI) / maxf(delta, 0.001)
	onceki_sapma = sapma
	yalpa = lerpf(yalpa, clampf(-donus * 0.12, -0.35, 0.35), minf(1.0, delta * 3.0))
	pivot.rotation = Vector3(egim, sapma, yalpa)

	var etkinlik := 0.15 if uyuyor else clampf(hiz / 66.0, 0.0, 1.0)
	faz += delta * lerpf(3.0, 13.0, etkinlik)
	malzeme.set_shader_parameter("faz", faz)
	malzeme.set_shader_parameter("genlik", lerpf(0.025, 0.075, etkinlik))
	malzeme.set_shader_parameter("yuzgec", 0.012 if uyuyor else 0.028)
