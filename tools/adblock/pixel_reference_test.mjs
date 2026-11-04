import assert from 'node:assert/strict';
import {test} from 'node:test';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import {capturePixelReference, pixelReferenceState, referenceLaunchArguments, waitForPixelDocument} from './pixel_reference.mjs';

test('visible image decoding completes before paint, without decoding hidden or offscreen lazy images',async()=>{
    const calls=[];let finish;
    const image={src:'https://example.test/photo.webp',complete:true,naturalWidth:100,
        getBoundingClientRect:()=>({x:10,y:10,width:100,height:100}),
        decode:()=>{calls.push('decode');return new Promise(resolve=>{finish=resolve;});}};
    const lazy={...image,complete:false,naturalWidth:0,
        getBoundingClientRect:()=>({x:10,y:1000,width:100,height:100}),
        decode:()=>{throw Error('Lazy image must remain deferred');}};
    const hidden={...image,decode:()=>{throw Error('Hidden image must remain deferred');}};
    const document={fonts:{ready:Promise.resolve(),status:'loaded'},images:[image,lazy,hidden],
        readyState:'complete',title:'News',body:{innerText:'story '.repeat(300)},activeElement:null,
        querySelectorAll:()=>[]};
    const context={document,location:{href:'https://example.test/'},innerWidth:1024,innerHeight:768,
        devicePixelRatio:1,getComputedStyle:e=>({display:'block',visibility:e===hidden?'hidden':'visible'}),
        requestAnimationFrame:callback=>{calls.push('paint');callback();}};
    let settled=false;
    const pending=vm.runInNewContext('('+pixelReferenceState.toString()+')()',context)
        .then(state=>{settled=true;return state;});
    await new Promise(resolve=>setImmediate(resolve));
    assert.equal(settled,false);
    assert.deepEqual(calls,['decode']);
    finish();const state=await pending;
    assert.deepEqual(calls,['decode','paint','paint']);
    assert.equal(state.image_decode_preparation,'visible-image-decode');
    assert.deepEqual(Array.from(state.decoded_images),[image.src]);
    assert.equal(state.image_decode_errors.length,0);
    image.decode=async()=>{throw Error('Invalid encoded bitmap');};
    const failed=await vm.runInNewContext('('+pixelReferenceState.toString()+')()',context);
    assert.equal(failed.image_decode_errors[0].url,image.src);
    assert.equal(failed.image_decode_errors[0].error,'Invalid encoded bitmap');
});

test('capture waits for document load before the settle period',async()=>{
    let expression;
    const page={evaluate:async source=>{expression=source;return false;}};
    assert.equal(await waitForPixelDocument(page,'https://example.com/',{timeoutMs:0}),false);
    assert.match(expression,/document.readyState==='complete'/);
    assert.match(expression,/document.fonts.status==='loaded'/);
    assert.match(expression,/https:\/\/example.com\//);
});

test('the old blank document, streaming HTML and pending fonts cannot start settling',async()=>{
    const states=[['about:blank','complete','loaded',2000],['https://example.com/','loading','loaded',2000],
        ['https://example.com/','complete','loading',2000],['https://example.com/','complete','loaded',0],
        ['https://news.example.com/','complete','loaded',2000]];
    let checks=0;
    const page={evaluate:async expression=>{
        const [href,readyState,status,length]=states[checks++];
        return vm.runInNewContext(expression,{URL,location:{href},
            document:{readyState,fonts:{status},body:{innerText:'x'.repeat(length)}}});
    }};
    assert.equal(await waitForPixelDocument(page,'https://example.com/',{timeoutMs:1000,pollMs:0}),true);
    assert.equal(checks,5);
});

test('a replaced execution context is retried while unrelated debugger errors propagate',async()=>{
    let checks=0;
    const page={evaluate:async()=>{
        if(!checks++) throw Error('Execution context was destroyed.');
        return true;
    }};
    assert.equal(await waitForPixelDocument(page,'https://example.com/',{timeoutMs:1000,pollMs:0}),true);
    assert.equal(checks,2);
    await assert.rejects(waitForPixelDocument({evaluate:async()=>{throw Error('Debugger closed');}},
        'https://example.com/'),/Debugger closed/);
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
        {url:'https://other.test/'},{images:[{url:'https://example.test/avatar.png',width:10,height:10,x:0,y:0,complete:true,naturalWidth:0}]},
        {styles:[{url:'https://example.test/main.css',active:true,loaded:false}]},
        {image_decode_errors:[{url:'https://example.test/photo.webp',error:'Invalid encoded bitmap'}]}]) {
        await assert.rejects(capturePixelReference({...page,evaluate:async()=>({...state,...change})},file,nav),
            /not ready|missing visible images|missing active stylesheets|image decode failures/);
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
    const failure=JSON.parse(await fs.readFile(file+'.json','utf8'));
    assert.equal(failure.stable,false);
    assert.deepEqual(failure.unstable_captures,[file+'.unstable-1.png',file+'.unstable-2.png']);
    assert.equal(await fs.readFile(failure.unstable_captures[0],'utf8'),'0');
    assert.equal(await fs.readFile(failure.unstable_captures[1],'utf8'),'1');
    page.send=async()=>({data:Buffer.from('stable').toString('base64')});
    const result=await capturePixelReference(page,file,{coverage:'page',url:state.url});
    assert.equal(result.stable,true);
    assert.equal(await fs.readFile(file,'utf8'),'stable');
    assert.equal(JSON.parse(await fs.readFile(file+'.json','utf8')).title,'News');
    assert.equal(JSON.parse(await fs.readFile(file+'.json','utf8')).stable,true);
});
