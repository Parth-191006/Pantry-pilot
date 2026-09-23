#!/usr/bin/env python3
"""Renders the Recipe Pilot launcher icons.

The mark (leaf + terracotta check badge) is defined *geometrically* here with
signed-distance functions that mirror lib/ui/logo.dart one-for-one, so the
launcher artwork and the in-app vector logo stay the same drawing.

Outputs (checked in, consumed by `dart run flutter_launcher_icons`):
  assets/icon/app_icon.png             512x512  full logo (rounded-square plate)
  assets/icon/app_icon_foreground.png  512x512  transparent mark, adaptive-safe

Pure standard library: zlib + struct are enough to write a PNG by hand, which
keeps this runnable on a bare machine with no imaging packages installed.

Usage:  python tool/generate_icons.py
"""

import math
import os
import struct
import zlib

S = 512  # rendered square size in pixels

# ---------------------------------------------------------------------------
# Geometry — all units are fractions of the canvas side (same as logo.dart)
# ---------------------------------------------------------------------------
LEAF_CENTER = (0.45, 0.41)
HALF_LENGTH = 0.265
HALF_WIDTH = 0.155
LEAF_ANGLE = math.radians(-38)
COS_A, SIN_A = math.cos(LEAF_ANGLE), math.sin(LEAF_ANGLE)

# A lens (leaf) is the intersection of two equal circles: half-width = R - d,
# half-length = sqrt(R^2 - d^2).
_R = (HALF_LENGTH**2 + HALF_WIDTH**2) / (2 * HALF_WIDTH)
_D = _R - HALF_WIDTH

BADGE_CENTER = (0.735, 0.725)
BADGE_RADIUS = 0.208
CHECK_RADIUS = 0.026  # stroke half-thickness
CHECK_POINTS = [
    (BADGE_CENTER[0] - 0.40 * BADGE_RADIUS, BADGE_CENTER[1] - 0.02 * BADGE_RADIUS),
    (BADGE_CENTER[0] - 0.10 * BADGE_RADIUS, BADGE_CENTER[1] + 0.32 * BADGE_RADIUS),
    (BADGE_CENTER[0] + 0.42 * BADGE_RADIUS, BADGE_CENTER[1] - 0.34 * BADGE_RADIUS),
]

SIDE_VEINS = (-0.42, 0.02, 0.46)

PLATE_RADIUS = 0.28
PLATE_STOPS = ((0.0, (0x43, 0xA0, 0x47)), (0.55, (0x1B, 0x5E, 0x20)),
               (1.0, (0x10, 0x33, 0x1A)))
LEAF_FILL = ((0xFB, 0xFE, 0xFA), (0xD8, 0xEB, 0xD3))
VEIN_COLOR = (0x2E, 0x7D, 0x32)
SHADOW_COLOR = (0x06, 0x30, 0x1A)
RING_COLOR = (0x06, 0x25, 0x1A)
BADGE_FILL = ((0xFF, 0xA5, 0x6B), (0xE2, 0x57, 0x1E))


# ---------------------------------------------------------------------------
# Signed distance helpers (design units)
# ---------------------------------------------------------------------------
def sd_rounded_rect(x, y, half, radius):
    dx = abs(x) - half + radius
    dy = abs(y) - half + radius
    ox, oy = max(dx, 0.0), max(dy, 0.0)
    return math.hypot(ox, oy) + min(max(dx, dy), 0.0) - radius


def sd_circle(x, y, cx, cy, radius):
    return math.hypot(x - cx, y - cy) - radius


def sd_capsule(x, y, ax, ay, bx, by, radius):
    pax, pay = x - ax, y - ay
    bax, bay = bx - ax, by - ay
    denom = bax * bax + bay * bay
    h = 0.0 if denom == 0 else max(0.0, min(1.0, (pax * bax + pay * bay) / denom))
    return math.hypot(pax - bax * h, pay - bay * h) - radius


