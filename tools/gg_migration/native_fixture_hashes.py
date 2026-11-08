#!/usr/bin/env python3
"""Capture native Skia hashes for the CPU raster unit fixtures.

The reference library is built by test_cpu_raster.sh. Inputs come from the
checked-in test literals; this tool does not execute the V renderer or derive
reference pixels from its implementation.
"""
import argparse
import ast
import ctypes as C
import hashlib
import json
from pathlib import Path
import platform
import re

IDENTITY = [1, 0, 0, 1, 0, 0]
MODES = dict(src_over=0, src_in=1, src_out=2, src_atop=3, dst_over=4, dst_in=5,
             dst_out=6, dst_atop=7, plus=8, src=9, xor=10, multiply=11, screen=12,
             overlay=13, darken=14, lighten=15, color_dodge=16, color_burn=17,
             hard_light=18, soft_light=19, difference=20, exclusion=21, hue=22,
             saturation=23, color=24, luminosity=25, plus_darker=26, plus_lighter=27)


def segment(kind, *values):
    assert len(values) <= 11
    return [kind, *values, *([0] * (11 - len(values)))]


def rectangle(l, t, r, b):
    return segment(0, l, t) + segment(1, r, t) + segment(1, r, b) + segment(1, l, b) + segment(5)


def circle(cx, cy, r):
    return (segment(0, cx+r, cy) + segment(4, cx-r, cy, 0, 0, 0, 0, r, r, 0, 0, 1)
            + segment(4, cx+r, cy, 0, 0, 0, 0, r, r, 0, 0, 1) + segment(5))


