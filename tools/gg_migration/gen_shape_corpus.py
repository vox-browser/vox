#!/usr/bin/env python3
"""Generate a deterministic gg.canvas scene script covering rect/rrect/oval draws."""
import argparse
import math
import random

TRANSFORMS = {
    'identity': [1, 0, 0, 0, 1, 0, 0, 0, 1],
    'translate': [1, 0, 0.375, 0, 1, -0.625, 0, 0, 1],
    'scale2': [2, 0, 0.25, 0, 2, 0.5, 0, 0, 1],
    'scale_half': [0.5, 0, 3, 0, 0.5, 2.25, 0, 0, 1],
    'anisotropic': [2, 0, 1, 0, 0.75, 3, 0, 0, 1],
    'flip_x': [-1, 0, 60, 0, 1, 0, 0, 0, 1],
    'rotate90': [0, -1, 60, 1, 0, 2, 0, 0, 1],
    'rotate30': [math.cos(math.pi / 6), -math.sin(math.pi / 6), 20,
                 math.sin(math.pi / 6), math.cos(math.pi / 6), -6, 0, 0, 1],
    'skew': [1, 0.3, 0, 0.1, 1, 0, 0, 0, 1],
}


def f(v):
    return repr(float(v))


def random_paint(rng):
    style = rng.choice([0, 0, 1])
    width = rng.choice([0, 1, 2.5, 6]) if style else 0
    color = [rng.choice([0, 0.25, 0.5, 35 / 255, 1]) for _ in range(3)]
    alpha = rng.choice([1, 1, 0.5, 200 / 255, 1 / 255])
    return 'paint {} {} {} {} {} {} {} {} {} {}'.format(
        *map(f, color), f(alpha), rng.choice([0, 1, 1]), style, f(width),
        rng.choice([0, 1, 2]), rng.choice([0, 1, 2]), f(rng.choice([4, 1, 1.5])))


def random_shape(rng, width, height):
    left = rng.choice([rng.uniform(-8, width / 2), round(rng.uniform(0, width / 2)),
                       round(rng.uniform(0, width / 2)) + 0.5])
    top = rng.choice([rng.uniform(-8, height / 2), round(rng.uniform(0, height / 2))])
    w = rng.choice([rng.uniform(0.25, 3), rng.uniform(4, width), round(rng.uniform(4, width))])
    h = rng.choice([rng.uniform(0.25, 3), rng.uniform(4, height), round(rng.uniform(4, height))])
    kind = rng.choice(['rect', 'rrect', 'rrect', 'oval'])
    ltrb = '{} {} {} {}'.format(f(left), f(top), f(left + w), f(top + h))
    if kind != 'rrect':
        return f'{kind} {ltrb}'
    mode = rng.choice(['circular', 'elliptical', 'complex', 'huge'])
    if mode == 'circular':
        r = rng.uniform(0.5, min(w, h) / 2)
        radii = [r, r] * 4
    elif mode == 'elliptical':
        rx, ry = rng.uniform(0.5, w / 2), rng.uniform(0.5, h / 2)
        radii = [rx, ry] * 4
    elif mode == 'complex':
        radii = [rng.choice([0, rng.uniform(0.5, 9)]) for _ in range(8)]
    else:
        radii = [rng.uniform(w, 3 * w) for _ in range(8)]
    return f'rrect {ltrb} ' + ' '.join(map(f, radii))


def random_clip_out(rng, width, height):
    """A non-AA difference clip rectangle: narrow gaps (like skip-ink underline
    gaps), large regions, fractional edges and slivers that round away."""
    kind = rng.choice(['gap', 'gap', 'large', 'fraction', 'sliver'])
    if kind == 'gap':
        w, h = rng.uniform(1.5, 8), rng.uniform(2, 6)
    elif kind == 'large':
        w, h = rng.uniform(16, width), rng.uniform(10, height)
    elif kind == 'fraction':
        w, h = rng.choice([2.25, 5.5, 9.75]), rng.choice([3.5, 7.25])
    else:
        w, h = rng.uniform(0.1, 0.45), rng.uniform(4, height)
    left = rng.uniform(-6, width - 2)
    top = rng.uniform(-6, height - 2)
    if kind == 'fraction':
        left, top = round(left) + 0.25, round(top) + 0.5
    return 'clipout {} {} {} {}'.format(f(left), f(top), f(left + w), f(top + h))


