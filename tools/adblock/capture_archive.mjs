// Capture real response bytes and a script-free DOM for repeatable native
// renderer comparisons. This does not serialize computed geometry or pixels.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {isExpectedSiteURL} from './navigation.mjs';
import {capturePixelReference} from './pixel_reference.mjs';

export const imageAccept = 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8';
const digest = value => crypto.createHash('sha256').update(value).digest('hex');

export function freezeDocument() {
    const clone = document.documentElement.cloneNode(true);
    const styles=[...document.querySelectorAll('style')];
    const clonedStyles=[...clone.querySelectorAll('style')];
    let cssomStyles=0;
    for(let index=0;index<styles.length;++index) {
        const source=styles[index],sheet=source.sheet;
        if(!sheet) continue;
        if(sheet.disabled) {clonedStyles[index].media='not all';continue;}
        // CSS-in-JS commonly inserts rules into an empty style element. Its
        // outerHTML contains none of the author rules actually being painted.
        // Retain raw authored text whenever it exists, including color syntax.
        if(source.textContent.trim()) continue;
        const rules=[...sheet.cssRules].map(rule=>rule.cssText);
        if(rules.length) {
            clonedStyles[index].textContent=rules.join('\n');
            ++cssomStyles;
        }
    }
    const scripts = clone.querySelectorAll('script');
    const removedScripts = scripts.length;
    // Consistent with the Reddit workload: retain normal noscript parsing,
    // but do not execute the changing page's scripts again in the replay.
    for (const script of scripts) script.remove();
    for (const base of clone.querySelectorAll('base')) base.remove();
    const base = document.createElement('base');
    base.href = document.baseURI;
    clone.querySelector('head').prepend(base);
    const type=document.doctype;
    const doctype=!type ? '' : '<!DOCTYPE '+type.name+
        (type.publicId ? ' PUBLIC "'+type.publicId+'"' : '')+
        (type.systemId ? (type.publicId ? '' : ' SYSTEM')+' "'+type.systemId+'"' : '')+'>\n';
    return {html: doctype + clone.outerHTML, url: location.href,
        base: document.baseURI, removed_scripts: removedScripts,
        compat_mode:document.compatMode,cssom_styles:cssomStyles,
        elements: clone.querySelectorAll('*').length, title: document.title,
        text: document.body.innerText, width: innerWidth, height: innerHeight,
        scale: devicePixelRatio};
}

export function archiveHeaders(response, length, {completeMediaRange=false}={}) {
    // CDP decodes the transport body. Preserve origin/CORS/content policy;
    // remove only wire compression/framing and recompute its byte length.
    return Object.entries(response.headers).filter(([name]) =>
        !['content-encoding', 'transfer-encoding', 'content-length'].includes(name.toLowerCase())
        && !(completeMediaRange && name.toLowerCase()==='content-range'))
        .flatMap(([name, value]) => String(value).split('\n').map(value => ({name, value})))
        .concat([{name: 'content-length', value: String(length)}]);
}

function isCompleteMediaRange(response, length) {
    const value=Object.entries(response.headers)
        .find(([name])=>name.toLowerCase()==='content-range')?.[1];
    if(typeof value!=='string') return false;
    const match=/^bytes 0-(\d+)\/(\d+)$/i.exec(value.trim());
    if(!match) return false;
    const end=Number(match[1]),total=Number(match[2]);
    return Number.isSafeInteger(end) && Number.isSafeInteger(total)
        && total>0 && end===total-1 && length===total;
}

