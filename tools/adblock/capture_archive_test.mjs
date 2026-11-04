import assert from 'node:assert/strict';
import {test} from 'node:test';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import vm from 'node:vm';
import {archiveHeaders, archiveResponseWithExtraHeaders, captureArchive, captureEncodedResponseCache, freezeDocument, imageAccept, reuseArchivedResponseHeaders} from './capture_archive.mjs';

const ready = snapshot => ({ready:'complete',fonts:'loaded',images:[],styles:[],rects:[],...snapshot});

test('freezing retains live CSSOM author rules, raw color syntax and document mode',()=>{
    const raw='p{color:rgb(51 51 51 / 59%)}';
    for(const doctype of [null,{name:'html',publicId:'',systemId:''},
        {name:'html',publicId:'-//W3C//DTD HTML 4.01 Transitional//EN',systemId:''}]) {
        const styles=[{textContent:'',sheet:{cssRules:[{cssText:'p { color: red; }'}]}},
            {textContent:raw,sheet:{cssRules:[{cssText:'p { color: rgba(51,51,51,.59); }'}]}},
            {textContent:'p{display:none}',sheet:{disabled:true}}];
        const cloned=styles.map(source=>({textContent:source.textContent}));
        const clone={querySelectorAll:selector=>selector==='style'?cloned:[],
            querySelector:()=>({prepend:()=>{}}),
            get outerHTML(){return '<html><head>'+cloned.map(s=>'<style'+
                (s.media?' media="'+s.media+'"':'')+'>'+s.textContent+'</style>').join('')+'</head></html>';}};
        const document={documentElement:{cloneNode:()=>clone},doctype,
            compatMode:doctype?'CSS1Compat':'BackCompat',baseURI:'https://example.com/',
            title:'News',body:{innerText:'story '.repeat(300)},
            querySelectorAll:()=>styles,createElement:()=>({})};
        const result=vm.runInNewContext('('+freezeDocument.toString()+')()',
            {document,location:{href:document.baseURI},innerWidth:1024,innerHeight:768,devicePixelRatio:1});
        assert.equal(result.cssom_styles,1);
        assert.equal(result.compat_mode,document.compatMode);
        assert(result.html.includes('p { color: red; }'));
        assert(result.html.includes(raw));
        assert(result.html.includes('media="not all"'));
        assert.equal(result.html.startsWith('<!DOCTYPE'),Boolean(doctype));
        if(doctype?.publicId) assert(result.html.startsWith('<!DOCTYPE html PUBLIC "'+doctype.publicId+'">'));
    }
});

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

test('network response headers retain CORS fields and update cached responses without duplicate names',()=>{
    const response={status:200,headers:{'Content-Type':'font/woff2','Vary':'Accept','X-Cached':'kept'}};
    for(const statusCode of [200,304]) {
        const full=archiveResponseWithExtraHeaders(response,{statusCode,headers:{
            'access-control-allow-origin':'*','vary':'Origin','Content-Length':'0'}});
        const headers=archiveHeaders(full,123);
        assert(headers.some(h=>h.name==='access-control-allow-origin' && h.value==='*'));
        assert.deepEqual(headers.filter(h=>h.name.toLowerCase()==='vary'),[{name:'vary',value:'Origin'}]);
        assert(headers.some(h=>h.name==='X-Cached' && h.value==='kept'));
        assert.deepEqual(headers.filter(h=>h.name.toLowerCase()==='content-length'),[{name:'content-length',value:'123'}]);
    }
    assert.equal(archiveResponseWithExtraHeaders(response,{statusCode:302,headers:{Location:'elsewhere'}}),response);
    assert.equal(archiveResponseWithExtraHeaders(response,undefined),response);
});

