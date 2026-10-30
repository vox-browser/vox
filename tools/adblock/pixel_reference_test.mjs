import assert from 'node:assert/strict';
import {test} from 'node:test';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {capturePixelReference, referenceLaunchArguments, waitForPixelDocument} from './pixel_reference.mjs';

test('capture waits for document load before the settle period',async()=>{
    let expression;
    const page={evaluate:async source=>{expression=source;return false;}};
    assert.equal(await waitForPixelDocument(page),false);
    assert.match(expression,/document.readyState==='complete'/);
    assert.match(expression,/document.fonts.ready/);
});

test('archive certificate trust is scoped to its SPKI and requires a proxy',()=>{
    assert.throws(()=>referenceLaunchArguments({'replay-spki':'hash'}),/requires the archive proxy/);
    const args=referenceLaunchArguments({'replay-spki':'hash','proxy-server':'socks5://127.0.0.1:1234'});
    assert(args.includes('--ignore-certificate-errors-spki-list=hash'));
    assert(!args.includes('--ignore-certificate-errors'));
    assert(args.includes('--force-color-profile=srgb'));
});

test('failed navigation, incomplete pages and missing visible images cannot become references',async t=>{
    const directory=await fs.mkdtemp(path.join(os.tmpdir(),'vox-pixel-reference-failure-'));
    t.after(()=>fs.rm(directory,{recursive:true,force:true}));
    const file=path.join(directory,'brave.png');
    const state={url:'https://example.test/',title:'News',ready:'complete',fonts:'loaded',
        text:'story '.repeat(300),width:1024,height:768,scale:1,images:[]};
    const nav={coverage:'page',url:state.url};
    const page={evaluate:async()=>state,send:()=>{throw Error('Unexpected screenshot');}};
    await assert.rejects(capturePixelReference(page,file,{coverage:'challenge'}),/successful page coverage/);
    for (const change of [{ready:'loading'},{fonts:'loading'},{width:800},{scale:2},{text:'Access denied'},
        {url:'https://other.test/'},{images:[{url:'https://example.test/avatar.png',width:10,height:10,x:0,y:0,complete:true,naturalWidth:0}]}]) {
        await assert.rejects(capturePixelReference({...page,evaluate:async()=>({...state,...change})},file,nav),
            /not ready|missing visible images/);
        const diagnostic=JSON.parse(await fs.readFile(file+'.json','utf8'));
        assert.equal(diagnostic.stable,false);
        for (const [key,value] of Object.entries(change)) assert.deepEqual(diagnostic[key],value);
        await assert.rejects(fs.stat(file),{code:'ENOENT'});
    }
});

test('changing frames cannot leave a passing reference, while offscreen lazy images are permitted',async t=>{
    const directory=await fs.mkdtemp(path.join(os.tmpdir(),'vox-pixel-reference-'));
    t.after(()=>fs.rm(directory,{recursive:true,force:true}));
    const file=path.join(directory,'brave.png');
    const state={url:'https://example.test/',title:'News',ready:'complete',fonts:'loaded',
        text:'story '.repeat(300),width:1024,height:768,scale:1,
        images:[{width:10,height:10,x:0,y:1000,complete:false,naturalWidth:0}]};
    let count=0;
    const page={evaluate:async()=>state,send:async()=>({data:Buffer.from(String(count++)).toString('base64')})};
    await assert.rejects(capturePixelReference(page,file,{coverage:'page',url:state.url}),/changed between/);
    await assert.rejects(fs.stat(file),{code:'ENOENT'});
    assert.equal(JSON.parse(await fs.readFile(file+'.json','utf8')).stable,false);
    page.send=async()=>({data:Buffer.from('stable').toString('base64')});
    const result=await capturePixelReference(page,file,{coverage:'page',url:state.url});
    assert.equal(result.stable,true);
    assert.equal(await fs.readFile(file,'utf8'),'stable');
    assert.equal(JSON.parse(await fs.readFile(file+'.json','utf8')).title,'News');
    assert.equal(JSON.parse(await fs.readFile(file+'.json','utf8')).stable,true);
});
