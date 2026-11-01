#!/usr/bin/env python3
"""Measure Chromium-reported damaging scroll presentations through CDP.

Run under run_memory_bounded.py. Requires no injection or macOS capture/input
permission. Input enters Chromium's widget through CDP, bypassing Cocoa. Frame
feedback tracing is enabled: this is a separately labeled measurement endpoint,
not physical scanout or an uninstrumented optimization acceptance result.
"""
import argparse
import base64
import gzip
import hashlib
import io
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time

from PIL import Image
from capture_brave_reference import BRAVE, launch_command, resize_native_viewport
from hacker_news_browser_instructions import test_display
from measure_browser_instructions import CDP, chrome_debugger_endpoint
from measure_precise_scroll import distribution

REPO = Path(__file__).resolve().parents[1]
CATEGORIES = '-*,input.scrolling,disabled-by-default-devtools.timeline.frame,blink.user_timing'
MARK = 'vox_brave_scroll_target'
ENDPOINT = 'Chromium presentation feedback for damaging scroll frames; CDP wheel input; frame-event tracing enabled; not physical scanout'


def summarize(trace, expected_inputs, marker=MARK):
    events = trace['traceEvents']
    marks = [e for e in events if e.get('name') == marker]
    if len(marks) != 1:
        raise ValueError('Missing or ambiguous target renderer marker')
    pid = marks[0]['pid']
    inputs = [e for e in events if e.get('pid') == pid and e.get('name') == 'EventLatency'
              and e.get('ph') == 'b' and e.get('args', {}).get('event_latency', {}).get('event_type')
              in {'FIRST_GESTURE_SCROLL_UPDATE', 'GESTURE_SCROLL_UPDATE'}]
    inputs.sort(key=lambda e: e['ts'])
    ids = [e['args']['event_latency']['event_latency_id'] for e in inputs]
    if len(inputs) != expected_inputs or len(set(ids)) != expected_inputs:
        raise ValueError('Missing or duplicated browser-received scroll inputs')
    times = [e['ts'] for e in inputs]
    if any(not math.isfinite(t) for t in times) or any(b <= a for a, b in zip(times, times[1:])):
        raise ValueError('Invalid input timestamps')
    starts, presented, opened, complete = {}, {}, {}, []
    for e in events:
        if e.get('pid') != pid:
            continue
        name, phase, args = e.get('name'), e.get('ph'), e.get('args', {})
        if name == 'ScrollJankV4' and phase == 'b':
            data = args['scroll_jank_v4']
            if data.get('damage_type') != 'DAMAGING':
                continue
            real = data.get('updates', {}).get('real', {})
            if not real.get('total_raw_delta_pixels'):
                continue
            key = data['result_id']
            if key in starts:
                raise ValueError('Duplicate damaging frame ID')
            starts[key] = data
        elif name == 'Presentation':
            key = args['scroll_jank_v4']['result_id']
            if key in presented:
                raise ValueError('Duplicate presentation feedback')
            presented[key] = e['ts']
        elif name == 'PipelineReporter':
            key = json.dumps(e.get('id2', e.get('id')), sort_keys=True)
            if phase == 'b':
                if key in opened:
                    raise ValueError('Overlapping compositor reporter IDs')
                opened[key] = args['frame_reporter']
            elif phase == 'e':
                if key not in opened:
                    # Tracing can start during an existing pipeline.
                    continue
                data = opened.pop(key)
                if data['state'] == 'STATE_PRESENTED_ALL' and not data.get('has_missing_content'):
                    complete.append(e['ts'])
    if not starts or set(starts) - set(presented):
        raise ValueError('Missing damaging-frame presentation feedback')
    input_ids = set(ids)
    input_times = dict(zip(ids, times))
    if any(s['updates']['real']['first_event_latency_id'] not in input_ids for s in starts.values()):
        raise ValueError('Presentation belongs to an unmeasured input')
    if ids[-1] not in {s['updates']['real']['first_event_latency_id'] for s in starts.values()}:
        raise ValueError('Last input has no confirmed scroll presentation')
    if any(presented[key] < input_times[data['updates']['real']['first_event_latency_id']]
           for key, data in starts.items()):
        raise ValueError('Presentation precedes its input')
    frames = sorted(presented[key] for key in starts)
    if len(set(frames)) != len(frames) or any(not math.isfinite(t) for t in frames):
        raise ValueError('Invalid presentation timestamps')
    if any(t not in set(complete) for t in frames):
        raise ValueError('Scroll feedback lacks a complete compositor presentation')
    chosen = [t for t in frames if times[0] <= t <= times[-1]]
    if len(chosen) < 3:
        raise ValueError('Insufficient scroll presentations within input window')
    gaps = [b-a for a, b in zip(chosen, chosen[1:])]
    input_gaps = [b-a for a, b in zip(times, times[1:])]
    window = times[-1]-times[0]
    # Match Vox's conservative convention: first publication is the reference.
    moving = len(chosen)-1
    return dict(endpoint=ENDPOINT, renderer_pid=pid, completed_inputs=len(inputs),
                completed_presentations=len(frames), measured_presentations=len(chosen),
                moving_intervals=moving, measurement_window_us=window,
                mean_scroll_fps=moving*1e6/window, input_delivery_hz=(len(inputs)-1)*1e6/window,
                scroll_interval_us=distribution(gaps), input_interval_us=distribution(input_gaps),
                first_publication_delay_us=chosen[0]-times[0],
                first_counted_scroll_delay_us=chosen[1]-times[0],
                last_scroll_publication_gap_us=times[-1]-chosen[-1],
                frame_budget_us=1e6/60, intervals_over_budget=sum(g>1e6/60 for g in gaps),
                fraction_over_budget=sum(g>1e6/60 for g in gaps)/len(gaps),
                browser_input_timestamps_us=times, presentation_timestamps_us=frames)


