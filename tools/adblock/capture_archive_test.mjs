import assert from 'node:assert/strict';
import {test} from 'node:test';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {archiveHeaders, captureArchive, imageAccept} from './capture_archive.mjs';

test('decoded body keeps response policy and repeated values, replacing only wire framing', () => {
    const headers = archiveHeaders({headers:{'Content-Encoding':'br','Transfer-Encoding':'chunked',
        'Content-Length':'400','Content-Type':'image/webp','Vary':'Accept',
        'Access-Control-Allow-Origin':'https://edition.cnn.com','X-Repeat':'one\ntwo'}},123);
    assert.deepEqual(headers,[{name:'Content-Type',value:'image/webp'},
        {name:'Vary',value:'Accept'},{name:'Access-Control-Allow-Origin',value:'https://edition.cnn.com'},
        {name:'X-Repeat',value:'one'},{name:'X-Repeat',value:'two'},
        {name:'content-length',value:'123'}]);
});
test('empty header values survive archive serialization', () => {
    assert.deepEqual(archiveHeaders({headers:{'X-Empty':''}},0),[
        {name:'X-Empty',value:''},{name:'content-length',value:'0'}]);
});

test('failed main response bodies retain diagnostics without sealing an archive', async t => {
    const root=await fs.mkdtemp(path.join(os.tmpdir(),'vox-archive-failure-'));
    t.after(()=>fs.rm(root,{recursive:true,force:true}));
    const directory=path.join(root,'capture'),url='https://example.com/';
    const page={
        events:[
            {method:'Network.requestWillBeSent',params:{requestId:'main',request:{url,method:'GET'}}},
            {method:'Network.responseReceived',params:{requestId:'main',type:'Document',frameId:'top',
                loaderId:'document-loader',response:{url,status:200,headers:{'Content-Type':'text/html'}}}},
            {method:'Network.loadingFinished',params:{requestId:'main'}},
        ],
        evaluate:async()=>({html:'<!doctype html><title>News</title>',url,base:url,
            text:'story '.repeat(300),width:1024,height:768,scale:1}),
        send:async method=>{
            if(method==='Page.captureScreenshot')return {data:Buffer.from('png').toString('base64')};
            assert.equal(method,'Network.getResponseBody');
            throw Error('Response body was evicted');
        },
    };
    await assert.rejects(captureArchive(page,directory,url),/Missing successful main response/);
    const failure=JSON.parse(await fs.readFile(path.join(directory,'capture-failure.json'),'utf8'));
    assert.equal(failure.status,'failed');
    assert.equal(failure.resources[0].error,'Response body was evicted');
    assert.deepEqual(failure.document_responses,[{url,status:200,frame_id:'top',
        loader_id:'document-loader',method:'GET',completed:true}]);
    await assert.rejects(fs.stat(path.join(directory,'archive.json')),{code:'ENOENT'});
});

test('a completed POST main navigation can be frozen only with its verified top frame',async t=>{
    const root=await fs.mkdtemp(path.join(os.tmpdir(),'vox-archive-post-'));
    t.after(()=>fs.rm(root,{recursive:true,force:true}));
    const url='https://example.com/questions';
    const entries=[{id:'main',type:'Document',frameId:'top'},
        {id:'child',type:'Document',frameId:'child'},{id:'xhr',type:'XHR',frameId:'top'}];
    for(const mainFrameID of [undefined,'other','top']) {
        const directory=path.join(root,String(mainFrameID));
        const captured=[];
        const page={
            events:entries.flatMap(e=>[
                {method:'Network.requestWillBeSent',params:{requestId:e.id,request:{url,method:'POST'}}},
                {method:'Network.responseReceived',params:{requestId:e.id,type:e.type,frameId:e.frameId,
                    response:{url,status:200,headers:{'Content-Type':'text/html'}}}},
                {method:'Network.loadingFinished',params:{requestId:e.id}},
            ]),
            evaluate:async()=>({html:'<!doctype html><title>Questions</title>',url,base:url,
                text:'question '.repeat(300),width:1024,height:768,scale:1}),
            send:async(method,args)=>{
                if(method==='Page.captureScreenshot')return {data:Buffer.from('png').toString('base64')};
                assert.equal(method,'Network.getResponseBody');
                captured.push(args.requestId);
                return {body:'Original successful POST navigation',base64Encoded:false};
            },
        };
        if(mainFrameID!=='top') {
            await assert.rejects(captureArchive(page,directory,url,{mainFrameID}),/Missing successful main response/);
            assert.deepEqual(captured,[]);
            continue;
        }
        const result=await captureArchive(page,directory,url,{mainFrameID});
        assert.equal(result.document_request_method,'POST');
        assert.deepEqual(captured,['main']);
        const report=JSON.parse(await fs.readFile(path.join(directory,'archive.json'),'utf8'));
        assert.equal(report.document_request_method,'POST');
        assert.equal(report.resources.length,1);
        assert.equal(report.resources[0].method,'POST');
    }
});

