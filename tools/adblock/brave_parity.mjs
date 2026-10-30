// Compare Vox with the full MV2 uBlock Origin extension in an isolated Brave
// profile. Existing profiles are read only to locate the extension's code.
// Requires Node >= 22 (built-in fetch and WebSocket), Brave and full uBO.
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawn, execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { captureArchive } from './capture_archive.mjs';
import { createOracleProfile } from './oracle_profile.mjs';
import { capturePixelReference, referenceLaunchArguments, waitForPixelDocument } from './pixel_reference.mjs';
import { navigationObservation } from './navigation.mjs';
import { hasHeaderFilter, requestIdentity, summarizeRequestParity } from './request_stream.mjs';
import { collectVisibility, validateVisibilityProbe } from './visibility_probe.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const options = {
    brave: '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
    url: 'https://www.theverge.com/',
    output: path.join(root, 'Build/comparisons/adblock-theverge.json'),
    checker: path.join(root, 'Build/adblock-check'),
    'vox-log': '',
    requests: '',
    'document-fixture': '',
    'visibility-probe': '',
    'capture-dir': '',
    'profile-template': '',
    'pixel-reference': '',
    'proxy-server': '',
    'replay-spki': '',
    settle: 15,
};
for (let i = 2; i < process.argv.length; i += 2) {
    const key = process.argv[i].replace(/^--/, '');
    if (!(key in options) && key !== 'extension') throw new Error(`Unknown option: --${key}`);
    if (process.argv[i + 1] === undefined) throw new Error(`Missing --${key} value`);
    options[key] = process.argv[i + 1];
}
options.settle = Number(options.settle);
if (!(options.settle > 0 && options.settle <= 120)) throw new Error('--settle must be 1..120 seconds');
const recordedVox = options['vox-log']
    ? (await fs.readFile(options['vox-log'], 'utf8')).split(/\r?\n/).filter(line => line.trim()).map(JSON.parse)
    : null;
if (options.requests && recordedVox) throw new Error('Use either --requests or --vox-log');
const requestedCorpus = options.requests ? JSON.parse(await fs.readFile(options.requests, 'utf8')) : null;
if (requestedCorpus && (!Array.isArray(requestedCorpus) || requestedCorpus.some(entry =>
    typeof entry.url !== 'string' || typeof entry.request_type !== 'string'))) {
    throw new Error('--requests must contain an array of typed request or response checks');
}
const replayInput = recordedVox || requestedCorpus;
if (Boolean(options['document-fixture']) !== Boolean(options['visibility-probe'])) {
    throw new Error('--document-fixture and --visibility-probe must be supplied together');
}
if (replayInput && options['document-fixture']) throw new Error('Document fixtures require a live page visit');
const fixtureHTML = options['document-fixture'] ? await fs.readFile(options['document-fixture'], 'utf8') : null;
const probeSource = options['visibility-probe'] ? await fs.readFile(options['visibility-probe'], 'utf8') : null;
const visibilityProbe = probeSource ? JSON.parse(probeSource) : null;
const probeIDs = visibilityProbe ? validateVisibilityProbe(visibilityProbe) : [];
if (visibilityProbe && new URL(visibilityProbe.url).hostname !== new URL(options.url).hostname) {
    throw new Error('Visibility probe URL must match the requested site');
}
if (recordedVox && options.output === path.join(root, 'Build/comparisons/adblock-theverge.json')) {
    options.output = path.join(root, 'Build/comparisons/adblock-vox-theverge.json');
}
if (recordedVox?.some(entry => typeof entry.blocked !== 'boolean' || typeof entry.exception !== 'boolean'
    || typeof entry.url !== 'string' || typeof entry.request_type !== 'string'
    || (entry.phase === 'response' && !Array.isArray(entry.response_headers)))) {
    throw new Error('--vox-log must contain JSON lines from VOX_ADBLOCK_LOG');
}