test('cached headers require the prepared encoded body, matching request origin and unchanged metadata',async t=>{
    const directory=await fs.mkdtemp(path.join(os.tmpdir(),'vox-prepared-headers-'));
    t.after(()=>fs.rm(directory,{recursive:true,force:true}));
    const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
    const url='https://cdn.example/font.woff2',body=Buffer.from('original encoded font');
    const request={method:'GET',headers:{Origin:'https://news.example'}};
    const response={url,status:200,fromDiskCache:true,headers:{'Content-Type':'font/woff2','Age':'100'}};
    const headers=[{name:'Content-Type',value:'font/woff2'},{name:'Access-Control-Allow-Origin',value:'https://news.example'},
        {name:'Vary',value:'Origin'},{name:'Age',value:'50'}];
    const bytes=JSON.stringify(headers),base=path.join(directory,'cache/resources',hash(url));
    await fs.mkdir(path.dirname(base),{recursive:true});await fs.writeFile(base,body);await fs.writeFile(base+'.headers.json',bytes);
    await fs.writeFile(path.join(directory,'archive.json'),JSON.stringify({resources:[{
        url,method:'GET',request_origin:'https://news.example',sha256:hash(body),response_headers_sha256:hash(bytes)}]}));
    const restored=await reuseArchivedResponseHeaders(directory,request,response,body);
    assert.equal(restored.url,url);assert.equal(restored.headers['Access-Control-Allow-Origin'],'https://news.example');
    assert.equal(restored.headers.Age,'100');
    for(const [req,res,data] of [[{...request,headers:{Origin:'https://other.example'}},response,body],
        [request,{...response,fromDiskCache:false},body],[request,response,Buffer.from('different encoded font')]])
        assert.equal(await reuseArchivedResponseHeaders(directory,req,res,data),res);
    await fs.writeFile(base+'.headers.json','[]');
    await assert.rejects(reuseArchivedResponseHeaders(directory,request,response,body),/Prepared response cache changed/);
});

test('encoded cache preparation retains original responses without claiming a frozen source document',async t=>{
    const root=await fs.mkdtemp(path.join(os.tmpdir(),'vox-response-preparation-'));
    t.after(()=>fs.rm(root,{recursive:true,force:true}));
    const directory=path.join(root,'capture'),url='https://news.example/';
    const body=Buffer.from('<html>original scripted document</html>');
    const page={events:[
        {method:'Network.requestWillBeSent',params:{requestId:'page',request:{url,method:'GET',headers:{Origin:'https://news.example'}}}},
        {method:'Network.responseReceived',params:{requestId:'page',type:'Document',response:{url,status:200,headers:{'Content-Type':'text/html'}}}},
        {method:'Network.loadingFinished',params:{requestId:'page'}},
    ],evaluate:async()=>{throw Error('Cache preparation must not serialize a DOM');},
    send:async method=>{assert.equal(method,'Network.getResponseBody');return {body:body.toString('base64'),base64Encoded:true};}};
    const result=await captureEncodedResponseCache(page,directory,url);
    assert.equal(result.resources,1);
    const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
    assert.deepEqual(await fs.readFile(path.join(directory,'cache/resources',hash(url))),body);
    const metadata=JSON.parse(await fs.readFile(path.join(directory,'archive.json'),'utf8'));
    assert.equal(metadata.resources[0].sha256,hash(body));
    assert.equal(metadata.frozen_html_sha256,undefined);
    await assert.rejects(fs.stat(path.join(directory,'frozen.html')),{code:'ENOENT'});
});

