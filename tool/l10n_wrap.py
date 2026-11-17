"""Dart kaynaklarındaki Türkçe arayüz metinlerini `.tr` / `.trArgs([...])` ile sarar
ve çeviri anahtarlarını listeler.

Kullanım:
  python tool/l10n_wrap.py apply   # dosyaları dönüştür (tekrar çalıştırmak güvenlidir)
  python tool/l10n_wrap.py keys    # koddaki tüm anahtarları JSON olarak yaz (stdout)
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGETS = [
    "lib/presentation",
    "lib/core/errors/error_messages.dart",
    "lib/core/utils/validators.dart",
    "lib/core/utils/date_formats.dart",
    "lib/application/services/notification_service.dart",
    "lib/application/services/account_service.dart",
    "lib/application/providers/team_providers.dart",
    "lib/data/repositories/firestore_team_repository.dart",
]
IMPORT_LINE = "import 'package:harcama_takip/core/l10n/app_locale.dart';"
TURKISH = set("çğıöşüÇĞİÖŞÜ")
SKIP_BEFORE = re.compile(
    r"(debugPrint\(\s*|ValueKey\(\s*|Key\(\s*|RegExp\(\s*r?|DateFormat\(\s*|fontFamily:\s*|"
    r"getLocation\(\s*|\[\s*|case\s+|code:\s*|plugin:\s*|path:\s*|debugLabel:\s*|"
    r"assert\([^;]*,\s*|AndroidNotificationChannel\(\s*|AndroidNotificationDetails\(\s*)$",
    re.S,
)
DEFAULT_PARAM = re.compile(r"(this\.\w+|String\??\s+\w+)\s*=\s*$")


def is_human(text):
    plain = re.sub(r"\{\d+\}", " ", text).strip()
    if len(re.findall(r"[A-Za-zçğıöşüÇĞİÖŞÜ]{2,}", plain)) == 0:
        return False
    if plain.startswith("/") or "://" in plain or plain.endswith(".dart"):
        return False
    if re.fullmatch(r"[A-Z0-9_]+", plain):
        return False  # kodlar: TRY, ABCD2345
    if any(ch in TURKISH for ch in plain):
        return True
    if " " in plain:
        return True
    return bool(re.fullmatch(r"[A-ZÇĞİÖŞÜ][a-zçğıöşü]+[.:!?…]?", plain))


class Lit:
    def __init__(self, start, end, quote, raw, template, args, has_interp):
        self.start, self.end, self.quote, self.raw = start, end, quote, raw
        self.template, self.args, self.has_interp = template, args, has_interp


def read_string(src, i):
    """src[i] bir tırnak. Dönen: Lit ya da None (üçlü tırnak vb. için atla)."""
    q = src[i]
    if src.startswith(q * 3, i):
        j = src.find(q * 3, i + 3)
        return Lit(i, (j + 3) if j >= 0 else len(src), q * 3, True, "", [], False)
    j = i + 1
    out, args = [], []
    while j < len(src):
        c = src[j]
        if c == "\\":
            out.append(src[j:j + 2])
            j += 2
            continue
        if c == q:
            break
        if c == "$":
            if src[j + 1] == "{":
                depth, k = 1, j + 2
                while k < len(src) and depth:
                    ch = src[k]
                    if ch in "'\"":
                        inner = read_string(src, k)
                        k = inner.end
                        continue
                    if ch == "{":
                        depth += 1
                    elif ch == "}":
                        depth -= 1
                    k += 1
                args.append(src[j + 2:k - 1].strip())
                out.append("{%d}" % (len(args) - 1))
                j = k
                continue
            m = re.match(r"[A-Za-z_]\w*", src[j + 1:])
            if m:
                args.append(m.group(0))
                out.append("{%d}" % (len(args) - 1))
                j += 1 + len(m.group(0))
                continue
        out.append(c)
        j += 1
    content = "".join(out)
    if q == '"':
        content = content.replace('\\"', '"').replace("'", "\\'")
    return Lit(i, j + 1, q, False, content, args, bool(args))


def scan(src):
    """Kaynaktaki (yorum dışı) dize gruplarını döner: [(grup, const_bildirimi_mi)]."""
    groups = []
    i, n = 0, len(src)
    depth = 0
    const_decl_depth = None
    current = None
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            i = src.find("\n", i)
            i = n if i < 0 else i
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i)
            i = n if j < 0 else j + 2
            continue
        if c in "'\"":
            raw = i > 0 and src[i - 1] == "r" and not (src[i - 2].isalnum() or src[i - 2] == "_")
            lit = read_string(src, i)
            lit.raw = lit.raw or raw
            between = src[current[-1].end:i] if current else None
            if current is not None and between.strip() == "":
                current.append(lit)
            else:
                current = [lit]
                groups.append((current, const_decl_depth is not None))
            i = lit.end
            continue
        if not c.isspace():
            if c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
            elif c == ";" and const_decl_depth is not None and depth <= const_decl_depth:
                const_decl_depth = None
            if c.isalpha() or c == "_":
                m = re.match(r"\w+", src[i:])
                word = m.group(0)
                if word == "const" and const_decl_depth is None:
                    rest = src[i + 5:i + 200]
                    before = src[max(0, i - 12):i]
                    if re.match(r"\s+(\w+(<[^=;()]*>)?\s+)?\w+\s*=", rest) or before.rstrip().endswith("static"):
                        const_decl_depth = depth
                i += len(word)
                current = None if word not in ("r",) else current
                continue
            current = None
        i += 1
    return groups


def process(src, apply):
    keys, deferred = [], []
    edits = []
    for group, in_const_decl in scan(src):
        first, last = group[0], group[-1]
        if any(l.raw for l in group):
            continue
        line_start = src.rfind("\n", 0, first.start) + 1
        line = src[line_start:src.find("\n", first.start)]
        if re.match(r"\s*(import|export|part)\s", line):
            continue
        template, args = "", []
        for l in group:
            t = l.template
            for idx in range(len(l.args) - 1, -1, -1):
                t = t.replace("{%d}" % idx, "{%d}" % (idx + len(args)))
            template += t
            args += l.args
        if not is_human(template):
            continue
        before = src[max(0, first.start - 80):first.start]
        if SKIP_BEFORE.search(before):
            continue
        after = src[last.end:last.end + 80].lstrip()
        if after.startswith(".tr"):
            keys.append(template)
            continue
        if in_const_decl or DEFAULT_PARAM.search(before):
            keys.append(template)
            deferred.append(template)
            continue
        keys.append(template)
        suffix = ".trArgs([%s])" % ", ".join(args) if args else ".tr"
        edits.append((first.start, last.end, "'%s'%s" % (template, suffix)))
    if apply and edits:
        for start, end, text in sorted(edits, reverse=True):
            src = src[:start] + text + src[end:]
        if "core/l10n/app_locale.dart" not in src:
            m = re.search(r"^import .*;$", src, re.M)
            src = src[:m.start()] + IMPORT_LINE + "\n" + src[m.start():]
    return src, keys, deferred


def files():
    for target in TARGETS:
        path = os.path.join(ROOT, target)
        if os.path.isfile(path):
            yield path
        else:
            for base, _, names in os.walk(path):
                for name in sorted(names):
                    if name.endswith(".dart"):
                        yield os.path.join(base, name)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "keys"
    all_keys, all_deferred = [], {}
    for path in files():
        src = io.open(path, encoding="utf-8").read()
        new_src, keys, deferred = process(src, mode == "apply")
        all_keys += keys
        if deferred:
            all_deferred[os.path.relpath(path, ROOT)] = deferred
        if mode == "apply" and new_src != src:
            io.open(path, "w", encoding="utf-8", newline="\n").write(new_src)
    unique = sorted(set(all_keys))
    out = {"keys": unique, "deferred": all_deferred}
    sys.stdout.buffer.write(json.dumps(out, ensure_ascii=False, indent=1).encode("utf-8"))


if __name__ == "__main__":
    main()