class Client(CDP):
    def __init__(self, url):
        self.events = []
        super().__init__(url)

    def receive(self):
        value = super().receive()
        if 'method' in value:
            self.events.append(value)
        return value

    def event(self, method):
        while not any(e['method'] == method for e in self.events):
            self.receive()
        return next(e['params'] for e in self.events if e['method'] == method)


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as file:
        for chunk in iter(lambda: file.read(1024*1024), b''):
            h.update(chunk)
    return h.hexdigest()


def pixels(data):
    with Image.open(io.BytesIO(data)) as image:
        rgba = image.convert('RGBA')
        return rgba.size, hashlib.sha256(rgba.tobytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--binary', type=Path, default=Path(BRAVE))
    p.add_argument('--url', required=True)
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--require-title', required=True)
    p.add_argument('--width', type=int, default=1024)
    p.add_argument('--height', type=int, default=768)
    p.add_argument('--inputs', type=int, default=600)
    p.add_argument('--input-hz', type=float, default=60)
    p.add_argument('--delta', type=float, default=4.2, help='CSS-pixel wheel delta (Vox native delta 2 moves 4.2 CSS px)')
    p.add_argument('--reverse-every', type=int, default=60)
    p.add_argument('--settle-seconds', type=float, default=20)
    p.add_argument('--script-policy', choices=['enabled','disabled'], default='enabled')
    p.add_argument('--proxy-server', default='socks5://127.0.0.1:9', help='Default denies non-loopback access; loopback bypass stays enabled')
    p.add_argument('--certificate-spki')
    p.add_argument('--reference', type=Path)
    p.add_argument('--network-policy', required=True)
    args = p.parse_args()
    if not (10 <= args.inputs <= 100000 and args.reverse_every > 0 and args.width > 0 and args.height > 0
            and all(math.isfinite(v) and v > 0 for v in [args.input_hz,args.delta])
            and math.isfinite(args.settle_seconds) and args.settle_seconds >= 0):
        p.error('Invalid input schedule or geometry')
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=False, mode=0o700)
    binary = args.binary.resolve()
    app = binary.parent.parent
    files = {binary, Path(__file__).resolve(), REPO/'tools/capture_brave_reference.py',
             REPO/'tools/measure_browser_instructions.py', REPO/'tools/measure_precise_scroll.py'}
    files.update(f.resolve() for f in app.rglob('*') if f.is_file() and (
        f.name == 'Brave Browser Framework' or f.parent.name == 'MacOS' or f.suffix in {'.dylib','.pak','.dat','.bin'}))
    pins = {str(f):sha(f) for f in sorted(files)}
    profile = out/'profile'; position = test_display()
    command = launch_command(str(binary), profile, args.proxy_server, windowed=True)
    if args.certificate_spki:
        command.append('--ignore-certificate-errors-spki-list='+args.certificate_spki)
    env = {k:v for k,v in os.environ.items() if 'proxy' not in k.lower() and not k.startswith(('VOX_','LADYBIRD_','DYLD_','GC_','JSC_'))}
    env.update(NO_PROXY='*')
    receipt = dict(command=command, started_unix=time.time(), host=dict(cpu_count=os.cpu_count(),
                   load_average_before=list(os.getloadavg())), pinned_sha256=pins,
                   url=args.url, placement=position, viewport=[args.width,args.height],scale=2,
                   script_policy=args.script_policy, network_policy=args.network_policy,
                   schedule=dict(inputs=args.inputs,hz=args.input_hz,delta_css_px=args.delta,
                                 reverse_every=args.reverse_every,settle_seconds=args.settle_seconds),
                   trace_categories=CATEGORIES, input_route='CDP widget injection; Cocoa bypassed',
                   endpoint=ENDPOINT, optimization_acceptance=False)
    child = browser = page = None
    def evaluate(expression):
        result = page.call('Runtime.evaluate',dict(expression=expression,returnByValue=True))
        if 'exceptionDetails' in result:
            raise RuntimeError(result['exceptionDetails'])
        return result['result'].get('value')
    audit_expression = '''({url:location.href,title:document.title,ready:document.readyState,
      width:innerWidth,height:innerHeight,scale:devicePixelRatio,y:scrollY,
      documentHeight:document.documentElement.scrollHeight,fonts:document.fonts.status,
      bodyText:document.body.innerText,postIds:[...document.querySelectorAll('#siteTable > .thing.link')].map(e=>e.getAttribute('data-fullname')),
      storyIds:[...document.querySelectorAll('tr.athing')].map(e=>e.id)})'''
    try:
        with (out/'browser.log').open('w') as log:
            child = subprocess.Popen(command, env=env, cwd=REPO, stdout=log, stderr=log)
        receipt['browser_pid'] = child.pid
        deadline = time.monotonic()+30
        while (ep := chrome_debugger_endpoint(profile/'DevToolsActivePort')) is None:
            if child.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('Brave debugger unavailable')
            time.sleep(.05)
        browser = Client(f'ws://127.0.0.1:{ep[0]}'+ep[1])
        receipt['version'] = browser.call('Browser.getVersion')
        target = browser.call('Target.createTarget',dict(url='about:blank',newWindow=True,background=True,
                    left=position['position'][0],top=position['position'][1],width=args.width+80,height=args.height+140))['targetId']
        page = Client(f'ws://127.0.0.1:{ep[0]}/devtools/page/{target}')
        page.call('Page.enable'); page.call('Network.enable')
        resize_native_viewport(browser,page,target,args.width,args.height,2)
        if args.script_policy == 'disabled':
            page.call('Emulation.setScriptExecutionDisabled',{'value':True})
        navigation = page.call('Page.navigate',{'url':args.url})
        if navigation.get('errorText'):
            raise RuntimeError(navigation)
        deadline = time.monotonic()+60
        ready_at = None
        while True:
            identity = evaluate('({title:document.title,ready:document.readyState,fonts:document.fonts.status})')
            ready = args.require_title in identity.get('title','') and identity['ready']=='complete' and identity['fonts']=='loaded'
            if not ready: ready_at = None
            elif ready_at is None: ready_at = time.monotonic()
            if ready_at is not None and time.monotonic()-ready_at >= args.settle_seconds: break
            if time.monotonic()>deadline: raise RuntimeError('Document readiness/settling timeout')
            time.sleep(.1)
        audit = evaluate(audit_expression)
        audit['body_text_sha256'] = hashlib.sha256(audit.pop('bodyText').encode()).hexdigest()
        if audit['y'] != 0 or [audit['width'],audit['height'],audit['scale']] != [args.width,args.height,2] or audit['documentHeight'] <= args.height:
            raise RuntimeError('Invalid initial document/viewport/scroll range')
        receipt['document_before'] = audit
        screenshot = base64.b64decode(page.call('Page.captureScreenshot',dict(format='png',fromSurface=True,captureBeyondViewport=False))['data'])
        (out/'initial.png').write_bytes(screenshot); size, pixel_hash = pixels(screenshot)
        if size != (args.width*2,args.height*2): raise RuntimeError('Wrong capture size')
        receipt['initial_pixels_sha256'] = pixel_hash
        if args.reference:
            if pixels(args.reference.read_bytes()) != (size,pixel_hash): raise RuntimeError('Initial pixels changed from fixed reference')
            receipt['reference'] = str(args.reference.resolve())
        # Screenshot/audits finish before the measurement. No CPU sampling,
        # screenshots, paint settings or animation overrides in the input window.
        browser.call('Tracing.start',dict(categories=CATEGORIES,transferMode='ReturnAsStream'))
        evaluate('performance.mark('+json.dumps(MARK)+')')
        started = time.monotonic(); sent=[]; checkpoints=[]
        for i in range(args.inputs):
            wait = started+i/args.input_hz-time.monotonic()
            if wait>0: time.sleep(wait)
            before = time.monotonic()
            page.call('Input.dispatchMouseEvent',dict(type='mouseWheel',x=args.width/2,y=args.height/2,
                       deltaX=0,deltaY=args.delta if (i//args.reverse_every)%2==0 else -args.delta,modifiers=0))
            sent.append(dict(index=i,sent_monotonic=before,ack_monotonic=time.monotonic()))
            if (i+1)%args.reverse_every == 0:
                checkpoints.append(dict(inputs=i+1,state=evaluate('({title:document.title,y:scrollY,x:scrollX})')))
        time.sleep(1)
        browser.call('Tracing.end'); completion=browser.event('Tracing.tracingComplete'); receipt['trace_completion']=completion
        if completion.get('dataLossOccurred'): raise RuntimeError('Trace buffer lost events')
        stream=completion['stream']; chunks=[]
        while True:
            part=browser.call('IO.read',{'handle':stream})
            chunks.append(base64.b64decode(part['data']) if part.get('base64Encoded') else part['data'].encode())
            if part.get('eof'): break
        browser.call('IO.close',{'handle':stream})
        data=b''.join(chunks); (out/'trace.json.gz').write_bytes(gzip.compress(data,mtime=0)); trace=json.loads(data)
        receipt.update(input_commands=sent,checkpoints=checkpoints)
        if max(c['state']['y'] for c in checkpoints)-min(c['state']['y'] for c in checkpoints)<1 or any(
                args.require_title not in c['state']['title'] or c['state']['x'] != 0 for c in checkpoints):
            raise RuntimeError('Document did not scroll or identity changed')
        summary=summarize(trace,args.inputs)
        (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        audit = evaluate(audit_expression);audit['body_text_sha256']=hashlib.sha256(audit.pop('bodyText').encode()).hexdigest()
        receipt['document_after'] = audit
        if any(receipt['document_before'][k] != audit[k] for k in ['url','title','body_text_sha256','postIds','storyIds','width','height','scale']):
            raise RuntimeError('Document content/geometry changed during scrolling')
        receipt['network_events'] = [e for e in page.events if e['method'] in ['Network.loadingFailed','Network.responseReceived']]
        browser.call('Browser.close');receipt['browser_exit_code']=child.wait(timeout=15)
        if receipt['browser_exit_code'] != 0: raise RuntimeError('Abnormal browser exit')
        if pins != {str(f):sha(f) for f in sorted(files)}: raise RuntimeError('Browser/tool identities changed')
        receipt['valid']=True
        print(json.dumps({k:v for k,v in summary.items() if not k.endswith('timestamps_us')},indent=2))
    except BaseException as error:
        receipt.update(valid=False,error=str(error));raise
    finally:
        if child and child.poll() is None:
            try:
                if browser:browser.call('Browser.close')
                receipt['browser_exit_code']=child.wait(timeout=5)
            except Exception:
                child.kill();receipt['browser_exit_code']=child.wait()
        for connection in [page,browser]:
            if connection:connection.sock.close()
        receipt.update(finished_unix=time.time());receipt['host']['load_average_after']=list(os.getloadavg())
        (out/'run.json').write_text(json.dumps(receipt,indent=2)+'\n')


if __name__=='__main__':
    main()