async function captureMediaRange(t, range, bytes) {
    const root=await fs.mkdtemp(path.join(os.tmpdir(),'vox-archive-media-'));
    t.after(()=>fs.rm(root,{recursive:true,force:true}));
    const url='https://news.example/',mediaURL=url+'preview.mp4';
    const entries=[{id:'main',url,type:'Document',status:200,
        headers:{'Content-Type':'text/html'},body:Buffer.from('original page')},
        {id:'media',url:mediaURL,type:'Media',status:206,
            headers:{'Content-Type':'video/mp4','Content-Range':range,
                'Access-Control-Allow-Origin':'*'},body:bytes}];
    const page={events:entries.flatMap(e=>[
        {method:'Network.requestWillBeSent',params:{requestId:e.id,request:{url:e.url,method:'GET'}}},
        {method:'Network.responseReceived',params:{requestId:e.id,type:e.type,
            response:{url:e.url,status:e.status,headers:e.headers}}},
        {method:'Network.loadingFinished',params:{requestId:e.id}},
    ]),evaluate:async()=>ready({html:'<!doctype html><video src="preview.mp4"></video>',
        url,base:url,text:'story '.repeat(300),width:1024,height:768,scale:1}),
    send:async(method,args)=>{
        if(method==='Page.captureScreenshot')return {data:Buffer.from('png').toString('base64')};
        assert.equal(method,'Network.getResponseBody');
        return {body:entries.find(e=>e.id===args.requestId).body.toString('base64'),base64Encoded:true};
    }};
    const directory=path.join(root,'capture');
    const result=await captureArchive(page,directory,url);
    const resource=path.join(directory,'cache/resources',crypto.createHash('sha256').update(mediaURL).digest('hex'));
    return {result,resource,report:JSON.parse(await fs.readFile(path.join(directory,'archive.json'),'utf8'))};
}

test('a complete media range retains original bytes as a full replay response',async t=>{
    const bytes=Buffer.from([0,0,0,16,102,116,121,112,105,115,111,109,0,0,0,0]);
    const {result,resource,report}=await captureMediaRange(t,'bytes 0-15/16',bytes);
    assert.equal(result.resources,2);
    assert.equal(result.failed_body_captures,0);
    assert.deepEqual(await fs.readFile(resource),bytes);
    assert.equal(await fs.readFile(resource+'.status','utf8'),'200');
    assert.deepEqual(JSON.parse(await fs.readFile(resource+'.headers.json','utf8')),[
        {name:'Content-Type',value:'video/mp4'},
        {name:'Access-Control-Allow-Origin',value:'*'},
        {name:'content-length',value:'16'},
    ]);
    const media=report.resources.find(r=>r.type==='Media');
    assert.equal(media.status,206);
    assert.equal(media.replayed_status,200);
    assert.equal(media.sha256,crypto.createHash('sha256').update(bytes).digest('hex'));
});

