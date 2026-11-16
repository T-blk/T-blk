#!/usr/bin/env python3
"""Đóng gói font cho giao diện hiện đại + bảng đo độ rộng chữ.

- Cắt font Inter / JetBrains Mono chỉ còn ký tự Latin + tiếng Việt, đổi CFF -> TrueType (glyf)
  cho chắc ăn với FBInk (stb_truetype).
- Sinh lib/metrics.txt: độ rộng từng ký tự (phần nghìn em) để dash.sh căn giữa / căn phải chính xác.

    python3 tools/make_fonts.py kindle/dashboard
"""
import os
import sys

from fontTools import subset
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont, newTable

I = "/usr/share/fonts/opentype/inter/"
JB = "/usr/share/fonts/truetype/jetbrains-mono/"
FONTS = {  # key: (nguồn, file đích)
    "thin": (I + "InterDisplay-Thin.otf", "Inter-Thin.ttf"),
    "light": (I + "InterDisplay-Light.otf", "Inter-Light.ttf"),
    "reg": (I + "Inter-Regular.otf", "Inter-Regular.ttf"),
    "semi": (I + "Inter-SemiBold.otf", "Inter-SemiBold.ttf"),
    "bold": (I + "Inter-Bold.otf", "Inter-Bold.ttf"),
    "black": (I + "InterDisplay-Black.otf", "Inter-Black.ttf"),
    "mono": (JB + "JetBrainsMono-Light.ttf", "JBMono-Light.ttf"),
}
NOTO = {"nreg": "NotoSans-Regular.ttf", "nbold": "NotoSans-Bold.ttf"}

VI = "ăâđêôơưĂÂĐÊÔƠƯàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ"
CHARS = set(chr(c) for c in range(32, 127)) | set(VI) | set(VI.upper())
CHARS |= set("·–—‘’“”…°′″•×÷±→←↑↓№«»©")
CHARS |= set(chr(c) for c in (0x300, 0x301, 0x303, 0x309, 0x323, 0x302, 0x306, 0x31B))
CHARS.discard("\n")


def to_ttf(font):
    if "CFF " not in font:
        return font
    order = font.getGlyphOrder()
    gs = font.getGlyphSet()
    glyf = newTable("glyf")
    glyf.glyphOrder = order
    glyf.glyphs = {}
    for name in order:
        pen = TTGlyphPen(gs)
        try:
            gs[name].draw(Cu2QuPen(pen, 1.0, reverse_direction=True))
        except Exception:
            pass
        glyf[name] = pen.glyph()
    font["glyf"] = glyf
    font["loca"] = newTable("loca")
    del font["CFF "]
    if "VORG" in font:
        del font["VORG"]
    font["maxp"] = newTable("maxp")
    font["maxp"].tableVersion = 0x00010000
    for a in ("maxZones", "maxTwilightPoints", "maxStorage", "maxFunctionDefs", "maxInstructionDefs",
              "maxStackElements", "maxSizeOfInstructions", "maxComponentElements"):
        setattr(font["maxp"], a, 0)
    font["maxp"].maxZones = 1
    font["head"].glyphDataFormat = 0
    font["post"].formatType = 2.0
    font["post"].extraNames = []
    font["post"].mapping = {}
    font["post"].glyphOrder = order
    font.sfntVersion = "\x00\x01\x00\x00"
    font["glyf"].compile(font)  # tính lại bbox
    font["maxp"].recalc(font)
    return font


def metrics_lines(key, font):
    upm = font["head"].unitsPerEm
    hh = font["hhea"]
    os2 = font["OS/2"]
    cap = getattr(os2, "sCapHeight", 0) or int(upm * 0.72)
    k = (hh.ascent - hh.descent) * 1000 // upm
    out = [f"@\t{key}\t{k}\t{hh.ascent * 1000 // upm}\t{cap * 1000 // upm}"]
    cmap = font.getBestCmap()
    hmtx = font["hmtx"]
    for ch in sorted(CHARS):
        g = cmap.get(ord(ch))
        if g is None or ch in "\t":
            continue
        adv = hmtx[g][0] * 1000 // upm
        out.append(f"{key}\t{ch}\t{adv}")
    return out


def main():
    dst = sys.argv[1] if len(sys.argv) > 1 else "kindle/dashboard"
    fdir = os.path.join(dst, "fonts")
    lines = []
    for key, (src, name) in FONTS.items():
        f = TTFont(src)
        opts = subset.Options()
        opts.layout_features = ["kern", "liga", "tnum", "ccmp", "mark", "mkmk"]
        opts.name_IDs = ["*"]
        opts.notdef_outline = True
        opts.hinting = False
        s = subset.Subsetter(opts)
        s.populate(text="".join(CHARS))
        s.subset(f)
        f = to_ttf(f)
        out = os.path.join(fdir, name)
        f.save(out)
        lines += metrics_lines(key, TTFont(out))
        print(f"{name}: {os.path.getsize(out) // 1024} KB")
    for key, name in NOTO.items():
        lines += metrics_lines(key, TTFont(os.path.join(fdir, name)))
    with open(os.path.join(dst, "lib", "metrics.txt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("metrics:", len(lines), "dòng")


if __name__ == "__main__":
    main()