def random_radii(rng, w, h, mode=None):
    mode = mode or rng.choice(['circular', 'elliptical', 'complex', 'tab', 'oval'])
    if mode == 'circular':
        r = rng.uniform(0.5, max(0.5, min(w, h) / 2))
        return [r, r] * 4
    if mode == 'elliptical':
        rx, ry = rng.uniform(0.5, max(0.5, w / 2)), rng.uniform(0.5, max(0.5, h / 2))
        return [rx, ry] * 4
    if mode == 'tab':
        # Two adjacent rounded corners, like a three-sided label.
        r = rng.uniform(0.5, max(0.5, min(w, h) / 2))
        first = rng.randrange(4)
        radii = [0.0] * 8
        for corner in (first, (first + 1) % 4):
            radii[2 * corner] = radii[2 * corner + 1] = r
        return radii
    if mode == 'oval':
        return [w / 2, h / 2] * 4
    return [rng.choice([0, rng.uniform(0.5, 9)]) for _ in range(8)]


def random_box(rng, width, height):
    left = rng.choice([rng.uniform(-8, width * 0.7), round(rng.uniform(0, width / 2)),
                       round(rng.uniform(0, width / 2)) + 0.5])
    top = rng.choice([rng.uniform(-8, height * 0.7), round(rng.uniform(0, height / 2))])
    w = rng.choice([rng.uniform(2, width), round(rng.uniform(4, width))])
    h = rng.choice([rng.uniform(2, height), round(rng.uniform(4, height))])
    return left, top, w, h


def ltrb(left, top, w, h):
    return '{} {} {} {}'.format(f(left), f(top), f(left + w), f(top + h))


def random_clip(rng, width, height):
    """An intersect or difference rect or rrect clip, with or without AA."""
    left, top, w, h = random_box(rng, width, height)
    op = rng.choice([0, 1])
    aa = rng.choice([0, 1, 1])
    if rng.random() < 0.4:
        return f'cliprect {ltrb(left, top, w, h)} {op} {aa}'
    radii = random_radii(rng, w, h)
    return f'cliprrect {ltrb(left, top, w, h)} ' + ' '.join(map(f, radii)) + f' {op} {aa}'


def random_drrect(rng, width, height):
    """drawDRRect: uniform rings (stroked rrects), elliptical rings like CSS
    borders, and rect or rrect holes."""
    left, top, w, h = random_box(rng, width, height)
    mode = rng.choice(['ring', 'elliptical', 'rect', 'hole'])
    if mode == 'ring':
        d = rng.choice([0.5, 1, 2, rng.uniform(0.5, 4)])
        r = rng.choice([0, rng.uniform(0, min(w, h) / 2)])
        outer = [r, r] * 4
        inner = [max(0, r - d)] * 8
        dx = dy = d
    elif mode == 'elliptical':
        d = rng.choice([0.5, 1, 2])
        rx, ry = rng.uniform(1, max(1, w / 2)), rng.uniform(1, max(1, h / 2))
        outer = [rx, ry] * 4
        inner = [max(0, rx - d), max(0, ry - d)] * 4
        dx = dy = d
    elif mode == 'rect':
        outer = [0] * 8
        inner = [0] * 8
        dx, dy = rng.uniform(0, w / 3), rng.uniform(0, h / 3)
    else:
        outer = random_radii(rng, w, h)
        dx, dy = rng.uniform(0.5, w / 3), rng.uniform(0.5, h / 3)
        inner = random_radii(rng, max(1, w - 2 * dx), max(1, h - 2 * dy))
    return ('drrect ' + ltrb(left, top, w, h) + ' ' + ' '.join(map(f, outer)) + ' '
            + ltrb(left + dx, top + dy, w - 2 * dx, h - 2 * dy) + ' ' + ' '.join(map(f, inner)))


