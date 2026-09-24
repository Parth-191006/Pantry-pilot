#!/usr/bin/env python3
"""Renders the Recipe Pilot launcher icons.

The mark (a single minimalist leaf) is defined *geometrically* here with
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
# Geometry — all units are fractions of the canvas side (same as logo.dart).
# The leaf axis runs diagonally (tip up-right, base down-left); the body is
# two quadratic arcs through tip and base, approximated here as an ellipse
# with the same length/width — visually identical at icon sizes.
# ---------------------------------------------------------------------------
LEAF_CENTER = (0.5, 0.46)
LEAF_LENGTH = 0.62
LEAF_HALF_WIDTH = 0.16
STEM_LENGTH = 0.09
STEM_RADIUS = 0.016
VEIN_BOW = 0.06      # perpendicular bow of the vein at the leaf's midpoint
VEIN_RADIUS = 0.013  # vein half-thickness

AXIS = (math.cos(math.radians(55)), -math.sin(math.radians(55)))  # base -> tip
PERP = (-AXIS[1], AXIS[0])                                        # left of axis

PLATE_RADIUS = 0.28
PLATE_STOPS = ((0.0, (0x43, 0xA0, 0x47)), (0.55, (0x1B, 0x5E, 0x20)),
               (1.0, (0x10, 0x33, 0x1A)))
LEAF_FILL = ((0xFD, 0xFB, 0xF3), (0xE3, 0xED, 0xD6))  # top-right -> bottom-left
VEIN_COLOR = (0x1B, 0x5E, 0x20)


# ---------------------------------------------------------------------------
# Signed distance helpers (design units)
# ---------------------------------------------------------------------------
def sd_rounded_rect(x, y, hw, hh, radius):
    dx = abs(x) - hw + radius
    dy = abs(y) - hh + radius
    ox, oy = max(dx, 0.0), max(dy, 0.0)
    return math.hypot(ox, oy) + min(max(dx, dy), 0.0) - radius


def sd_capsule(x, y, ax, ay, bx, by, radius):
    pax, pay = x - ax, y - ay
    bax, bay = bx - ax, by - ay
    denom = bax * bax + bay * bay
    h = 0.0 if denom == 0 else max(0.0, min(1.0, (pax * bax + pay * bay) / denom))
    return math.hypot(pax - bax * h, pay - bay * h) - radius


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


def leaf_frame(fx, fy):
    """Point in leaf-local coordinates: (along-axis a, across-axis b)."""
    dx, dy = fx - LEAF_CENTER[0], fy - LEAF_CENTER[1]
    a = dx * AXIS[0] + dy * AXIS[1]
    b = dx * PERP[0] + dy * PERP[1]
    return a, b


def shade(fx, fy, scale, include_bg):
    """Colour of one sample point, given in design space (0..1)."""
    aa = 1.0 / (S * scale)  # one screen pixel expressed in design units

    def cov(d):
        return max(0.0, min(1.0, 0.5 - d / aa))

    px = (0.0, 0.0, 0.0, 0.0)  # transparent

    if include_bg:
        d = sd_rounded_rect(fx - 0.5, fy - 0.5, 0.5, 0.5, PLATE_RADIUS)
        a = cov(d)
        if a > 0:
            base = grad(PLATE_STOPS, (fx + fy) / 2)
            # Soft light source in the upper-left corner of the plate.
            sheen = max(0.0, 1.0 - math.hypot(fx - 0.20, fy - 0.14) / 0.62) ** 2
            base = lerp_color(base, (255, 255, 255), 0.14 * sheen)
            px = over(px, tuple(c / 255 for c in base), a)

    # --- Leaf -----------------------------------------------------------------
    # Body: ellipse with the same length and half-width as the two-arc body
    # painted by logo.dart (indistinguishable at icon resolutions).
    a, b = leaf_frame(fx, fy)
    L = LEAF_LENGTH / 2
    W = LEAF_HALF_WIDTH
    qx, qy = a / L, b / W
    d_body = (math.hypot(qx, qy) - 1.0) * W
    body_a = cov(d_body)

    # Gradient axis in logo.dart runs top-right (white) -> bottom-left (sage).
    # Projection of the pixel onto that axis: t = (1 - x + y) / 2.
    t = (1.0 - fx + fy) / 2

    # Stem: capsule from the base, extending along -axis. It shares the fill
    # gradient, so it reads as part of the silhouette.
    base_x = LEAF_CENTER[0] - AXIS[0] * L
    base_y = LEAF_CENTER[1] - AXIS[1] * L
    stem_x = base_x - AXIS[0] * STEM_LENGTH
    stem_y = base_y - AXIS[1] * STEM_LENGTH
    d_stem = sd_capsule(fx, fy, base_x, base_y, stem_x, stem_y, STEM_RADIUS)
    stem_a = cov(d_stem)

    silhouette_a = max(body_a, stem_a)
    if silhouette_a > 0:
        fill = lerp_color(LEAF_FILL[0], LEAF_FILL[1], t)
        px = over(px, tuple(c / 255 for c in fill), silhouette_a)

    # --- Vein: shallow parabola from base to tip, bowed toward +perp ----------
    if body_a > 0:
        tt = max(-1.0, min(1.0, a / L))          # position along the axis
        vein_b = VEIN_BOW * (1.0 - tt * tt)      # bowed curve height
        if abs(a) <= L:
            d_vein = abs(b - vein_b) - VEIN_RADIUS
        else:
            # Outside the leaf's length: distance to the nearest endpoint.
            end_a = L if a > 0 else -L
            d_vein = math.hypot(a - end_a, b - vein_b) - VEIN_RADIUS
        vein_a = cov(d_vein) * body_a
        if vein_a > 0:
            px = over(px, tuple(c / 255 for c in VEIN_COLOR), vein_a * 0.55)

    return px


def render(include_bg, mark_scale):
    rows = []
    for py in range(S):
        row = bytearray()
        for px_i in range(S):
            # Sample in design space; scale the mark about the canvas centre.
            fx = 0.5 + ((px_i + 0.5) / S - 0.5) / mark_scale
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
