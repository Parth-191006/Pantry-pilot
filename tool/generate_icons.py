#!/usr/bin/env python3
"""Renders the Recipe Pilot launcher icons.

The mark (open recipe book + terracotta fork badge) is defined *geometrically*
here with signed-distance functions that mirror lib/ui/logo.dart one-for-one,
so the launcher artwork and the in-app vector logo stay the same drawing.

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
BOOK_CENTER = (0.455, 0.485)
PAGE_W = 0.23           # full width of one page
PAGE_H = 0.215          # full height of both pages
PAGE_TILT = math.radians(6)
PAGE_GAP = 0.014        # spine-to-page breathing room, per side
PAGE_RADIUS = 0.035

ING_LINE_WIDTHS = (0.115, 0.085, 0.100)
ING_LINE_YS = (0.28, 0.49, 0.70)   # fractions of page height from page top
ING_LINE_R = 0.012

DISH_DX = 0.10 * PAGE_W  # dish centre offset from the right page's centre
DISH_DY = -0.26 * PAGE_H  # upper half — the fork badge must never cover it
DISH_R = 0.19 * PAGE_H
DISH_LINE_R = 0.010

SPINE_HALF_W = 0.015
SPINE_HALF_H = 0.52 * PAGE_H

BADGE_CENTER = (0.735, 0.735)
BADGE_RADIUS = 0.195
FORK_R = 0.013           # stroke half-thickness
TINE_DX = 0.34           # tine x offsets, fractions of badge radius
TINE_TOP = -0.52
TINE_BOTTOM = -0.08
CROSSBAR_Y = -0.18
HANDLE_END = 0.58

COS_T, SIN_T = math.cos(PAGE_TILT), math.sin(PAGE_TILT)

PLATE_RADIUS = 0.28
PLATE_STOPS = ((0.0, (0x43, 0xA0, 0x47)), (0.55, (0x1B, 0x5E, 0x20)),
               (1.0, (0x10, 0x33, 0x1A)))
PAGE_FILL = ((0xFD, 0xFB, 0xF3), (0xED, 0xE4, 0xCF))
FOLD_COLOR = (0x8A, 0x7A, 0x55)
ING_COLOR = (0x4E, 0x9B, 0x5A)
SPINE_COLOR = (0x10, 0x33, 0x1A)
SHADOW_COLOR = (0x06, 0x30, 0x1A)
RING_COLOR = (0x06, 0x25, 0x1A)
BADGE_FILL = ((0xFF, 0xA5, 0x6B), (0xE2, 0x57, 0x1E))
DISH_FILL = ((0xFF, 0xB2, 0x7A), (0xE2, 0x57, 0x1E))


# ---------------------------------------------------------------------------
# Signed distance helpers (design units)
# ---------------------------------------------------------------------------
def sd_rounded_rect(x, y, hw, hh, radius):
    dx = abs(x) - hw + radius
    dy = abs(y) - hh + radius
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


def page_frame(fx, fy, direction):
    """Point in book-local coordinates for the page tilted by `direction`."""
    dx, dy = fx - BOOK_CENTER[0], fy - BOOK_CENTER[1]
    lx = dx * COS_T + direction * dy * SIN_T
    ly = -direction * dx * SIN_T + dy * COS_T
    return lx, ly


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

    # --- Book drop shadow ---------------------------------------------------
    d_shadow = sd_rounded_rect(
        fx - BOOK_CENTER[0], fy - BOOK_CENTER[1] - 0.028,
        PAGE_W + 0.006, PAGE_H / 2 + 0.006, PAGE_RADIUS,
    )
    shadow_a = 0.35 * max(0.0, min(1.0, 1.0 - d_shadow / (8 * aa))) ** 1.4
    if shadow_a > 0:
        px = over(px, tuple(c / 255 for c in SHADOW_COLOR), shadow_a)

    # --- Pages (fill + fold shading + contents, clipped to the page) --------
    for direction in (-1.0, 1.0):
        lx, ly = page_frame(fx, fy, direction)
        cx = direction * (PAGE_W / 2 + PAGE_GAP)
        d_page = sd_rounded_rect(lx - cx, ly, PAGE_W / 2, PAGE_H / 2, PAGE_RADIUS)
        page_a = cov(d_page)
        if page_a <= 0:
            continue

        fill = lerp_color(PAGE_FILL[0], PAGE_FILL[1], (lx + ly + 0.5) / 1.1)
        # Inner-edge darkening near the spine sells the fold.
        u = lx / PAGE_W  # -0.5 .. 0.5 across the page
        spine_prox = max(0.0, min(1.0, (direction * -u - 0.1) / 0.4))
        fill = lerp_color(fill, FOLD_COLOR, 0.22 * spine_prox)
        px = over(px, tuple(c / 255 for c in fill), page_a)

        content_a = 0.0
        content_rgb = (0.0, 0.0, 0.0)

        if direction < 0:
            # Left page: the ingredient list — three rounded lines.
            left = cx - PAGE_W / 2 + 0.20 * PAGE_W
            for width, yf in zip(ING_LINE_WIDTHS, ING_LINE_YS):
                y = (yf - 0.5) * PAGE_H
                d_line = sd_capsule(lx, ly, left, y, left + width, y, ING_LINE_R)
                content_a = max(content_a, cov(d_line) * 0.55)
            content_rgb = ING_COLOR
        else:
            # Right page: a plated dish — terracotta on a white plate.
            dish_cx = cx + DISH_DX
            dish_cy = DISH_DY
            d_plate = sd_circle(lx, ly, dish_cx, dish_cy, DISH_R)
            plate_a = cov(d_plate)
            if plate_a > 0:
                px = over(px, (0xFD / 255, 0xFB / 255, 0xF3 / 255),
                          plate_a * page_a)
                inner = math.hypot(lx - dish_cx, ly - dish_cy) / (DISH_R * 0.72)
                dish_rgb = lerp_color(DISH_FILL[0], DISH_FILL[1], inner)
                px = over(px, tuple(c / 255 for c in dish_rgb),
                          cov(d_plate + DISH_R * 0.28) * page_a)
            # A serving line under the dish.
            y = 0.26 * PAGE_H
            line_l = cx - PAGE_W / 2 + 0.24 * PAGE_W
            d_line = sd_capsule(lx, ly, line_l, y,
                                line_l + 0.48 * PAGE_W, y, DISH_LINE_R)
            content_a = cov(d_line) * 0.45
            content_rgb = ING_COLOR

        if content_a > 0:
            px = over(px, tuple(c / 255 for c in content_rgb),
                      content_a * page_a)

    # --- Spine ---------------------------------------------------------------
    d_spine = sd_rounded_rect(
        fx - BOOK_CENTER[0], fy - BOOK_CENTER[1],
        SPINE_HALF_W, SPINE_HALF_H, SPINE_HALF_W,
    )
    spine_a = cov(d_spine)
    if spine_a > 0:
        px = over(px, tuple(c / 255 for c in SPINE_COLOR), spine_a)

    # --- Fork badge ----------------------------------------------------------
    bcx, bcy = BADGE_CENTER
    br = BADGE_RADIUS

    d_disc = sd_circle(fx, fy, bcx, bcy, br)
    ring_a = cov(abs(d_disc) - br * 0.11) * 0.38
    if ring_a > 0:
        px = over(px, tuple(c / 255 for c in RING_COLOR), ring_a)

    disc_a = cov(d_disc)
    if disc_a > 0:
        top = bcy - br
        fill = lerp_color(BADGE_FILL[0], BADGE_FILL[1], (fy - top) / (2 * br))
        px = over(px, tuple(c / 255 for c in fill), disc_a)

        gloss = sd_circle(fx, fy, bcx, bcy - br * 0.34, br * 0.62)
        gloss_a = cov(gloss) * 0.14 * disc_a
        if gloss_a > 0:
            px = over(px, (1.0, 1.0, 1.0), gloss_a)

        # The fork: three tines fanning from a crossbar into one handle.
        tines = [
            sd_capsule(fx, fy,
                       bcx + br * dx * 0.68, bcy + br * TINE_TOP,
                       bcx + br * dx * 0.68, bcy + br * (CROSSBAR_Y + 0.10),
                       FORK_R)
            for dx in (-TINE_DX, 0.0, TINE_DX)
        ]
        crossbar = sd_capsule(fx, fy,
                              bcx - br * TINE_DX * 0.68, bcy + br * CROSSBAR_Y,
                              bcx + br * TINE_DX * 0.68, bcy + br * CROSSBAR_Y,
                              FORK_R)
        handle = sd_capsule(fx, fy, bcx, bcy + br * CROSSBAR_Y,
                            bcx, bcy + br * HANDLE_END, FORK_R)
        d_fork = min(min(tines), crossbar, handle)
        fork_a = cov(d_fork) * disc_a
        if fork_a > 0:
            px = over(px, (1.0, 1.0, 1.0), fork_a)

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
