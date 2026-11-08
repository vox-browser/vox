import importlib.util,json,sys,ctypes as C,hashlib
from pathlib import Path
s=importlib.util.spec_from_file_location('reference','tools/gg_migration/native_fixture_hashes.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
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
]
for c in cases:
 w,h=c.get('width',48),c.get('height',40);iw,ih=c.get('iw',7),c.get('ih',6)
 image=m.image_pixels(iw,ih,c['premul']);r.pattern_sha256=hashlib.sha256(image).hexdigest();storage=(C.c_uint8*len(image)).from_buffer(image);r.library.oracle_pattern(storage);r.filters([c['filter']])
 clips=[(triangle,False)] if c.get('clip') else []
 ints=[w,h,w*4,2,2,int(c.get('smoothing',False)),len(clips),*[v for p,even in clips for v in [len(p)//12,int(even)]],m.MODES[c['mode']],0,iw,ih,iw*4+4,2 if c['premul'] else 1,int(c.get('p3',False))]
 floats=[*c.get('transform',m.IDENTITY),c['alpha'],*c['destination'],*c['source'],*[v for p,_ in clips for v in p]]
 name='oracle_canvas_bitmap_chromium' if c.get('bitmap_space') else 'oracle_canvas_bitmap'
 r.call(name,m.background(w,h,'image') if w==48 else bytearray(w*h*4),ints,floats,c['name'],'captured')
print(json.dumps(r.records,indent=2))
