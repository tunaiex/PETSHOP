#!/usr/bin/env python3
"""GLB'yi saat icin hafifletir: dokulari kucultur, kullanilmayan UV kanallarini atar.

Kullanim: python3 -I araclar/glb_optimize.py girdi.glb cikti.glb [doku_boyutu]
Varsayilan doku boyutu 512 (balik ekranda en fazla ~220 piksel).
"""
import io
import json
import struct
import sys

from PIL import Image


def oku(yol):
    d = open(yol, "rb").read()
    magic, _, _ = struct.unpack("<4sII", d[:12])
    assert magic == b"glTF", "GLB degil"
    jl, _ = struct.unpack("<I4s", d[12:20])
    js = json.loads(d[20:20 + jl])
    bl, _ = struct.unpack("<I4s", d[20 + jl:28 + jl])
    return js, d[28 + jl:28 + jl + bl]


def yaz(yol, js, parcalar):
    # parcalar: bufferView sirasina gore bayt dizileri; yeniden paketlenir
    bin_ = bytearray()
    for i, p in enumerate(parcalar):
        while len(bin_) % 4:
            bin_ += b"\0"
        js["bufferViews"][i]["byteOffset"] = len(bin_)
        js["bufferViews"][i]["byteLength"] = len(p)
        bin_ += p
    while len(bin_) % 4:
        bin_ += b"\0"
    js["buffers"] = [{"byteLength": len(bin_)}]
    jb = json.dumps(js, separators=(",", ":")).encode()
    while len(jb) % 4:
        jb += b" "
    toplam = 12 + 8 + len(jb) + 8 + len(bin_)
    with open(yol, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, toplam))
        f.write(struct.pack("<I4s", len(jb), b"JSON") + jb)
        f.write(struct.pack("<I4s", len(bin_), b"BIN\0") + bin_)


def main():
    girdi, cikti = sys.argv[1], sys.argv[2]
    boyut = int(sys.argv[3]) if len(sys.argv) > 3 else 512
    js, bin_ = oku(girdi)
    bvs = js["bufferViews"]
    parcalar = [bytes(bin_[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]) for v in bvs]

    # 1) Dokulari kucult
    for im in js.get("images", []):
        i = im["bufferView"]
        res = Image.open(io.BytesIO(parcalar[i]))
        if max(res.size) > boyut:
            res = res.resize((boyut, boyut), Image.LANCZOS)
        cik = io.BytesIO()
        res.save(cik, "PNG", optimize=True)
        parcalar[i] = cik.getvalue()
        im["mimeType"] = "image/png"

    # 2) Malzemelerin kullanmadigi UV kanallarini (TEXCOORD_1, _2) kaldir
    kullanilan = {0}
    def tara(o):
        if isinstance(o, dict):
            if "index" in o and "texCoord" in o:
                kullanilan.add(o["texCoord"])
            for v in o.values():
                tara(v)
        elif isinstance(o, list):
            for v in o:
                tara(v)
    tara(js.get("materials", []))
    for m in js["meshes"]:
        for p in m["primitives"]:
            for ad in list(p["attributes"]):
                if ad.startswith("TEXCOORD_") and int(ad.split("_")[1]) not in kullanilan:
                    del p["attributes"][ad]

    # 3) Artik hicbir accessor'un kullanmadigi bufferView'leri bosalt
    kullanilan_ac = set()
    for m in js["meshes"]:
        for p in m["primitives"]:
            kullanilan_ac.update(p["attributes"].values())
            if "indices" in p:
                kullanilan_ac.add(p["indices"])
    for s in js.get("skins", []):
        if "inverseBindMatrices" in s:
            kullanilan_ac.add(s["inverseBindMatrices"])
    for a in js.get("animations", []):
        for smp in a["samplers"]:
            kullanilan_ac.update([smp["input"], smp["output"]])
    gerekli_bv = {im["bufferView"] for im in js.get("images", [])}
    for i, a in enumerate(js["accessors"]):
        if i in kullanilan_ac and "bufferView" in a:
            gerekli_bv.add(a["bufferView"])
    for i in range(len(parcalar)):
        if i not in gerekli_bv:
            parcalar[i] = b""

    yaz(cikti, js, parcalar)
    print(f"{girdi}: {len(bin_)//1024} KB -> {cikti}: {sum(map(len, parcalar))//1024} KB, doku {boyut}px")


if __name__ == "__main__":
    main()