export async function captureArchive(page, directory, expectedURL, {mainFrameID}={}) {
    await fs.mkdir(directory, {mode: 0o700}); // Never overwrite a prior workload.
    const cache = path.join(directory, 'cache');
    await fs.mkdir(path.join(cache, 'resources'), {recursive: true});
    await fs.mkdir(path.join(cache, 'pages'));
    const snapshotExpression = `(async()=>{
        await document.fonts.ready;
        await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
        return (${freezeDocument.toString()})();
    })()`;
    const snapshot = await page.evaluate(snapshotExpression);
    if (snapshot.width !== 1024 || snapshot.height !== 768 || snapshot.scale !== 1
        || snapshot.text.length < 1000 || !isExpectedSiteURL(expectedURL, snapshot.url)) {
        throw new Error('Capture requires the loaded requested site at 1024x768 and device scale 1');
    }
    await fs.writeFile(path.join(directory, 'frozen.html'), snapshot.html);
    await fs.writeFile(path.join(directory, 'live.txt'), snapshot.text);
    // The live source is a reference too. Require the same loaded fonts,
    // visible resources and consecutive-frame stability as frozen replay;
    // otherwise an incomplete or moving source can never qualify its archive.
    const sourcePixels = await capturePixelReference(page, path.join(directory, 'live.png'),
        {coverage:'page', url:snapshot.url});
    // A stable pair of PNGs does not prove that the DOM serialized before it
    // was the one painted. Bracket the source capture with the replayable DOM
    // and text identities, retaining both versions when a live page changes.
    const after = await page.evaluate(snapshotExpression);
    const identity = value => ({html_sha256:digest(value.html), text_sha256:digest(value.text),
        url:value.url,base:value.base,compat_mode:value.compat_mode,
        width:value.width,height:value.height,scale:value.scale});
    const documentSnapshot = {before:identity(snapshot),after:identity(after)};
    documentSnapshot.stable = JSON.stringify(documentSnapshot.before) === JSON.stringify(documentSnapshot.after);
    await fs.writeFile(path.join(directory, 'document-snapshot.json'),
        JSON.stringify(documentSnapshot,null,2)+'\n');
    if(!documentSnapshot.stable) {
        await fs.writeFile(path.join(directory, 'frozen-after.html'),after.html);
        await fs.writeFile(path.join(directory, 'capture-failure.json'),JSON.stringify({
            status:'failed',reason:'Live document changed during source capture',
            document_snapshot:documentSnapshot,source_pixels:sourcePixels},null,2)+'\n');
        throw new Error('Live document changed during source capture; see document-snapshot.json');
    }
    const requests = new Map(page.events.filter(e => e.method === 'Network.requestWillBeSent')
        .map(e => [e.params.requestId, e.params.request]));
    const responses = new Map(page.events.filter(e => e.method === 'Network.responseReceived')
        .map(e => [e.params.requestId, e.params]));
    const completed = new Set(page.events.filter(e => e.method === 'Network.loadingFinished')
        .map(e => e.params.requestId));
    const resources = [];
    for (const [id, entry] of responses) {
        const {response, type} = entry;
        const method=requests.get(id)?.method;
        const isMain=type==='Document' && response.url===snapshot.url
            && mainFrameID && entry.frameId===mainFrameID;
        const supportedStatus=response.status===200 || (type==='Media' && response.status===206);
        if (!/^https?:/.test(response.url) || !supportedStatus
            || (method!=='GET' && !(method==='POST' && isMain)) || !completed.has(id)) continue;
        if(type==='Document' && response.url===snapshot.url && mainFrameID && !isMain) continue;
        const row = {url: response.url, type, status: response.status, method};
        try {
            const result = await page.send('Network.getResponseBody', {requestId: id});
            const body = Buffer.from(result.body, result.base64Encoded ? 'base64' : 'utf8');
            if (!body.length || body.length > 16 * 1024 * 1024) throw new Error('Unsupported body size');
            const completeMediaRange=response.status===206;
            if(completeMediaRange && !isCompleteMediaRange(response,body.length))
                throw new Error('Cannot archive an incomplete media range');
            // The replay explicitly chooses this captured representation in
            // both engines; keep the native Accept cache discriminator too.
            const keys = [response.url];
            if (type === 'Image') keys.push(response.url + '\nAccept: ' + imageAccept);
            // A range covering the entire representation can replay as a full
            // 200 response. Keep its original 206 status in capture provenance.
            const headers = archiveHeaders(response, body.length,{completeMediaRange});
            if(completeMediaRange) row.replayed_status=200;
            for (const key of keys) {
                const filename = path.join(cache, 'resources', digest(key));
                await fs.writeFile(filename, body);
                await fs.writeFile(filename + '.url', response.url);
                await fs.writeFile(filename + '.status', '200');
                await fs.writeFile(filename + '.headers.json', JSON.stringify(headers));
            }
            row.bytes = body.length; row.sha256 = digest(body);
        } catch (error) {
            row.error = error.message;
        }
        resources.push(row);
    }
    const main = resources.find(r => r.url === snapshot.url && r.type === 'Document' && !r.error);
    if (!main) {
        const {html, text, ...metadata} = snapshot;
        await fs.writeFile(path.join(directory, 'capture-failure.json'), JSON.stringify({
            status:'failed', reason:'Missing successful main response', ...metadata, resources,
            document_responses:[...responses.values()].filter(entry=>entry.type==='Document')
                .map(entry=>({url:entry.response.url,status:entry.response.status,
                    frame_id:entry.frameId,loader_id:entry.loaderId,
                    method:requests.get(entry.requestId)?.method,completed:completed.has(entry.requestId)})),
        },null,2)+'\n');
        throw new Error('Missing successful main response; see capture-failure.json');
    }
    const document = path.join(cache, 'resources', digest(snapshot.url));
    await fs.writeFile(document, snapshot.html);
    const headers = JSON.parse(await fs.readFile(document + '.headers.json'));
    for (const header of headers) if (header.name.toLowerCase() === 'content-length')
        header.value = String(Buffer.byteLength(snapshot.html));
    await fs.writeFile(document + '.headers.json', JSON.stringify(headers));
    const pageFile = path.join(cache, 'pages', digest(snapshot.url));
    await fs.writeFile(pageFile, snapshot.html);
    await fs.writeFile(pageFile + '.content-type', 'text/html;charset=utf-8');
    const {html, text, ...metadata} = snapshot;
    const report = {...metadata, source_pixels:sourcePixels,document_snapshot:documentSnapshot,
        document_request_method:main.method, frozen_html_sha256: digest(html), resources,
        workload: 'Frozen live DOM, scripts removed, normal scripting policy, original encoded resource bodies; no saved raster or computed-style replacement.'};
    await fs.writeFile(path.join(directory, 'archive.json'), JSON.stringify(report, null, 2) + '\n');
    return {directory, url: snapshot.url, source_pixels:sourcePixels, document_request_method:main.method,
        compat_mode:snapshot.compat_mode,cssom_styles:snapshot.cssom_styles||0,
        resources: resources.filter(r => !r.error).length,
        failed_body_captures: resources.filter(r => r.error).length, frozen_html_sha256: digest(html)};
}