def border_side(rng, width, height):
    """The clips of a single rounded CSS border side (Vox's border modes):
    outer rrect intersect, inner rrect difference, then a side rectangle."""
    left, top, w, h = random_box(rng, width, height)
    r = rng.choice([3, 8, rng.uniform(1, min(w, h) / 2)])
    widths = [0, 0, 0, 0]
    side = rng.randrange(4)
    widths[side] = rng.choice([1, 2, 3])
    inner_radii = []
    for corner in range(4):
        wx = widths[3] if corner in (0, 3) else widths[1]
        wy = widths[0] if corner < 2 else widths[2]
        inner_radii += [max(0, r - wx), max(0, r - wy)]
    il, it = left + widths[3], top + widths[0]
    iw, ih = w - widths[1] - widths[3], h - widths[0] - widths[2]
    extent = max(widths[side], r)
    side_box = [(left, top, w, extent), (left + w - extent, top, extent, h),
                (left, top + h - extent, w, extent), (left, top, extent, h)][side]
    return ['save',
            f'cliprrect {ltrb(left, top, w, h)} ' + ' '.join(map(f, [r, r] * 4)) + ' 0 1',
            f'cliprrect {ltrb(il, it, iw, ih)} ' + ' '.join(map(f, inner_radii)) + ' 1 1',
            'save', f'cliprect {ltrb(*side_box)} 0 1', f'rect {ltrb(left, top, w, h)}',
            'restore', 'restore']


def random_path(rng, width, height):
    """A filled path: convex and concave polygons, stars, curves, several
    contours, rect-shaped and nested-rect paths, and ovals."""
    fill = rng.choice([0, 0, 1])
    cx, cy = rng.uniform(0, width), rng.uniform(0, height)
    size = rng.choice([rng.uniform(2, 12), rng.uniform(10, max(width, height))])
    kind = rng.choice(['polygon', 'polygon', 'star', 'curves', 'contours', 'rect', 'nested',
                       'oval'])

    def pt(r=size):
        return rng.uniform(cx - r, cx + r), rng.uniform(cy - r, cy + r)

    tokens = []
    if kind == 'polygon':
        n = rng.randrange(3, 9)
        angles = sorted(rng.uniform(0, 2 * math.pi) for _ in range(n))
        if rng.random() < 0.5:
            rng.shuffle(angles)  # usually concave or self-intersecting
        for i, a in enumerate(angles):
            r = size * rng.uniform(0.4, 1)
            tokens += ['M' if i == 0 else 'L', f(cx + r * math.cos(a)), f(cy + r * math.sin(a))]
        tokens.append('Z')
    elif kind == 'star':
        n = rng.choice([5, 7])
        for i in range(n):
            a = 2 * math.pi * (i * 2 % n) / n
            tokens += ['M' if i == 0 else 'L', f(cx + size * math.sin(a)), f(cy - size * math.cos(a))]
        tokens.append('Z')
    elif kind == 'curves':
        x, y = pt()
        tokens += ['M', f(x), f(y)]
        for _ in range(rng.randrange(1, 5)):
            verb = rng.choice(['L', 'Q', 'C', 'K', 'A'])
            if verb == 'L':
                tokens += ['L', *map(f, pt())]
            elif verb == 'Q':
                tokens += ['Q', *map(f, pt()), *map(f, pt())]
            elif verb == 'C':
                tokens += ['C', *map(f, pt()), *map(f, pt()), *map(f, pt())]
            elif verb == 'K':
                tokens += ['K', *map(f, pt()), *map(f, pt()), f(rng.choice([0.5, 0.707106781, 2]))]
            else:
                # SVG arcs, sometimes with integer radii, rotations and end points.
                if rng.random() < 0.4:
                    r = rng.randrange(1, max(2, int(size)))
                    tokens += ['A', f(r), f(r), f(rng.choice([0, 90, 180])), str(rng.randrange(2)),
                               str(rng.randrange(2)), *map(lambda v: f(round(v)), pt())]
                else:
                    tokens += ['A', f(rng.uniform(0, size)), f(rng.uniform(0, size)),
                               f(rng.uniform(-180, 180)), str(rng.randrange(2)),
                               str(rng.randrange(2)), *map(f, pt())]
        if rng.random() < 0.8:
            tokens.append('Z')
    elif kind == 'contours':
        for _ in range(rng.randrange(2, 4)):
            x, y = pt()
            tokens += ['M', f(x), f(y)]
            for _ in range(rng.randrange(2, 5)):
                tokens += ['L', *map(f, pt())]
            tokens.append('Z')
    elif kind == 'rect':
        l, t = pt()
        r, b = l + rng.uniform(1, size), t + rng.uniform(1, size)
        tokens += ['M', f(l), f(t), 'L', f(r), f(t), 'L', f(r), f(b), 'L', f(l), f(b)]
        if rng.random() < 0.5:
            tokens.append('Z')
    elif kind == 'nested':
        l, t = pt()
        r, b = l + rng.uniform(6, 2 * size), t + rng.uniform(6, 2 * size)
        i = rng.uniform(1, 3)
        tokens += ['M', f(l), f(t), 'L', f(r), f(t), 'L', f(r), f(b), 'L', f(l), f(b), 'Z']
        if rng.random() < 0.5:
            tokens += ['M', f(l + i), f(t + i), 'L', f(r - i), f(t + i), 'L', f(r - i), f(b - i),
                       'L', f(l + i), f(b - i), 'Z']
        else:
            tokens += ['M', f(l + i), f(t + i), 'L', f(l + i), f(b - i), 'L', f(r - i), f(b - i),
                       'L', f(r - i), f(t + i), 'Z']
    else:
        l, t = pt()
        tokens += ['O', f(l), f(t), f(l + rng.uniform(1, size)), f(t + rng.uniform(1, size))]
    return f'path {fill} ' + ' '.join(tokens)


