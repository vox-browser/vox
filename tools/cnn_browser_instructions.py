#!/usr/bin/env python3
"""Compare frozen CNN captures with full-uBO Brave and native Vox.

Cold process launch through first completed capture. Vox includes teardown;
Brave's observed descendant counters are a polling lower bound. GPU machine
instructions and external services are excluded. Frozen DOM has author scripts
removed; this is not a live JavaScript or interaction parity claim.
"""
import argparse
import base64
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import subprocess
import time
from types import SimpleNamespace

from check_pixel_equality import compare
import measure_browser_instructions as measure
from pikabu_browser_instructions import (
    connect_brave, close_brave, brave_command, evaluate, fingerprint_tree,
    fresh_copy, digest,
)
from process_instruction_counts import MacCounters, ProcessTreeCounter, CounterSampler
from reddit_browser_instructions import FrozenAssetsCDP, evaluate_pairs, native_environment

REPO = Path(__file__).resolve().parents[1]


def runtime_overrides():
    # Boehm reads more than the four common heap/marker controls. In
    # particular GC_DONT_GC and GC_ENABLE_INCREMENTAL change the workload.
    # dyld search overrides can silently replace the linked collector too.
    return {k: v for k, v in os.environ.items()
            if k.startswith(('GC_', 'DYLD_'))}


def linked_collector(binary):
    """Resolve the macOS collector with the default dyld search environment."""
    dependencies = subprocess.check_output(['otool', '-L', str(binary)], text=True)
    library = next((line.strip().split(' (', 1)[0] for line in dependencies.splitlines()[1:]
                    if re.search(r'(^|/)libgc(?:\.\d+)*\.dylib \(', line.strip())), None)
    if library is None:
        raise RuntimeError('Production comparison requires a linked Boehm collector')

    def expand(path):
        for token in ['@executable_path', '@loader_path']:
            if path == token or path.startswith(token + '/'):
                return binary.parent / path[len(token):].lstrip('/')
        return Path(path)

    if library.startswith('@rpath/'):
        commands = subprocess.check_output(['otool', '-l', str(binary)], text=True)
        paths = re.findall(r'cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset \d+\)', commands)
        candidates = [expand(p) / library[len('@rpath/'):] for p in paths]
    else:
        candidates = [expand(library)]
    for path in candidates:
        if path.is_file(): return path.resolve()
    raise RuntimeError('Cannot resolve the linked Boehm collector')

STATE = r'''JSON.stringify({url:location.href,title:document.title,ready:document.readyState,
 width:innerWidth,height:innerHeight,scale:devicePixelRatio,text:document.body?.innerText||'',
 fonts:document.fonts.status,images:[...document.images].map(i=>{const r=i.getBoundingClientRect();
 return {url:i.currentSrc||i.src,complete:i.complete,naturalWidth:i.naturalWidth,
 x:r.x,y:r.y,width:r.width,height:r.height}})})'''
RECTS = r'''JSON.stringify([...document.querySelectorAll('*')].map((e,index)=>{
 const r=e.getBoundingClientRect(),s=getComputedStyle(e);return {index,tag:e.tagName,
 id:e.id,classes:e.getAttribute('class'),x:r.x,y:r.y,width:r.width,height:r.height,
 font:s.font,fontFamily:s.fontFamily,lineHeight:s.lineHeight,display:s.display,
 text:e.textContent.slice(0,150)}}))'''


def ready(state):
    visible = [i for i in state.get('images', []) if i['width'] > 50 and i['height'] > 50
               and i['y'] < 768 and i['y'] + i['height'] > 0
               and i['x'] < 1024 and i['x'] + i['width'] > 0]
    return (state.get('ready') == 'complete' and state.get('fonts') == 'loaded'
            and (state.get('width'), state.get('height'), state.get('scale')) == (1024,768,1)
            and len(state.get('text','')) > 1000 and bool(visible)
            and all(i['complete'] and i['naturalWidth'] for i in visible))


def native_state(audit):
    selections = {s['name']: s for s in audit['selections']}
    bodies = selections.get('body', {}).get('elements', [])
    images = []
    for element in selections.get('images', {}).get('elements', []):
        image = element.get('image', {})
        model_ready = image.get('complete') and image.get('natural_width', 0) > 0
        images.append(dict(**element['rect'],
            complete=bool(model_ready or image.get('paint_decoded')),
            naturalWidth=image.get('natural_width', 0) if model_ready else image.get('paint_width', 0)))
    return dict(url=audit['url'], ready=audit['ready'], fonts=audit['fonts_status'],
        width=audit['viewport_width'], height=audit['viewport_height'], scale=1,
        text=bodies[0]['text'] if bodies else '', images=images)


