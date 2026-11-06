import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {capturePostReferenceTrace,validatePostCaptureTrace} from './post_capture_trace.mjs';

const digest = bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
async function fixture(t) {
    const root=await fs.mkdtemp(path.join(os.tmpdir(),'vox-post-trace-'));
    t.after(()=>fs.rm(root,{recursive:true,force:true}));
    const bytes=Buffer.from('completed reference PNG');
    const reference={stable:true,file:path.join(root,'reference.png'),sha256:digest(bytes),width:1024,height:768};
    await fs.writeFile(reference.file,bytes);
    const events=[{method:'Tracing.tracingComplete'}],calls=[];
    const page={events,send:async(method,params)=>{
        calls.push({method,params});
        if(method==='Page.getLayoutMetrics')return {cssLayoutViewport:{clientWidth:1024,clientHeight:768}};
        if(method==='Page.captureScreenshot')return {data:bytes.toString('base64')};
        if(method==='Tracing.end')events.push({method:'Tracing.dataCollected',params:{value:[
            {name:'LayerTreeHostImpl:snapshot',args:{snapshot:{device_viewport_size:{width:756,height:556},active_tree:{layers:[]}}}},
            {name:'LayerTreeHostImpl:snapshot',args:{snapshot:{device_viewport_size:{width:1024,height:768},active_tree:{layers:[{layer_name:'document'}]}}}},
        ]}},{method:'Tracing.tracingComplete'});
        return {};
    }};
    return {root,bytes,reference,page,calls,directory:path.join(root,'trace')};
}

test('post-capture tracing needs a page reference and cannot export a mutated prepared profile',()=>{
    validatePostCaptureTrace({});
    validatePostCaptureTrace({'post-capture-trace-dir':'trace','pixel-reference':'reference.png'});
    validatePostCaptureTrace({'post-capture-trace-dir':'trace','capture-dir':'source'});
    for(const change of [{},{'vox-log':'requests.jsonl','pixel-reference':'a.png'},
        {requests:'requests.json','capture-dir':'source'},
        {'pixel-reference':'a.png','profile-output':'profile'}])
        assert.throws(()=>validatePostCaptureTrace({'post-capture-trace-dir':'trace',...change}));
});

test('post-capture trace preserves the reference and selects document rather than browser UI snapshots',async t=>{
    const f=await fixture(t);
    const result=await capturePostReferenceTrace(f.page,f.directory,f.reference);
    assert.equal(result.success,true);
    assert.equal(result.reference_unchanged,true);
    assert.equal(result.post_png_matches_reference,true);
    assert.equal(result.reference_viewport_layer_snapshots,1);
    assert.match(result.scope,/never a replacement pixel reference/);
    assert.deepEqual(await fs.readFile(f.reference.file),f.bytes);
    assert.deepEqual(f.calls.map(c=>c.method),['Page.getLayoutMetrics','Tracing.start',
        'Page.captureScreenshot','Page.getLayoutMetrics','Tracing.end']);
    assert.deepEqual(f.calls[1].params.traceConfig.includedCategories,
        ['disabled-by-default-cc.debug','disabled-by-default-devtools.timeline.layers','disabled-by-default-cc.debug.picture']);
    assert.equal(JSON.parse(await fs.readFile(path.join(f.directory,'trace.json'))).length,2);
});

test('changed instrumented pixels remain separate from the saved reference',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.send=async(method,params)=>method==='Page.captureScreenshot'
        ? {data:Buffer.from('instrumented diagnostic PNG').toString('base64')}:send(method,params);
    const result=await capturePostReferenceTrace(f.page,f.directory,f.reference);
    assert.equal(result.success,true);
    assert.equal(result.post_png_matches_reference,false);
    assert.deepEqual(await fs.readFile(f.reference.file),f.bytes);
    assert.notEqual(result.post_png_sha256,result.reference.sha256);
});