def random_curve_path(rng, width, height):
    """A path of curves that need chopping (control points far outside the
    surface) or that turn around by 180 degrees on a line (cusps)."""
    fill = rng.choice([0, 1])
    cx, cy = rng.uniform(0, width), rng.uniform(0, height)
    tokens = []
    if rng.random() < 0.5:
        reach = rng.choice([4, 10, 40]) * max(width, height)

        def far():
            return rng.uniform(cx - reach, cx + reach), rng.uniform(cy - reach, cy + reach)

        def near():
            return rng.uniform(0, width), rng.uniform(0, height)

        tokens += ['M', *map(f, near())]
        for _ in range(rng.randrange(1, 4)):
            verb = rng.choice(['Q', 'C', 'K'])
            if verb == 'Q':
                tokens += ['Q', *map(f, far()), *map(f, near())]
            elif verb == 'C':
                tokens += ['C', *map(f, far()), *map(f, far()), *map(f, near())]
            else:
                tokens += ['K', *map(f, far()), *map(f, near()),
                           f(rng.choice([0.25, 0.707106781, 3]))]
    else:
        # Points on an axis-aligned or diagonal line with integer steps, so the
        # turnaround is exact.
        dx, dy = rng.choice([(1, 0), (0, 1), (1, 1), (1, -1)])
        x0, y0 = round(cx), round(cy)

        def at(k):
            return f(x0 + dx * k), f(y0 + dy * k)

        a, b, c = sorted(rng.sample(range(-30, 31), 3))
        tokens += ['M', *at(a)]
        verb = rng.choice(['Q', 'K', 'C', 'C'])
        if verb == 'Q':
            tokens += ['Q', *at(c), *at(b)]
        elif verb == 'K':
            tokens += ['K', *at(c), *at(b), f(rng.choice([0.5, 0.707106781, 2]))]
        elif rng.random() < 0.5:
            # Two turnarounds.
            tokens += ['C', *at(c), *at(a), *at(b)]
        else:
            tokens += ['C', *at(c), *at(b), *at(rng.randrange(-30, 31))]
        if rng.random() < 0.5:
            tokens += ['L', f(x0 + 5), f(y0 + 9)]
    if rng.random() < 0.3:
        tokens.append('Z')
    return f'path {fill} ' + ' '.join(tokens)


def random_line_path(rng, width, height):
    """A single line segment (SkPath::isLine), sometimes axis-aligned, pixel
    aligned or of zero length (a dot with round or square caps)."""
    x0, y0 = rng.uniform(-4, width + 4), rng.uniform(-4, height + 4)
    kind = rng.choice(['any', 'any', 'horizontal', 'vertical', 'aligned', 'dot'])
    if kind == 'horizontal':
        x1, y1 = rng.uniform(-4, width + 4), y0
    elif kind == 'vertical':
        x1, y1 = x0, rng.uniform(-4, height + 4)
    elif kind == 'aligned':
        x0, y0 = round(x0) + 0.5, round(y0)
        x1, y1 = x0, round(rng.uniform(0, height))
    elif kind == 'dot':
        x1, y1 = x0, y0
    else:
        x1, y1 = rng.uniform(-4, width + 4), rng.uniform(-4, height + 4)
    return f'path 0 M {f(x0)} {f(y0)} L {f(x1)} {f(y1)}'