def background(width, height, kind='stroke'):
    out = bytearray()
    for y in range(height):
        for x in range(width):
            if kind == 'blur':
                a = 0 if (x+2*y) % 9 == 0 else (x*5+y*7) % 256
                out.extend((a*x//width, a*y//height, a//3, a))
            elif kind == 'stroke':
                a = (x*7+y*3) % 256
                out.extend((a*x//width, a*y//height, a//2, a))
            else:
                a = 0 if (x*3+y) % 11 == 0 else (x*9+y*4) % 256
                out.extend((a*y//height, a//2, a*x//width, a))
    return out


def image_pixels(width, height, premultiplied):
    pitch = width*4+4
    out = bytearray(pitch*height)
    for y in range(height):
        for x in range(width):
            a = (x*37+y*91) % 256
            if (x+2*y) % 5 == 0:
                a = 255
            if (x*3+y) % 7 == 3:
                a = 0
            rgb = [(x*53+y*17) % 256, (x*11+y*67) % 256, (x*29+y*41+100) % 256]
            out[y*pitch+x*4:y*pitch+x*4+4] = bytes([*(v*a//255 if premultiplied else v for v in rgb), a])
    return out


def literal(source):
    source = re.sub(r'\bf32\(([^()]*)\)', r'\1', source).replace('!', '')
    source = re.sub(r'(?<![\w\d])\.('+ '|'.join(['butt','round','square','bevel','miter',*MODES])+r')\b', r"'\1'", source)
    source = re.sub(r'\btrue\b', 'True', source)
    source = re.sub(r'\bfalse\b', 'False', source)
    return ast.literal_eval(source)


class Reference:
    def __init__(self, library):
        self.reference_sha256 = hashlib.sha256(library.read_bytes()).hexdigest()
        self.pattern_sha256 = None
        self.pending_filters = []
        self.library = C.CDLL(str(library.resolve()))
        for name in ['oracle_canvas_fill', 'oracle_canvas_stroke', 'oracle_canvas_bitmap']:
            getattr(self.library, name).argtypes = [C.POINTER(C.c_uint8), C.POINTER(C.c_int32), C.POINTER(C.c_float)]
        self.library.oracle_pattern.argtypes = [C.POINTER(C.c_uint8)]
        self.library.oracle_filters.argtypes = [C.c_int32, C.POINTER(C.c_int32), C.POINTER(C.c_float)]
        self.records = []

    def call(self, name, pixels, ints, floats, key, expected_mac):
        output = bytearray(pixels)
        args = (C.c_int32*len(ints))(*ints)
        values = (C.c_float*len(floats))(*floats)
        assert getattr(self.library, name)((C.c_uint8*len(output)).from_buffer(output), args, values)
        digest = hashlib.sha256(output).hexdigest()
        self.records.append(dict(case=key, expected_macos=expected_mac, native_sha256=digest,
                                 input_sha256=hashlib.sha256(pixels).hexdigest(),
                                 function=name, arguments=ints, floats=floats, filters=self.pending_filters,
                                 pattern_sha256=self.pattern_sha256))
        return digest

    def filters(self, filters):
        self.pending_filters = filters
        ints, floats = [], []
        for kind, color, radius, dx, dy, matrix, clamp in filters:
            ints += [kind, clamp, color]
            floats += [radius, dx, dy, *matrix]
        self.library.oracle_filters(len(filters), (C.c_int32*len(ints))(*ints), (C.c_float*len(floats))(*floats))

    def path(self, pixels, width, height, path, key, expected, *, transform=IDENTITY,
             color=0xff000000, alpha=1, stroke=None, clips=(), style=None, filters=(), alpha_type=2, mode='src_over', mask_blur=0):
        clip_ints = [len(clips), *[v for p, even in clips for v in [len(p)//12, int(even)]]]
        clip_floats = [v for p, _ in clips for v in p]
        self.pattern_sha256 = None
        style_ints, style_floats = [0], []
        if style:
            w, h = style['width'], style['height']
            bitmap = image_pixels(w, h, style.get('premultiplied', False))
            self.pattern_sha256 = hashlib.sha256(bitmap).hexdigest()
            storage = (C.c_uint8*len(bitmap)).from_buffer(bitmap)
            self.library.oracle_pattern(storage)
            style_ints = [4, w, h, w*4+4, 2 if style.get('premultiplied') else 1,
                          int(style.get('display_p3', False)), style.get('repetition', 0)]
            style_floats = style['transform']
        self.filters(filters)
        if stroke:
            line_width, cap, join, miter, dashes, phase = stroke
            ints = [width, height, width*4, alpha_type, len(path)//12, color, cap, join, len(dashes),
                    *clip_ints, MODES[style.get('mode', mode)] if style else MODES[mode], *style_ints]
            floats = [*transform, alpha, line_width, miter, *path, phase, *dashes, *clip_floats, mask_blur, *style_floats]
            name = 'oracle_canvas_stroke'
        else:
            ints = [width, height, width*4, alpha_type, 0, len(path)//12, color,
                    *clip_ints, MODES[style.get('mode', mode)] if style else MODES[mode], *style_ints]
            floats = [*transform, alpha, *path, *clip_floats, mask_blur, *style_floats]
            name = 'oracle_canvas_fill'
        return self.call(name, pixels, ints, floats, key, expected)


def stroke_fixtures(root, reference):
    for file in ['dash_test.v', 'scan_hairline_test.v', 'stroke_test.v']:
        text = (root/'cpuraster'/file).read_text()
        for function, body in re.findall(r'(?ms)^fn (test_\w+)\(\) \{(.*?)^\}', text):
            match = re.search(r"(?s)assert (dashed_hash|stroke_hash|wide_stroke_hash)\(s,(.*?)\) == (?:fixture_hash\()?'([0-9a-f]+)'", body)
            if not match:
                continue
            values = literal('['+match[2]+']')
            width, height, transform, color, alpha, line_width, cap, join, *rest = values
            path = []
            for kind, points in re.findall(r's << \w+_segment\((\d+),\s*(\[[^\]]*\])\)', body):
                path += segment(int(kind), *literal(points))
            assert path, function
            if match[1] == 'stroke_hash':
                rest = [10, [], 0]
            elif match[1] == 'wide_stroke_hash':
                rest += [[], 0]
            miter, dashes, phase = rest
            reference.path(background(width, height), width, height, path, file+':'+function, match[3],
                           transform=transform, color=color, alpha=alpha,
                           stroke=(line_width, dict(butt=0, round=1, square=2)[cap],
                                   dict(round=0, bevel=1, miter=2)[join], miter, dashes, phase))


def struct_cases(text, helper, record):
    pattern = r'(?s)'+helper+r'\('+record+r"\{(.*?)\}\) == (?:fixture_hash\()?'([0-9a-f]+)'"
    for i, (body, expected) in enumerate(re.findall(pattern, text)):
        fields = {}
        for name, value in re.findall(r'(?m)^\s*(\w+):\s*([^\n]+)', body):
            if value.strip() == 'pattern_test_scale()':
                fields[name] = [1.7, 0, 0, 1.3, .4, .6]
            elif value.strip() == 'rotation':
                fields[name] = [.9, .4, -.4, .9, 5, 2]
            else:
                fields[name] = literal(value)
        yield i, fields, expected


def pattern_fixtures(root, reference):
    text = (root/'cpuraster/image_shader_test.v').read_text()
    path = rectangle(1.5, 2.25, 46, 37.5)
    triangle = segment(0, 2, 3)+segment(1, 45.5, 10.25)+segment(1, 20.5, 38)+segment(5)
    for i, c, expected in struct_cases(text, 'pattern_test_hash', 'PatternTestCase'):
        stroke = None
        draw_path = path
        if c.get('stroke'):
            draw_path = segment(0, 4, 30)+segment(2, 44, 26, 20, -6)
            stroke = (c['line_width'], 1, 0, 10, [], 0)
        reference.path(background(48, 40, 'image'), 48, 40, draw_path, f'image_shader_test.v:{i}', expected,
                       transform=c.get('ctm', IDENTITY), alpha=c.get('alpha', 1), color=0,
                       style=c, stroke=stroke, clips=[(triangle, False)] if c.get('clip') else [])


def image_fixtures(root, reference):
    text = (root/'cpuraster/canvas_image_test.v').read_text()
    triangle = segment(0, 2, 3)+segment(1, 45.5, 10.25)+segment(1, 20.5, 38)+segment(5)
    for i, c, expected in struct_cases(text, 'image_test_hash', 'ImageTestCase'):
        premul = c.get('premultiplied', True)
        bitmap = image_pixels(7, 6, premul)
        reference.pattern_sha256 = hashlib.sha256(bitmap).hexdigest()
        storage = (C.c_uint8*len(bitmap)).from_buffer(bitmap)
        reference.library.oracle_pattern(storage)
        reference.filters([])
        clips = [(triangle, False)] if c.get('clip') else []
        ints = [48, 40, 192, 2, 2, int(c.get('smoothing', False)), len(clips),
                *[v for p, even in clips for v in [len(p)//12, int(even)]],
                MODES[c.get('mode', 'src_over')], 0, 7, 6, 32, 2 if premul else 1, int(c.get('display_p3', False))]
        floats = [*c.get('transform', IDENTITY), c.get('alpha', 1), *c['destination'],
                  *c.get('source', [0, 0, 7, 6]), *[v for p, _ in clips for v in p]]
        reference.call('oracle_canvas_bitmap', background(48, 40, 'image'), ints, floats,
                       f'canvas_image_test.v:{i}', expected)


def filter_fixtures(root, reference):
    text = (root/'cpuraster/filter_layer_test.v').read_text()
    path = segment(0, 10, 8)+segment(2, 38, 12, 40, 30)+segment(1, 12, 34)+segment(5)
    triangle = segment(0, 2, 3)+segment(1, 45.5, 10.25)+segment(1, 20.5, 38)+segment(5)
    blur_cases = [
        ('7263a58806bf8436', 2.5, 0xc0e04010, 1, IDENTITY, None, [], 'src_over', 2),
        ('11314abdec52c202', .8, 0xff3070c0, 1, [1.25,0,0,.75,2,4], (3,1,0,10,[],0), [], 'src_over', 1),
        ('698232341bfd269c', 4, 0xff10a040, 1, IDENTITY, None, [(triangle,False)], 'multiply', 2),
        ('9715f8489f927c77', 12, 0x80ff8000, .7, IDENTITY, None, [], 'src_over', 2),
    ]
    for i,(expected,sigma,color,alpha,transform,stroke,clips,mode,alpha_type) in enumerate(blur_cases):
        assert expected in text
        reference.path(background(48,40,'image'),48,40,path,f'filter_layer_test.v:blur:{i}',expected,
                       color=color,alpha=alpha,transform=transform,stroke=stroke,clips=clips,mode=mode,
                       alpha_type=alpha_type,filters=[(0,0,sigma,0,0,[0]*20,0)])
    shadow_cases = [
        ('e285128862b4c6f0',-1,0,0,0xff000000,'src_over'),
        ('ab22cb5dca7fc310',0,7,-5,0x805030e0,'src_over'),
        ('a62f8ada40e53b93',2.5,5.25,-3.75,0x805030e0,'src_over'),
        ('05e318754d94c77f',.8,-7.25,4.5,0xff3070c0,'multiply'),
        ('4cb7f8b02151c3f6',12,2,3,0x80ff8000,'screen'),
        ('4394924f9676093c',0,90,80,0xff000000,'xor'),
    ]
    for i,(expected,sigma,dx,dy,color,mode) in enumerate(shadow_cases):
        assert expected in text
        reference.path(background(48,40,'image'),48,40,path,f'filter_layer_test.v:drop-shadow:{i}',expected,
                       color=0xc0e04010,mode=mode,clips=[(triangle,False)] if i==3 else [],
                       filters=[(1,color,sigma,dx,dy,[0]*20,0)])
    text = (root/'cpuraster/color_filter_test.v').read_text()
    matrix = literal(re.search(r'(?s)const cf_grayscale.*?matrix: (\[[^\]]*\])',text)[1])
    path = segment(0,4,5)+segment(2,40,2,44,30)+segment(1,10,36)+segment(5)
    reference.path(background(48,40,'image'),48,40,path,'color_filter_test.v:solid-grayscale','b9e3807216264fee',
                   color=0xc0e04010,filters=[(2,0,0,0,0,matrix,1)])

    contrast = literal(re.search(r'(?s)const cf_contrast.*?matrix: (\[[^\]]*\])',text)[1])
    opacity = literal(re.search(r'(?s)const cf_opacity.*?matrix: (\[[^\]]*\])',text)[1])
    reference.path(background(48,40,'image'),48,40,path,'color_filter_test.v:thin-contrast','981723a1df76bd4e',
                   color=2234942615,alpha=.54357654,alpha_type=1,stroke=(.81891125,2,2,10,[],0),
                   filters=[(2,0,0,0,0,contrast,0),(2,0,0,0,0,opacity,1)])


def mask_blur_fixtures(root, reference):
    text = (root/'cpuraster/blur_test.v').read_text()
    curve = segment(0,12,10)+segment(2,60,14,52,6)+segment(3,40,50,6,30,58,44)+segment(5)
    cases = [
        ('31420421a7850a76',curve,IDENTITY,0xff204080,3,None,[],'src_over',2),
        ('dea51d8b129f7d39',curve,[1.5,0,0,1.5,-10,-6],0xa0e05010,12,None,[],'src_over',2),
        ('edcd6b85fed92936',curve,IDENTITY,0xff204080,.5,None,[],'src_over',2),
        ('49259369cfea127b',curve,IDENTITY,0xc0306090,5,(1,2,2,10,[],0),[],'src_over',2),
        ('802858540a0d2a24',curve,IDENTITY,0xff40c060,7,None,[(rectangle(8.5,6.25,50.75,41.5),False)],'multiply',2),
        ('727f7a3691bdb1cf',rectangle(10.25,8.5,52.75,44),IDENTITY,0xff802040,8,None,[],'src_over',2),
        ('627f3ce6ef3d3aec',rectangle(6,6,58,50),IDENTITY,0xc0306090,6,(4,0,2,10,[],0),[],'src_over',2),
        ('f9911f428908818f',rectangle(30,26,36,31),IDENTITY,0xff802040,9,None,[],'src_over',2),
        ('6c7f50d0617e3740',rectangle(-4200,-100,4250,150)+rectangle(-100,-50,100,100),IDENTITY,0xff204080,12,None,[],'src_over',1),
    ]
    for i,(expected,path,transform,color,blur,stroke,clips,mode,alpha_type) in enumerate(cases):
        assert expected in text
        reference.path(background(64,56,'blur'),64,56,path,f'blur_test.v:{i}',expected,
                       transform=transform,color=color,mask_blur=blur,stroke=stroke,clips=clips,mode=mode,
                       alpha_type=alpha_type)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('library', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    reference = Reference(args.library)
    stroke_fixtures(root, reference)
    pattern_fixtures(root, reference)
    image_fixtures(root, reference)
    filter_fixtures(root, reference)
    mask_blur_fixtures(root, reference)
    files = [root/'cpuraster'/n for n in ['dash_test.v', 'scan_hairline_test.v', 'stroke_test.v',
                                        'image_shader_test.v', 'canvas_image_test.v', 'filter_layer_test.v', 'color_filter_test.v', 'blur_test.v']]
    if hashlib.sha256(args.library.read_bytes()).hexdigest() != reference.reference_sha256:
        raise SystemExit('Reference library changed while capturing fixtures')
    result = dict(platform=platform.platform(), reference_sha256=reference.reference_sha256,
                  tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  sources={str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
                  records=reference.records)
    if platform.system() == 'Darwin':
        mismatches = [r['case'] for r in reference.records if r['native_sha256'][:len(r['expected_macos'])] != r['expected_macos']]
        if mismatches:
            raise SystemExit('Native macOS fixture inputs disagree with checked-in hashes: '+str(mismatches))
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(f'{len(reference.records)} native fixture hashes captured')


if __name__ == '__main__':
    main()
