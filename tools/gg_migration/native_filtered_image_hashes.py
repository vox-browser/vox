#!/usr/bin/env python3
"""Capture native CPU image-filter fixtures; no V candidate pixels are read.

Run from the canonical checkout: python3 tools/gg_migration/native_filtered_image_hashes.py LIBRARY
The bitmap-space policy is a CPU command comparison, not a Dawn GPU comparison.
"""
import importlib.util,json,sys,ctypes as C,hashlib
from pathlib import Path
s=importlib.util.spec_from_file_location('reference',str(Path(__file__).with_name('native_fixture_hashes.py')));m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
r=m.Reference(Path(sys.argv[1]));r.library.oracle_canvas_bitmap_chromium.argtypes=[C.POINTER(C.c_uint8),C.POINTER(C.c_int32),C.POINTER(C.c_float)]
contrast=[1.3,0,0,0,-.15,0,1.3,0,0,-.15,0,0,1.3,0,-.15,0,0,0,1,0]
triangle=m.segment(0,2,3)+m.segment(1,45.5,10.25)+m.segment(1,20.5,38)+m.segment(5)
cases=[
 dict(name='color-premul',premul=True,destination=[10,12,7,6],source=[0,0,7,6],alpha=.7,mode='src_over',filter=(2,0,0,0,0,contrast,0)),
 dict(name='color-p3-subset',premul=False,p3=True,destination=[4,6,5,4],source=[1,1,5,4],alpha=.65,mode='src_in',clip=True,filter=(2,0,0,0,0,contrast,0)),
 dict(name='color-unpremul-clip',premul=False,destination=[12,10,7,6],source=[0,0,7,6],alpha=.35,mode='color_dodge',clip=True,smoothing=True,filter=(2,0,0,0,0,contrast,0)),
 dict(name='color-runtime-subset',premul=True,destination=[8,10,4,4],source=[2,1,4,4],alpha=1,mode='plus_lighter',clip=True,filter=(2,0,0,0,0,contrast,0)),
 dict(name='bitmap-blur',bitmap_space=True,premul=True,destination=[4.25,5.5,30,25],source=[0,0,7,6],alpha=.7,mode='src_in',clip=True,smoothing=True,transform=[1.25,0,0,.75,2,4],filter=(0,0,2.5,0,0,[0]*20,0)),
 dict(name='bitmap-shadow-rotated',bitmap_space=True,premul=False,destination=[3,8,7,6],source=[0,0,7,6],alpha=.35,mode='src_over',transform=[.9,.4,-.4,.9,5,2],filter=(1,0x805030e0,.8,-7.25,4.5,[0]*20,0)),
 dict(name='bitmap-shadow-unbounded-input',bitmap_space=True,premul=False,width=10,height=20,iw=21,ih=22,destination=[3,8,21,22],source=[0,0,21,22],alpha=.27487868,mode='color_dodge',smoothing=True,filter=(1,0xffffffff,.85911834,-8.656294,-15,[0]*20,0)),
 dict(name='bitmap-shadow-sprite-layout',bitmap_space=True,premul=True,width=65,height=44,iw=2,ih=13,destination=[49,39,2,3],source=[0,0,2,3],alpha=.43391985,mode='soft_light',smoothing=True,transform=[1,0,0,1,-8,-15],filter=(1,2458785036,.030803392,-4,-17.134123,[0]*20,0)),
 dict(name='color-scaled-nearest',premul=True,destination=[4.25,5.5,30,25],source=[0,0,7,6],alpha=.7,mode='src_over',clip=True,transform=[1.25,0,0,.75,2,4],filter=(2,0,0,0,0,contrast,0)),
 dict(name='color-rotated-nearest',premul=False,p3=True,destination=[4,6,35,24],source=[1,1,5,4],alpha=.65,mode='multiply',clip=True,transform=[.9,.4,-.4,.9,5,2],filter=(2,0,0,0,0,contrast,0)),
 dict(name='color-snap-nearest',premul=True,destination=[10.01,12.01,7.002,6.002],source=[0,0,7,6],alpha=.35,mode='color_dodge',clip=True,filter=(2,0,0,0,0,contrast,0)),
 dict(name='color-flipped-nearest',premul=True,destination=[5.25,6.5,22,18],source=[0,0,7,6],alpha=.7,mode='overlay',clip=True,transform=[-1.2,0,0,.8,42,3],filter=(2,0,0,0,0,contrast,0)),
 dict(name='color-scaled-linear',premul=True,destination=[4.25,5.5,30,25],source=[0,0,7,6],alpha=.7,mode='src_over',clip=True,smoothing=True,transform=[1.25,0,0,.75,2,4],filter=(2,0,0,0,0,contrast,0)),
 dict(name='color-rotated-linear',premul=False,p3=True,destination=[4,6,35,24],source=[1,1,5,4],alpha=.65,mode='multiply',clip=True,smoothing=True,transform=[.9,.4,-.4,.9,5,2],filter=(2,0,0,0,0,contrast,0)),
 dict(name='color-mipmap-premul',premul=True,iw=31,ih=25,destination=[6.25,5.75,8,7],source=[1,2,28,21],alpha=.85,mode='multiply',clip=True,smoothing=True,filter=(2,0,0,0,0,contrast,0)),
 dict(name='color-mipmap-unpremul-p3',premul=False,p3=True,iw=31,ih=25,destination=[6.25,5.75,8,7],source=[1,2,28,21],alpha=.85,mode='multiply',clip=True,smoothing=True,transform=[.9,.4,-.4,.9,5,2],filter=(2,0,0,0,0,contrast,0)),
]
for smoothing in [False, True]:
 for mode in ['src', 'src_in', 'src_out', 'dst_in', 'dst_atop', 'plus_darker', 'plus_lighter']:
  cases.append(dict(name=('linear-' if smoothing else 'nearest-')+'restore-'+mode,
                    premul=False,p3=True,destination=[3.25,4.5,24,18],source=[1,1,5,4],
                    alpha=.65,mode=mode,clip=True,smoothing=smoothing,
                    transform=[1.25,0,0,.75,2,4] if smoothing else [.9,.4,-.4,.9,5,2],
                    filter=(2,0,0,0,0,contrast,0)))