async function findExtension() {
    if (options.extension) return path.resolve(options.extension);
    const base = path.join(os.homedir(), 'Library/Application Support/BraveSoftware/Brave-Browser');
    const profiles = (await fs.readdir(base)).filter(s => s === 'Default' || /^Profile \d+$/.test(s));
    for (const profile of profiles) {
        const dir = path.join(base, profile, 'Extensions');
        for (const id of await fs.readdir(dir).catch(() => [])) {
            for (const version of (await fs.readdir(path.join(dir, id))).reverse()) {
                const candidate = path.join(dir, id, version);
                const manifest = await fs.readFile(path.join(candidate, 'manifest.json'), 'utf8').then(JSON.parse).catch(() => null);
                if (manifest?.name === 'uBlock Origin' && manifest.manifest_version === 2) return candidate;
            }
        }
    }
    throw new Error('Full MV2 uBlock Origin was not found. Supply --extension PATH.');
}

const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
class CDP {
    async connect(url) {
        this.ws = new WebSocket(url);
        this.pending = new Map();
        this.next = 0;
        this.events = [];
        await new Promise((resolve, reject) => { this.ws.onopen = resolve; this.ws.onerror = reject; });
        this.ws.onclose = () => {
            for (const pending of this.pending.values()) {
                clearTimeout(pending.timer);
                pending.reject(new Error('Brave debugger connection closed'));
            }
            this.pending.clear();
        };
        this.ws.onmessage = event => {
            const message = JSON.parse(event.data);
            if (!message.id) { this.events.push(message); return; }
            const pending = this.pending.get(message.id);
            if (!pending) return;
            this.pending.delete(message.id);
            clearTimeout(pending.timer);
            if (message.error) pending.reject(new Error(JSON.stringify(message.error)));
            else pending.resolve(message.result);
        };
        return this;
    }
    send(method, params = {}) {
        return new Promise((resolve, reject) => {
            const id = ++this.next;
            const timer = setTimeout(() => {
                this.pending.delete(id);
                reject(new Error(`Brave debugger timed out: ${method}`));
            }, 60000);
            this.pending.set(id, { resolve, reject, timer });
            this.ws.send(JSON.stringify({ id, method, params }));
        });
    }
    async evaluate(expression) {
        const result = await this.send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
        if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
        return result.result.value;
    }
    close() { this.ws.close(); }
}

