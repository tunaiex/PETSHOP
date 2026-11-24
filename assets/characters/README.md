# Tamagotchi karakterleri (3D, rigli)

| Karakter | Kemik | Animasyon |
|---|---|---|
| Bebek | 44 | 8 |
| Genc  | 39 | 8 |
| Yasli | 47 | 8 |

Her klasörde:
- `*.glb` – Godot / Three.js / Unity (glTFast) için, doku gömülü
- `*.fbx` – Unity / Unreal için, doku gömülü
- `*.blend` – Blender kaynak dosyası (doku paketli)
- `*_texture.png` – 2048x2048 doku

**Animasyonlar (döngülü):** Idle, Happy, Wave, Eat, Sad, Sleep, Walk, Dance

**Kemikler:** Root, Hips, Spine/Spine1/Spine2, Neck, Head, Shoulder/UpperArm/ForeArm/Hand/Fingers1-2 (.L/.R),
UpperLeg/LowerLeg/Foot/Toes (.L/.R), Belly, Hat1-3, Pompom, saç zincirleri (Hair*, HairSide*, HairPuff*, HairBack1-4),
Bebek: Bow, Pacifier, HairBun · Yaşlı: Scarf1-3, Skirt.L/R/F/B 1-2.

Saç zincirleri tüm animasyonlarda gecikmeli dalga hareketi yapar (hareket arttıkça genlik artar).

Önizleme: `onizleme.html` dosyasını bir yerel sunucuyla açın (`python3 -m http.server`).
Üretim betikleri: `tools/character_rig/` (bpy + 4 yönlü görsellerden visual hull + projeksiyon bake).
