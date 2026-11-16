#!/usr/bin/env python3
"""Chuẩn bị ảnh cho Kindle Dashboard (chạy trên Mac/PC).

Tạo các cỡ ảnh PNG thang xám (định dạng `eips -g` đọc được):
  photos/*.png           298x250   khung ảnh, bố cục dọc
  photos/land/*.png      454x270   khung ảnh, bố cục ngang
  photos/full/*.png      758x1024  xem toàn màn hình, dọc
  photos/fullland/*.png  1024x758  xem toàn màn hình, ngang
  photos/thumb/*.png     150x150   ảnh nhỏ cho trang chọn ảnh
  photos/v/RxC[m]/*.png  cỡ riêng cho từng ô ảnh x kiểu hiển thị (tràn, polaroid, tròn, nhãn, bìa)
                         m: r = bo góc (thẻ), t = bo 2 góc trên, c = tròn
  photos/captions.txt    chú thích (tên file gốc, giữ dấu tiếng Việt)
  photos/status/*.png    ảnh riêng cho màn hình trạng thái, lấy từ thư mục con "trangthai"
                         (đặt tên theo mã: taptrung hop goidien roidi toilet cafe antrua ngutrua vengay,
                          vd toilet.jpg, toilet_2.png — nhiều ảnh thì mỗi lần vào đổi một ảnh)

    python3 tools/prepare_photos.py ~/Pictures/cho-kindle kindle/dashboard/photos [--preview THƯ_MỤC_XEM_TRƯỚC]

Thư mục nguồn (them-anh.command tạo sẵn):
  1-anh-khung/            ảnh cho ô ảnh, xem toàn màn hình, bố cục Thẻ / Ảnh lớn
  2-trang-thai/<mã>/      ảnh riêng cho từng màn hình trạng thái (anime, meme... của bạn)
"""
import os
import re
import sys
import unicodedata

from PIL import Image, ImageOps, ImageEnhance

SIZES = {"": (298, 250), "land": (454, 270), "full": (758, 1024), "fullland": (1024, 758), "thumb": (150, 150)}
# Ô ảnh của các bố cục: (rộng, cao, mặt nạ khi "tràn khung")  — khớp với lib/layouts.sh
SLOTS = [(298, 250, ""), (341, 250, "r"), (758, 600, "")]
CARD_BG = 238          # nền xám của bố cục Thẻ (GRAYE)
RADIUS = 26


def variants():
    out = set()
    for w, h, mk in SLOTS:
        tm = "t" if mk == "r" else ""
        d = min(w, h) - 10
        out |= {(w, h, mk), (w - 28, h - 72, ""), (d, d, "c"), (w, h - 50, tm), (w, h - 70, tm)}
    return sorted(out)


HERE = os.path.dirname(os.path.abspath(__file__))
DASH = os.path.join(HERE, "..", "kindle", "dashboard")


def eink(img):
    """Tối ưu cho màn e-ink 16 mức xám: kéo giãn tương phản, làm nét nhẹ."""
    from PIL import ImageFilter
    img = ImageOps.autocontrast(img, cutoff=1)
    return img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))


def save_eink(im, path):
    """Lưu PNG đã khuếch tán điểm (dither) về đúng 16 mức xám màn Kindle hiển thị được -> không bị loang mảng."""
    pal = Image.new("P", (1, 1))
    levels = [i * 17 for i in range(16)]
    pal.putpalette(sum(([v, v, v] for v in levels), []) + [0, 0, 0] * 240)
    q = im.convert("RGB").quantize(palette=pal, dither=Image.Dither.FLOYDSTEINBERG)
    q.convert("L").save(path, "PNG", optimize=True)


def masked(img, w, h, mk):
    from PIL import ImageDraw
    out = ImageOps.fit(img, (w, h), Image.LANCZOS)
    if not mk:
        return out
    m = Image.new("L", (w * 4, h * 4), 0)
    dr = ImageDraw.Draw(m)
    if mk == "c":
        dr.ellipse((0, 0, w * 4 - 1, h * 4 - 1), fill=255)
        bg = 255
    else:
        r = RADIUS * 4
        dr.rounded_rectangle((0, 0, w * 4 - 1, h * 4 - 1 + (r if mk == "t" else 0)), radius=r, fill=255)
        bg = CARD_BG
    m = m.resize((w, h), Image.LANCZOS)
    base = Image.new("L", (w, h), bg)
    base.paste(out, (0, 0), m)
    return base


EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".tif", ".tiff", ".heic"}


def collect(paths):
    for p in paths:
        if os.path.isdir(p):
            for name in sorted(os.listdir(p)):
                if os.path.splitext(name)[1].lower() in EXTS:
                    yield os.path.join(p, name)
        else:
            yield p