def native_fonts_ready(audit):
    weights = {f['weight'] for f in audit.get('font_faces', [])
        if f['family'].strip(' \"\'').lower() == 'cnn_sans_display'
        and f['status'] == 'loaded' and f['parsed_font_present'] and f['source_path']}
    return {'auto', '500', '700'} <= weights


@contextmanager
def cnn_native_environment(network_deny):
    # Explicitly disable the native proxy as well as the standard proxy names.
    # Otherwise an inherited SOCKS route could bypass the offline connect guard.
    saved = os.environ.get('VOX_PROXY')
    try:
        os.environ['VOX_PROXY'] = ''
        with native_environment(network_deny):
            yield
    finally:
        if saved is None: os.environ.pop('VOX_PROXY', None)
        else: os.environ['VOX_PROXY'] = saved


def check_filter_report(report, cosmetics=False):
    counts = report['counts']
    if (counts['requests'] <= 0 or counts['mismatches'] or counts['oracle_disagreements']
            or not report['common_stream']['matches']):
        raise RuntimeError('Full-uBO request/header parity failed')
    if cosmetics:
        if report.get('navigation', {}).get('coverage') != 'page':
            raise RuntimeError('Full-uBO reference did not load the requested page')
        cosmetic = report.get('cosmetic') or {}
        if not all(cosmetic.get(k) for k in ['css_matches', 'procedural_matches', 'scriptlet_filters_match']):
            raise RuntimeError('Full-uBO document filter parity failed')


