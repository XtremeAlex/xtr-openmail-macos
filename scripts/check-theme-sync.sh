#!/usr/bin/env bash
# Verifica che i token del tema SwiftUI coincidano con quelli della web app (fonte di verita')
# e che la copia del tema nell'altro progetto macOS sia identica.
#
#   scripts/check-theme-sync.sh
#   WEB_CSS=/percorso/app.css OTHER_THEME_DIR=/percorso/Theme scripts/check-theme-sync.sh
#
# Uscita 0 = allineati; 1 = differenze (elencate). Se la web app non e' presente accanto al
# progetto il controllo dei token viene saltato (utile in CI senza i repository fratelli).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PARENT="$(dirname "$ROOT")"
THEME_DIR="${THEME_DIR:-$(dirname "$(find "$ROOT" -path '*/Theme/Theme.swift' -not -path '*/.build/*' | head -1)")}"
WEB_CSS="${WEB_CSS:-$PARENT/xtr-aeroport-edifact-spring-web/src/main/resources/static/tool/css/app.css}"
if [ -z "${OTHER_THEME_DIR:-}" ]; then
  for candidate in "$PARENT/xtr-openmail-macos/Sources/XtrOpenMail/Theme" \
                   "$PARENT/xtr-toolkit-hosts-macos/xtr-toolkit-hosts-macos/Theme"; do
    [ "$candidate" != "$THEME_DIR" ] && [ -d "$candidate" ] && OTHER_THEME_DIR="$candidate"
  done
fi

python3 - "$THEME_DIR" "$WEB_CSS" "${OTHER_THEME_DIR:-}" <<'PY'
import os, re, sys

theme_dir, css_path, other_dir = sys.argv[1], sys.argv[2], sys.argv[3]
theme = open(os.path.join(theme_dir, "Theme.swift"), encoding="utf-8").read()
problems = []

# token CSS -> nome Swift
tokens = {"bg": "bg", "bg-alt": "bgAlt", "surface": "surface", "surface-2": "surface2", "border": "border",
          "control": "control", "text": "text", "text-muted": "textMuted", "accent-text": "accentText",
          "btn": "button", "btn-hover": "buttonHover", "ok": "ok", "warn": "warn", "info": "info",
          "code-bg": "codeBg", "code-text": "codeText", "paper": "paper", "paper-active": "paperActive",
          "paper-back": "paperBack"}

def block(css, selector):
    m = re.search(re.escape(selector) + r"\s*\{(.*?)\}", css, re.S)
    return dict(re.findall(r"--([a-z0-9-]+):\s*#([0-9a-fA-F]{6})\s*;", m.group(1))) if m else {}

if os.path.isfile(css_path):
    css = open(css_path, encoding="utf-8").read()
    dark, light = block(css, ":root"), block(css, "html.light")
    for css_name, swift_name in tokens.items():
        d = dark.get(css_name)
        l = light.get(css_name, d)
        if d is None:
            problems.append(f"token --{css_name} non trovato nel CSS")
            continue
        m = re.search(r"static let " + swift_name + r"\s*=\s*Color\(dark:\s*0x([0-9A-Fa-f]{6}),\s*light:\s*0x([0-9A-Fa-f]{6})\)", theme)
        if not m:
            problems.append(f"{swift_name}: definizione Color(dark:light:) non trovata")
        elif (m.group(1).lower(), m.group(2).lower()) != (d.lower(), l.lower()):
            problems.append(f"{swift_name}: Swift {m.group(1)}/{m.group(2)} ≠ CSS {d}/{l} (--{css_name})")
    accent = dark.get("accent", "").lower()
    if accent and f"0x{accent}" not in theme.lower():
        problems.append(f"accent: #{accent} assente in Theme.swift")
    print(f"Token verificati contro {css_path}")
else:
    print(f"Web app non trovata ({css_path}): controllo token saltato")

def body(path):
    # Le copie possono differire solo per il commento d'intestazione iniziale
    lines = open(path, encoding="utf-8").read().splitlines()
    while lines and (lines[0].startswith("//") or not lines[0].strip()):
        lines.pop(0)
    return "\n".join(lines)

if other_dir and os.path.isdir(other_dir):
    for name in ("Theme.swift", "ThemeComponents.swift"):
        a, b = os.path.join(theme_dir, name), os.path.join(other_dir, name)
        if os.path.isfile(b) and body(a) != body(b):
            problems.append(f"{name} diverso da {b}")
    print(f"Copie confrontate con {other_dir}")

for p in problems:
    print("✗ " + p)
print("Tema allineato ✓" if not problems else f"{len(problems)} differenze")
sys.exit(1 if problems else 0)
PY
