"""Google Play mağaza görsellerini üretir.

Önce ekran görüntülerini üretin:
  flutter test test/store/store_screenshots_test.dart --dart-define=STORE_SHOTS=true
Sonra:
  python tool/store_graphics.py

Çıktılar (store_listing/):
  feature_graphic.png        1024x500 tanıtım görseli
  icon_512.png               512x512 uygulama simgesi
  screenshots/phone/*.png    1080x1920 başlıklı telefon ekran görüntüleri
"""
import os
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "store_listing")
RAW = os.path.join(OUT, "screenshots", "raw")
PHONE = os.path.join(OUT, "screenshots", "phone")

C1 = (16, 122, 82)   # zümrüt (simgeyle aynı)
C2 = (30, 58, 138)   # lacivert
WHITE = (255, 255, 255)

SHOTS = [
    ("01_dashboard", "Ayın tüm harcamaları\ntek bakışta"),
    ("07_new_expense", "Harcamanızı saniyeler\niçinde kaydedin"),
    ("04_installments", "Taksitlerinizi ay ay\ntakip edin"),
    ("03_cards", "Kesim ve son ödeme\ntarihlerini kaçırmayın"),
    ("05b_reports_categories", "Paranızın nereye\ngittiğini görün"),
    ("06_budgets", "Bütçe belirleyin,\nlimitleri izleyin"),
    ("02_expenses", "Tüm harcamalarınız\ndüzenli bir listede"),
]


def font_dir():
    flutter = shutil.which("flutter") or shutil.which("flutter.bat")
    root = os.path.dirname(os.path.dirname(os.path.realpath(flutter)))
    return os.path.join(root, "bin", "cache", "artifacts", "material_fonts")


FONTS = font_dir()


def font(weight, size):
    return ImageFont.truetype(os.path.join(FONTS, f"roboto-{weight}.ttf"), size)


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / w + y / h) / 2
            px[x, y] = tuple(round(C1[i] + (C2[i] - C1[i]) * t) for i in range(3))
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, *img.size], radius=radius, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def phone(shot, width, radius_ratio=0.07, bezel_ratio=0.025):
    """Ekran görüntüsünü yuvarlak köşeli koyu bir telefon çerçevesine koyar."""
    h = round(shot.height * width / shot.width)
    screen = shot.convert("RGB").resize((width, h), Image.LANCZOS)
    bezel = round(width * bezel_ratio)
    r = round(width * radius_ratio)
    body = Image.new("RGBA", (width + 2 * bezel, h + 2 * bezel), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle(
        [0, 0, body.width - 1, body.height - 1], radius=r + bezel, fill=(17, 24, 39, 255)
    )
    body.alpha_composite(rounded(screen, r), (bezel, bezel))
    return body


def paste_with_shadow(canvas, item, xy, blur=30, offset=(0, 18), alpha=110):
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    a = item.split()[-1].point(lambda v: alpha if v else 0)
    shadow.paste((0, 0, 0, 255), (xy[0] + offset[0], xy[1] + offset[1]), a)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(item, xy)


def framed(name, caption):
    W, H = 1080, 1920
    canvas = gradient(W, H).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    f = font("bold", 76)
    d.multiline_text((W // 2, 120), caption, font=f, fill=WHITE, anchor="ma", align="center", spacing=18)

    shot = Image.open(os.path.join(RAW, f"{name}.png"))
    device = phone(shot, 780)
    x = (W - device.width) // 2
    y = 430
    # Telefonun alt kısmı tuvalin dışına taşar; üst kısım ve içerik görünür kalır.
    paste_with_shadow(canvas, device, (x, y))
    canvas.convert("RGB").save(os.path.join(PHONE, f"{name}.png"), optimize=True)


def feature_graphic():
    W, H = 1024, 500
    canvas = gradient(W, H).convert("RGBA")
    d = ImageDraw.Draw(canvas)

    icon = Image.open(os.path.join(ROOT, "web", "icons", "Icon-512.png")).convert("RGBA")
    icon = icon.resize((120, 120), Image.LANCZOS)
    paste_with_shadow(canvas, rounded(icon, 28), (64, 96), blur=14, offset=(0, 8), alpha=90)

    d.text((64, 250), "Harcama Takip", font=font("bold", 64), fill=WHITE)
    d.multiline_text(
        (64, 336),
        "Harcamalar, kartlar ve taksitler\ntek bir yerde.",
        font=font("regular", 32),
        fill=(220, 240, 232),
        spacing=8,
    )

    shot = Image.open(os.path.join(RAW, "01_dashboard.png"))
    device = phone(shot, 300, radius_ratio=0.08, bezel_ratio=0.03)
    paste_with_shadow(canvas, device, (650, 60), blur=20, offset=(0, 12))
    canvas.convert("RGB").save(os.path.join(OUT, "feature_graphic.png"), optimize=True)


def main():
    os.makedirs(PHONE, exist_ok=True)
    for name, caption in SHOTS:
        framed(name, caption)
    feature_graphic()
    shutil.copyfile(os.path.join(ROOT, "web", "icons", "Icon-512.png"), os.path.join(OUT, "icon_512.png"))
    print("ok")


if __name__ == "__main__":
    main()
