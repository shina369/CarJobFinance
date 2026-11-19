from pathlib import Path

OUT = Path(__file__).parent

DEFS = """
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#3ee98f"/>
    <stop offset="0.55" stop-color="#00b84a"/>
    <stop offset="1" stop-color="#006b2a"/>
  </linearGradient>
  <radialGradient id="glow" cx="0.3" cy="0.22" r="0.75">
    <stop offset="0" stop-color="#ffffff" stop-opacity="0.22"/>
    <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="coin" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fde68a"/>
    <stop offset="1" stop-color="#f59e0b"/>
  </linearGradient>
  <linearGradient id="body" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#ffffff"/>
    <stop offset="1" stop-color="#e9f8ef"/>
  </linearGradient>
</defs>
"""

MARK = """
<g id="mark">
  <ellipse cx="512" cy="770" rx="300" ry="26" fill="#003d18" opacity="0.28"/>
  <rect x="282" y="690" width="96" height="86" rx="26" fill="#0b3a1f"/>
  <rect x="646" y="690" width="96" height="86" rx="26" fill="#0b3a1f"/>
  <rect x="214" y="468" width="70" height="44" rx="20" fill="url(#body)"/>
  <rect x="740" y="468" width="70" height="44" rx="20" fill="url(#body)"/>
  <path d="M352 520 L398 392 Q410 360 446 360 L578 360 Q614 360 626 392 L672 520 Z" fill="url(#body)"/>
  <path d="M394 505 L428 410 Q434 394 452 394 L572 394 Q590 394 596 410 L630 505 Z" fill="#007a32"/>
  <path d="M440 420 L470 420 L438 500 L408 500 Z" fill="#ffffff" opacity="0.18"/>
  <rect x="244" y="492" width="536" height="222" rx="78" fill="url(#body)"/>
  <rect x="290" y="560" width="112" height="58" rx="29" fill="url(#coin)"/>
  <rect x="622" y="560" width="112" height="58" rx="29" fill="url(#coin)"/>
  <rect x="438" y="604" width="148" height="44" rx="22" fill="#007a32"/>
  <circle cx="726" cy="300" r="150" fill="#006b2a"/>
  <circle cx="726" cy="300" r="128" fill="url(#coin)"/>
  <circle cx="726" cy="300" r="102" fill="none" stroke="#ffffff" stroke-opacity="0.45" stroke-width="10"/>
  <polyline points="664,346 706,302 734,326 786,270" fill="none" stroke="#006b2a" stroke-width="26" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M752 256 L804 252 L800 304 Z" fill="#006b2a" stroke="#006b2a" stroke-width="10" stroke-linejoin="round"/>
</g>
"""

MARK_SHIFT = 'transform="translate(-33 39)"'


def svg(w: int, h: int, inner: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
        f'viewBox="0 0 {w} {h}">{DEFS}{inner}</svg>'
    )


def mark(scale: float = 1.0, cx: float = 512, cy: float = 512) -> str:
    return (
        f'<g transform="translate({cx} {cy}) scale({scale}) translate(-512 -512)">'
        f'<g {MARK_SHIFT}>{MARK}</g></g>'
    )


BG_SQUARE = '<rect width="1024" height="1024" fill="url(#bg)"/><rect width="1024" height="1024" fill="url(#glow)"/>'

variants = {
    "full": svg(1024, 1024, BG_SQUARE + mark(1.0)),
    "maskable": svg(1024, 1024, BG_SQUARE + mark(0.78)),
    "legacy": svg(
        1024,
        1024,
        '<rect x="40" y="40" width="944" height="944" rx="210" fill="url(#bg)"/>'
        '<rect x="40" y="40" width="944" height="944" rx="210" fill="url(#glow)"/>'
        + mark(0.9),
    ),
    "foreground": svg(1024, 1024, mark(0.72)),
    "background": svg(1024, 1024, BG_SQUARE),
    "feature": svg(
        1024,
        500,
        '<rect width="1024" height="500" fill="url(#bg)"/>'
        '<rect width="1024" height="500" fill="url(#glow)"/>'
        '<circle cx="930" cy="-40" r="220" fill="#ffffff" opacity="0.06"/>'
        '<circle cx="1000" cy="520" r="180" fill="#ffffff" opacity="0.05"/>'
        + mark(0.5, 250, 250)
        + '<text x="470" y="225" font-family="Segoe UI, Roboto, sans-serif" font-weight="700" '
        'font-size="72" fill="#ffffff">CarJobFinance</text>'
        '<text x="472" y="290" font-family="Segoe UI, Roboto, sans-serif" font-weight="400" '
        'font-size="34" fill="#eafff2">Corridas, despesas e lucro real</text>'
        '<text x="472" y="336" font-family="Segoe UI, Roboto, sans-serif" font-weight="400" '
        'font-size="34" fill="#eafff2">na palma da mão.</text>',
    ),
}

for name, content in variants.items():
    (OUT / f"{name}.svg").write_text(content, encoding="utf-8")
print("ok")
