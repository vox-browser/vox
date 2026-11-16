#!/usr/bin/env python3
"""Replay retained site archives and focused controls with pinned browser inputs.

The default evidence directory is the retained optimized-sites audit. Generated
captures belong in a unique Build directory; original references stay unchanged.
"""
import sys,json,threading,hashlib,argparse,struct,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[1];sys.path.insert(0,str(R/'tools'))
from page_archive import Replay,load_archive
from forum_news_pixels import native_capture_environment,guarded,check_native,executable_identity,write_json
from completed_browser import completed_browser_lease
from check_pixel_equality import compare
from production_source_manifest import compiled_package_witnesses
p=argparse.ArgumentParser();p.add_argument('--output',required=True);p.add_argument('--binary',type=Path);p.add_argument('--diagnostic',action='store_true');p.add_argument('--grid-log',action='store_true');p.add_argument('--shape-log',action='store_true');p.add_argument('--png-log',action='store_true');p.add_argument('--retain-intrinsic-lines',action='store_true');p.add_argument('--audit-selectors',type=Path);p.add_argument('--feature-revision');p.add_argument('--glyph-log',action='store_true');p.add_argument('sites',nargs='+');args=p.parse_args()
for name in args.sites:
 if name not in ['wikipedia','vlang','lobsters','github','hn','cnn']:
  source=R/f'Tests/Browser/Brave/input/{name}.html';ref=R/f'Tests/Browser/Brave/expected/{name}.png'
  if not source.exists():source=R/f'Tests/Browser/Brave/diagnostic/{name}.html';ref=source.with_suffix('.png')
  assert source.is_file() and ref.is_file(),f'Missing fixture/reference: {name}'