test('partial, malformed and truncated media ranges cannot become complete replay bodies',async t=>{
    for(const range of ['bytes 0-7/16','bytes 8-15/16','bytes 0-15/16',
        'bytes 0-7/*','bytes 0-9007199254740992/9007199254740993',undefined]) {
        const {result,resource,report}=await captureMediaRange(t,range,Buffer.alloc(8));
        assert.equal(result.resources,1);
        assert.equal(result.failed_body_captures,1);
        assert.match(report.resources.find(r=>r.type==='Media').error,/complete media range/i);
        await assert.rejects(fs.stat(resource),{code:'ENOENT'});
    }
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
        evaluate:async()=>ready({html:'<!doctype html><title>News</title>',url,base:url,
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
            evaluate:async()=>ready({html:'<!doctype html><title>Questions</title>',url,base:url,
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
        async evaluate() { return ready({html, url, base:url, text:'text '.repeat(300),
            width:1024, height:768, scale:1, removed_scripts:3}); },
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
    assert.equal(result.source_pixels.stable,true);
    assert.equal(result.source_pixels.sha256,crypto.createHash('sha256').update(encoded).digest('hex'));
    const sourceState=JSON.parse(await fs.readFile(path.join(directory,'live.png.json'),'utf8'));
    assert.equal(sourceState.stable,true);
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
    assert.equal(manifest.document_snapshot.stable,true);
    assert.equal(manifest.document_snapshot.before.html_sha256,key(html));
    await assert.rejects(captureArchive(page, directory, url), /EEXIST/);
});

test('stable source pixels cannot seal a different DOM or visible text',async t=>{
    const root=await fs.mkdtemp(path.join(os.tmpdir(),'vox-archive-document-change-'));
    t.after(()=>fs.rm(root,{recursive:true,force:true}));
    for(const changed of ['html','text']) {
        const directory=path.join(root,changed),url='https://news.example/';
        let snapshots=0;
        const before={html:'<html>news</html>',url,base:url,compat_mode:'CSS1Compat',
            text:'story '.repeat(300),width:1024,height:768,scale:1};
        const page={events:[],evaluate:async expression=>{
            const isSnapshot=expression.includes('cloneNode(true)');
            if(isSnapshot) ++snapshots;
            return ready({...before,...(isSnapshot && snapshots===2 ? {[changed]:before[changed]+' changed'} : {})});
        },send:async method=>{
            assert.equal(method,'Page.captureScreenshot');
            return {data:Buffer.from('stable frame').toString('base64')};
        }};
        await assert.rejects(captureArchive(page,directory,url),/Live document changed during source capture/);
        assert.equal(snapshots,2);
        assert.equal(await fs.readFile(path.join(directory,'frozen.html'),'utf8'),before.html);
        const after=await fs.readFile(path.join(directory,'frozen-after.html'),'utf8');
        assert.equal(after,changed==='html' ? before.html+' changed' : before.html);
        const identity=JSON.parse(await fs.readFile(path.join(directory,'document-snapshot.json'),'utf8'));
        assert.equal(identity.stable,false);
        await assert.rejects(fs.stat(path.join(directory,'archive.json')),{code:'ENOENT'});
    }
});

test('an unstable live source retains both frames without sealing an archive',async t=>{
    const root=await fs.mkdtemp(path.join(os.tmpdir(),'vox-archive-unstable-'));
    t.after(()=>fs.rm(root,{recursive:true,force:true}));
    const directory=path.join(root,'capture'),url='https://news.example/';
    let captures=0;
    const page={events:[],evaluate:async()=>ready({html:'<html>news</html>',url,
        text:'story '.repeat(300),width:1024,height:768,scale:1}),
    send:async method=>{
        assert.equal(method,'Page.captureScreenshot');
        return {data:Buffer.from('frame-'+(++captures)).toString('base64')};
    }};
    await assert.rejects(captureArchive(page,directory,url),/changed between consecutive captures/);
    assert.equal(captures,2);
    for(const name of ['archive.json','live.png'])
        await assert.rejects(fs.stat(path.join(directory,name)),{code:'ENOENT'});
    const state=JSON.parse(await fs.readFile(path.join(directory,'live.png.json'),'utf8'));
    assert.equal(state.stable,false);
    assert.equal(await fs.readFile(state.unstable_captures[0],'utf8'),'frame-1');
    assert.equal(await fs.readFile(state.unstable_captures[1],'utf8'),'frame-2');
});

test('unready live resources cannot be sealed even when the document has loaded',async t=>{
    const root=await fs.mkdtemp(path.join(os.tmpdir(),'vox-archive-unready-'));
    t.after(()=>fs.rm(root,{recursive:true,force:true}));
    const url='https://news.example/';
    for(const [name,resource,error] of [
        ['image',{images:[{url:url+'photo.webp',x:1,y:1,width:100,height:50,
            complete:true,naturalWidth:0}]},/missing visible images/],
        ['stylesheet',{styles:[{url:url+'news.css',active:true,loaded:false}]},/missing active stylesheets/],
        ['fonts',{fonts:'loading'},/not ready/],
    ]) {
        const directory=path.join(root,name);
        let evaluations=0;
        const page={events:[],evaluate:async()=>ready({html:'<html>news</html>',url,
            text:'story '.repeat(300),width:1024,height:768,scale:1,
            ...(evaluations++?resource:{})}),send:async()=>assert.fail('Unready source must not capture or read bodies')};
        await assert.rejects(captureArchive(page,directory,url),error);
        await assert.rejects(fs.stat(path.join(directory,'archive.json')),{code:'ENOENT'});
        assert.equal(JSON.parse(await fs.readFile(path.join(directory,'live.png.json'),'utf8')).stable,false);
    }
});