def audit_native_filters(args, prefix):
    output = Path(str(prefix)+'.ubo.json')
    command = ['node', str(REPO/'tools/adblock/brave_parity.mjs'), '--url', args.url,
        '--brave', str(args.brave), '--extension', str(args.extension),
        '--profile-template', str(args.profile),
        '--checker', str(args.checker), '--vox-log', str(prefix)+'.requests.jsonl',
        '--output', str(output)]
    with Path(str(prefix)+'.ubo.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=args.timeout)
    result = json.loads(output.read_text())
    check_filter_report(result)
    return dict(passed=True, report=str(output), sha256=digest(output), counts=result['counts'])


def profile_metadata(args):
    metadata = json.loads(args.profile.with_suffix('.json').read_text())
    if metadata['profile_sha256'] != fingerprint_tree(args.profile)['sha256']:
        raise RuntimeError('Prepared profile changed')
    if metadata['extension_sha256'] != fingerprint_tree(args.extension)['sha256']:
        raise RuntimeError('Prepared extension changed')
    if metadata['list_manifest_sha256'] != digest(REPO/'adblock/lists/manifest.json'):
        raise RuntimeError('Pinned filter lists changed')
    return metadata


def run_brave(args, prefix, api):
    metadata = profile_metadata(args)
    with fresh_copy(args.profile, prefix.parent, 'profile') as profile:
        config = SimpleNamespace(binary=args.brave, extension=args.extension)
        command = brave_command(config, profile, True)
        background = page = None
        with Path(str(prefix)+'.log').open('w') as log:
            launched = time.monotonic()
            process = subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
            counter = ProcessTreeCounter(api,process.pid)
            try:
                with CounterSampler(counter,.005):
                    deadline = time.monotonic()+args.timeout
                    background,page = connect_brave(profile,process,counter,deadline)
                    # Reconnect only the page socket to the provenance-preserving
                    # offline replay dispatcher. The browser/counters stay intact.
                    page.sock.close()
                    import urllib.request
                    port = int((profile/'DevToolsActivePort').read_text().splitlines()[0])
                    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
                    targets=json.load(opener.open(f'http://127.0.0.1:{port}/json/list'))
                    page=FrozenAssetsCDP(next(t['webSocketDebuggerUrl'] for t in targets if t['type']=='page'),args.cache)
                    settings=evaluate(background,"""(async()=>{const u=(await import('./js/background.js')).default;
                      return {selected:u.selectedFilterLists,autoUpdate:u.userSettings.autoUpdate,ready:u.readyToFilter};})()""")
                    if settings['selected'] != metadata['selected_lists'] or settings['autoUpdate'] or not settings['ready']:
                        raise RuntimeError('Full-uBO prepared settings did not survive restart')
                    evaluate(background,"(async()=> (await import('./js/logger.js')).default.readAll('vox-cnn'))()")
                    for method in ['Page.enable','Runtime.enable']:
                        page.call(method)
                    page.call('Emulation.setDeviceMetricsOverride',dict(width=1024,height=768,deviceScaleFactor=1,mobile=False))
                    page.call('Network.setBypassServiceWorker',{'bypass':True})
                    page.call('Page.navigate',{'url':args.url})
                    while True:
                        value=evaluate(page,STATE)
                        state=json.loads(value) if value else {}
                        if ready(state) and state.get('url') == args.url:break
                        if time.monotonic()>deadline:raise RuntimeError('CNN content gate failed: '+json.dumps(state))
                        time.sleep(.02)
                    image=page.call('Page.captureScreenshot',{'format':'png','captureBeyondViewport':False})
                    endpoint=time.monotonic()
                    report=counter.report(snapshot=counter.snapshot_before(endpoint))
                    report.update(engine='brave',endpoint='last complete sampler pass before first screenshot response',
                        process_launch_to_capture_ms=(endpoint-launched)*1000,document=state,ubo=settings,
                        command=command,content_gate_passed=True,profile_metadata=metadata)
                    Path(str(prefix)+'.png').write_bytes(base64.b64decode(image['data']))
                    report['screenshot']=str(prefix)+'.png'
                    # Audits are outside Brave's instruction endpoint.
                    report['replay_requests']=page.requests
                    raw=evaluate(background,"(async()=> (await import('./js/logger.js')).default.readAll('vox-cnn'))()")
                    report['ubo_network_log']=[json.loads(row) for row in raw]
                    Path(str(prefix)+'.rects.json').write_text(evaluate(page,RECTS))
                    report['version']=page.call('Browser.getVersion')
            finally:
                close_brave(process,background,page)
    return report


def run_vox(args,prefix,api):
    config=SimpleNamespace(binary=args.vox,url=args.url,width=1024,height=768,timeout=args.timeout,
        sample_interval=.005,vox_arg=['--enable-javascript'])
    audit=Path(str(prefix)+'.document.json')
    selectors=Path(str(prefix)+'.selectors.json')
    selectors.write_text(json.dumps({'selectors':[
        {'name':'all','selector':'*','limit':0},
        {'name':'body','selector':'body','limit':1},
        {'name':'headlines','selector':'h1,h2,h3,.container__headline-text,.container__text-label--text-content','limit':50},
        {'name':'images','selector':'img','limit':100,'attributes':['src','srcset']},
    ]}))
    keys=['VOX_ADBLOCK_LOG','VOX_CAPTURE_AUDIT_PATH','VOX_CAPTURE_AUDIT_CONFIG']
    saved={k:os.environ.get(k) for k in keys}
    try:
        os.environ.update(VOX_ADBLOCK_LOG=str(prefix)+'.requests.jsonl',
            VOX_CAPTURE_AUDIT_PATH=str(audit),VOX_CAPTURE_AUDIT_CONFIG=str(selectors))
        with cnn_native_environment(args.network_deny),fresh_copy(args.cache,prefix.parent,'cache') as cache:
            report=measure.run_vox(config,prefix,api,cache)
        report['document']=json.loads(audit.read_text())
        state = native_state(report['document'])
        report['content_gate_passed'] = ready(state) and state['url'] == args.url
        report['font_gate_passed'] = native_fonts_ready(report['document'])
    finally:
        for k,v in saved.items():
            if v is None:os.environ.pop(k,None)
            else:os.environ[k]=v
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--mode',choices=['brave','vox','compare'],required=True)
    p.add_argument('--cache',type=Path,required=True)
    p.add_argument('--profile',type=Path,required=True)
    p.add_argument('--extension',type=Path,required=True)
    p.add_argument('--url',default='https://edition.cnn.com/')
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--expected',type=Path)
    p.add_argument('--repeat',type=int,default=7)
    p.add_argument('--timeout',type=float,default=180)
    p.add_argument('--vox',type=Path,default=REPO/'Build/v/Vox.app/Contents/MacOS/Vox')
    p.add_argument('--brave',type=Path,default=Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'))
    p.add_argument('--network-deny',type=Path,default=REPO/'Build/pikabu-instructions-network-deny.dylib')
    p.add_argument('--checker',type=Path,default=REPO/'Build/adblock-check')
    p.add_argument('--adblock-reference',type=Path,
        help='Live full-uBO archive receipt with exact request, cosmetic, procedural and scriptlet agreement')
    args=p.parse_args()
    for key in ['cache','profile','extension','output','expected','vox','brave','network_deny','checker','adblock_reference']:
        if getattr(args,key) is not None:setattr(args,key,getattr(args,key).resolve())
    if args.repeat<1:p.error('Repeat must be positive')
    if args.mode=='compare' and args.expected is None:p.error('Comparison requires an immutable expected image')
    if args.mode=='compare' and (args.repeat != 7 or args.adblock_reference is None):
        p.error('Comparison requires seven pairs and a live full-uBO reference receipt')
    collector_environment = runtime_overrides()
    if args.mode=='compare' and collector_environment:
        p.error('Production comparison requires the default collector and loader environment')
    metadata = profile_metadata(args)
    if args.adblock_reference:
        reference = json.loads(args.adblock_reference.read_text())
        check_filter_report(reference, cosmetics=True)
        if reference['navigation']['url'] != args.url:
            raise RuntimeError('Full-uBO reference URL differs from the measured URL')
        lists = json.loads((REPO/'adblock/lists/manifest.json').read_text())['lists']
        if reference['lists'] != [{k:r[k] for k in ['name','sha256']} for r in lists]:
            raise RuntimeError('Full-uBO reference filter lists differ')
    args.output.mkdir(mode=0o700,parents=True,exist_ok=False)
    inputs=[args.vox,args.brave,args.network_deny,args.checker,Path(__file__),
        REPO/'adblock/lists/manifest.json',*sorted(args.vox.parent.glob('*.dylib')),
        *sorted((REPO/'adblock').glob('engine.*')),
        *sorted((REPO/'tools/adblock').glob('*.mjs')),
        *[REPO/'tools'/name for name in ['measure_browser_instructions.py','process_instruction_counts.py',
            'pikabu_browser_instructions.py','reddit_browser_instructions.py','probe_frozen_github_chrome.py']]]
    inputs += [f for f in [args.expected,args.adblock_reference,args.profile.with_suffix('.json')] if f]
    collector_path = linked_collector(args.vox) if args.mode == 'compare' else None
    if collector_path:
        inputs.append(collector_path)
    pinned={str(f):digest(f) for f in inputs}
    cache_hash=fingerprint_tree(args.cache)['sha256']
    api=MacCounters();pairs=[]
    for index in range(args.repeat if args.mode=='compare' else 1):
        pair={}
        engines=(['vox','brave'] if index%2==0 else ['brave','vox']) if args.mode=='compare' else [args.mode]
        for engine in engines:
            prefix=args.output/f'pair-{index+1}.{engine}'
            report=(run_vox if engine=='vox' else run_brave)(args,prefix,api)
            if report['unreadable_pids']:raise RuntimeError('Unreadable process counters')
            report['collector_environment']=runtime_overrides()
            if args.expected:
                verdict=compare(args.expected,Path(report['screenshot']),Path(str(prefix)+'.diff.png'),REPO/'Build/pixel-equality/pixel_diff')
                report['pixel_comparison']=verdict;report['pixels_exact']=verdict['exact']
            if args.mode=='compare' and engine=='vox':
                # Independent full-extension oracle audit after the counted
                # process has exited; never include it in either browser total.
                report['filter_gate']=audit_native_filters(args,prefix)
            Path(str(prefix)+'.json').write_text(json.dumps(report,indent=2)+'\n')
            pair[engine]=report
            print(json.dumps(dict(pair=index+1,engine=engine,instructions=report['instructions'],pixels_exact=report.get('pixels_exact'))),flush=True)
            if not report.get('content_gate_passed') or (engine=='vox' and not report.get('font_gate_passed')):
                raise RuntimeError('CNN content/font gate failed; retained counts are diagnostic')
            if args.mode=='compare' and not report['pixels_exact']:raise RuntimeError('Pixel mismatch; no instruction credit')
        pairs.append(pair)
    if pinned!={f:digest(f) for f in pinned} or cache_hash!=fingerprint_tree(args.cache)['sha256']:
        raise RuntimeError('Pinned binaries or cache changed')
    if collector_path and linked_collector(args.vox) != collector_path:
        raise RuntimeError('Collector library resolution changed during the cohort')
    if profile_metadata(args) != metadata:
        raise RuntimeError('Pinned extension/profile changed during the cohort')
    if args.mode=='compare':
        summary=evaluate_pairs(pairs)
        summary.update(pairs=pairs,pinned_sha256=pinned,cache_sha256=cache_hash,scope=__doc__,
            collector_environment=runtime_overrides())
        (args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        print(json.dumps({k:v for k,v in summary.items() if k not in ['pairs','pinned_sha256','scope']}),flush=True)
        return 0 if summary['passed'] else 1
    return 0

if __name__=='__main__':raise SystemExit(main())
