"""`.tr` eklenince geçersizleşen `const` ifadelerini analiz çıktısına göre kaldırır.
Fazladan kaldırılanları sonradan `dart fix --apply` geri ekler."""
import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CODES = (
    "const_eval", "invalid_constant", "non_constant", "const_with_non_const",
    "const_initialized_with_non_constant_value", "const_constructor_param_type_mismatch",
)


def analyze():
    out = subprocess.run("flutter analyze --no-pub", cwd=ROOT, shell=True, capture_output=True)
    text = out.stdout.decode("utf-8", "replace")
    errors = []
    for line in text.splitlines():
        m = re.search(r"error - .* - (\S+\.dart):(\d+):(\d+) - (\w+)", line)
        if m:
            errors.append((m.group(1), int(m.group(2)), int(m.group(3)), m.group(4), line.strip()))
    return errors


def remove_enclosing_const(path, line_no, col):
    full = os.path.join(ROOT, path)
    src = io.open(full, encoding="utf-8").read()
    lines = src.split("\n")
    offset = sum(len(l) + 1 for l in lines[:line_no - 1]) + col - 1
    # Hata konumunu saran en içteki `const` ifadesini bul.
    best = None
    for m in re.finditer(r"\bconst\s+(?=[A-Z_\[<{(])", src[:offset]):
        start = m.end()
        depth, i, end = 0, start, None
        while i < len(src):
            c = src[i]
            if c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
                if depth == 0:
                    end = i
                    break
                if depth < 0:
                    break
            elif c in "'\"":
                q = c
                i += 1
                while i < len(src) and src[i] != q:
                    i += 2 if src[i] == "\\" else 1
            i += 1
        if end is not None and end >= offset:
            best = m
    if best is None:
        return False
    src = src[:best.start()] + src[best.end():]
    io.open(full, "w", encoding="utf-8", newline="\n").write(src)
    return True


def main():
    for round_no in range(40):
        errors = [e for e in analyze() if any(e[3].startswith(c) for c in CODES)]
        if not errors:
            print("const hatası kalmadı (tur %d)" % round_no)
            return
        # Aynı dosyada ofset kaymasın diye dosya başına sondan başa bir hata düzelt.
        seen, fixed = set(), 0
        for path, line, col, code, raw in sorted(errors, key=lambda e: (e[0], -e[1], -e[2])):
            if path in seen:
                continue
            seen.add(path)
            if remove_enclosing_const(path, line, col):
                fixed += 1
            else:
                print("ÇÖZÜLEMEDİ:", raw)
        print("tur %d: %d hata, %d düzeltme" % (round_no, len(errors), fixed))
        if fixed == 0:
            sys.exit(1)


if __name__ == "__main__":
    main()