test('archive replays encoded images and the frozen main body with original response policy', async t => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'vox-archive-test-'));
    t.after(() => fs.rm(root, {recursive:true, force:true}));
    const directory = path.join(root, 'capture');
    const url = 'https://edition.example.com/';
    const imageURL = 'https://media.example.com/photo.webp';
    const html = '<!doctype html><html><head><base href="' + url + '"></head><body>frozen</body></html>';
    const encoded = Buffer.from([0, 255, 127, 128, 4]);
    const entries = [
        {id:'document', url, type:'Document', body:'original scripted document',
            headers:{'Content-Type':'text/html', 'Content-Security-Policy':"default-src 'self'"}},
        {id:'image', url:imageURL, type:'Image', body:encoded.toString('base64'),
            headers:{'Content-Type':'image/webp', 'Access-Control-Allow-Origin':url, 'Content-Encoding':'br'}},
        {id:'failed', url:url+'missing', type:'Image', body:'missing', headers:{}, status:404},
        {id:'unfinished', url:url+'pending', type:'Image', body:'not finished', headers:{}},
    ];
    const page = {
        events:entries.flatMap(e => [
            {method:'Network.requestWillBeSent', params:{requestId:e.id, request:{url:e.url, method:'GET'}}},
            {method:'Network.responseReceived', params:{requestId:e.id, type:e.type,
                response:{url:e.url, status:e.status||200, headers:e.headers}}},
            ...(e.id === 'unfinished' ? [] : [{method:'Network.loadingFinished', params:{requestId:e.id}}]),
        ]),
        async evaluate() { return {html, url, base:url, text:'text '.repeat(300),
            width:1024, height:768, scale:1, removed_scripts:3}; },
        async send(method, args) {
            if (method === 'Page.captureScreenshot') return {data:encoded.toString('base64')};
            assert.equal(method, 'Network.getResponseBody');
            const entry = entries.find(e => e.id === args.requestId);
            return {body:entry.body, base64Encoded:entry.id === 'image'};
        },
    };
    const result = await captureArchive(page, directory, 'https://example.com/');
    assert.equal(result.resources, 2);
    assert.equal(result.failed_body_captures, 0);
    const key = value => crypto.createHash('sha256').update(value).digest('hex');
    const resource = value => path.join(directory, 'cache/resources', key(value));
    assert.deepEqual(await fs.readFile(resource(imageURL)), encoded);
    assert.deepEqual(await fs.readFile(resource(imageURL+'\nAccept: '+imageAccept)), encoded);
    assert.equal(await fs.readFile(resource(url), 'utf8'), html);
    assert.equal(await fs.readFile(path.join(directory, 'cache/pages', key(url)), 'utf8'), html);
    const headers = JSON.parse(await fs.readFile(resource(url)+'.headers.json'));
    assert(headers.some(h => h.name === 'Content-Security-Policy' && h.value === "default-src 'self'"));
    assert(headers.some(h => h.name === 'content-length' && h.value === String(Buffer.byteLength(html))));
    const manifest = JSON.parse(await fs.readFile(path.join(directory, 'archive.json')));
    assert.equal(manifest.resources[0].sha256, key('original scripted document'));
    assert.equal(manifest.frozen_html_sha256, key(html));
    await assert.rejects(captureArchive(page, directory, url), /EEXIST/);
});