def path_scene(rng, width, height, strokes=False, curves=False, lines_only=False,
               gradients=False):
    lines = []
    for _ in range(rng.choice([1, 1, 2, 3, 5])):
        transform = rng.choice(list(TRANSFORMS))
        lines.append('matrix ' + ' '.join(map(f, TRANSFORMS[transform])))
        paint = random_paint(rng).split()
        if strokes:
            # Strokes of every join and cap, hairlines and miter limits.
            paint[6] = rng.choice(['1', '1', '0'])
            paint[7] = f(rng.choice([0, 1, 2.5, 6, rng.uniform(0.5, 10)]))
            paint[10] = f(rng.choice([4, 1, 1.5, 10]))
        else:
            paint[6] = '0'  # fills
        if gradients:
            paint[4] = '1'  # an opaque paint color
        lines.append(' '.join(paint))
        if gradients and rng.random() < 0.85:
            lines.append(random_gradient(rng, width, height))
        clipped = rng.random() < 0.25
        if clipped:
            lines.append('save')
            lines.append(random_clip(rng, width, height))
        if lines_only:
            lines.append(random_line_path(rng, width, height))
        elif curves:
            lines.append(random_curve_path(rng, width, height))
        elif rng.random() < 0.75:
            lines.append(random_path(rng, width, height))
        else:
            lines.append(random_shape(rng, width, height))
        if clipped:
            lines.append('restore')
    return lines


def clip_scene(rng, width, height):
    lines = []
    open_saves = 0
    for _ in range(rng.choice([1, 1, 2, 3])):
        transform = rng.choice(list(TRANSFORMS))
        lines.append('matrix ' + ' '.join(map(f, TRANSFORMS[transform])))
        paint = random_paint(rng).split()
        if rng.random() < 0.8:
            paint[6] = '0'  # mostly fills
        lines.append(' '.join(paint))
        if rng.random() < 0.25:
            lines += border_side(rng, width, height)
            continue
        if rng.random() < 0.5:
            lines.append('save')
            open_saves += 1
        for _ in range(rng.choice([0, 1, 1, 2, 3])):
            lines.append(random_clip(rng, width, height))
        if rng.random() < 0.35:
            lines.append(random_drrect(rng, width, height))
        else:
            lines.append(random_shape(rng, width, height))
        if open_saves and rng.random() < 0.6:
            lines.append('restore')
            open_saves -= 1
    return lines


def random_gradient(rng, width, height):
    """A gradient line like the bridge's SVG path gradients: linear, or
    two-point conical that is mostly radial (concentric, from a point), with
    2 to 8 stops (sometimes more), every tile mode, implicit, duplicate and
    unsorted positions, premultiplied interpolation and local matrices.
    Some lines use features gg.canvas does not support yet (no dithering,
    a linear color space, translucent paints, other conical gradients)."""
    kind = rng.choice([1, 1, 1, 2, 2])
    tile = rng.choice([0, 0, 0, 0, 1, 2, 3])
    premul = rng.choice([0, 1])
    dither = 1 if rng.random() < 0.95 else 0
    linear_cs = 1 if rng.random() < 0.04 else 0
    opacity = 1 if rng.random() < 0.92 else rng.choice([0.5, 200 / 255])
    count = rng.choice([2, 2, 2, 3, 3, 4, 5, 6, 8] + ([10] if rng.random() < 0.3 else []))
    if kind == 1:
        x0, y0 = rng.uniform(-10, width + 10), rng.uniform(-10, height + 10)
        if rng.random() < 0.03:
            x1, y1 = x0, y0
        else:
            x1, y1 = rng.uniform(-10, width + 10), rng.uniform(-10, height + 10)
        points = [x0, y0, x1, y1, 0, 0]
    else:
        cx, cy = rng.uniform(0, width), rng.uniform(0, height)
        r1 = rng.choice([rng.uniform(2, max(width, height)), rng.uniform(0.5, 4)])
        if rng.random() < 0.1:
            # A conical gradient that is not radial.
            points = [cx, cy, rng.uniform(1, 6), cx + rng.uniform(-6, 6), cy, r1]
        else:
            points = [cx, cy, 0, cx, cy, r1]
    m = rng.choice([
        [1, 0, 0, 0, 1, 0, 0, 0, 1],
        [1, 0, 0, 0, 1, 0, 0, 0, 1],
        [2, 0, -3, 0, 0.5, 4, 0, 0, 1],
        [0.8660254, -0.5, 10, 0.5, 0.8660254, -4, 0, 0, 1],
        [1, 0.25, 0, 0, 1, 0, 0, 0, 1],
        [1, 0, rng.uniform(-8, 8), 0, 1, rng.uniform(-8, 8), 0, 0, 1],
    ])
    mode = rng.choice(['even', 'sorted', 'sorted', 'implicit', 'hard', 'unsorted'])
    if mode == 'even':
        positions = [i / (count - 1) for i in range(count)]
    elif mode == 'sorted':
        positions = sorted(rng.random() for _ in range(count))
        positions[0], positions[-1] = 0, 1
    elif mode == 'implicit':
        positions = sorted(rng.uniform(0.1, 0.9) for _ in range(count))
    elif mode == 'hard':
        positions = sorted(rng.choice([0, 0.25, 0.5, 0.5, 0.75, 1]) for _ in range(count))
    else:
        positions = [rng.random() for _ in range(count)]
    stops = []
    translucent = rng.random() < 0.25
    for pos in positions:
        color = [rng.choice([0, 1, rng.random()]) for _ in range(3)]
        alpha = rng.choice([1, 0.5, 0, rng.random()]) if translucent else 1
        stops.append(' '.join(map(f, color + [alpha, pos])))
    return 'gradient {} {} {} {} {} {} {} {} {}  {}'.format(
        kind, tile, premul, dither, linear_cs, f(opacity), count,
        ' '.join(map(f, points)), ' '.join(map(f, m)), '  '.join(stops))


