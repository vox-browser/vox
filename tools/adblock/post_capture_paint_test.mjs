import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {capturePostReferencePaint,validatePostCapturePaint} from './post_capture_paint.mjs';

const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
async function fixture(t) {
    const root=await fs.mkdtemp(path.join(os.tmpdir(),'vox-post-paint-'));
    t.after(()=>fs.rm(root,{recursive:true,force:true}));
    const bytes=Buffer.from('completed reference PNG'),calls=[],events=[];
    const reference={stable:true,file:path.join(root,'reference.png'),sha256:digest(bytes),width:1024,height:768};
    await fs.writeFile(reference.file,bytes);
    const commands=[{method:'save'},{method:'clipRRect',params:{rrect:{left:719,top:186,right:754,bottom:202}}}];
    const page={events,send:async(method,params)=>{
        calls.push({method,params});
        if(method==='Page.getLayoutMetrics')return {cssLayoutViewport:{clientWidth:1024,clientHeight:768}};
        if(method==='Page.captureScreenshot') {
            events.push({method:'LayerTree.layerTreeDidChange',params:{layers:[
                {layerId:'empty',drawsContent:true,width:0,height:0},
                {layerId:'document',drawsContent:true,width:1024,height:1300},
                {layerId:'transform',drawsContent:false,width:1024,height:768}]}});
            return {data:bytes.toString('base64')};
        }
        if(method==='LayerTree.makeSnapshot')return {snapshotId:'picture'};
        if(method==='LayerTree.snapshotCommandLog')return {commandLog:commands};
        return {};
    }};
    return {root,bytes,reference,page,calls,commands,directory:path.join(root,'paint')};
}

test('paint diagnostics require a saved reference and cannot export a modified prepared profile',()=>{
    validatePostCapturePaint({});
    validatePostCapturePaint({'post-capture-paint-dir':'paint','pixel-reference':'a.png'});
    validatePostCapturePaint({'post-capture-paint-dir':'paint','capture-dir':'source'});
    for(const change of [{},{requests:'requests.json','pixel-reference':'a.png'},
        {'vox-log':'requests.jsonl','pixel-reference':'a.png'},
        {'pixel-reference':'a.png','profile-output':'profile'}])
        assert.throws(()=>validatePostCapturePaint({'post-capture-paint-dir':'paint',...change}));
});

test('paint logs follow the completed reference and release only captured content snapshots',async t=>{
    const f=await fixture(t),result=await capturePostReferencePaint(f.page,f.directory,f.reference);
    assert.equal(result.success,true);
    assert.equal(result.post_png_matches_reference,true);
    assert.equal(result.reference_unchanged,true);
    assert.equal(result.painted_layers,1);
    const records=JSON.parse(await fs.readFile(path.join(f.directory,'paint-records.json')));
    assert.deepEqual(records[0].commands,f.commands);
    assert.equal(records[0].commands_sha256,digest(JSON.stringify(f.commands)));
    assert.deepEqual(f.calls.filter(c=>c.method==='LayerTree.makeSnapshot').map(c=>c.params),[{layerId:'document'}]);
    assert.deepEqual(f.calls.filter(c=>c.method==='LayerTree.releaseSnapshot').map(c=>c.params),[{snapshotId:'picture'}]);
    assert.equal(f.calls.at(-1).method,'LayerTree.disable');
    assert.match(result.scope,/never a replacement/);
    assert.deepEqual(await fs.readFile(f.reference.file),f.bytes);
});

test('a failed command log releases its snapshot and retains the failure',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.send=(method,params)=>method==='LayerTree.snapshotCommandLog'
        ? Promise.reject(Error('Picture expired')):send(method,params);
    const result=await capturePostReferencePaint(f.page,f.directory,f.reference);
    assert.equal(result.success,false);
    assert.equal(result.complete,false);
    assert.deepEqual(result.errors,['Picture expired']);
    assert.equal(f.calls.filter(c=>c.method==='LayerTree.releaseSnapshot').length,1);
    assert.deepEqual(await fs.readFile(f.reference.file),f.bytes);
});

