"""Create editable RouteRisk explainer diagrams for the submission video."""

from html import escape
from pathlib import Path

OUT = Path(__file__).parent
W, H = 1920, 1080
BG = "#0B111A"
SURFACE = "#16222E"
STROKE = "#2B3B49"
WHITE = "#F5F9FC"
MUTED = "#A7BAC8"
BLUE = "#168CFF"
TEAL = "#50E7B5"
ORANGE = "#FFB86D"
RED = "#FF6575"


def text(x, y, value, size=30, color=WHITE, weight=400, anchor="start", spacing=0):
    return (
        f'<text x="{x}" y="{y}" fill="{color}" font-family="Arial, Helvetica, sans-serif" '
        f'font-size="{size}" font-weight="{weight}" text-anchor="{anchor}" '
        f'letter-spacing="{spacing}">{escape(value)}</text>'
    )


def rect(x, y, w, h, fill=SURFACE, radius=28, stroke=STROKE, sw=2):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'


def circle(x, y, r, fill, stroke="none", sw=0):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'


def line(x1, y1, x2, y2, stroke=STROKE, sw=3, dash=""):
    extra = f' stroke-dasharray="{dash}"' if dash else ""
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round"{extra}/>'


def path(d, stroke, sw=5, fill="none", opacity=1):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" opacity="{opacity}"/>'


def arrow(x1, x2, y, color=BLUE):
    return path(f"M {x1} {y} L {x2} {y} M {x2-16} {y-15} L {x2} {y} L {x2-16} {y+15}", color, 5)


def base(number, title, subtitle, footer):
    items = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
        "<defs>",
        '<radialGradient id="glow"><stop offset="0" stop-color="#12334E" stop-opacity=".60"/><stop offset="1" stop-color="#0B111A" stop-opacity="0"/></radialGradient>',
        '<linearGradient id="route"><stop stop-color="#168CFF"/><stop offset="1" stop-color="#50E7B5"/></linearGradient>',
        "</defs>",
        f'<rect width="{W}" height="{H}" fill="{BG}"/>',
        '<ellipse cx="1560" cy="180" rx="720" ry="500" fill="url(#glow)"/>',
    ]
    for gx in range(90, W, 110):
        items.append(line(gx, 0, gx, H, "#243747", 1))
    for gy in range(70, H, 110):
        items.append(line(0, gy, W, gy, "#243747", 1))
    items += [
        rect(110, 64, 64, 64, "#102E4B", 18, BLUE, 2),
        text(142, 111, "R", 48, WHITE, 800, "middle"),
        text(194, 105, "ROUTERISK", 29, WHITE, 700, spacing=4),
        text(1806, 105, f"EXPLAINER  /  {number:02d}", 23, MUTED, 700, "end", 3),
        text(110, 221, title, 65, WHITE, 700),
        text(110, 285, subtitle, 30, MUTED),
        line(110, 975, 1810, 975, STROKE, 2),
        text(110, 1024, footer, 25, MUTED),
    ]
    return items


def finish(items, name):
    (OUT / f"{name}.svg").write_text("\n".join(items + ["</svg>"]) + "\n")


def card(items, x, label, title, body_lines, accent, icon):
    y, w, h = 390, 492, 440
    items.append(rect(x, y, w, h))
    items.append(rect(x + 34, y + 32, 84, 84, "#102F46", 24, "none", 0))
    items.append(icon(x + 76, y + 74))
    items.append(text(x + 34, y + 168, label, 22, accent, 700, spacing=3))
    items.append(text(x + 34, y + 231, title, 39, WHITE, 700))
    for index, body in enumerate(body_lines):
        items.append(text(x + 34, y + 290 + index * 41, body, 27, MUTED))


def crash_icon(x, y):
    return "".join(
        circle(x + dx, y + dy, 10, ORANGE)
        for dx, dy in [(-23, -10), (10, -22), (27, 15), (-14, 24)]
    )


def segment_icon(x, y):
    return path(f"M {x-34} {y+26} C {x-9} {y+11}, {x+8} {y-28}, {x+34} {y-27}", BLUE, 14) + circle(x + 14, y - 14, 8, ORANGE)


def meter_icon(x, y):
    return (
        path(f"M {x-32} {y+24} A 42 42 0 0 1 {x+32} {y+24}", TEAL, 9)
        + path(f"M {x} {y+13} L {x+19} {y-17}", WHITE, 5)
        + circle(x, y + 13, 6, WHITE)
    )


def report_icon(x, y):
    return (
        rect(x - 27, y - 34, 54, 68, "#102F46", 8, BLUE, 4)
        + line(x - 13, y - 13, x + 13, y - 13, BLUE, 4)
        + line(x - 13, y + 1, x + 13, y + 1, BLUE, 4)
        + line(x - 13, y + 15, x + 5, y + 15, BLUE, 4)
    )


def location_icon(x, y):
    return (
        circle(x, y, 26, "#102F46", BLUE, 5)
        + circle(x, y, 9, BLUE)
        + line(x - 39, y, x - 29, y, BLUE, 4)
        + line(x + 29, y, x + 39, y, BLUE, 4)
    )