def gradient_scene(rng, width, height):
    """Rects, rrects and ovals filled and stroked with gradients and solid
    colors, under transforms and rect and rrect clips."""
    lines = []
    open_saves = 0
    for _ in range(rng.choice([1, 1, 2, 3])):
        transform = rng.choice(list(TRANSFORMS))
        lines.append('matrix ' + ' '.join(map(f, TRANSFORMS[transform])))
        paint = random_paint(rng).split()
        if rng.random() < 0.8:
            paint[6] = '0'  # mostly fills
        paint[4] = '1'  # an opaque paint color
        lines.append(' '.join(paint))
        if rng.random() < 0.85:
            lines.append(random_gradient(rng, width, height))
        if rng.random() < 0.5:
            lines.append('save')
            open_saves += 1
            for _ in range(rng.choice([0, 1, 1, 2])):
                lines.append(random_clip(rng, width, height))
        lines.append(random_shape(rng, width, height))
        if open_saves and rng.random() < 0.6:
            lines.append('restore')
            open_saves -= 1
    return lines


def layer_scene(rng, width, height):
    """saveLayer scenes: rect, rrect and path clips before unbounded and
    bounded layers (sometimes nested), filled and stroked shapes, paths and
    gradients inside them, and draws after their restore."""
    lines = []
    depth = 0
    for _ in range(rng.choice([1, 2, 2, 3])):
        transform = rng.choice(list(TRANSFORMS))
        lines.append('matrix ' + ' '.join(map(f, TRANSFORMS[transform])))
        for _ in range(rng.choice([0, 1, 1, 2])):
            lines.append(random_clip(rng, width, height))
        if depth < 2 and rng.random() < 0.75:
            if rng.random() < 0.3:
                left, top, w, h = random_box(rng, width, height)
                lines.append(f'savelayer {ltrb(left, top, w, h)}')
            else:
                lines.append('savelayer')
            depth += 1
            if rng.random() < 0.4:
                transform = rng.choice(list(TRANSFORMS))
                lines.append('matrix ' + ' '.join(map(f, TRANSFORMS[transform])))
            if rng.random() < 0.3:
                lines.append(random_clip(rng, width, height))
        for _ in range(rng.choice([1, 1, 2, 3])):
            paint = random_paint(rng).split()
            if rng.random() < 0.7:
                paint[6] = '0'  # mostly fills
            lines.append(' '.join(paint))
            if rng.random() < 0.25:
                paint[4] = '1'
                lines[-1] = ' '.join(paint)
                lines.append(random_gradient(rng, width, height))
            if rng.random() < 0.4:
                lines.append(random_path(rng, width, height))
            else:
                lines.append(random_shape(rng, width, height))
        if depth and rng.random() < 0.6:
            lines.append('restore')
            depth -= 1
    while depth:
        lines.append('restore')
        depth -= 1
    if rng.random() < 0.5:
        lines.append(random_paint(rng))
        lines.append(random_shape(rng, width, height))
    return lines