def leaf_distance(x, y):
    """Lens = intersection of two circles, rotated into leaf space."""
    dx, dy = x - LEAF_CENTER[0], y - LEAF_CENTER[1]
    lx = dx * COS_A + dy * SIN_A
    ly = -dx * SIN_A + dy * COS_A
    return max(
        math.hypot(lx, ly - _D) - _R,
        math.hypot(lx, ly + _D) - _R,
    )


def lerp_color(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def grad(stops, t):
    t = max(0.0, min(1.0, t))
    for i in range(len(stops) - 1):
        t0, c0 = stops[i]
        t1, c1 = stops[i + 1]
        if t <= t1:
            span = t1 - t0
            local = 0.0 if span == 0 else (t - t0) / span
            return lerp_color(c0, c1, local)
    return stops[-1][1]


def over(dst, src_rgb, src_a):
    """Source-over compositing on non-premultiplied (r, g, b, a) 0..1 floats."""
    if src_a <= 0:
        return dst
    da = dst[3]
    out_a = src_a + da * (1 - src_a)
    if out_a <= 0:
        return (0.0, 0.0, 0.0, 0.0)
    r = (src_rgb[0] * src_a + dst[0] * da * (1 - src_a)) / out_a
    g = (src_rgb[1] * src_a + dst[1] * da * (1 - src_a)) / out_a
    b = (src_rgb[2] * src_a + dst[2] * da * (1 - src_a)) / out_a
    return (r, g, b, out_a)


def shade(fx, fy, scale, include_bg):
    """Colour of one sample point, given in design space (0..1)."""
    aa = 1.0 / (S * scale)  # one screen pixel expressed in design units

    def cov(d):
        return max(0.0, min(1.0, 0.5 - d / aa))

    px = (0.0, 0.0, 0.0, 0.0)  # transparent

    if include_bg:
        d = sd_rounded_rect(fx - 0.5, fy - 0.5, 0.5, PLATE_RADIUS)
        a = cov(d)
        if a > 0:
            base = grad(PLATE_STOPS, (fx + fy) / 2)
            # Soft light source in the upper-left corner of the plate.
            sheen = max(0.0, 1.0 - math.hypot(fx - 0.20, fy - 0.14) / 0.62) ** 2
            base = lerp_color(base, (255, 255, 255), 0.14 * sheen)
            px = over(px, tuple(c / 255 for c in base), a)

    # --- Leaf (drop shadow, fill, veins) -----------------------------------
    d_leaf = leaf_distance(fx, fy)
    d_shadow = leaf_distance(fx, fy - 0.018)
    shadow_a = 0.35 * max(0.0, min(1.0, 1.0 - d_shadow / (8 * aa))) ** 1.4
    if shadow_a > 0:
        px = over(px, tuple(c / 255 for c in SHADOW_COLOR), shadow_a)

    leaf_a = cov(d_leaf)
    if leaf_a > 0:
        fill = lerp_color(LEAF_FILL[0], LEAF_FILL[1], (fx + fy - 0.2) / 0.9)
        px = over(px, tuple(c / 255 for c in fill), leaf_a)

        # Veins, clipped to the leaf.
        dx, dy = fx - LEAF_CENTER[0], fy - LEAF_CENTER[1]
        lx = dx * COS_A + dy * SIN_A
        ly = -dx * SIN_A + dy * COS_A
        rib = sd_capsule(lx, ly, -HALF_LENGTH * 0.84, 0.0,
                         HALF_LENGTH * 0.86, 0.0, 0.010)
        vein_a = cov(rib) * 0.42
        for t in SIDE_VEINS:
            local = HALF_WIDTH * math.sqrt(max(0.0, 1 - t * t * 0.9))
            for direction in (1.0, -1.0):
                branch = sd_capsule(
                    lx, ly,
                    HALF_LENGTH * t, 0.0,
                    HALF_LENGTH * t + HALF_LENGTH * 0.16, local * 0.72 * direction,
                    0.0065,
                )
                vein_a = max(vein_a, cov(branch) * 0.30)
        if vein_a > 0:
            px = over(px, tuple(c / 255 for c in VEIN_COLOR), vein_a * leaf_a)

    # --- Check badge -------------------------------------------------------
    d_disc = sd_circle(fx, fy, BADGE_CENTER[0], BADGE_CENTER[1], BADGE_RADIUS)
    ring_a = cov(abs(d_disc) - BADGE_RADIUS * 0.11) * 0.38
    if ring_a > 0:
        px = over(px, tuple(c / 255 for c in RING_COLOR), ring_a)

    disc_a = cov(d_disc)
    if disc_a > 0:
        top = BADGE_CENTER[1] - BADGE_RADIUS
        fill = lerp_color(BADGE_FILL[0], BADGE_FILL[1],
                          (fy - top) / (2 * BADGE_RADIUS))
        px = over(px, tuple(c / 255 for c in fill), disc_a)

        gloss = sd_circle(fx, fy, BADGE_CENTER[0],
                          BADGE_CENTER[1] - BADGE_RADIUS * 0.34,
                          BADGE_RADIUS * 0.62)
        gloss_a = cov(gloss) * 0.14 * disc_a
        if gloss_a > 0:
            px = over(px, (1.0, 1.0, 1.0), gloss_a)

        d_check = min(
            sd_capsule(fx, fy, CHECK_POINTS[0][0], CHECK_POINTS[0][1],
                       CHECK_POINTS[1][0], CHECK_POINTS[1][1], CHECK_RADIUS),
            sd_capsule(fx, fy, CHECK_POINTS[1][0], CHECK_POINTS[1][1],
                       CHECK_POINTS[2][0], CHECK_POINTS[2][1], CHECK_RADIUS),
        )
        check_a = cov(d_check) * disc_a
        if check_a > 0:
            px = over(px, (1.0, 1.0, 1.0), check_a)

    return px


def render(include_bg, mark_scale):
    rows = []
    for py in range(S):
        row = bytearray()
        for px in range(S):
            # Sample in design space; scale the mark about the canvas centre.
            fx = 0.5 + ((px + 0.5) / S - 0.5) / mark_scale
            fy = 0.5 + ((py + 0.5) / S - 0.5) / mark_scale
            r, g, b, a = shade(fx, fy, mark_scale, include_bg)
            row += bytes((
                int(max(0, min(255, round(r * 255)))),
                int(max(0, min(255, round(g * 255)))),
                int(max(0, min(255, round(b * 255)))),
                int(max(0, min(255, round(a * 255)))),
            ))
        rows.append(row)
    return rows


def write_png(path, rows):
    raw = b"".join(b"\x00" + bytes(row) for row in rows)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = (b"\x89PNG\r\n\x1a\n" +
           chunk(b"IHDR", struct.pack(">IIBBBBB", S, S, 8, 6, 0, 0, 0)) +
           chunk(b"IDAT", zlib.compress(raw, 9)) +
           chunk(b"IEND", b""))
    with open(path, "wb") as handle:
        handle.write(png)
    return len(png)


def main():
    out_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                           "assets", "icon")
    os.makedirs(out_dir, exist_ok=True)

    plate = os.path.join(out_dir, "app_icon.png")
    size = write_png(plate, render(include_bg=True, mark_scale=1.0))
    print(f"wrote {plate} ({size / 1024:.1f} KiB)")

    foreground = os.path.join(out_dir, "app_icon_foreground.png")
    # Adaptive foregrounds are masked to the middle ~66% of the canvas.
    size = write_png(foreground, render(include_bg=False, mark_scale=0.66))
    print(f"wrote {foreground} ({size / 1024:.1f} KiB)")


if __name__ == "__main__":
    main()