cases += [
 dict(name='linear-restore-near-unit-scale',premul=True,destination=[3.25,4.5,7,6],source=[0,0,7,6],alpha=.65,mode='src_in',clip=True,smoothing=True,transform=[.9,0,0,1.1,2,4],filter=(2,0,0,0,0,contrast,0)),
 dict(name='linear-restore-runtime-child-base-level',premul=False,iw=11,ih=1,destination=[2.3826473,7.3846455,4.1874094,10.494535],source=[0,0,11,1],alpha=.999,mode='plus_lighter',smoothing=True,filter=(2,0,0,0,0,contrast,0)),
 dict(name='source-clipped-nearest',premul=True,destination=[3.25,4.5,24,18],source=[-2,1,12,9],alpha=.65,mode='multiply',clip=True,transform=[.9,.4,-.4,.9,5,2],filter=(2,0,0,0,0,contrast,0)),
 dict(name='source-clipped-linear',premul=False,p3=True,destination=[3.25,4.5,24,18],source=[-2,1,12,9],alpha=.65,mode='src_in',clip=True,smoothing=True,transform=[1.25,0,0,.75,2,4],filter=(2,0,0,0,0,contrast,0)),
 dict(name='source-clipped-empty-restore',premul=True,destination=[3.25,4.5,24,18],source=[10,1,5,4],alpha=.65,mode='src_in',clip=True,filter=(2,0,0,0,0,contrast,0)),
 dict(name='source-clipped-empty-quick-reject',premul=True,destination=[60,50,24,18],source=[10,1,5,4],alpha=.65,mode='src_in',clip=True,filter=(2,0,0,0,0,contrast,0)),
 dict(name='source-clipped-negative-width',premul=True,destination=[3.25,4.5,24,18],source=[-2,1,-5,4],alpha=.65,mode='src_in',clip=True,filter=(2,0,0,0,0,contrast,0)),
 dict(name='linear-restore-sheared',premul=False,p3=True,destination=[3.25,4.5,24,18],source=[1,1,5,4],alpha=.65,mode='plus_lighter',clip=True,smoothing=True,transform=[.7,.45,.3,1.2,5,2],filter=(2,0,0,0,0,contrast,0)),
 dict(name='linear-restore-rotated-near-unit',premul=True,destination=[3.25,4.5,5,4],source=[1,1,5,4],alpha=.65,mode='src_in',clip=True,smoothing=True,transform=[.96,.28,-.28,.96,5,2],filter=(2,0,0,0,0,contrast,0)),
]
for mode in ['src', 'src_in', 'src_out', 'dst_in', 'dst_atop', 'plus_darker', 'plus_lighter']:
 cases.append(dict(name='rotated-linear-restore-'+mode,premul=False,p3=True,
                   destination=[3.25,4.5,24,18],source=[1,1,5,4],alpha=.65,mode=mode,
                   clip=True,smoothing=True,transform=[.9,.4,-.4,.9,5,2],
                   filter=(2,0,0,0,0,contrast,0)))