test('stale layer notifications do not qualify a new checkpoint',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.events.push({method:'LayerTree.layerTreeDidChange',params:{layers:[{layerId:'old',drawsContent:true,width:100,height:100}]}});
    f.page.send=async(method,params)=>method==='Page.captureScreenshot'?{data:f.bytes.toString('base64')}:send(method,params);
    const result=await capturePostReferencePaint(f.page,f.directory,f.reference);
    assert.equal(result.success,false);
    assert.match(result.errors.join(' '),/No painted content layers/);
    assert.equal(f.calls.some(c=>c.method==='LayerTree.makeSnapshot'),false);
});

test('instrumented pixels remain separate even when they change',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.send=async(method,params)=>{
        const result=await send(method,params);
        return method==='Page.captureScreenshot'?{data:Buffer.from('changed diagnostic').toString('base64')}:result;
    };
    const result=await capturePostReferencePaint(f.page,f.directory,f.reference);
    assert.equal(result.success,true);
    assert.equal(result.post_png_matches_reference,false);
    assert.deepEqual(await fs.readFile(f.reference.file),f.bytes);
});

test('unsupported layer diagnostics cannot disable another client domain or alter a reference',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.send=(method,params)=>method==='LayerTree.enable'?Promise.reject(Error('Unsupported')):send(method,params);
    const result=await capturePostReferencePaint(f.page,f.directory,f.reference);
    assert.equal(result.success,false);
    assert.deepEqual(result.errors,['Unsupported']);
    assert.equal(f.calls.some(c=>c.method==='LayerTree.disable'),false);
});

test('changed viewport or reference invalidates an otherwise complete diagnostic',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.send=async(method,params)=>{
        const result=await send(method,params);
        if(method==='LayerTree.snapshotCommandLog')await fs.writeFile(f.reference.file,'changed outside diagnostics');
        return method==='Page.getLayoutMetrics'?{cssLayoutViewport:{clientWidth:756,clientHeight:556}}:result;
    };
    const result=await capturePostReferencePaint(f.page,f.directory,f.reference);
    assert.equal(result.success,false);
    assert.equal(result.reference_unchanged,false);
    assert.match(result.errors.join(' '),/viewport differs/);
    assert.match(result.errors.join(' '),/Reference changed during/);
});

test('snapshot release failures are preserved rather than silently qualifying paint logs',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.send=(method,params)=>method==='LayerTree.releaseSnapshot'?Promise.reject(Error('Release failed')):send(method,params);
    const result=await capturePostReferencePaint(f.page,f.directory,f.reference);
    assert.equal(result.complete,true);
    assert.equal(result.success,false);
    assert.deepEqual(result.errors,['Release failed']);
});

test('an uncertified reference or an existing diagnostic directory is never overwritten',async t=>{
    const f=await fixture(t);
    await assert.rejects(()=>capturePostReferencePaint(f.page,f.directory,{...f.reference,stable:false}),/completed stable/);
    await fs.mkdir(f.directory);
    await fs.writeFile(path.join(f.directory,'sentinel'),'retain prior evidence');
    await assert.rejects(()=>capturePostReferencePaint(f.page,f.directory,f.reference),/EEXIST/);
    assert.equal(await fs.readFile(path.join(f.directory,'sentinel'),'utf8'),'retain prior evidence');
    assert.equal(f.calls.length,0);
    assert.deepEqual(await fs.readFile(f.reference.file),f.bytes);
});

test('a failed frame checkpoint disables diagnostics before attempting a layer snapshot',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.send=(method,params)=>method==='Runtime.evaluate'?Promise.resolve({exceptionDetails:{text:'Frame failed'}}):send(method,params);
    const result=await capturePostReferencePaint(f.page,f.directory,f.reference);
    assert.equal(result.success,false);
    assert.match(result.errors.join(' '),/frame checkpoint failed/);
    assert.equal(f.calls.some(c=>c.method==='LayerTree.makeSnapshot'),false);
    assert.equal(f.calls.at(-1).method,'LayerTree.disable');
});

test('missing command data cannot qualify an otherwise valid layer snapshot',async t=>{
    const f=await fixture(t),send=f.page.send;
    f.page.send=(method,params)=>method==='LayerTree.snapshotCommandLog'?Promise.resolve({}):send(method,params);
    const result=await capturePostReferencePaint(f.page,f.directory,f.reference);
    assert.equal(result.success,false);
    assert.match(result.errors.join(' '),/no command log/);
    assert.equal(f.calls.filter(c=>c.method==='LayerTree.releaseSnapshot').length,1);
});
