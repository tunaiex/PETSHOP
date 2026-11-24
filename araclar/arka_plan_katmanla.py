#!/usr/bin/env python3
"""Blender render'ini (guzel.png + maske_*.png) oyun katmanlarina boler.

Kullanim: python3 -I araclar/arka_plan_katmanla.py RENDER_DIZINI CIKTI_DIZINI
Ciktilar: arka_plan.webp, tas_on.png, kutuk_on.png, yaprak_on.png, konumlar.json
(konumlar: her katmanin 480x480 sahnedeki merkezi -> akvaryum.tscn'deki position)
"""
import json
import sys

from PIL import Image, ImageEnhance, ImageFilter

kaynak, cikti = sys.argv[1].rstrip("/") + "/", sys.argv[2].rstrip("/") + "/"
g = Image.open(kaynak + "guzel.png").convert("RGB")
g = g.filter(ImageFilter.MedianFilter(3))            # Cycles gurultusunu yumusat
g = g.resize((480, 480), Image.LANCZOS)
# Renk ayari: su altı fotograflari gibi biraz daha doygun ve kontrastli
g = ImageEnhance.Color(g).enhance(1.18)
g = ImageEnhance.Contrast(g).enhance(1.08)
g.save(cikti + "arka_plan.webp", quality=92, method=6)

konumlar = {}
for ad, dosya in [("tas", "tas_on.png"), ("kutuk", "kutuk_on.png"), ("on", "yaprak_on.png")]:
    m = Image.open(kaynak + f"maske_{ad}.png").convert("L").resize((480, 480), Image.LANCZOS)
    m = m.point(lambda v: 0 if v < 8 else min(255, int(v * 1.04)))
    katman = g.copy()
    katman.putalpha(m)
    bb = m.point(lambda v: 255 if v > 0 else 0).getbbox()
    katman.crop(bb).save(cikti + dosya, optimize=True)
    konumlar[ad] = {"boyut": [bb[2] - bb[0], bb[3] - bb[1]], "merkez": [(bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2]}
json.dump(konumlar, open(cikti + "konumlar.json", "w"), indent=1)
print(json.dumps(konumlar))