cases += [
 dict(name='bitmap-color-premul',bitmap_space=True,premul=True,destination=[10,12,7,6],source=[0,0,7,6],alpha=.7,mode='src_over',filter=(2,0,0,0,0,contrast,0)),
 dict(name='bitmap-color-rotated-p3',bitmap_space=True,premul=False,p3=True,destination=[4,6,35,24],source=[1,1,5,4],alpha=.65,mode='multiply',clip=True,smoothing=True,transform=[.9,.4,-.4,.9,5,2],filter=(2,0,0,0,0,contrast,0)),
 dict(name='bitmap-color-downsample',bitmap_space=True,premul=True,iw=31,ih=25,destination=[6.25,5.75,8,7],source=[1,2,28,21],alpha=.85,mode='src_in',clip=True,smoothing=True,filter=(2,0,0,0,0,contrast,0)),
]
for c in cases:
 w,h=c.get('width',48),c.get('height',40);iw,ih=c.get('iw',7),c.get('ih',6)
 image=m.image_pixels(iw,ih,c['premul']);r.pattern_sha256=hashlib.sha256(image).hexdigest();storage=(C.c_uint8*len(image)).from_buffer(image);r.library.oracle_pattern(storage);r.filters([c['filter']])
 clips=[(triangle,False)] if c.get('clip') else []
 ints=[w,h,w*4,2,2,int(c.get('smoothing',False)),len(clips),*[v for p,even in clips for v in [len(p)//12,int(even)]],m.MODES[c['mode']],0,iw,ih,iw*4+4,2 if c['premul'] else 1,int(c.get('p3',False))]
 floats=[*c.get('transform',m.IDENTITY),c['alpha'],*c['destination'],*c['source'],*[v for p,_ in clips for v in p]]
 name='oracle_canvas_bitmap_chromium' if c.get('bitmap_space') else 'oracle_canvas_bitmap'
 r.call(name,m.background(w,h,'image') if w==48 else bytearray(w*h*4),ints,floats,c['name'],'captured')
import platform
if platform.system() == 'Darwin':
 expected = [
  'fcdf07f1784c94ae', 'cdff66946d64f415', '79f27b4c61142d18', 'e3441259be4b7ca6',
  'b04f05f0f7807d28', '742faaa5a08e2c8d', '7a9e4b5a7ebf291f', '6dd8c713245e52c2',
  'e025e6ff0e8b6e21', '116d6bd4d0f19821', '171f9638805833aa', '52406c90e7dae2ce',
  'd5f8f3845bfa1191', 'e95056f459921fcc', '4d2545a295b0c06a', 'b7ec0bc884c06b1c',
  '46fcd61c577e37c9', '8df3a99256c17efc', 'ee3b65cf28b7c260', '52bef994eb1f0a52',
  '74c6cb30d370371a', '1e7ab89a4da1e16f', '5e28aece98e44f83', '6a3d3514d69c10b6',
  '06b178d6241aeedf', '84bb844bc9446aa4', '10b411f2added94d', '9dcb80513fcef5b6',
  '4137bfce1d4c56ef', '424a58d921b95596', 'e9ae408499d06d09', 'b597b38558cfdfc1',
  'c6cdff1bcb881136', '7b33de5d39e16a66', '62b1b888837ad40a', 'f00be8e39ec6bc7f',
  'f00be8e39ec6bc7f', 'f3f022c3c8bcb02f', '33a4cc97cfdb1da1', 'a9973dbbb81b55a3',
  'b9ed9372ad2fa689', '4b7094d961364ddc', 'c014e794ae2d0531', '820e54abd9a5bdb9',
  '65bee32ef9751dba', '2f6d605edd08a4c8',
  '26a3b278f9abcba9', '64abfa4e28e7d1c5', 'b5c557eb9dd295df',
 ]
 for record, digest in zip(r.records, expected):
  assert record['native_sha256'].startswith(digest), record['case']
print(json.dumps(dict(platform=platform.platform(), reference_sha256=r.reference_sha256,
                     tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                     records=r.records), indent=2))
