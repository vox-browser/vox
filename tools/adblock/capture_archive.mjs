// Capture real response bytes and a script-free DOM for repeatable native
// renderer comparisons. This does not serialize computed geometry or pixels.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {isExpectedSiteURL} from './navigation.mjs';

export const imageAccept = 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8';
const digest = value => crypto.createHash('sha256').update(value).digest('hex');

export function freezeDocument() {
    const clone = document.documentElement.cloneNode(true);
    const scripts = clone.querySelectorAll('script');
    const removedScripts = scripts.length;
    // Consistent with the Reddit workload: retain normal noscript parsing,
    // but do not execute the changing page's scripts again in the replay.
    for (const script of scripts) script.remove();
    for (const base of clone.querySelectorAll('base')) base.remove();
    const base = document.createElement('base');
    base.href = document.baseURI;
    clone.querySelector('head').prepend(base);
    return {html: '<!doctype html>\n' + clone.outerHTML, url: location.href,
        base: document.baseURI, removed_scripts: removedScripts,
        elements: clone.querySelectorAll('*').length, title: document.title,
        text: document.body.innerText, width: innerWidth, height: innerHeight,
        scale: devicePixelRatio};
}

export function archiveHeaders(response, length) {
    // CDP decodes the transport body. Preserve origin/CORS/content policy;
    // remove only wire compression/framing and recompute its byte length.
    return Object.entries(response.headers).filter(([name]) =>
        !['content-encoding', 'transfer-encoding', 'content-length'].includes(name.toLowerCase()))
        .flatMap(([name, value]) => String(value).split('\n').map(value => ({name, value})))
        .concat([{name: 'content-length', value: String(length)}]);
}

export async function captureArchive(page, directory, expectedURL) {
    await fs.mkdir(directory, {mode: 0o700}); // Never overwrite a prior workload.
    const cache = path.join(directory, 'cache');
    await fs.mkdir(path.join(cache, 'resources'), {recursive: true});
    await fs.mkdir(path.join(cache, 'pages'));
    const snapshot = await page.evaluate(`(${freezeDocument.toString()})()`);
    if (snapshot.width !== 1024 || snapshot.height !== 768 || snapshot.scale !== 1
        || snapshot.text.length < 1000 || !isExpectedSiteURL(expectedURL, snapshot.url)) {
        throw new Error('Capture requires the loaded requested site at 1024x768 and device scale 1');
    }
    await fs.writeFile(path.join(directory, 'frozen.html'), snapshot.html);
    await fs.writeFile(path.join(directory, 'live.txt'), snapshot.text);
    const png = await page.send('Page.captureScreenshot', {format: 'png', captureBeyondViewport: false});
    await fs.writeFile(path.join(directory, 'live.png'), Buffer.from(png.data, 'base64'));
    const requests = new Map(page.events.filter(e => e.method === 'Network.requestWillBeSent')
        .map(e => [e.params.requestId, e.params.request]));
    const responses = new Map(page.events.filter(e => e.method === 'Network.responseReceived')
        .map(e => [e.params.requestId, e.params]));
    const completed = new Set(page.events.filter(e => e.method === 'Network.loadingFinished')
        .map(e => e.params.requestId));
    const resources = [];
    for (const [id, entry] of responses) {
        const {response, type} = entry;
        if (!/^https?:/.test(response.url) || response.status !== 200
            || requests.get(id)?.method !== 'GET' || !completed.has(id)) continue;
        const row = {url: response.url, type, status: response.status};
        try {
            const result = await page.send('Network.getResponseBody', {requestId: id});
            const body = Buffer.from(result.body, result.base64Encoded ? 'base64' : 'utf8');
            if (!body.length || body.length > 16 * 1024 * 1024) throw new Error('Unsupported body size');
            // The replay explicitly chooses this captured representation in
            // both engines; keep the native Accept cache discriminator too.
            const keys = [response.url];
            if (type === 'Image') keys.push(response.url + '\nAccept: ' + imageAccept);
            const headers = archiveHeaders(response, body.length);
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
    const report = {...metadata, frozen_html_sha256: digest(html), resources,
        workload: 'Frozen live DOM, scripts removed, normal scripting policy, original encoded resource bodies; no saved raster or computed-style replacement.'};
    await fs.writeFile(path.join(directory, 'archive.json'), JSON.stringify(report, null, 2) + '\n');
    return {directory, url: snapshot.url, resources: resources.filter(r => !r.error).length,
        failed_body_captures: resources.filter(r => r.error).length, frozen_html_sha256: digest(html)};
}
