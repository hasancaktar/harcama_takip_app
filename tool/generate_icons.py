"""Uygulama ikonlarını tek kaynaktan üretir (Android, iOS, Web).

Kullanım:  pip install pillow && python tool/generate_icons.py
Tasarım: zümrüt -> lacivert degrade zemin üzerinde beyaz cüzdan ve yükselen
çubuklar (harcama takibi + bütçe kontrolü).
"""
import os
import re
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 1024  # ana tuval
SS = 2    # kenar yumuşatma için üst örnekleme

C1 = (16, 122, 82)    # zümrüt
C2 = (30, 58, 138)    # lacivert
WHITE = (255, 255, 255, 255)


def gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(round(C1[i] + (C2[i] - C1[i]) * t) for i in range(3))
    return img


def glyph(size, scale=1.0, color=WHITE, accent=None):
    """Cüzdan + yükselen çubuklar. `scale` simgenin tuvale oranı."""
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = big * scale / 100.0          # 100 birimlik ızgara
    ox = (big - 100 * u) / 2
    oy = (big - 100 * u) / 2

    def R(x0, y0, x1, y1, r, fill):
        d.rounded_rectangle([ox + x0 * u, oy + y0 * u, ox + x1 * u, oy + y1 * u], radius=r * u, fill=fill)

    accent = accent or (16, 122, 82, 255)
    # cüzdan kapağı (arkada, hafif saydam)
    R(20, 24, 74, 44, 8, (255, 255, 255, 150))
    # cüzdan gövdesi
    R(14, 32, 86, 80, 11, color)
    # yükselen çubuklar
    R(25, 60, 34, 71, 2.5, accent)
    R(39, 52, 48, 71, 2.5, accent)
    R(53, 43, 62, 71, 2.5, accent)
    # toka
    R(68, 48, 92, 64, 8, accent)
    d.ellipse([ox + 73 * u, oy + 52.5 * u, ox + 80 * u, oy + 59.5 * u], fill=color)
    return img.resize((size, size), Image.LANCZOS)


def rounded_mask(size, radius_ratio):
    big = size * SS
    m = Image.new("L", (big, big), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, big - 1, big - 1], radius=big * radius_ratio, fill=255)
    return m.resize((size, size), Image.LANCZOS)


def full_icon(size, glyph_scale=0.78, rounded=None):
    base = gradient(S).convert("RGBA")
    base.alpha_composite(glyph(S, glyph_scale))
    if rounded:
        base.putalpha(rounded_mask(S, rounded))
    return base.resize((size, size), Image.LANCZOS)


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    return path


def main():
    # --- Android: eski cihazlar için yuvarlatılmış kare ---
    for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(full_icon(px, rounded=0.22), "android", "app", "src", "main", "res", f"mipmap-{name}", "ic_launcher.png")
    # --- Android 8+: uyarlanabilir ikon (ön plan güvenli alanda) ---
    for name, px in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
        res = ("android", "app", "src", "main", "res", f"mipmap-{name}")
        save(glyph(px, 0.56), *res, "ic_launcher_foreground.png")
        save(glyph(px, 0.56, accent=(0, 0, 0, 0)), *res, "ic_launcher_monochrome.png")
    # Bildirim çubuğu simgesi (tek renk, saydam zemin)
    for name, px in {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}.items():
        save(glyph(px, 0.92, accent=(0, 0, 0, 0)), "android", "app", "src", "main", "res", f"drawable-{name}", "ic_stat_notification.png")

    # --- Web ---
    save(full_icon(192, rounded=0.22), "web", "icons", "Icon-192.png")
    save(full_icon(512, rounded=0.22), "web", "icons", "Icon-512.png")
    save(full_icon(192, glyph_scale=0.6).convert("RGB"), "web", "icons", "Icon-maskable-192.png")
    save(full_icon(512, glyph_scale=0.6).convert("RGB"), "web", "icons", "Icon-maskable-512.png")
    save(full_icon(64, rounded=0.22), "web", "favicon.png")

    # --- iOS: saydamlık yok, köşeleri sistem yuvarlar ---
    ios_dir = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.isdir(ios_dir):
        for f in os.listdir(ios_dir):
            m = re.match(r"Icon-App-([\d.]+)x[\d.]+@(\d)x\.png", f)
            if m:
                px = round(float(m.group(1)) * int(m.group(2)))
                full_icon(px).convert("RGB").save(os.path.join(ios_dir, f))

    # Önizleme (belgeler için)
    save(full_icon(512, rounded=0.22), "docs", "app-icon.png")
    print("İkonlar üretildi.")


if __name__ == "__main__":
    main()