def speaker_icon(x, y):
    return (
        path(f"M {x-34} {y-14} L {x-20} {y-14} L {x-2} {y-30} L {x-2} {y+30} L {x-20} {y+14} L {x-34} {y+14} Z", TEAL, 3, TEAL)
        + path(f"M {x+10} {y-20} Q {x+34} {y} {x+10} {y+20}", TEAL, 5)
    )


def shield_icon(x, y):
    return path(f"M {x} {y-38} L {x+30} {y-25} L {x+25} {y+12} Q {x+14} {y+29} {x} {y+36} Q {x-14} {y+29} {x-25} {y+12} L {x-30} {y-25} Z", RED, 5)


def clock_icon(x, y):
    return circle(x, y, 35, "#102F46", ORANGE, 5) + line(x, y, x, y - 20, ORANGE, 5) + line(x, y, x + 16, y + 10, ORANGE, 5)


def message_icon(x, y):
    return path(f"M {x-36} {y-26} H {x+36} V {y+20} H {x-8} L {x-26} {y+37} V {y+20} H {x-36} Z", TEAL, 5)


# 1. Scoring, with the actual inputs used by RiskScoringService.
items = base(
    1,
    "From crash history to route exposure",
    "A weighted formula scores the roads on each suggested route.",
    "Historical exposure is a relative estimate—not a crash prediction.",
)
card(items, 110, "01  INPUT", "Crash history", ["Public DVRPC records", "near the route"], ORANGE, crash_icon)
card(items, 714, "02  ANALYZE", "Road segments", ["Weight severity,", "proximity, and recency"], BLUE, segment_icon)
card(items, 1318, "03  RESULT", "Exposure / mile", ["Combine segment scores", "for each whole route"], TEAL, meter_icon)
items += [arrow(618, 698, 610), arrow(1222, 1302, 610)]
finish(items, "01-how-scoring-works")

# 2. A conceptual comparison rather than fabricated numerical results.
items = base(
    2,
    "See the tradeoff before you drive",
    "The fastest route and the lower-exposure route may differ.",
    "Illustrative comparison · The driver chooses which route to take.",
)
items += [
    rect(110, 365, 1025, 520),
    text(156, 419, "SAME START  →  SAME DESTINATION", 24, MUTED, 700, spacing=2),
    path("M 236 700 C 380 460, 760 460, 1016 690", BLUE, 16),
    path("M 236 700 C 420 880, 760 850, 1016 690", TEAL, 16),
    circle(236, 700, 21, WHITE, BLUE, 7),
    circle(1016, 690, 21, WHITE, TEAL, 7),
    circle(519, 551, 10, ORANGE),
    circle(666, 545, 10, ORANGE),
    circle(804, 569, 10, ORANGE),
    text(265, 752, "START", 24, MUTED, 700),
    text(914, 752, "ARRIVE", 24, MUTED, 700),
    rect(1193, 398, 617, 209),
    rect(1223, 428, 12, 150, BLUE, 6, "none", 0),
    text(1261, 459, "FASTEST", 24, BLUE, 700, spacing=3),
    text(1261, 518, "Less travel time", 36, WHITE, 700),
    text(1261, 562, "Higher historical exposure", 27, MUTED),
    rect(1193, 644, 617, 209),
    rect(1223, 674, 12, 150, TEAL, 6, "none", 0),
    text(1261, 705, "LOWER EXPOSURE", 24, TEAL, 700, spacing=3),
    text(1261, 764, "Different travel time", 36, WHITE, 700),
    text(1261, 808, "Lower historical score", 27, MUTED),
]
finish(items, "02-route-tradeoff")

# 3. Live report matching is separate from historical scoring.
items = base(
    3,
    "Watch for reported crashes ahead",
    "During a trip, RouteRisk checks whether a 511NJ report is on the selected route.",
    "Checks about once a minute while the app is open · Reports may be delayed.",
)
card(items, 110, "01  REPORT", "511NJ feed", ["Active reported crashes", "with map locations"], ORANGE, report_icon)
card(items, 714, "02  MATCH", "Route + location", ["Near the chosen road", "and ahead of the driver?"], BLUE, location_icon)
card(items, 1318, "03  WARN", "Voice + haptic", ["A short warning", "with an on-screen card"], TEAL, speaker_icon)
items += [arrow(618, 698, 610), arrow(1222, 1302, 610)]
finish(items, "03-live-incident-alert")

# 4. Optional experimental safety feature.
items = base(
    4,
    "A backup if a crash might occur",
    "RouteRisk can run an optional possible-impact check during navigation.",
    "Experimental · Automatic parent contact requires a configured delivery service.",
)
card(items, 110, "01  DETECT", "Possible impact", ["Strong phone impact", "plus sudden speed drop"], RED, shield_icon)
card(items, 714, "02  CHECK", "20 seconds", ["Driver can tap", "“I’m okay” to cancel"], ORANGE, clock_icon)
card(items, 1318, "03  CONTACT", "Parent alert", ["Optional text + call", "after the countdown"], TEAL, message_icon)
items += [arrow(618, 698, 610), arrow(1222, 1302, 610)]
finish(items, "04-optional-safety-backup")