def out_name(src, used):
    """Tên ảnh ổn định theo tên file gốc (ASCII, không dấu cách) để ảnh "cố định" không bị đổi."""
    stem = os.path.splitext(os.path.basename(src))[0]
    stem = stem.replace("đ", "d").replace("Đ", "D")
    stem = unicodedata.normalize("NFKD", stem).encode("ascii", "ignore").decode()
    stem = re.sub(r"[^A-Za-z0-9_-]+", "_", stem).strip("_")[:40] or "anh"
    name, k = stem, 2
    while name.lower() in used:
        name, k = f"{stem}_{k}", k + 1
    used.add(name.lower())
    return name + ".png"


def convert(src, dst_dir, name):
    img = Image.open(src)
    img = eink(ImageOps.exif_transpose(img).convert("L"))
    for sub, box in SIZES.items():
        d = os.path.join(dst_dir, sub) if sub else dst_dir
        os.makedirs(d, exist_ok=True)
        if sub.startswith("full"):
            out = ImageOps.pad(img, box, Image.LANCZOS, color=255)   # giữ trọn ảnh, viền trắng
        else:
            out = ImageOps.fit(img, box, Image.LANCZOS)              # cắt giữa cho đầy khung
        save_eink(out, os.path.join(d, name))
    for w, h, mk in variants():
        d = os.path.join(dst_dir, "v", f"{w}x{h}{mk}")
        os.makedirs(d, exist_ok=True)
        save_eink(masked(img, w, h, mk), os.path.join(d, name))


def caption(src):
    stem = unicodedata.normalize("NFC", os.path.splitext(os.path.basename(src))[0])
    stem = re.sub(r"^(IMG|DSC|DSCN|PXL|P)[_-]?\d+[_-]?", "", stem, flags=re.I)
    stem = re.sub(r"[_]+", " ", stem).strip()
    stem = re.sub(r"\s+(\d{4})$", r" · \1", stem)
    return stem.replace("|", "/")


STATUS_IDS = ["taptrung", "hop", "goidien", "roidi", "toilet", "cafe", "antrua", "ngutrua", "vengay"]


def status_sources(srcdirs):
    """(mã, file) từ  2-trang-thai/<mã>/*  và kiểu cũ  trangthai/<mã>*.jpg"""
    for sd in srcdirs:
        new = os.path.join(sd, "2-trang-thai")
        if os.path.isdir(new):
            for sid in STATUS_IDS:
                d = os.path.join(new, sid)
                if os.path.isdir(d):
                    for f in collect([d]):
                        yield sid, f
        old = os.path.join(sd, "trangthai")
        if os.path.isdir(old):
            for f in collect([old]):
                b = os.path.basename(f).lower()
                sid = next((x for x in STATUS_IDS if b.startswith(x)), None)
                if sid:
                    yield sid, f
                else:
                    print(f"bỏ qua {b}: tên phải bắt đầu bằng một mã {STATUS_IDS}")


def convert_status(srcdirs, dst, previews=None):
    n = 0
    cnt = {}
    for sid, src in status_sources(srcdirs):
        try:
            img = eink(ImageOps.exif_transpose(Image.open(src)).convert("L"))
        except Exception as e:
            print(f"bỏ qua {src}: {e}")
            continue
        cnt[sid] = cnt.get(sid, 0) + 1
        name = f"{sid}_{cnt[sid]:02d}.png"
        for d, box in ((os.path.join(dst, "status"), (758, 560)), (os.path.join(dst, "status", "land"), (580, 650))):
            os.makedirs(d, exist_ok=True)
            save_eink(ImageOps.pad(img, box, Image.LANCZOS, color=255), os.path.join(d, name))
        if previews is not None:
            previews.append(("status", sid, os.path.join(dst, "status", name), os.path.basename(src)))
        n += 1
        print(f"-> trạng thái {STATUS_NAMES[sid]}: {os.path.basename(src)}")
    return n


# ---------- Xem trước: vẽ lại đúng như màn hình Kindle ----------
STATUS_NAMES = {"taptrung": "Đang tập trung", "hop": "Đang họp", "goidien": "Đang nghe điện thoại",
                "roidi": "Ra ngoài một chút", "toilet": "Toilet time", "cafe": "Cà phê thư giãn",
                "antrua": "Đi ăn trưa", "ngutrua": "Ngủ trưa", "vengay": "Tan làm rồi"}


def _font(name, px):
    from PIL import ImageFont
    f = os.path.join(DASH, "fonts", name)
    try:
        return ImageFont.truetype(f, int(px / 1.21))
    except OSError:
        return ImageFont.load_default()


def _center(d, y, text, f, fill, W=758, maxw=678):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=f) <= maxw or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    for ln in lines[:3]:
        d.text(((W - d.textlength(ln, font=f)) / 2, y), ln, font=f, fill=fill)
        y += int(f.size * 1.25)


def hook_for(sid):
    try:
        for ln in open(os.path.join(DASH, "lib", "hooks.txt"), encoding="utf-8"):
            if ln.startswith(sid + "|"):
                return ln.split("|", 1)[1].strip()
    except OSError:
        pass
    return ""