test('a screenshot failure still stops tracing and retains its partial data',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.send=async(method,params)=>{
        if(method==='Page.captureScreenshot')throw Error('Diagnostic screenshot failed');
        return send(method,params);
    };
    const result=await capturePostReferenceTrace(f.page,f.directory,f.reference);
    assert.equal(result.success,false);
    assert.equal(result.complete,true);
    assert.deepEqual(result.errors,['Diagnostic screenshot failed']);
    assert.equal(result.reference_viewport_layer_snapshots,1);
    assert.equal(f.calls.at(-1).method,'Tracing.end');
});

test('unsupported tracing preserves its failure without stopping an unrelated trace',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.send=async(method,params)=>{
        if(method==='Tracing.start')throw Error('Tracing already started');
        return send(method,params);
    };
    const result=await capturePostReferenceTrace(f.page,f.directory,f.reference);
    assert.equal(result.success,false);
    assert.equal(result.complete,false);
    assert.deepEqual(result.errors,['Tracing already started']);
    assert.equal(f.calls.some(c=>c.method==='Tracing.end'),false);
    assert.deepEqual(await fs.readFile(f.reference.file),f.bytes);
});

test('stale completion notifications cannot qualify a trace that never completes',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.send=(method,params)=>method==='Tracing.end'?Promise.resolve({}):send(method,params);
    const result=await capturePostReferenceTrace(f.page,f.directory,f.reference,{timeoutMs:0});
    assert.equal(result.success,false);
    assert.equal(result.complete,false);
    assert.match(result.errors.join(' '),/did not complete/);
});

test('missing layer data cannot masquerade as a successful compositor diagnostic',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.send=async(method,params)=>{
        const result=await send(method,params);
        if(method==='Tracing.end')f.page.events.splice(1,1);
        return result;
    };
    const result=await capturePostReferenceTrace(f.page,f.directory,f.reference);
    assert.equal(result.success,false);
    assert.match(result.errors.join(' '),/No layer snapshots/);
});

test('a detached viewport override is reported even if a matching layer appears in the trace',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.send=(method,params)=>method==='Page.getLayoutMetrics'
        ? Promise.resolve({cssLayoutViewport:{clientWidth:756,clientHeight:556}}):send(method,params);
    const result=await capturePostReferenceTrace(f.page,f.directory,f.reference);
    assert.equal(result.success,false);
    assert.equal(result.reference_viewport_layer_snapshots,1);
    assert.match(result.errors.join(' '),/viewport differs/);
});

test('replacement or removal of the reference is recorded as a failed diagnostic',async t=>{
    for(const remove of [false,true]) {
        const f=await fixture(t),send=f.page.send;
        f.page.send=async(method,params)=>{
            if(method==='Page.captureScreenshot') {
                if(remove)await fs.unlink(f.reference.file);
                else await fs.writeFile(f.reference.file,'changed elsewhere');
            }
            return send(method,params);
        };
        const result=await capturePostReferenceTrace(f.page,f.directory,f.reference);
        assert.equal(result.success,false);
        assert.equal(result.reference_unchanged,false);
        assert.match(result.errors.join(' '),/Reference changed/);
        assert.equal(JSON.parse(await fs.readFile(path.join(f.directory,'summary.json'))).success,false);
    }
});

test('uncertified references and existing diagnostics are never overwritten',async t=>{
    const f=await fixture(t);
    await assert.rejects(()=>capturePostReferenceTrace(f.page,f.directory,{...f.reference,stable:false}),/stable reference/);
    await fs.mkdir(f.directory);await fs.writeFile(path.join(f.directory,'summary.json'),'retained');
    await assert.rejects(()=>capturePostReferenceTrace(f.page,f.directory,f.reference),{code:'EEXIST'});
    assert.equal(await fs.readFile(path.join(f.directory,'summary.json'),'utf8'),'retained');
    assert.equal(f.calls.length,0);
});