def random_clip_path(rng, width, height):
    """A clipPath line: polygons (triangles, convex and concave quads, stars,
    several contours, border-corner miters), sometimes a rect or oval path
    that SkCanvas turns into a rect or rrect clip."""
    op = rng.choice([0, 0, 1])
    aa = rng.choice([0, 1])
    fill = rng.choice([0, 0, 1])
    cx, cy = rng.uniform(0, width), rng.uniform(0, height)
    size = rng.uniform(4, max(width, height))

    def pt():
        return f(rng.uniform(cx - size, cx + size)), f(rng.uniform(cy - size, cy + size))

    kind = rng.choice(['triangle', 'quad', 'quad', 'polygon', 'star', 'contours', 'miter',
                       'rect', 'oval'])
    tokens = []
    if kind in ('triangle', 'quad', 'polygon'):
        n = {'triangle': 3, 'quad': 4}.get(kind, rng.randrange(5, 9))
        angles = sorted(rng.uniform(0, 2 * math.pi) for _ in range(n))
        if rng.random() < 0.4:
            rng.shuffle(angles)  # concave or self-intersecting
        for i, a in enumerate(angles):
            r = size * rng.uniform(0.3, 1)
            tokens += ['M' if i == 0 else 'L', f(cx + r * math.cos(a)), f(cy + r * math.sin(a))]
        tokens.append('Z')
    elif kind == 'star':
        n = rng.choice([5, 7])
        for i in range(n):
            a = 2 * math.pi * (i * 2 % n) / n
            tokens += ['M' if i == 0 else 'L', f(cx + size * math.sin(a)), f(cy - size * math.cos(a))]
        tokens.append('Z')
    elif kind == 'contours':
        for _ in range(rng.randrange(2, 4)):
            tokens += ['M', *pt()]
            for _ in range(rng.randrange(2, 4)):
                tokens += ['L', *pt()]
            tokens.append('Z')
    elif kind == 'miter':
        # Like the difference quadrilaterals of CSS border corners.
        l, t = rng.uniform(0, width / 2), rng.uniform(0, height / 2)
        w, h = rng.uniform(4, width / 2), rng.uniform(4, height / 2)
        a, b = rng.uniform(1, 6), rng.uniform(1, 6)
        tokens += ['M', f(l - a), f(t - b), 'L', f(l + a * h / b), f(t + h), 'L', f(l + w + a),
                   f(t + b), 'L', f(l + w - a), f(t - b), 'Z']
    elif kind == 'rect':
        l, t = pt()
        tokens += ['M', l, t, 'L', f(float(l) + size), t, 'L', f(float(l) + size),
                   f(float(t) + size / 2), 'L', l, f(float(t) + size / 2), 'Z']
    else:
        l, t = pt()
        tokens += ['O', l, t, f(float(l) + size), f(float(t) + size * 0.7)]
    return f'clippath {op} {aa} {fill} ' + ' '.join(tokens)