out=R/args.output;out.mkdir(exist_ok=False)
old=R/'docs/performance/optimized-pixels-20261112/raw/optimized-pixels-20261112'
with completed_browser_lease(R,args.binary) as selected:
 binary=selected.executable
 shared={str(q):hashlib.sha256(q.read_bytes()).hexdigest() for q in sorted((R/'Build/v').glob('libVox*.dylib'))}
 write_json(out/'scope.json',dict(diagnostic=args.diagnostic,production_scope=not args.diagnostic,completed_artifact=selected.staged,shared_native_libraries=shared))
 pin=executable_identity(binary);write_json(out/'identity.json',pin)
 if not args.diagnostic:
  receipt=selected.receipt or json.loads((R/'Build/production-build/latest.json').read_bytes());expected=receipt['ready_executable_sha256'] if selected.staged else receipt['executable_sha256'];assert expected==pin[str(binary)]
  frozen_path=Path(receipt['frozen_compilation']);frozen_path=frozen_path if frozen_path.exists() else R / frozen_path.relative_to('/Users/alex/code/vox2');frozen=json.loads(frozen_path.read_bytes());features=['layout/chromium_partial_border.v','layout/chromium_shadow_pixel_scale.v','layout/table_formatting_context.v','paint/replaced_image_clip.v','chromium/msaa_tiles.v','layout/flex_measurement_layout.v','layout/chromium_raster_layers.v','chromium/gradient_gpu_darwin.v','native/include/native_css_gradient_gpu_darwin.h','chromium/svg_image_group.v','native_capture_darwin.m','ggshape/blur_filter_darwin.v','ggshape/blur_filter_darwin.m','chromium/image_decode.v','layout/video_paint_facts.v','main.v','images/png_sampling_darwin.v','ggshape/sampled_image_darwin.v','imageraster/rgba.v','imageraster/png_profile.v','ggshape/image_color_darwin.v','chromium/background_text_raster_darwin.v','cpuraster/resize_pixels.v','native/include/native_sampled_png_darwin.h','Build/v/modules/gg/canvas/vox_document_image.v','Build/v/modules/gg/canvas/gpu_layer.v','Build/v/modules/gg/canvas/gpu_surface.v','chromium/inner_shadow_gpu_darwin.v','ggshape/shape_darwin.v','chromium/rounded_outer_group_darwin.v','cpuraster/inner_shadow.v','layout/paint_transport.v','chromium/gpu_raster_darwin.v','chromium/shadowed_png_group_darwin.v','chromium/outer_decorations.v','chromium/elliptical_outer_group_darwin.v','ggshape/rotated_filter_darwin.v','native/include/native_graphite_bridge.h','chromium/rect_prefetch.v','Build/v/modules/gg/canvas/vox_shadow_mask.v','chromium/rounded_background_pair.v','chromium/rounded_background_group_darwin.v','chromium/inset_decorations.v','chromium/inset_group_darwin.v','chromium/filter_clip.v','chromium/svg_compositor_layer.v','chromium/elliptical_text_group_darwin.v','images/jpeg_sampling_darwin.v','yuv/jpeg_scaled.v','yuv/jpeg_orientation.v','ggshape/gradient_local_coordinates_darwin.v','images/lossless_webp_sampling_darwin.v','chromium/rounded_image_samples_darwin.v']
  witness={str(R/f):dict(current=hashlib.sha256(subprocess.check_output(['git','show',args.feature_revision+':'+f]) if args.feature_revision and not f.startswith('Build/') else (R/f).read_bytes()).hexdigest(),compiled=frozen['exact_source_manifest'].get(str(R/f),frozen['exact_source_manifest'].get('/Users/alex/code/vox2/'+f))) for f in features}
  for package in ['gg','ggshape','images','imageraster','yuv','chromium','media','browsernet','browsersettings']:
   witness.update(compiled_package_witnesses(frozen, package))
  assert all(x['current']==x['compiled'] for x in witness.values()),witness
  write_json(out/'production-receipt.json',receipt);write_json(out/'feature-inputs.json',witness)
 if args.diagnostic:
  startup=out/'startup';startup.mkdir();profile=startup/'profile';profile.mkdir();(startup/'requests.jsonl').touch();write_json(startup/'config.json',dict(selectors=[]))
  env=native_capture_environment(profile,'/etc/ssl/cert.pem',startup/'cache',startup/'audit.json',startup/'config.json',startup/'requests.jsonl',0)
  guarded([binary,'--headless-smoke'],startup/'smoke',120,env)
 for site in args.sites:
  folder=out/site;folder.mkdir();fixture=site not in ['wikipedia','vlang','lobsters','github','hn','cnn']
  width,height=(800,600) if site=='persian-numeric-direction' else (1024,768)
  if fixture:
   source=R/f'Tests/Browser/Brave/input/{site}.html';ref=R/f'Tests/Browser/Brave/expected/{site}.png';url=str(source);replay=None
   if not source.exists():
    source=R/f'Tests/Browser/Brave/diagnostic/{site}.html';ref=source.with_suffix('.png');url=str(source)
   width,height=struct.unpack('>II',ref.read_bytes()[16:24])
   if site in ['device-pixel-shadows','rounded-single-border-device-layout']:width,height=width//2,height//2
  else:
   archive=R/'Tests/Browser/Brave/hn-home-instructions' if site=='hn' else R/f'Tests/Browser/Brave/sites/{site}' if site in ['lobsters','cnn'] else old/f'{site}-archive'
   manifest=load_archive(archive);url=manifest['url'];source=archive/'manifest.json'
   ref=R/'docs/performance/optimized-pixels-20261112/raw/optimized-pixels-hn-20261112-2/pair-1-brave/document.png' if site=='hn' else old/f'forum/{site}/brave.png' if site in ['lobsters','cnn'] else old/f'{site}-replay/1-brave.png'
   replay=Replay(archive,folder/'replay');thread=threading.Thread(target=replay.server.serve_forever,daemon=True);thread.start()
  inputs=[source,ref,R/'Build/pixel-tools/pixel_diff']
  if site.startswith('webp-srgb-table'):inputs.append(R/'Tests/Browser/Brave/sites/cnn/bodies/1f1ea2536d7f4cb1e3d805beab53611f4c990e069f1da6181ebad55725654572')
  hashes={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs};write_json(folder/'inputs.json',hashes)
  try:
   for index in range(2):
    job=folder/str(index);job.mkdir();profile=job/'profile';profile.mkdir()
    if replay:write_json(profile/'settings.json',dict(enabled=True,host='127.0.0.1',port=str(replay.server.server_address[1])))
    requests=job/'requests.jsonl';requests.touch();selectors=[dict(name='body',selector='body',limit=1)]
    if args.audit_selectors:selectors+=json.loads(args.audit_selectors.read_bytes())
    if site=='hn':selectors+=json.loads((R/'docs/performance/optimized-pixels-20261112/raw/optimized-pixels-hn-20261112-2/audit-config.json').read_bytes())['selectors']
    if site=='github':selectors+=json.loads((old/'github-replay/audit-config.json').read_bytes())['selectors']
    write_json(job/'config.json',dict(selectors=selectors))
    env=native_capture_environment(profile,replay.ready['ca'] if replay else '/etc/ssl/cert.pem',job/'cache',job/'audit.json',job/'config.json',requests,2 if site=='hn' else 5 if replay else 1)
    if site in ['hn','device-pixel-shadows','rounded-single-border-device-layout']:env['LADYBIRD_SCREENSHOT_SCALE']='2'
    if args.glyph_log:
     (job/'glyphs').mkdir();env['VOX_TEXT_RASTER_DUMP']=str(job/'glyphs')
    if args.grid_log:env['VOX_DIAGNOSTIC_PAINT_LAYER']='1'
    if args.shape_log:env['VOX_GG_DIAGNOSTICS']='1'
    if args.png_log:env['VOX_DIAGNOSTIC_PNG']='1'
    if args.retain_intrinsic_lines:
     assert args.diagnostic
     env['VOX_DIAGNOSTIC_RETAIN_INTRINSIC_LINES']='1'
    extra=['--disable-javascript'] if site in ['wikipedia','vlang'] else []
    guarded([binary,*extra,'--window-width',str(width),'--window-height',str(height+84),'--screenshot',job/'vox.png',url],job/'capture',120,env)
    a=json.loads((job/'audit.json').read_bytes());assert a['ready']=='complete' and (a['viewport_width'],a['viewport_height'])==(width,height)
    if replay:
     assert a['url']==url
     assert len(a['selections'][0]['elements'][0]['text'])>1000
    if site=='wikipedia':assert a['title']=='Wikipedia'
    if site=='vlang':assert a['title']=='V — The V Programming Language'
    if site=='github':
     assert a['selections'][0]['elements'][0]['rect']['y']==0, 'GitHub capture scrolled away from reference origin'
     previous=json.loads((old/'github-replay/2-vox.audit.json').read_bytes());assert a['title']==previous['title']
     rows=next(x['elements'] for x in a['selections'] if x['name']=='rows');assert len(rows)==33
     assert [x['text'] for x in rows]==[x['text'] for x in previous['selections'][0]['elements']]
    if site in ['lobsters','cnn']:check_native(a,json.loads((old/f'forum/{site}/brave.png.json').read_bytes()))
    if site=='hn':
     previous=json.loads((R/'docs/performance/optimized-pixels-20261112/raw/optimized-pixels-hn-20261112-2/pair-1-vox/audit.json').read_bytes());assert a['title']==previous['title']
     rows=next(x['elements'] for x in a['selections'] if x['name']=='stories');oldrows=next(x['elements'] for x in previous['selections'] if x['name']=='stories');assert len(rows)==30 and [x['text'] for x in rows]==[x['text'] for x in oldrows]
    result=compare(ref,job/'vox.png',job/'diff.png',R/'Build/pixel-tools/pixel_diff');write_json(job/'pixels.json',result);print(site,index,result['different_pixels'],flush=True)
    assert pin==executable_identity(binary)
    if not args.diagnostic:
     assert all(hashlib.sha256(Path(name).read_bytes()).hexdigest()==value['current'] for name,value in witness.items())
    for name,digest in shared.items():assert hashlib.sha256(Path(name).read_bytes()).hexdigest()==digest
    for name,digest in hashes.items():assert hashlib.sha256(Path(name).read_bytes()).hexdigest()==digest
  finally:
   if replay:replay.server.shutdown();replay.server.server_close();thread.join()
