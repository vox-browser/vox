#!/usr/bin/env python3
"""Generates deterministic glyph-run scenes for skia_text_oracle.mm and text_scene.v.

Each scene draws one positioned run with the bridge's font smoothing flags,
a random color over a random background, and a random device matrix.
"""
import argparse
import random

FONTS = [
    '/System/Library/Fonts/Supplemental/Arial.ttf',
    '/System/Library/Fonts/Supplemental/Georgia.ttf',
    '/System/Library/Fonts/Supplemental/Verdana.ttf',
    '/System/Library/Fonts/Supplemental/Tahoma.ttf',
    '/System/Library/Fonts/Geneva.ttf',
    '/System/Library/Fonts/SFNS.ttf',
]


def existing_fonts():
    import os
    return [f for f in FONTS if os.path.exists(f)]


def color(rng):
    kind = rng.random()
    if kind < 0.25:
        return (0, 0, 0, 255)
    if kind < 0.35:
        return (255, 255, 255, 255)
    alpha = 255 if rng.random() < 0.7 else rng.randrange(1, 255)
    return (rng.randrange(256), rng.randrange(256), rng.randrange(256), alpha)


def background(rng):
    kind = rng.random()
    if kind < 0.3:
        return 'transparent'
    a = 255 if kind < 0.85 else rng.randrange(256)
    # Premultiplied BGRA.
    b, g, r = (rng.randrange(a + 1) for _ in range(3))
    return f'{b} {g} {r} {a}'


def matrix(rng):
    kind = rng.random()
    tx, ty = round(rng.uniform(-3, 3), 3), round(rng.uniform(-3, 3), 3)
    if kind < 0.4:
        return (1, 0, 0, 1, 0, 0)
    if kind < 0.6:
        return (1, 0, 0, 1, tx, ty)
    if kind < 0.75:
        s = rng.choice([2, 1.5, 0.75, 1.25])
        return (s, 0, 0, s, tx, ty)
    if kind < 0.85:
        return (rng.choice([2, 1.5, 0.8]), 0, 0, rng.choice([1, 2, 1.2]), tx, ty)
    if kind < 0.93:
        # A small rotation.
        import math
        a = rng.uniform(-0.3, 0.3)
        return (round(math.cos(a), 6), round(math.sin(a), 6), round(-math.sin(a), 6),
                round(math.cos(a), 6), tx + 10, ty)
    return (1, 0, round(rng.uniform(-0.3, 0.3), 3), 1, tx + 8, ty)


def scene(rng, index, fonts, smoothing):
    width, height = 160, 64
    size = round(rng.choice([rng.uniform(6, 20), rng.uniform(6, 40), rng.uniform(20, 90)]), 2)
    m = matrix(rng)
    sm = smoothing if smoothing is not None else rng.choice([16, 16, 16, 18, 0, 2])
    lines = [f'text t{index:05d} {width} {height}', f'background {background(rng)}',
             f'font {rng.choice(fonts)} {size} 400 {sm}',
             'matrix ' + ' '.join(str(v) for v in m),
             'color ' + ' '.join(str(v) for v in color(rng)),
             f'origin {round(rng.uniform(0, 12), 3)} {round(rng.uniform(size * 0.6, height - 4), 3)}']
    x = 0.0
    for _ in range(rng.randrange(1, 10)):
        glyph = rng.randrange(1, 220)
        lines.append(f'glyph {glyph} {round(x, 4)} {round(rng.choice([0, 0, 0, rng.uniform(-2, 2)]), 4)}')
        x += size * rng.uniform(0.3, 0.8)
    lines.append('end')
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--seed', type=int, default=1)
    parser.add_argument('--count', type=int, default=200)
    parser.add_argument('--smoothing', type=int)
    args = parser.parse_args()
    rng = random.Random(args.seed)
    fonts = existing_fonts()
    for i in range(args.count):
        print(scene(rng, i, fonts, args.smoothing))


if __name__ == '__main__':
    main()