def preview_status(sid, path):
    from PIL import ImageDraw
    W, H = 758, 1024
    im = Image.new("L", (W, H), 255)
    d = ImageDraw.Draw(im)
    d.text((40, 26), "14:24  ·  từ 14:24 · đã 0 phút", font=_font("Inter-SemiBold.ttf", 24), fill=102)
    p = Image.open(path)
    iy = max(72, 80 + (560 - p.height) // 2)
    im.paste(p, ((W - p.width) // 2, iy))
    y = max(560, iy + p.height + 34)
    _center(d, y, STATUS_NAMES[sid], _font("Inter-SemiBold.ttf", 60), 0)
    _center(d, y + 92, hook_for(sid), _font("Inter-Light.ttf", 36), 102)
    fd = os.path.join(DASH, "ui", "flora_div.png")
    if os.path.exists(fd):
        im.paste(Image.open(fd), ((W - 420) // 2, H - 120))
    _center(d, H - 64, "Chạm để quay lại  ·  vuốt ngang: câu khác", _font("Inter-Regular.ttf", 18), 153)
    return im


def preview_photo(dst, name, cap):
    from PIL import ImageDraw
    W, H = 758, 1024
    im = Image.new("L", (W, H), 255)
    d = ImageDraw.Draw(im)
    v = lambda k: Image.open(os.path.join(dst, "v", k, name))
    im.paste(v("758x600"), (0, 0))
    d.text((40, 630), "Bố cục Ảnh lớn", font=_font("Inter-SemiBold.ttf", 24), fill=0)
    d.text((40, 664), cap, font=_font("Inter-Light.ttf", 22), fill=102)
    im.paste(Image.new("L", (370, 330), 238), (0, 694))
    im.paste(v("341x250r"), (14, 724))
    im.paste(v("240x240c"), (420, 704))
    for x, t in ((14, "Thẻ (bo góc)"), (420, "Tròn")):
        d.text((x, 990), t, font=_font("Inter-Regular.ttf", 20), fill=102)
    return im


def write_previews(items, dst, outdir):
    os.makedirs(outdir, exist_ok=True)
    for f in os.listdir(outdir):
        if f.endswith(".png"):
            os.remove(os.path.join(outdir, f))
    shots = []
    for kind, a, b, src in items:
        if kind == "status":
            im = preview_status(a, b)
            fn = f"trang-thai_{os.path.basename(b)}"
        else:
            im = preview_photo(dst, a, b)
            fn = f"anh_{a}"
        im.save(os.path.join(outdir, fn), optimize=True)
        shots.append(im)
    if shots:  # bảng tổng hợp
        cols = 4
        tw, th = 252, 340
        rows = (len(shots) + cols - 1) // cols
        sheet = Image.new("L", (cols * (tw + 12) + 12, rows * (th + 12) + 12), 180)
        for i, s in enumerate(shots):
            t = s.copy()
            t.thumbnail((tw, th), Image.LANCZOS)
            sheet.paste(t, (12 + (i % cols) * (tw + 12), 12 + (i // cols) * (th + 12)))
        sheet.save(os.path.join(outdir, "00-tong-hop.png"), optimize=True)
    print(f"Xem trước: {outdir}")


def photo_sources(srcs):
    """Ảnh khung: thư mục 1-anh-khung/ (và ảnh để thẳng ở thư mục gốc như kiểu cũ)."""
    out = []
    for p in srcs:
        if os.path.isdir(p):
            out += list(collect([p]))
            k = os.path.join(p, "1-anh-khung")
            if os.path.isdir(k):
                out += list(collect([k]))
        else:
            out.append(p)
    return out


def main():
    args = sys.argv[1:]
    prev = None
    if "--preview" in args:
        i = args.index("--preview")
        prev = args[i + 1]
        del args[i:i + 2]
    if len(args) < 2:
        print(__doc__)
        sys.exit(1)
    *srcs, dst = args
    os.makedirs(dst, exist_ok=True)
    n = 0
    used = set()
    caps = []
    items = []
    for src in photo_sources(srcs):
        try:
            name = out_name(src, used)
            convert(src, dst, name)
            c = caption(src)
            if c:
                caps.append(f"{name}|{c}")
            items.append(("photo", name, c or name, src))
            n += 1
            print(f"-> {os.path.basename(src)}  ->  {name}")
        except Exception as e:  # HEIC cần pillow-heif: pip3 install pillow-heif
            print(f"bỏ qua {src}: {e}")
    ns = convert_status([s for s in srcs if os.path.isdir(s)], dst, items)
    with open(os.path.join(dst, "captions.txt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(caps) + ("\n" if caps else ""))
    print(f"Xong {n} ảnh khung, {ns} ảnh trạng thái.")
    if prev:
        write_previews(items, dst, prev)


if __name__ == "__main__":
    try:
        from pillow_heif import register_heif_opener
        register_heif_opener()
    except ImportError:
        pass
    main()