const extension = await findExtension();
const extensionManifest = JSON.parse(await fs.readFile(path.join(extension, 'manifest.json'), 'utf8'));
const manifest = JSON.parse(await fs.readFile(path.join(root, 'adblock/lists/manifest.json'), 'utf8'));
if (extensionManifest.version !== manifest.engine.version) {
    throw new Error(`Full uBO ${manifest.engine.version} is required for exact parity; found ${extensionManifest.version}`);
}
const lists = await Promise.all(manifest.lists.map(async entry => {
    const content = await fs.readFile(path.join(root, 'adblock', entry.file), 'utf8');
    if (crypto.createHash('sha256').update(content).digest('hex') !== entry.sha256) throw new Error(`List hash mismatch: ${entry.name}`);
    return { name: entry.name, content };
}));
// Default to a clean profile; an explicit prepared template is copied into a
// temporary directory. Neither mode launches against the source profile.
const profile = await createOracleProfile(options['profile-template']);
const browser = spawn(options.brave, [
    '--headless=new', '--no-first-run', '--no-default-browser-check', '--disable-sync',
    '--disable-background-networking', '--remote-debugging-port=0', '--remote-allow-origins=*',
    ...referenceLaunchArguments(options),
    `--user-data-dir=${profile}`, `--load-extension=${extension}`, 'about:blank',
], { stdio: ['ignore', 'ignore', 'ignore'] });
let background, page;
try {
    let port;
    for (let attempt = 0; attempt < 300; attempt++) {
        const active = await fs.readFile(path.join(profile, 'DevToolsActivePort'), 'utf8').catch(() => '');
        if (active) { port = active.split('\n')[0]; break; }
        if (browser.exitCode !== null || browser.signalCode !== null) throw new Error(`Brave exited with ${browser.exitCode ?? browser.signalCode}`);
        await pause(100);
    }
    if (!port) throw new Error('Brave remote debugger did not start');
    let targets;
    for (let attempt = 0; attempt < 300; attempt++) {
        targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
        if (targets.some(t => t.type === 'background_page' && t.url.endsWith('/background.html'))) break;
        await pause(100);
    }
    const bgTarget = targets.find(t => t.type === 'background_page' && t.url.endsWith('/background.html'));
    if (!bgTarget) throw new Error('Full uBlock Origin background page did not load');
    background = await new CDP().connect(bgTarget.webSocketDebuggerUrl);
    page = await new CDP().connect(targets.find(t => t.type === 'page').webSocketDebuggerUrl);
    // The CDP target appears before the extension bootstrap has installed vAPI.
    // Importing its modules too early would execute them out of bootstrap order.
    for (let attempt = 0; attempt < 300; attempt++) {
        if (await background.evaluate(`typeof vAPI!=='undefined' && typeof vAPI.defer?.create==='function'`)) break;
        if (attempt === 299) throw new Error('Full uBO bootstrap did not start');
        await pause(100);
    }
    // A fresh full-uBO profile may compile its bundled lists under heavy host
    // load. Keep a bounded startup watchdog without changing filter inputs.
    const readyAttempts = 1200;
    for (let attempt = 0; attempt < readyAttempts; attempt++) {
        if (await background.evaluate(`(async()=> (await import('./js/background.js')).default.readyToFilter)()`)) break;
        if (attempt + 1 === readyAttempts) throw new Error('Full uBO did not become ready');
        await pause(100);
    }
    // Use identical recorded list bytes in both engines. Updating the extension
    // cache here modifies only the newly created temporary profile.
    await background.evaluate(`(async()=>{
        const u=(await import('./js/background.js')).default;
        const a=(await import('./js/assets.js')).default;
        u.userSettings.autoUpdate=false;
        await u.saveUserFilters('');
        const lists=${JSON.stringify(lists)};
        await u.saveSelectedFilterLists(lists.map(x=>x.name));
        for(const list of lists) await a.put(list.name,list.content);
        await a.remove(/^compiled\\//);
        await u.loadFilterLists();
        return u.selectedFilterLists;
    })()`);
    await background.evaluate(`(async()=> (await import('./js/logger.js')).default.readAll('vox-parity'))()`);
    // Observe the return value of the full extension's existing header filter.
    // The normal logger omits the response headers and phase, while cancelled
    // responses may never reach CDP's responseReceived event. This transparent
    // wrapper preserves the original arguments, return value, and exceptions.
    await background.evaluate(`(async()=>{
        const {PageStore}=await import('./js/pagestore.js');
        globalThis.voxParityHeaderChecks=[];
        const original=PageStore.prototype.filterOnHeaders;
        PageStore.prototype.filterOnHeaders=function(context,...headers){
            const result=Reflect.apply(original,this,[context,...headers]);
            voxParityHeaderChecks.push({
                url:context.url,type:context.type,method:context.getMethodName(),
                docHostname:context.getDocHostname(),tabId:context.tabId,
                phase:'response',response_headers:structuredClone(headers[0]||[]),
                request_headers:structuredClone(headers[1]||[]),
                observed:{blocked:result===1,exception:result===2,rule:context.filter?.raw||''},
            });
            return result;
        };
    })()`);
    await page.send('Page.enable');
    await page.send('Network.enable', options['capture-dir'] ? {maxTotalBufferSize: 128 * 1024 * 1024, maxResourceBufferSize: 16 * 1024 * 1024} : {});
    if (options['capture-dir'] || options['pixel-reference']) {
        await page.send('Emulation.setDeviceMetricsOverride', {width:1024,height:768,deviceScaleFactor:1,mobile:false});
        await page.send('Emulation.setFocusEmulationEnabled', {enabled:true});
    }
    let navigation = null;
    let documentFixture = null;
    let visibility = null;
    let mainFrameID;
    if (!replayInput) {
        const result = await page.send('Page.navigate', { url: options.url });
        mainFrameID = result.frameId;
        if (!result.errorText && (options['capture-dir'] || options['pixel-reference'])
            && !await waitForPixelDocument(page,options.url)) result.errorText = 'Pixel capture document did not complete loading';
        await pause(options.settle * 1000);
        const snapshot = await page.evaluate(`({url:location.href,title:document.title,ready_state:document.readyState,body_text_length:document.body?.innerText.length||0,body_text_sample:document.body?.innerText.slice(0,4000)||'',element_count:document.querySelectorAll('*').length})`);
        navigation = navigationObservation(options.url, result, snapshot, page.events);
    }
    if (fixtureHTML !== null) {
        if (navigation?.coverage !== 'page') throw new Error('The requested live page must load before installing the shared DOM fixture');
        const sourceIDs = await page.evaluate(`(function(html,ids){
            const source=new DOMParser().parseFromString(html,'text/html');
            const elements=Array.from(source.querySelectorAll('[id]'));
            return ids.map(id=>({id,count:elements.filter(element=>element.id===id).length}));
        })(${JSON.stringify(fixtureHTML)},${JSON.stringify(probeIDs)})`);
        if (sourceIDs.some(entry => entry.count !== 1)) {
            throw new Error('Every visibility probe ID must exist exactly once in the original fixture HTML');
        }
        await page.send('Page.setDocumentContent', { frameId: mainFrameID, html: fixtureHTML });
        // Existing full-uBO content-script observers handle the newly inserted
        // fixture. Do not emulate hiding or apply the checker CSS in Brave.
        await pause(2000);
        if (await page.evaluate('location.href') !== navigation.url) throw new Error('Installing the DOM fixture changed the document URL');
        visibility = await page.evaluate(`(${collectVisibility.toString()})(${JSON.stringify(visibilityProbe)})`);
        documentFixture = {
            mode: 'shared synthetic ad-slot fixture at the live site URL',
            file: path.resolve(options['document-fixture']),
            sha256: crypto.createHash('sha256').update(fixtureHTML).digest('hex'),
            probe_file: path.resolve(options['visibility-probe']),
            probe_sha256: crypto.createHash('sha256').update(probeSource).digest('hex'),
            original_ids: sourceIDs,
            observer_settle_ms: 2000,
        };
    }
    const pixelReference = options['pixel-reference']
        ? await capturePixelReference(page, path.resolve(options['pixel-reference']), navigation) : null;
    // Retain the navigation/filter report for inaccessible sites as well. A
    // challenge must fail coverage without replacing a previously valid archive.
    const archive = options['capture-dir'] && navigation?.coverage === 'page'
        ? await captureArchive(page, path.resolve(options['capture-dir']), options.url) : null;
    const documentURL = navigation?.url && /^https?:/.test(navigation.url) ? navigation.url : options.url;
    const raw = await background.evaluate(`(async()=> (await import('./js/logger.js')).default.readAll('vox-parity'))()`);
    const logs = raw.map(JSON.parse).filter(entry => entry.realm === 'network' && /^https?:/.test(entry.url));
    const headerChecks = await background.evaluate('globalThis.voxParityHeaderChecks');
    const networkRequests = page.events.filter(event => event.method === 'Network.requestWillBeSent').map(event => event.params);
    // Redirect logging can emit several records for one request; compare the
    // request once, preserving its document origin and exact browser type.
    const entries = replayInput || [...logs.filter(entry => !hasHeaderFilter(entry.filter)), ...headerChecks];
    const normalizedEntries = entries.filter(entry => /^https?:/.test(entry.url)).map(entry => {
        const browserRequest = networkRequests.find(event => event.request.url === entry.url
            && event.request.method.toLowerCase() === (entry.method || 'get').toLowerCase()
            && event.documentURL && new URL(event.documentURL).hostname === entry.docHostname);
        const request = {
            url: entry.url,
            source_url: entry.source_url ?? browserRequest?.documentURL ?? (entry.docHostname ? `https://${entry.docHostname}/` : options.url),
            request_type: entry.request_type || entry.type,
            method: (entry.method || 'GET').toUpperCase(),
            phase: entry.phase || 'request',
            ...(entry.phase === 'response' ? { response_headers: entry.response_headers || [], request_headers: entry.request_headers || [] } : {}),
        };
        return { request, observed: entry.observed || null, actual: recordedVox ? {
            blocked: entry.blocked, exception: entry.exception,
            rule: entry.rule || '', redirect_url: entry.redirect_url || '', error: entry.error || '',
        } : null };
    });
    const requestMap = new Map(normalizedEntries.map(entry => [requestIdentity(entry.request), entry]));
    const requests = [...requestMap.values()].map(({ request }) => request);
    const expected = await background.evaluate(`(async()=>{
        const engine=(await import('./js/static-net-filtering.js')).default;
        const {FilteringContext}=await import('./js/filtering-context.js');
        return ${JSON.stringify(requests)}.map(r=>{
            const c=new FilteringContext().setURL(r.url).setDocOriginFromURL(r.source_url||r.url).setTabOriginFromURL(${JSON.stringify(documentURL)}).setType(r.request_type);
            c.setMethod(r.method);
            const result=r.phase==='response'
                ? r.request_type==='main_frame' ? 0 : engine.matchHeaders(c,r.response_headers||[],r.request_headers||[])
                : engine.matchRequest(c);
            return {blocked:result===1,exception:result===2,rule:result?engine.toLogData()?.raw||'':''};
        });
    })()`);
    const observed = requests.map(request => {
        if (request.phase === 'response') return requestMap.get(requestIdentity(request)).observed?.blocked ?? null;
        const sourceHostname = new URL(request.source_url || request.url).hostname;
        const records = logs.filter(entry => !hasHeaderFilter(entry.filter) && entry.url === request.url && entry.type === request.request_type
            && entry.docHostname === sourceHostname && (entry.method || 'get').toUpperCase() === request.method);
        return records.length ? records.some(entry => entry.filter?.result === 1 && !entry.filter.modifier) : null;
    });
    const observedFilters = requests.map(request => {
        if (request.phase === 'response') return [requestMap.get(requestIdentity(request)).observed?.rule || ''].filter(Boolean);
        const sourceHostname = new URL(request.source_url || request.url).hostname;
        return logs.filter(entry => !hasHeaderFilter(entry.filter) && entry.url === request.url && entry.type === request.request_type
            && entry.docHostname === sourceHostname && (entry.method || 'get').toUpperCase() === request.method)
            .map(entry => entry.filter ?? null);
    });
    const oracleDisagreements = requests.flatMap((request, index) => observed[index] !== null && observed[index] !== expected[index].blocked
        ? [{ request, observed_blocked: observed[index], replayed: expected[index] }] : []);
    const requestFile = path.join(profile, 'requests.json');
    await fs.writeFile(requestFile, JSON.stringify(requests));
    const actual = recordedVox ? [...requestMap.values()].map(({ actual }) => actual)
        : JSON.parse(execFileSync(options.checker, [requestFile], { cwd: root, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 }));
    if (actual.length !== requests.length) throw new Error('Vox checker returned the wrong number of decisions');
    const mismatches = requests.flatMap((request, i) =>
        actual[i].error || actual[i].blocked !== expected[i].blocked || actual[i].exception !== expected[i].exception
            ? [{ request, expected: expected[i], actual: actual[i] }] : []);
    let cosmeticComparison = null;
    if (!replayInput) {
        const tokens = await page.evaluate(`Array.from(new Set(Array.from(document.querySelectorAll('*')).flatMap(e=>[...(e.id?['#'+e.id]:[]),...Array.from(e.classList||[],c=>'.'+c)])))`);
        const cosmetic = await background.evaluate(`(async()=>{
            const c=(await import('./js/cosmetic-filtering.js')).default;
            const s=(await import('./js/scriptlet-filtering.js')).default;
            const {domainFromHostname}=await import('./js/uri-utils.js');
            const hostname=${JSON.stringify(new URL(documentURL).hostname)};
            const request={hostname,domain:domainFromHostname(hostname),url:${JSON.stringify(documentURL)}};
            c.removeFromSelectorCache(hostname,'cosmetic');
            const specific=c.retrieveSpecificSelectors(request,{dontInject:true});
            const hashToken=token=>{
                const type=token.charCodeAt(0),text=token.slice(1),len=text.length,step=(len+7)>>>3;
                let hash=((type<<5)+type)^len;
                for(let i=0;i<len;i+=step) hash=((hash<<5)+hash)^text.charCodeAt(i);
                return hash&0xFFFFFF;
            };
            const generic=c.retrieveGenericSelectors({tabId:${JSON.stringify(logs[0]?.tabId)},frameId:0,hashes:[...new Set(${JSON.stringify(tokens)}.filter(t=>t.length>1).map(hashToken))],exceptions:specific.exceptionFilters});
            return {css:(specific.injectedCSS||'')+(generic?.injectedCSS?'\\n'+generic.injectedCSS:''),procedural:specific.proceduralFilters||[],filters:s.retrieve(request)?.filters||[]};
        })()`);
        const actualCosmetic = JSON.parse(execFileSync(options.checker, ['--document-filters', documentURL, ...tokens], { cwd: root, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 }));
        // Use Chromium's CSS parser to canonicalize declaration syntax, then split
        // selector lists only at top-level commas (respect :has(), quotes and []),
        // so harmless grouping and ordering differences do not affect the result.
        const cssSets = await page.evaluate(`(function(sources){
            const splitSelectors=text=>{
                const out=[];let start=0,depth=0,quote='',escaped=false;
                for(let i=0;i<text.length;i++){
                    const ch=text[i];
                    if(escaped){escaped=false;continue;}
                    if(ch==='\\\\'){escaped=true;continue;}
                    if(quote){if(ch===quote)quote='';continue;}
                    if(ch==='"'||ch==="'"){quote=ch;continue;}
                    if(ch==='('||ch==='[')depth++;
                    else if(ch===')'||ch===']')depth--;
                    else if(ch===','&&depth===0){out.push(text.slice(start,i).trim());start=i+1;}
                }
                out.push(text.slice(start).trim());return out;
            };
            return sources.map(css=>{
                const sheet=new CSSStyleSheet();sheet.replaceSync(css);
                return [...new Set(Array.from(sheet.cssRules).flatMap(rule=>rule.selectorText?splitSelectors(rule.selectorText).map(selector=>selector+'{'+rule.style.cssText+'}'):[]))].sort();
            });
        })(${JSON.stringify([cosmetic.css, actualCosmetic.css])})`);
        const sameSet = (left, right) => JSON.stringify([...new Set(left)].sort()) === JSON.stringify([...new Set(right)].sort());
        cosmeticComparison = {
            token_count: tokens.length,
            css_rules: cssSets[0].length,
            scriptlet_filters: cosmetic.filters.length,
            css_matches: sameSet(cssSets[0], cssSets[1]),
            procedural_matches: sameSet(cosmetic.procedural, actualCosmetic.procedural),
            scriptlet_filters_match: sameSet(cosmetic.filters, actualCosmetic.filters),
            expected: cosmetic,
            actual: actualCosmetic,
        };
    }
    const capture = {
        captured_at: new Date().toISOString(), url: options.url,
        navigation,
        ...(pixelReference ? {pixel_reference:pixelReference} : {}),
        document_fixture: documentFixture,
        ...(archive ? {archive} : {}),
        visibility,
        input: recordedVox ? { mode: 'recorded-vox-network', file: path.resolve(options['vox-log']) } : requestedCorpus ? { mode: 'fixture-request-stream', file: path.resolve(options.requests) } : { mode: 'live-brave-network' },
        oracle: { browser: execFileSync(options.brave, ['--version'], { encoding: 'utf8' }).trim(), extension: 'uBlock Origin (full, Manifest V2)', version: extensionManifest.version, shields: 'disabled in isolated profile', settings: 'repository-selected lists; identical snapshots; empty user filters', profile: options['profile-template'] ? { kind: 'temporary-copy', template: path.resolve(options['profile-template']) } : { kind: 'fresh-temporary' } },
        engine: manifest.engine,
        lists: manifest.lists.map(({ name, sha256 }) => ({ name, sha256 })),
        counts: { requests: requests.length, blocked: expected.filter(x => x.blocked).length, allowed: expected.filter(x => !x.blocked).length, mismatches: mismatches.length, oracle_disagreements: oracleDisagreements.length },
        network_observation: { request_events: networkRequests.length, ublock_network_log_entries: logs.length, response_header_checks: headerChecks.length, failures: page.events.filter(event => event.method === 'Network.loadingFailed').map(({ params }) => ({ request_id: params.requestId, error: params.errorText, blocked_reason: params.blockedReason || '' })) },
        requests: requests.map((request, i) => ({ ...request, observed_ublock_blocked: observed[i], observed_ublock_filters: observedFilters[i], expected: expected[i], actual: actual[i] })),
        cosmetic: cosmeticComparison, mismatches, oracle_disagreements: oracleDisagreements,
    };
    const expectedByCheck = new Map(requests.map((request, index) => [requestIdentity(request), expected[index]]));
    const actualByCheck = new Map(requests.map((request, index) => [requestIdentity(request), actual[index]]));
    capture.common_stream = summarizeRequestParity(normalizedEntries.map(entry => ({
        ...entry.request,
        actual: entry.actual || actualByCheck.get(requestIdentity(entry.request)),
        expected: expectedByCheck.get(requestIdentity(entry.request)),
    })));
    await fs.mkdir(path.dirname(path.resolve(options.output)), { recursive: true });
    await fs.writeFile(options.output, JSON.stringify(capture, null, 2) + '\n');
    console.log(JSON.stringify({ output: path.resolve(options.output), ...capture.counts, common_stream: { requests: capture.common_stream.distinct_requests, vox_blocked: capture.common_stream.vox.blocked, full_ublock_origin_blocked: capture.common_stream.full_ublock_origin.blocked, matches: capture.common_stream.matches }, ...(visibility ? { visibility: { ...visibility.counts, matches: visibility.matches } } : {}), ...(navigation ? {coverage: navigation.coverage, status: navigation.status, title: navigation.title} : {}), ...(cosmeticComparison ? { css_matches: cosmeticComparison.css_matches, procedural_matches: cosmeticComparison.procedural_matches, scriptlet_filters_match: cosmeticComparison.scriptlet_filters_match } : {}) }));
    if (mismatches.length || oracleDisagreements.length || !capture.common_stream.matches || (visibility && !visibility.matches) || (cosmeticComparison && (!cosmeticComparison.css_matches || !cosmeticComparison.procedural_matches || !cosmeticComparison.scriptlet_filters_match))) process.exitCode = 1;
    else if (!requests.length || (navigation && navigation.coverage !== 'page')) process.exitCode = 2;
} finally {
    background?.close();
    page?.close();
    browser.kill('SIGTERM');
    await new Promise(resolve => {
        if (browser.exitCode !== null || browser.signalCode !== null) { resolve(); return; }
        const force = setTimeout(() => browser.kill('SIGKILL'), 5000);
        browser.once('exit', () => { clearTimeout(force); resolve(); });
    });
    await fs.rm(profile, { recursive: true, force: true });
}
