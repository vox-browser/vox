#!/usr/bin/env python3
"""Capture source-image filters, including deferred sampling and image edges."""
import ctypes as C
import hashlib
import importlib.util
import json
import platform
import sys
import struct
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    'reference', Path(__file__).with_name('native_fixture_hashes.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
r = m.Reference(Path(sys.argv[1]))
contrast = (2, 0, 0, 0, 0, [1.3, 0, 0, 0, -.15, 0, 1.3, 0, 0, -.15,
                          0, 0, 1.3, 0, -.15, 0, 0, 0, 1, 0], 0)
opacity = (2, 0, 0, 0, 0, [1, 0, 0, 0, 0, 0, 1, 0, 0, 0,
                          0, 0, 1, 0, 0, 0, 0, 0, .65, 0], 1)
def blur(sigma):
    return (0, 0, sigma, 0, 0, [0]*20, 0)
def shadow(sigma, dx=5.25, dy=-3.75, color=0x805030e0):
    return (1, color, sigma, dx, dy, [0]*20, 0)
triangle = m.segment(0, 2, 3) + m.segment(1, 45.5, 10.25) + m.segment(1, 20.5, 38) + m.segment(5)
cases = [
    dict(name='aligned-image-blur', filters=[blur(2.5)]),
    dict(name='aligned-subset-blur', source=[1, 1, 5, 4], destination=[4, 6, 5, 4],
         filters=[blur(.8)], transform=[1, 0, 0, 1, 3, -2], mode='src_in', clip=True),
    dict(name='aligned-image-shadow', filters=[shadow(2.5)], mode='multiply', clip=True),
    dict(name='unknown-image-boundary', iw=10, ih=1, width=86, height=65,
         pixels=[34, 60, 16, 61, 7, 85, 139, 213, 113, 115, 31, 118, 7, 2, 11, 34,
                 158, 206, 247, 247, 5, 79, 27, 87, 158, 135, 41, 159, 30, 6, 46, 46,
                 24, 6, 48, 64, 200, 141, 230, 254],
         source=[4, 0, 6, 1], destination=[52, 2, 6, 1], transform=[1, 0, 0, 1, 9, -6],
         filters=[shadow(-1, 15.59166, 6, 4280761295)], empty=True),
    dict(name='identity-shadow-image-boundary', filters=[contrast, shadow(.01), opacity],
         mode='plus_lighter', clip=True),
    dict(name='image-color-blur-chain', filters=[contrast, blur(.8), opacity, blur(2.5), contrast],
         mode='overlay'),
    dict(name='image-identity-color-chain', filters=[contrast, blur(0), opacity, blur(.01), contrast],
         mode='src_in', clip=True),
    dict(name='image-box-color-chain', filters=[blur(2.5), opacity, blur(12), contrast],
         mode='plus_darker', clip=True),
    dict(name='p3-premul-blur', p3=True, filters=[blur(2.5)]),
    dict(name='p3-unpremul-blur', p3=True, premul=False, filters=[blur(.8)], mode='multiply', clip=True),
    dict(name='p3-color-between-blurs', p3=True, filters=[blur(.8), contrast, blur(2.5)], mode='src_in'),
    dict(name='p3-conversion-after-identity', p3=True, premul=False,
         filters=[blur(.01), blur(2.5), contrast], mode='plus_lighter', clip=True),
    dict(name='srgb-unpremul-blur', premul=False, filters=[blur(2.5)]),
    dict(name='srgb-unpremul-blur-color-identity', premul=False,
         filters=[blur(2.5), contrast, blur(0)], mode='src_in', clip=True),
    dict(name='p3-premul-prefiltered-shadow', p3=True, filters=[contrast, shadow(2.5)]),
    dict(name='p3-unpremul-identity-shadow', p3=True, premul=False,
         filters=[opacity, shadow(.01), contrast], mode='src_in', clip=True),
    dict(name='srgb-unpremul-prefiltered-shadow', premul=False,
         filters=[contrast, shadow(2.5)], mode='multiply', clip=True),
    dict(name='p3-identity-color-chain', p3=True,
         filters=[contrast, blur(0), opacity, blur(.01), contrast], mode='darken', clip=True),
]
for p3 in [True, False]:
    cases.append(dict(name='global-image-shadow-offset-' + ('p3' if p3 else 'srgb'),
        p3=p3, iw=19, ih=14, width=50, height=73, empty=True, pixel_pitch=84,
        pixels=list((Path(__file__).resolve().parents[2] / 'cpuraster/testdata/image-shadow-offset.rgba').read_bytes()),
        source=[1, 2, 15, 9], destination=[15, -3, 15, 9], transform=[1, 0, 0, 1, 9, -9],
        filters=[shadow(3.3989284, 19, 11.136544, 4287222027)]))
cases += [
    dict(name='fractional-source-blur', source=[.25, .5, 6.25, 5], destination=[10.25, 12.5, 28, 18],
         transform=[1.25, 0, 0, .75, 2, 4], filters=[blur(1.2)], mode='src_in', clip=True),
    dict(name='fractional-p3-color-chain', source=[1.25, 1.5, 4.5, 3.75], destination=[4.5, 6.25, 22, 16],
         p3=True, premul=False, filters=[contrast, blur(.8), opacity, blur(2.5)], mode='overlay'),
    dict(name='fractional-unpremul-shadow', source=[1.25, 1.5, 4.5, 3.75], destination=[4.5, 6.25, 22, 16],
         premul=False, filters=[shadow(2.5)], mode='multiply', clip=True),
    dict(name='fractional-identity-shadow', source=[.25, .5, 6.25, 5], destination=[10.25, 12.5, 28, 18],
         filters=[shadow(.01, -.75, .5)], mode='plus_lighter', clip=True),
    dict(name='fractional-flipped-source', source=[1.25, 1.5, 4.5, 3.75], destination=[4.5, 6.25, 22, 16],
         transform=[-1.1, 0, 0, .8, 42, 3], filters=[blur(.8), contrast, blur(2.5)], mode='src_in'),
    dict(name='fractional-source-color', source=[1.25, 1.5, 4.5, 3.75], destination=[4.5, 6.25, 22, 16],
         p3=True, premul=False, filters=[contrast, opacity], mode='src_in', clip=True),
    dict(name='alpha-premul-blur', alpha=.7, filters=[blur(2.5)]),
    dict(name='alpha-unpremul-blur', alpha=.35, premul=False, filters=[blur(.8)], mode='multiply', clip=True),
    dict(name='alpha-p3-prefiltered-shadow', alpha=.65, p3=True,
         filters=[contrast, shadow(2.5)], mode='src_in'),
    dict(name='alpha-unpremul-identity-shadow', alpha=.999, premul=False,
         filters=[opacity, shadow(.01), contrast], mode='plus_lighter', clip=True),
    dict(name='alpha-invalid-shadow-sourcegraphic', alpha=.43391985, premul=False,
         filters=[contrast, shadow(-1)], mode='screen'),
    dict(name='alpha-blur-color-chain', alpha=.5, p3=True, premul=False,
         filters=[contrast, blur(.8), opacity, blur(2.5), contrast]),
    dict(name='alpha-identity-color-chain', alpha=.65, p3=True,
         filters=[contrast, blur(0), opacity, blur(.01), contrast], mode='src_in', clip=True),
    dict(name='zero-alpha-clearing-blur', alpha=0, filters=[blur(.8)], mode='src_in', clip=True),
    dict(name='fractional-alpha-blur', alpha=.65, source=[.25, .5, 6.25, 5], destination=[10.25, 12.5, 28, 18],
         transform=[1.25, 0, 0, .75, 2, 4], p3=True, filters=[blur(1.2)], mode='src_in', clip=True),
    dict(name='fractional-alpha-color', alpha=.7, source=[1.25, 1.5, 4.5, 3.75], destination=[4.5, 6.25, 22, 16],
         p3=True, premul=False, filters=[contrast, opacity], mode='src_in', clip=True),
]
cases += [
    dict(name='scaled-integer-source-blur', source=[0, 0, 7, 6], destination=[4, 5, 30, 25],
         filters=[blur(2.5)]),
    dict(name='scaled-subset-nearest-blur', source=[1, 1, 5, 4], destination=[4.25, 6.5, 25, 18],
         smoothing=False, filters=[blur(.8)], mode='src_in', clip=True),
    dict(name='scaled-p3-unpremul-prefilter', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         p3=True, premul=False, alpha=.65, filters=[contrast, blur(.8), opacity, blur(2.5)], mode='overlay'),
    dict(name='scaled-unpremul-blur', source=[0, 0, 7, 6], destination=[10.25, 12.5, 28, 18],
         premul=False, filters=[blur(1.2)], mode='multiply', clip=True),
    dict(name='flipped-integer-source-blur', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         transform=[-1.1, 0, 0, .8, 42, 3], filters=[blur(.8), contrast, blur(2.5)], mode='src_in'),
    dict(name='downscaled-integer-source-mipmap', source=[0, 0, 7, 6], destination=[10.25, 12.5, 2, 3],
         alpha=.7, p3=True, filters=[blur(1.2)], mode='plus_lighter', clip=True),
    dict(name='translated-integer-source-blur', source=[0, 0, 7, 6], destination=[10, 12, 7, 6],
         transform=[1, 0, 0, 1, .25, .75], filters=[blur(2.5)]),
    dict(name='identity-before-scaled-source-blur', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         p3=True, premul=False, alpha=.7, filters=[contrast, blur(0), opacity, blur(.01), blur(2.5)],
         mode='src_in', clip=True),
]
cases += [
    dict(name='clipped-aligned-image-blur', source=[1, 1, 7, 6], destination=[4, 6, 7, 6],
         p3=True, premul=False, filters=[blur(.8)], mode='multiply', clip=True),
    dict(name='clipped-resampled-image-blur', source=[-2, -1, 10, 8], destination=[4.25, 6.5, 25, 18],
         filters=[blur(.8)], mode='src_in', clip=True),
    dict(name='clipped-fractional-source-shadow', source=[-.25, .5, 6.75, 6], destination=[4.5, 6.25, 22, 16],
         p3=True, premul=False, alpha=.65, filters=[contrast, shadow(2.5), opacity], mode='overlay'),
    dict(name='clipped-aligned-source-shadow', source=[1, 1, 7, 6], destination=[4, 6, 7, 6],
         p3=True, alpha=.7, filters=[contrast, shadow(2.5)], mode='src_in'),
    dict(name='empty-source-image-clearing-blur', source=[9, 0, 7, 6],
         filters=[blur(.8)], mode='src_in', clip=True),
    dict(name='empty-source-image-shadow', source=[9, 0, 7, 6],
         filters=[shadow(.01)], mode='multiply', clip=True),
    dict(name='clipped-source-retains-original-quick-bounds', source=[0, 0, 100, 6],
         destination=[-30, 5, 50, 18], filters=[blur(.8)], mode='src_in', clip=True),
    dict(name='clipped-source-color-blur-chain', source=[-2, -1, 10, 8], destination=[4.25, 6.5, 25, 18],
         p3=True, premul=False, alpha=.7, filters=[contrast, blur(0), opacity, blur(.8), blur(2.5)],
         mode='src_in', clip=True),
]
cases.append(dict(name='near-integer-shadow-nearest-sampling', iw=2, ih=1, width=24, height=16,
    pixels=[0, 0, 0, 255, 0, 0, 0, 1], pixel_pitch=8, p3=True, empty=True,
    source=[0, 0, 2, 1], destination=[4, 6, 2, 1], alpha=127/255,
    filters=[shadow(0, 10.00099, 4, 0xff000000)]))
cases += [
    dict(name='scaled-source-identity-color-chain', source=[0, 0, 7, 6], destination=[4.5, 6.25, 22, 16],
         filters=[contrast, blur(0), opacity], mode='overlay'),
    dict(name='scaled-p3-identity-color-chain', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         p3=True, premul=False, alpha=.65, filters=[contrast, blur(.001), opacity, blur(0), contrast],
         mode='src_in', clip=True),
    dict(name='downscaled-source-identity-mipmap', source=[1, 1, 5, 4], destination=[10.25, 12.5, 2, 3],
         p3=True, alpha=.7, filters=[blur(0), opacity, blur(.001), contrast], mode='plus_lighter', clip=True),
    dict(name='flipped-source-identity-color', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         transform=[-1.1, 0, 0, .8, 42, 3], filters=[contrast, blur(.001)], mode='multiply', clip=True),
    dict(name='identity-filter-retains-fast-bounds', destination=[-8.002, 5, 7, 6],
         filters=[contrast, blur(.001)], mode='src_in'),
    dict(name='clipped-source-identity-color-chain', source=[-2, -1, 10, 8], destination=[4.25, 6.5, 25, 18],
         p3=True, premul=False, alpha=.7, filters=[contrast, blur(0), opacity, blur(.001)],
         mode='src_in', clip=True),
]
cases += [
    dict(name='scaled-source-identity-blur', source=[0, 0, 7, 6], destination=[4.5, 6.25, 22, 16],
         filters=[blur(0)]),
    dict(name='downscaled-source-identity-legacy-rejected', source=[1, 1, 5, 4], destination=[10.25, 12.5, 2, 3],
         filters=[blur(.001)]),
    dict(name='downscaled-p3-identity-alpha', source=[1, 1, 5, 4], destination=[10.25, 12.5, 2, 3],
         p3=True, alpha=.7, filters=[blur(0), blur(.001)], mode='plus_lighter', clip=True),
    dict(name='unpremul-source-identity-blur', source=[0, 0, 7, 6], destination=[4.5, 6.25, 22, 16],
         premul=False, alpha=.65, filters=[blur(.001)], mode='src_in', clip=True),
    dict(name='flipped-source-identity-blur', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         transform=[-1.1, 0, 0, .8, 42, 3], filters=[blur(.001)], mode='plus_darker'),
    dict(name='translated-source-identity-blur', source=[0, 0, 7, 6], destination=[10, 12, 7, 6],
         transform=[1, 0, 0, 1, .3, .7], filters=[blur(0)]),
]
cases += [
    dict(name='near-integer-raw-premul-blur', destination=[10.0004, 12.0006, 7.0007, 5.9994],
         filters=[blur(1.2)]),
    dict(name='near-integer-raw-unpremul-blur', destination=[10.0004, 12.0006, 7.0007, 5.9994],
         premul=False, filters=[blur(1.2)], mode='src_in', clip=True),
    dict(name='near-integer-p3-resolved-blur', destination=[10.0004, 12.0006, 7.0007, 5.9994],
         p3=True, premul=False, alpha=.65, filters=[blur(1.2)], mode='multiply'),
    dict(name='near-integer-prefiltered-blur', destination=[10.0004, 12.0006, 7.0007, 5.9994],
         alpha=.7, filters=[contrast, blur(.001), opacity, blur(1.2)], mode='src_in', clip=True),
    dict(name='near-transform-replaces-nearest-identity', source=[2, 2, 4, 3],
         destination=[6.0018, 8.0018, 4.0036, 3.0027], smoothing=False,
         p3=True, premul=False, filters=[blur(.001)]),
    dict(name='near-transform-replaces-nearest-blur', source=[2, 2, 4, 3],
         destination=[6.0018, 8.0018, 4.0036, 3.0027], smoothing=False,
         p3=True, alpha=.7, filters=[blur(1.2)], mode='plus_lighter', clip=True),
    dict(name='near-transform-resolves-unpremul-blur', source=[2, 2, 4, 3],
         destination=[6.0018, 8.0018, 4.0036, 3.0027], smoothing=False,
         premul=False, filters=[blur(1.2)]),
    dict(name='near-transform-replaces-nearest-color', source=[2, 2, 4, 3],
         destination=[6.0018, 8.0018, 4.0036, 3.0027], smoothing=False,
         p3=True, premul=False, filters=[opacity], mode='src', clip=True),
    dict(name='near-final-retains-linear-mipmap', source=[2, 2, 4, 3],
         destination=[6, 8, 4.0024, 3.0018], p3=True, filters=[blur(.001)]),
    dict(name='near-final-retains-requested-nearest', source=[2, 2, 4, 3],
         destination=[6, 8, 4.0024, 3.0018], smoothing=False, premul=False, alpha=.65,
         filters=[blur(.001)], mode='src_in', clip=True),
]
cases.append(dict(name='near-linear-clearing-sprite', iw=4, ih=1,
    pixels=[0, 0, 0, 255, 0, 0, 0, 255, 255, 0, 0, 255, 0, 0, 0, 255], pixel_pitch=16,
    source=[2, 0, 2, 1], destination=[6, 6, 2.0018, 1], mode='src_in', clip_rect=[7, 6, 1, 1],
    filters=[blur(.001), (2, 0, 0, 0, 0, [8, 0, 0, 0, 0, 0, 1, 0, 0, 0,
        0, 0, 1, 0, 0, 0, 0, 0, 1, 0], 1)]))
cases += [
    dict(name='factored-near-integer-raw-unpremul', premul=False,
         transform=[1.25, 0, 0, .75, 3.25, 2.75], destination=[5.40032, 12.3341333333333, 5.60056, 7.9992],
         filters=[blur(1.2)], mode='src_in', clip=True),
    dict(name='factored-near-integer-p3-color', premul=False, p3=True, alpha=.65,
         transform=[1.25, 0, 0, .75, 3.25, 2.75], destination=[5.40032, 12.3341333333333, 5.60056, 7.9992],
         filters=[contrast, blur(.001), opacity, blur(1.2)], mode='multiply'),
]
cases += [
    dict(name='scaled-source-shadow', destination=[4, 5, 30, 25], filters=[shadow(2.5)]),
    dict(name='scaled-subset-nearest-shadow', source=[1, 1, 5, 4], destination=[4.25, 6.5, 25, 18],
         smoothing=False, filters=[shadow(.8)], mode='src_in', clip=True),
    dict(name='scaled-p3-unpremul-prefiltered-shadow', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         p3=True, premul=False, alpha=.65, filters=[contrast, shadow(.8), opacity], mode='overlay'),
    dict(name='scaled-unpremul-shadow', destination=[10.25, 12.5, 28, 18],
         premul=False, filters=[shadow(1.2)], mode='multiply', clip=True),
    dict(name='flipped-subset-shadow', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         transform=[-1.1, 0, 0, .8, 42, 3], filters=[contrast, shadow(2.5)], mode='src_in'),
    dict(name='downscaled-p3-shadow', destination=[10.25, 12.5, 2, 3], alpha=.7, p3=True,
         filters=[shadow(1.2)], mode='plus_lighter', clip=True),
    dict(name='fractional-translation-integer-source-shadow', transform=[1, 0, 0, 1, .25, .75],
         filters=[shadow(2.5)]),
    dict(name='scaled-prefiltered-translucent-shadow', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         premul=False, alpha=.7, filters=[contrast, shadow(2.5), opacity], mode='src_in', clip=True),
]
cases += [
    dict(name='near-integer-raw-shadow', destination=[10.0004, 12.0006, 7.0007, 5.9994],
         filters=[shadow(1.2)]),
    dict(name='near-integer-unpremul-shadow', destination=[10.0004, 12.0006, 7.0007, 5.9994],
         premul=False, filters=[shadow(1.2)], mode='src_in', clip=True),
    dict(name='near-integer-p3-prefiltered-shadow', destination=[10.0004, 12.0006, 7.0007, 5.9994],
         p3=True, premul=False, alpha=.65, filters=[contrast, shadow(1.2), opacity], mode='multiply'),
    dict(name='near-shadow-retains-mipmap-sampling', source=[2, 2, 4, 3], destination=[6, 8, 4.0024, 3.0018],
         p3=True, filters=[shadow(1.2)], mode='plus_lighter', clip=True),
    dict(name='near-shadow-retains-requested-nearest', source=[2, 2, 4, 3], destination=[6, 8, 4.0024, 3.0018],
         smoothing=False, premul=False, alpha=.65, filters=[shadow(1.2)], mode='src_in', clip=True),
    dict(name='factored-near-integer-raw-shadow', premul=False,
         transform=[1.25, 0, 0, .75, 3.25, 2.75], destination=[5.40032, 12.3341333333333, 5.60056, 7.9992],
         filters=[shadow(1.2)], mode='src_in', clip=True),
    dict(name='factored-near-integer-color-shadow', premul=False, p3=True, alpha=.65,
         transform=[1.25, 0, 0, .75, 3.25, 2.75], destination=[5.40032, 12.3341333333333, 5.60056, 7.9992],
         filters=[contrast, shadow(1.2), opacity], mode='multiply'),
]
cases += [
    dict(name='scaled-source-identity-shadow', destination=[4, 5, 30, 25], filters=[shadow(0)]),
    dict(name='subset-nearest-identity-shadow', source=[1, 1, 5, 4], destination=[4.25, 6.5, 25, 18],
         smoothing=False, filters=[shadow(.000001, 5, -4)], mode='src_in', clip=True),
    dict(name='p3-prefiltered-identity-shadow', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         p3=True, premul=False, alpha=.65, filters=[contrast, shadow(.000001), opacity], mode='overlay'),
    dict(name='invalid-shadow-skips-prefilter-only-on-shadow', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         p3=True, premul=False, alpha=.65, filters=[contrast, shadow(-1), opacity], mode='src_in', clip=True),
    dict(name='downscaled-p3-invalid-shadow', destination=[10.25, 12.5, 2, 3], alpha=.7, p3=True,
         filters=[shadow(-1)], mode='plus_lighter', clip=True),
    dict(name='unpremul-nearest-invalid-shadow', destination=[10.25, 12.5, 28, 18], premul=False,
         smoothing=False, filters=[shadow(-1, 5, -4)], mode='multiply', clip=True),
    dict(name='near-raw-identity-shadow', destination=[10.0004, 12.0006, 7.0007, 5.9994],
         filters=[shadow(.000001)]),
    dict(name='factored-nearest-integer-offset-shadow', source=[2, 2, 4, 3], destination=[4.5, 6.25, 22, 16],
         transform=[1.25, 0, 0, .75, 3.25, 2.75], smoothing=False,
         filters=[shadow(0, 4, 4)], mode='src_in'),
]
cases.append(dict(name='offscreen-identity-shadow-preserves-merge-origin', iw=15, ih=24, width=84, height=24,
    pixels=list((Path(__file__).resolve().parents[2] / 'cpuraster/testdata/identity-shadow-origin-source.rgba').read_bytes()),
    initial=list((Path(__file__).resolve().parents[2] / 'cpuraster/testdata/identity-shadow-origin-background.rgba').read_bytes()),
    pitch=344, alpha_type=1, pixel_pitch=64, p3=True,
    transform=[1.5043701, 0, 0, -2.1267667, 3.25, 19.2],
    destination=[2.4294972, 4.8504453, 24.454557, 2.9388463], source=[1, 13, 5, 2],
    filters=[(2, 0, 0, 0, 0, [0, 0, 0, 0, .5, 0, 0, 0, 0, .5, 0, 0, 0, 0, .5, 0, 0, 0, 1, 0], 0),
        shadow(-1, 6, 15, 2399918666),
        (2, 0, 0, 0, 0, [.58240926, 0, 0, 0, .20879537, 0, .58240926, 0, 0, .20879537,
            0, 0, .58240926, 0, .20879537, 0, 0, 0, 1, 0], 0)]))
cases += [
    dict(name='resolved-nearest-scaled-shadow', destination=[4, 5, 30, 25],
         smoothing=False, filters=[shadow(0)]),
    dict(name='resolved-nearest-subset-shadow', source=[1, 1, 5, 4], destination=[4.25, 6.5, 25, 18],
         smoothing=False, filters=[shadow(.000001)], mode='src_in', clip=True),
    dict(name='resolved-nearest-p3-prefiltered-shadow', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         smoothing=False, p3=True, premul=False, alpha=.65,
         filters=[contrast, shadow(.000001), opacity], mode='overlay'),
    dict(name='resolved-nearest-invalid-shadow', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         smoothing=False, p3=True, premul=False, alpha=.65,
         filters=[contrast, shadow(-1), opacity], mode='src_in', clip=True),
    dict(name='resolved-nearest-downscaled-shadow', destination=[10.25, 12.5, 2, 3],
         smoothing=False, p3=True, alpha=.7, filters=[shadow(-1)], mode='plus_lighter', clip=True),
    dict(name='resolved-nearest-unpremul-shadow', destination=[10.25, 12.5, 28, 18],
         smoothing=False, premul=False, alpha=.999, filters=[shadow(.000001)], mode='multiply', clip=True),
    dict(name='resolved-nearest-flipped-shadow', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         transform=[-1.1, 0, 0, .8, 42, 3], smoothing=False,
         filters=[contrast, shadow(0, 3.5, -2.25)], mode='src_in'),
    dict(name='resolved-nearest-factored-shadow', source=[2, 2, 4, 3], destination=[4.5, 6.25, 22, 16],
         transform=[1.25, 0, 0, .75, 3.25, 2.75], smoothing=False, p3=True, alpha=.7,
         filters=[shadow(0, .25, -.75)], mode='src_in'),
    dict(name='resolved-nearest-shadow-without-foreground', destination=[-30, 6, 24, 18],
         smoothing=False, filters=[contrast, shadow(0, 34.5, -2.25), opacity], mode='src_in', clip=True),
    dict(name='empty-nearest-shadow-resolution', destination=[4.5, 6.25, 22, 16],
         smoothing=False, filters=[contrast, shadow(0, 150.25, -100), opacity], mode='src_in', clip=True),
]
cases.append(dict(name='thin-resolved-shadow', iw=24, ih=2, width=87, height=8,
    pixels=list((Path(__file__).resolve().parents[2] / 'cpuraster/testdata/resolved-shadow-thin-source.rgba').read_bytes()),
    initial=list((Path(__file__).resolve().parents[2] / 'cpuraster/testdata/resolved-shadow-thin-background.rgba').read_bytes()),
    pixel_pitch=100, pitch=352, alpha_type=1, p3=True, smoothing=False, mode='src_atop',
    transform=[1.9846058, 0, 0, -.2999618, 3.25, 6.4],
    destination=[18.515005, -1.4122566, 85.50765, 2.448695], source=[5, 0, 16, 2],
    filters=[(2, 0, 0, 0, 0, [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0], 1),
        shadow(-1, -16, 10, 0xffffffff),
        (2, 0, 0, 0, 0, [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0], 1),
        (2, 0, 0, 0, 0, [-.0664451, .47126946, .10513631, -.90223706, .2727217,
            -.21826614, -.57720643, .41614532, .73150754, -.86200744,
            -.14551322, -.39294574, -.6733888, .11890532, -.2589099, 0, 0, 0, .16235755, 0], 0)]))
cases.append(dict(cases[-1], name='thin-resolved-shadow-without-postfilters',
                  filters=cases[-1]['filters'][:2], mode='src'))
# Mixed source-image graphs: retained raw pixels or a fractional-source AA surface.
cases += [
    dict(name='source-chain-blur-shadow', filters=[blur(.8), shadow(2.5)]),
    dict(name='source-chain-shadow-blur-p3', source=[1, 1, 5, 4], destination=[4, 6, 5, 4],
         transform=[1, 0, 0, 1, 3, -2], p3=True, premul=False, alpha=.65,
         filters=[shadow(2.5), blur(.8)], mode='src_in', clip=True),
    dict(name='source-chain-two-shadows', premul=False, alpha=.7,
         filters=[shadow(2.5), shadow(.8, -7.25, 4.5)], mode='overlay'),
    dict(name='source-chain-identity-colors', p3=True,
         filters=[contrast, shadow(0), opacity, blur(.01), shadow(.8)]),
    dict(name='source-chain-colors-alpha', alpha=.65, alpha_type=1, clip=True,
         filters=[contrast, shadow(2.5), blur(.8), opacity], mode='src_out'),
    dict(name='source-chain-two-identity-shadows', premul=False,
         filters=[opacity, shadow(0), contrast, shadow(.01)], mode='multiply', clip=True),
    dict(name='fractional-chain-blur-shadow', source=[.25, .5, 6.25, 5], destination=[10.25, 12.5, 28, 18],
         transform=[1.25, 0, 0, .75, 2, 4], filters=[blur(.8), shadow(2.5)], mode='src_in', clip=True),
    dict(name='fractional-chain-shadow-blur-p3', source=[1.25, 1.5, 4.5, 3.75], destination=[4.5, 6.25, 22, 16],
         p3=True, premul=False, filters=[shadow(2.5), blur(.8)], mode='overlay'),
    dict(name='fractional-chain-two-shadows', source=[1.25, 1.5, 4.5, 3.75], destination=[4.5, 6.25, 22, 16],
         premul=False, alpha=.65, filters=[shadow(2.5), shadow(.8, -7.25, 4.5)], mode='multiply', clip=True),
    dict(name='fractional-chain-flipped', source=[1.25, 1.5, 4.5, 3.75], destination=[4.5, 6.25, 22, 16],
         transform=[-1.1, 0, 0, .8, 42, 3], filters=[shadow(2.5), contrast, blur(.8), shadow(.8)], mode='src_out'),
    dict(name='fractional-chain-identity-colors', source=[.25, .5, 6.25, 5], destination=[10.25, 12.5, 28, 18],
         transform=[1.25, 0, 0, .75, 2, 4], p3=True, premul=False, alpha=.7,
         filters=[contrast, shadow(0), opacity, blur(.01), shadow(.8)], mode='plus_lighter', clip=True),
    dict(name='clipped-source-chain', source=[-2, -1, 7, 6], destination=[4, 6, 7, 6],
         filters=[shadow(2.5), blur(.8)], mode='src_in', clip=True),
    dict(name='empty-source-chain', source=[10, 10, 7, 6], destination=[4, 6, 7, 6],
         filters=[shadow(2.5), blur(.8)], mode='src_in', clip=True),
    dict(name='zero-alpha-source-chain', alpha=0, filters=[shadow(2.5), blur(.8)], mode='src_in', clip=True),
]

# A real blur resolves scaled source sampling before later shadow branches.
cases += [
    dict(name='resampled-chain-blur-shadow', destination=[4, 5, 30, 25],
         filters=[blur(.8), shadow(2.5)]),
    dict(name='resampled-chain-nearest-p3', source=[1, 1, 5, 4], destination=[4.25, 6.5, 25, 18],
         p3=True, premul=False, alpha=.65, smoothing=False,
         filters=[contrast, blur(.8), shadow(2.5), opacity], mode='src_in', clip=True),
    dict(name='resampled-chain-flipped', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         transform=[-1.1, 0, 0, .8, 42, 3], alpha=.7,
         filters=[blur(2.5), contrast, shadow(.8)], mode='src_out'),
    dict(name='resampled-chain-nearly-integer', destination=[10.0004, 12.0006, 7.0007, 5.9994],
         filters=[blur(.8), shadow(1.2)]),
    dict(name='resampled-chain-identity-prefix-minified', destination=[10.25, 12.5, 2, 3],
         transform=[1.25, 0, 0, .75, 3.25, 2.75], p3=True, premul=False, alpha=.7,
         filters=[contrast, blur(.01), blur(.8), opacity, shadow(2.5)], mode='multiply', clip=True),
    dict(name='resampled-chain-two-shadows', destination=[4.5, 6.25, 22, 16],
         premul=False, alpha=.7, filters=[blur(.8), shadow(2.5), shadow(.8, -7.25, 4.5)], mode='src_atop'),
    dict(name='resampled-chain-copy', source=[1, 1, 5, 4], destination=[4.25, 6.5, 25, 18],
         filters=[blur(2.5), contrast, shadow(.8)], mode='src', clip=True),
    dict(name='resampled-chain-clipped-source', source=[-2, -1, 7, 6], destination=[4.25, 6.5, 25, 18],
         transform=[1.25, 0, 0, .75, 3.25, 2.75],
         filters=[blur(.8), shadow(2.5)], mode='src_in', clip=True),
]

fixture_root = Path(__file__).resolve().parents[2] / 'cpuraster/testdata'
for tag in ['prod', 'default']:
    name = 'resampled-request-' + tag
    f = json.loads((fixture_root / (name + '.json')).read_text())
    cases.append(dict(name=name, width=f['width'], height=f['height'], pitch=f['pitch'],
        alpha_type=f['alpha_type'], iw=f['image_width'], ih=f['image_height'],
        pixel_pitch=f['image_pitch'], premul=f['image_premultiplied'], p3=f['image_display_p3'],
        pixels=list((fixture_root / (name + '-source.rgba')).read_bytes()),
        initial=list((fixture_root / (name + '-background.rgba')).read_bytes()),
        transform=f['transform'], source=f['source'], destination=f['destination'],
        alpha=f['global_alpha'], mode=list(m.MODES)[f['composite']], clips=f['clips'],
        filters=[(x['kind'], x['color'], x['sigma'], x['offset_x'], x['offset_y'], x['matrix'], int(x['clamp']))
                 for x in f['filters']]))

# A first real shadow retains the scaled source foreground through merge.
cases += [
    dict(name='shadow-first-chain', destination=[4, 5, 30, 25],
         filters=[shadow(2.5), blur(.8)]),
    dict(name='shadow-first-nearest-p3', source=[1, 1, 5, 4], destination=[4.25, 6.5, 25, 18],
         p3=True, premul=False, alpha=.65, smoothing=False,
         filters=[contrast, shadow(2.5), opacity, shadow(.8)], mode='src_in', clip=True),
    dict(name='shadow-first-flipped', source=[1, 1, 5, 4], destination=[4.5, 6.25, 22, 16],
         transform=[-1.1, 0, 0, .8, 42, 3], alpha=.7,
         filters=[shadow(2.5), contrast, blur(2.5)], mode='src_out'),
    dict(name='shadow-first-nearly-integer', destination=[10.0004, 12.0006, 7.0007, 5.9994],
         filters=[shadow(1.2), blur(.8)]),
    dict(name='shadow-first-identity-prefix-minified', destination=[10.25, 12.5, 2, 3],
         transform=[1.25, 0, 0, .75, 3.25, 2.75], p3=True, premul=False, alpha=.7,
         filters=[contrast, blur(.01), shadow(.8), opacity, blur(.8)], mode='multiply', clip=True),
    dict(name='shadow-first-two-shadows', destination=[4.5, 6.25, 22, 16],
         premul=False, alpha=.7, filters=[shadow(2.5), shadow(.8, -7.25, 4.5)], mode='src_atop'),
    dict(name='shadow-first-copy', source=[1, 1, 5, 4], destination=[4.25, 6.5, 25, 18],
         filters=[shadow(2.5), contrast, blur(.8)], mode='src', clip=True),
    dict(name='shadow-first-clipped-source', source=[-2, -1, 7, 6], destination=[4.25, 6.5, 25, 18],
         transform=[1.25, 0, 0, .75, 3.25, 2.75],
         filters=[shadow(2.5), blur(.8)], mode='src_in', clip=True),
]

# Identity shadows merge two deferred source views before later spatial nodes.
for source_case in cases[-8:]:
    case = dict(source_case, name=source_case['name'].replace('shadow-first', 'identity-first'))
    filters = list(case['filters'])
    for i, step in enumerate(filters):
        if step[0] == 1:
            filters[i] = (step[0], step[1], .01, *step[3:])
            break
    case['filters'] = filters
    cases.append(case)

# Rejected blur nodes reset only the tinted branch to SourceGraphic.
for source_case in cases[-8:]:
    case = dict(source_case, name=source_case['name'].replace('identity-first', 'rejected-first'))
    filters = list(case['filters'])
    for i, step in enumerate(filters):
        if step[0] == 1:
            filters[i] = (step[0], step[1], -1, *step[3:])
            break
    case['filters'] = filters
    cases.append(case)
cases += [
    dict(name='rejected-after-blur', destination=[4, 5, 30, 25], p3=True, premul=False,
         alpha=.65, smoothing=False, filters=[contrast, blur(.8), opacity, shadow(-1), blur(2.5)],
         mode='src_in', clip=True),
    dict(name='rejected-after-shadow', destination=[4.5, 6.25, 22, 16], premul=False,
         alpha=.7, filters=[shadow(2.5), contrast, shadow(-1), opacity], mode='src_atop'),
]

cases.append(dict(name='rejected-alpha-prefilter', destination=[4, 5, 30, 25], p3=True,
    premul=False, alpha=.65, smoothing=False, filters=[opacity, shadow(-1), blur(.8)]))

# Exact float inputs found by searching for MakeFromImage layer crops.
def scalar_bits(bits):
    return struct.unpack('<f', struct.pack('<I', bits))[0]
def scalar(value):
    return struct.unpack('<f', struct.pack('<f', value))[0]
crop_geometries = [
    (3, 1, [1085067283, 1082968454, 1086745844, 1090940148], 1067450368),
    (2, 2, [1076837620, 1076337300, 1080834193, 1084229582], 1074161254),
    (3, 1, [1078835906, 1076337300, 1080834193, 1084229582], 1074161254),
]
for i, (left, width, dst_bits, scale_bits) in enumerate(crop_geometries):
    l, t, rr, bb = map(scalar_bits, dst_bits)
    dw, dh = scalar(rr-l), scalar(bb-t)
    assert scalar(l+dw) == rr and scalar(t+dh) == bb
    scale = scalar_bits(scale_bits)
    for variant, filters in enumerate([[opacity, shadow(.01)],
            [contrast, shadow(.01), opacity, blur(.8)], [opacity, shadow(-1), blur(.8)],
            [opacity, shadow(.8), blur(.8)]]):
        cases.append(dict(name=f'cropped-deferred-{i}-{variant}', source=[left, 1, width, 5],
            destination=[l, t, dw, dh], transform=[scale, 0, 0, scale, 2.25, 3.5],
            filters=filters, p3=variant != 1, premul=variant == 2, alpha=.65,
            mode='src_in' if variant == 1 else 'src_over', clip=variant == 1))

name = 'color-layer-crop'
f = json.loads((fixture_root / (name + '.json')).read_text())
cases.append(dict(name=name, width=f['width'], height=f['height'], pitch=f['pitch'],
    alpha_type=f['alpha_type'], iw=f['image_width'], ih=f['image_height'],
    pixel_pitch=f['image_pitch'], premul=f['image_premultiplied'], p3=f['image_display_p3'],
    pixels=list((fixture_root / (name + '-source.rgba')).read_bytes()),
    initial=list((fixture_root / (name + '-background.rgba')).read_bytes()),
    transform=f['transform'], source=f['source'], destination=f['destination'],
    alpha=f['global_alpha'], mode=list(m.MODES)[f['composite']], clips=f['clips'],
    filters=[(x['kind'], x['color'], x['sigma'], x['offset_x'], x['offset_y'], x['matrix'], int(x['clamp']))
             for x in f['filters']]))

for i, (left, width, dst_bits, scale_bits) in enumerate(crop_geometries):
    l, t, rr, bb = map(scalar_bits, dst_bits)
    scale = scalar_bits(scale_bits)
    gain4 = (2, 0, 0, 0, 0, [4,0,0,0,0, 0,4,0,0,0, 0,0,4,0,0, 0,0,0,1,0], 0)
    gain100 = (2, 0, 0, 0, 0, [100,0,0,0,0, 0,100,0,0,0, 0,0,100,0,0, 0,0,0,1,0], 0)
    for variant, filters in enumerate([[contrast, gain4], [opacity, gain100], [gain100], [opacity]]):
        cases.append(dict(name=f'cropped-color-{i}-{variant}', source=[left, 1, width, 5],
            destination=[l,t,scalar(rr-l),scalar(bb-t)], transform=[scale,0,0,scale,2.25,3.5],
            filters=filters, p3=variant in [1,2], premul=variant == 0, alpha=.65,
            mode=['src_over','src','src_in','plus_lighter'][variant], clip=variant in [1,2]))

for case in cases:
    w, h = case.get('width', 48), case.get('height', 40)
    iw, ih = case.get('iw', 7), case.get('ih', 6)
    premul = case.get('premul', True)
    image = bytearray(case['pixels']) if 'pixels' in case else m.image_pixels(iw, ih, premul)
    image_pitch = case.get('pixel_pitch', iw * 4) if 'pixels' in case else iw * 4 + 4
    storage = (C.c_uint8 * len(image)).from_buffer(image)
    r.library.oracle_pattern(storage)
    r.pattern_sha256 = hashlib.sha256(image).hexdigest()
    r.filters(case['filters'])
    clips = ([(c['segments'], c['even_odd']) for c in case['clips']] if 'clips' in case
             else [(triangle, False)] if case.get('clip') else [])
    if 'clip_rect' in case:
        x, y, cw, ch = case['clip_rect']
        clips = [(m.segment(0, x, y) + m.segment(1, x+cw, y) + m.segment(1, x+cw, y+ch)
                  + m.segment(1, x, y+ch) + m.segment(5), False)]
    ints = [w, h, case.get('pitch', w * 4), case.get('alpha_type', 2), 2, int(case.get('smoothing', True)), len(clips),
            *[v for p, even in clips for v in [len(p)//12, int(even)]],
            m.MODES[case.get('mode', 'src_over')], 0, iw, ih, image_pitch, 2 if premul else 1,
            int(case.get('p3', False))]
    floats = [*case.get('transform', m.IDENTITY), case.get('alpha', 1),
              *case.get('destination', [10, 12, 7, 6]), *case.get('source', [0, 0, 7, 6]),
              *[v for p, _ in clips for v in p]]
    initial = bytearray(case['initial']) if 'initial' in case else (bytearray(w*h*4) if case.get('empty') else m.background(w, h, 'image'))
    r.call('oracle_canvas_bitmap', initial, ints, floats, case['name'], 'captured')
expected = ['ed3ad78eb7f39e69', '175b0777ebb477e0', '008e86865ffcec77', 'c109c5a5d05dfb86',
            '6454322bbabaebc8', 'eb747c828384c545', '911409983b836492', '718eb0464fd3d842',
            'b6afd442846f1fe7', 'e9153669efc21a36', 'ec04ff3914c40623', 'fbe1dc130b1bbe80',
            'b584f633e3fc82cf', 'a902cd538e64aca3', 'c62cadba69cd7310', '7f699b125a13e896',
            'a1a9893f167e696e', '001b2763877bb22c', 'f2a7f0ed22c87bab', 'f2a7f0ed22c87bab']
expected += ['6285cc5ff30cb0e8', '1edd441e708f831d', 'd8e5098c0b88d10e',
             '5adddb55e2daa5f2', '87142d4b2b61a427', '7e93e71b503d462d']
if platform.system() == 'Linux':
    expected[20], expected[23], expected[24] = '068ae7ede00bb8bd', '007ae7e038db824f', '67db8f58ce335193'
expected += ['d97a0d9cd1df7e4d', '5e4ace20b1be0022', '0adcdf1ab86d62a6', '75e9b0d52e0b770b',
             'a13ffe5203eeb91e', '1c07622980ca4093', '502f0b408e262557', '62b1b888837ad40a',
             '7947909c7171a8d1', 'e31ad4c4058362b9']
expected += ['52a21c2bac4d4259', 'e9b398034919dbd9', 'a3b2ddfab2f04556', '8dbc9961e18faaa5',
             'a8230d732d6e0330', '0e53661aa81425c3', '7bb5c150a395bcf9', 'e126bfc9481ba799']
expected += ['c6e6def672ae03e9', '1856d090e74e592c', 'da2274221967646b', '5fa502d06913b702',
             '62b1b888837ad40a', 'f00be8e39ec6bc7f', '62b1b888837ad40a', '98407a88886b2f75']
expected += ['d8f9957149e13dae']
expected += ['66ea4382a30ae423', 'faf646ac30327c3f', 'e10325f572b4dc14',
             'e12c13dca8162f9f', 'f6e28ad1753237d4', 'c1ada75f25f9bac0']
expected += ['fac95cda665447d0', '3dc171f15c4a6337', '4ec3f389f0ccf270',
             '41cedb613f3f59b3', 'f43245c7c409678f', '78e8496c23d32d03']
expected += ['fa94d509cac7a3aa', 'd0e26776186b8bea', 'acc7141f085d1362', 'edddaf35caff87f0',
             '3c3fb2d670bf7693', '60aef21c9403b4ef', '0c4068f3faaac712', '61ae453832882d02',
             'd5ea576df832e18b', '35dc909ee4d6fb74']
expected += ['a95ab159f7e63159']
expected += ['c143b26618f52631', 'f095ad3dcce7789e']
expected += ['2bb81f3c940efdd1', '1f1f586daef2c8bf', '5e5361d693406941', 'a314c86fea2dc72a', 'b0cf78ae45b5d34a', 'b0b37ca26e9ec933', 'ecb21cc6ee1cdc4e', '5fe5ede2432aa2cc']
if platform.system() == 'Linux':
    expected[79] = '9d9fa7c17fc9bf77'
expected += ['69bc99f80ec99582', '4e951a3d41351d05', 'a51dd6ce8df7e098', 'aa1915a0e5923229', 'a012597b325882fd', 'aff305b8a0ccc68b', 'abdab1d4f3a93229']
expected += ['68ec54837de261df', '7a773e55fa8b6342', '8e8005e8ba8b0db1', '641353e85eba5b86', '47d575499b0cd948', 'f0d9a6813b237621', '6744041f50e2ed13', '25ca27a80dca1e6c']
if platform.system() == 'Linux':
    expected[94], expected[100] = '94c9d6dfcf804982', '92ad67f96173f5f1'
expected += ['6918c091a7f3c206']
expected += ['58dcb346943e34ad', '9b7978b9155b68b7', 'a005d44326d848c9', '75f9f4859dba60e3', '2e3b1a72ba273cd9', '2e367dd716646a39', '4e105e2ca7a7eea7', '34955f83e4426d58', '30aa689b07f085a0', '58098840e4e0f6d9']
if platform.system() == 'Linux':
    expected[-10:] = ['74ef0767c101390a', 'b0b67dba3bb87d45', '741e193007ca6ec3', '9a8d7906fd102a19', 'e00d7577ca66d313', '1ad1f894abb926c3', '5581e3d64779e918', 'a752fab16a4109bb', '98ab8774ecaffba1', '58098840e4e0f6d9']
expected += ['09ffe213e3642515', 'b54173ae0d037c96']
if platform.system() == 'Linux':
    expected[-2:] = ['aff78d507ddefba6', 'a1efef67211fbbde']
expected += ['a6eff4e4d6d0b525', '9736c314d18243e4', '21edf031b5cad9bf', '4f87fbb4a116f74d',
 '0a4d5b84834e14f6', '3413bb7c9b0e9950', '9aae5da5398fe1e4', '7d91d1dd5fc4ea7d',
 'd1881a087ec36965', 'ff49a0bb8b31af28', 'a72cc96950afdcd1', 'f68b7870dc82135b',
 '62b1b888837ad40a', '62b1b888837ad40a']
if platform.system() == 'Linux':
    expected[-14:] = ['a6eff4e4d6d0b525', '9736c314d18243e4', '21edf031b5cad9bf', '4f87fbb4a116f74d',
 '0a4d5b84834e14f6', '3413bb7c9b0e9950', '206ed0f93c797611', '7d91d1dd5fc4ea7d',
 'd1881a087ec36965', 'c22b2b4fdcb9c1c8', 'a72cc96950afdcd1', 'f68b7870dc82135b',
 '62b1b888837ad40a', '62b1b888837ad40a']
expected += ['96377cc5e9c1be3b', '5a943a8884b2705e', 'd6368e170d652582', '7376c5a0cf4a2011',
 '75dc62f04fca90f3', '48ff3cff3719f678', 'e16b6f85b42e091e', '846b048d1a7a0879']
expected += ['647ddc0897133c6d', 'f893a84730298ea1']
if platform.system() == 'Linux':
    expected[-2:] = ['647ddc0897133c6d', '9e770877597b62d4']
expected += ['859b91c3c575de06', '27b607573de5a8ca', '5939c34188b25a0f', '09ea9f3247a7e8b5', '4db99a1307529684', '31f259ec5a598801', '8978f9869cd65823', 'cf7733c7326d8f00']
expected += ['184b651f07c58e73', '92bb21a535a76d83', 'bbb5e38c1ab0ca9e', '35b6e57a5ac3f38d', 'e22c651cda68cd6d', '9f479983c4eac599', '23776fec044d9aac', '3416e69e948b6d3a']
if platform.system() == 'Linux':
    expected[-8:] = ['184b651f07c58e73', '53fedce89798753f', 'bbb5e38c1ab0ca9e', '35b6e57a5ac3f38d', 'e22c651cda68cd6d', '9f479983c4eac599', '23776fec044d9aac', '3416e69e948b6d3a']
expected += ['184b651f07c58e73', '92bb21a535a76d83', 'bbb5e38c1ab0ca9e', '35b6e57a5ac3f38d', 'e22c651cda68cd6d', '9f479983c4eac599', '23776fec044d9aac', '3416e69e948b6d3a', '5706ca183399eb51', 'b5ef1fde955a65aa', 'a30a880b43cc2f9f']
if platform.system() == 'Linux':
    expected[-11:] = ['184b651f07c58e73', '53fedce89798753f', 'bbb5e38c1ab0ca9e', '35b6e57a5ac3f38d', 'e22c651cda68cd6d', '9f479983c4eac599', '23776fec044d9aac', '3416e69e948b6d3a', '94bb2e3e5122f73c', 'b5ef1fde955a65aa', '8a0bb9c29ff1424f']
expected += ['4df34ad3170908fa', '8e7893ef665e07b6', 'eacd8fde217cf3fe', '030f88d9d77c6cc2', '925ff7120103e699', '62bbcb7ecc229498', '8f76dc9ca3585f3c', '4e47f5b286c15049', '65c6352c1aadf86d', 'e227f114505d2ce6', 'e4f3f15a9d09e674', '4e345290a5870197']
if platform.system() == 'Linux':
    expected[-12:] = ['7fa25b3afcf70974', 'ff202711441f1425', 'e9a48b9a15b48098', '030f88d9d77c6cc2', '5d8c9b12bd871571', '13e21e9efa7637f4', '454694f8f486415c', '4e47f5b286c15049', '03803f2bfe8fd947', 'e227f114505d2ce6', '428717f06c4023fc', '4e345290a5870197']
expected += ['7590fe0bcd5b92d1', 'da060111c6b1cd22', '34530ccb87a66891', 'd67ee88224a19e9e', '0c10a9f5df1cdcf1', '7f9693b40ef11387', 'f44d1959a67025ac', '44c0f31be7db0067', '8bfc2f0cbc7e43c7', 'da060111c6b1cd22', '34530ccb87a66891', 'd67ee88224a19e9e', '0c10a9f5df1cdcf1']
assert len(r.records) == len(expected)
for record, digest in zip(r.records, expected):
    assert record['native_sha256'].startswith(digest), record['case']
assert hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest() == r.reference_sha256
print(json.dumps(dict(platform=platform.platform(), reference_sha256=r.reference_sha256,
                     tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                     records=r.records), indent=2))