def clip_path_scene(rng, width, height):
    lines = []
    for _ in range(rng.choice([1, 1, 2, 3])):
        transform = rng.choice(list(TRANSFORMS))
        lines.append('matrix ' + ' '.join(map(f, TRANSFORMS[transform])))
        paint = random_paint(rng).split()
        if rng.random() < 0.7:
            paint[6] = '0'  # mostly fills
        lines.append(' '.join(paint))
        lines.append('save')
        for _ in range(rng.choice([1, 1, 2, 3])):
            if rng.random() < 0.7:
                lines.append(random_clip_path(rng, width, height))
            else:
                lines.append(random_clip(rng, width, height))
        if rng.random() < 0.6:
            lines.append(random_shape(rng, width, height))
        else:
            lines.append(random_path(rng, width, height))
        lines.append('restore')
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seed', type=int, default=20261104)
    parser.add_argument('--count', type=int, default=400)
    parser.add_argument('--many', type=int, default=0,
                        help='draws per scene (default: mostly 1, up to 4)')
    parser.add_argument('--fills', action='store_true',
                        help='avoid strokes (keeps many-draw scenes on the analytic renderers)')
    parser.add_argument('--clip-outs', action='store_true',
                        help='clip out rectangles (non-AA difference clips) before some draws')
    parser.add_argument('--clips', action='store_true',
                        help='scenes with save/restore, intersect and difference rect and rrect '
                             'clips, drawDRRect and CSS border side clips')
    parser.add_argument('--paths', action='store_true',
                        help='scenes of filled paths (polygons, curves, contours, rects, ovals) '
                             'mixed with shapes and clips')
    parser.add_argument('--strokes', action='store_true',
                        help='like --paths, but mostly strokes of every join and cap')
    parser.add_argument('--curves', action='store_true',
                        help='like --strokes, but stroked and filled curves that need chopping '
                             'or turn around on a line (cusps)')
    parser.add_argument('--lines', action='store_true',
                        help='like --strokes, but single line segments (drawn as drawPoints '
                             'lines), including zero-length dots')
    parser.add_argument('--clip-paths', action='store_true',
                        help='scenes of polygon clipPath calls (and rect and rrect clips) before '
                             'shape and path draws')
    parser.add_argument('--gradients', action='store_true',
                        help='scenes of rects, rrects and ovals with linear and radial gradient '
                             'paints under transforms and clips; with --paths or --strokes, '
                             'gradient paths')
    parser.add_argument('--inverse', action='store_true',
                        help='like --paths, but some fills use the inverse fill types')
    parser.add_argument('--layers', action='store_true',
                        help='saveLayer scenes: clips, unbounded and bounded (nested) layers with '
                             'shapes, paths and gradients inside, and draws after their restore')
    parser.add_argument('--msaa-backdrops', action='store_true',
                        help='also give 4x MSAA scenes a backdrop (loaded from the resolve texture)')
    args = parser.parse_args()
    rng = random.Random(args.seed)
    # A separate stream keeps the scenes identical to the corpus without clips.
    clip_rng = random.Random(args.seed + 1)
    inverse_rng = random.Random(args.seed + 2)
    for index in range(args.count):
        width, height = rng.choice([(64, 48), (64, 48), (160, 120)])
        samples = rng.choice([1, 1, 4])
        background = rng.choice([0, 1]) if samples == 1 or args.msaa_backdrops else 0
        name = f'shape-{index:04d}'
        print(f'scene {name} {width} {height} {samples} {background}')
        if args.paths or args.strokes or args.curves or args.lines or args.inverse:
            for line in path_scene(clip_rng, width, height,
                                   args.strokes or args.curves or args.lines, args.curves,
                                   args.lines, args.gradients):
                if args.inverse and line.startswith('path ') and inverse_rng.random() < 0.5:
                    fill, rest = line[len('path '):].split(' ', 1)
                    line = f'path {int(fill) + 2} {rest}'
                print(line)
            print('end')
            continue
        if args.clip_paths:
            for line in clip_path_scene(clip_rng, width, height):
                print(line)
            print('end')
            continue
        if args.layers:
            for line in layer_scene(clip_rng, width, height):
                print(line)
            print('end')
            continue
        if args.gradients:
            for line in gradient_scene(clip_rng, width, height):
                print(line)
            print('end')
            continue
        if args.clips:
            for line in clip_scene(clip_rng, width, height):
                print(line)
            print('end')
            continue
        draws = args.many or rng.choice([1, 1, 1, 2, 4])
        for _ in range(draws):
            transform = rng.choice(list(TRANSFORMS))
            print('matrix ' + ' '.join(map(f, TRANSFORMS[transform])))
            if args.clip_outs and clip_rng.random() < 0.6:
                for _ in range(clip_rng.choice([1, 1, 1, 2])):
                    print(random_clip_out(clip_rng, width, height))
            paint = random_paint(rng)
            if args.fills:
                fields = paint.split()
                fields[6] = '0'
                paint = ' '.join(fields)
            print(paint)
            if rng.random() < 0.3:
                print('color8 {} {} {} {}'.format(rng.randrange(256), rng.randrange(256),
                                                 rng.randrange(256), rng.choice([255, 127, 200])))
            print(random_shape(rng, width, height))
        print('end')


if __name__ == '__main__':
    main()
