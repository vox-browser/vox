// Compare Vox with the full MV2 uBlock Origin extension in an isolated Brave
// profile. Existing profiles are read only to locate the extension's code.
// Requires Node >= 22 (built-in fetch and WebSocket), Brave and full uBO.
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawn, execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const options = {
    brave: '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
    url: 'https://www.theverge.com/',
    output: path.join(root, 'Build/comparisons/adblock-theverge.json'),
    checker: path.join(root, 'Build/adblock-check'),
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
const profile = await fs.mkdtemp(path.join(os.tmpdir(), 'vox-adblock-parity-'));
await fs.mkdir(path.join(profile, 'Default'));
// Disable Brave's separate blocker in this temporary profile, so the oracle is
// full uBlock Origin. No settings, history, cookies or logins are copied.
await fs.writeFile(path.join(profile, 'Default/Preferences'), JSON.stringify({
    profile: { default_content_setting_values: { braveShields: 2 } },
}));
const browser = spawn(options.brave, [
    '--headless=new', '--no-first-run', '--no-default-browser-check', '--disable-sync',
    '--disable-background-networking', '--remote-debugging-port=0', '--remote-allow-origins=*',
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
    for (let attempt = 0; attempt < 300; attempt++) {
        if (await background.evaluate(`(async()=> (await import('./js/background.js')).default.readyToFilter)()`)) break;
        if (attempt === 299) throw new Error('Full uBO did not become ready');
        await pause(100);
    }
    // Use identical recorded list bytes in both engines. Updating the extension
    // cache here modifies only the newly created temporary profile.
    await background.evaluate(`(async()=>{
        const u=(await import('./js/background.js')).default;
        const a=(await import('./js/assets.js')).default;
        u.userSettings.autoUpdate=false;
        const lists=${JSON.stringify(lists)};
        await u.saveSelectedFilterLists(lists.map(x=>x.name));
        for(const list of lists) await a.put(list.name,list.content);
        await a.remove(/^compiled\\//);
        await u.loadFilterLists();
        return u.selectedFilterLists;
    })()`);
    await background.evaluate(`(async()=> (await import('./js/logger.js')).default.readAll('vox-parity'))()`);
    await page.send('Network.enable');
    await page.send('Page.navigate', { url: options.url });
    await pause(options.settle * 1000);
    const raw = await background.evaluate(`(async()=> (await import('./js/logger.js')).default.readAll('vox-parity'))()`);
    const logs = raw.map(JSON.parse).filter(entry => entry.realm === 'network' && /^https?:/.test(entry.url));
    const networkRequests = page.events.filter(event => event.method === 'Network.requestWillBeSent').map(event => event.params);
    // Redirect logging can emit several records for one request; compare the
    // request once, preserving its document origin and exact browser type.
    const requests = [...new Map(logs.map(entry => {
        const browserRequest = networkRequests.find(event => event.request.url === entry.url
            && event.request.method.toLowerCase() === (entry.method || 'get').toLowerCase()
            && event.documentURL && new URL(event.documentURL).hostname === entry.docHostname);
        const request = {
            url: entry.url,
            source_url: browserRequest?.documentURL || (entry.docHostname ? `https://${entry.docHostname}/` : options.url),
            request_type: entry.type,
            method: (entry.method || 'GET').toUpperCase(),
        };
        return [JSON.stringify(request), request];
    })).values()];
    if (requests.length < 10 || !requests.some(r => new URL(r.url).hostname === new URL(options.url).hostname)) {
        throw new Error(`The live page did not produce a useful request corpus (${requests.length} requests)`);
    }
    const expected = await background.evaluate(`(async()=>{
        const engine=(await import('./js/static-net-filtering.js')).default;
        const {FilteringContext}=await import('./js/filtering-context.js');
        return ${JSON.stringify(requests)}.map(r=>{
            const c=new FilteringContext().setURL(r.url).setDocOriginFromURL(r.source_url).setTabOriginFromURL(${JSON.stringify(options.url)}).setType(r.request_type);
            c.setMethod(r.method);
            const result=engine.matchRequest(c);
            return {blocked:result===1,exception:result===2,rule:result?engine.toLogData()?.raw||'':''};
        });
    })()`);
    const observed = requests.map(request => {
        const sourceHostname = new URL(request.source_url).hostname;
        const records = logs.filter(entry => entry.url === request.url && entry.type === request.request_type
            && entry.docHostname === sourceHostname && (entry.method || 'get').toUpperCase() === request.method);
        return records.some(entry => entry.filter?.result === 1 && !entry.filter.modifier);
    });
    const oracleDisagreements = requests.flatMap((request, index) => observed[index] !== expected[index].blocked
        ? [{ request, observed_blocked: observed[index], replayed: expected[index] }] : []);
    const requestFile = path.join(profile, 'requests.json');
    await fs.writeFile(requestFile, JSON.stringify(requests));
    const actual = JSON.parse(execFileSync(options.checker, [requestFile], { cwd: root, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 }));
    if (actual.length !== requests.length) throw new Error('Vox checker returned the wrong number of decisions');
    const mismatches = requests.flatMap((request, i) =>
        actual[i].error || actual[i].blocked !== expected[i].blocked || actual[i].exception !== expected[i].exception
            ? [{ request, expected: expected[i], actual: actual[i] }] : []);
    const tokens = await page.evaluate(`Array.from(new Set(Array.from(document.querySelectorAll('*')).flatMap(e=>[...(e.id?['#'+e.id]:[]),...Array.from(e.classList||[],c=>'.'+c)])))`);
    const cosmetic = await background.evaluate(`(async()=>{
        const c=(await import('./js/cosmetic-filtering.js')).default;
        const s=(await import('./js/scriptlet-filtering.js')).default;
        const {domainFromHostname}=await import('./js/uri-utils.js');
        const hostname=${JSON.stringify(new URL(options.url).hostname)};
        const request={hostname,domain:domainFromHostname(hostname),url:${JSON.stringify(options.url)}};
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
    const actualCosmetic = JSON.parse(execFileSync(options.checker, ['--document-filters', options.url, ...tokens], { cwd: root, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 }));
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
    const cosmeticComparison = {
        token_count: tokens.length,
        css_rules: cssSets[0].length,
        scriptlet_filters: cosmetic.filters.length,
        css_matches: sameSet(cssSets[0], cssSets[1]),
        procedural_matches: sameSet(cosmetic.procedural, actualCosmetic.procedural),
        scriptlet_filters_match: sameSet(cosmetic.filters, actualCosmetic.filters),
        expected: cosmetic,
        actual: actualCosmetic,
    };
    const capture = {
        captured_at: new Date().toISOString(), url: options.url,
        oracle: { browser: execFileSync(options.brave, ['--version'], { encoding: 'utf8' }).trim(), extension: 'uBlock Origin (full, Manifest V2)', version: extensionManifest.version, shields: 'disabled in isolated profile', settings: 'default lists; identical repository snapshots; empty user filters' },
        engine: manifest.engine,
        lists: manifest.lists.map(({ name, sha256 }) => ({ name, sha256 })),
        counts: { requests: requests.length, blocked: expected.filter(x => x.blocked).length, allowed: expected.filter(x => !x.blocked).length, mismatches: mismatches.length, oracle_disagreements: oracleDisagreements.length },
        network_observation: { request_events: networkRequests.length, ublock_network_log_entries: logs.length, failures: page.events.filter(event => event.method === 'Network.loadingFailed').map(({ params }) => ({ request_id: params.requestId, error: params.errorText, blocked_reason: params.blockedReason || '' })) },
        requests: requests.map((request, i) => ({ ...request, observed_ublock_blocked: observed[i], expected: expected[i], actual: actual[i] })),
        cosmetic: cosmeticComparison, mismatches, oracle_disagreements: oracleDisagreements,
    };
    await fs.mkdir(path.dirname(path.resolve(options.output)), { recursive: true });
    await fs.writeFile(options.output, JSON.stringify(capture, null, 2) + '\n');
    console.log(JSON.stringify({ output: path.resolve(options.output), ...capture.counts, css_matches: cosmeticComparison.css_matches, procedural_matches: cosmeticComparison.procedural_matches, scriptlet_filters_match: cosmeticComparison.scriptlet_filters_match }));
    if (mismatches.length || oracleDisagreements.length || !cosmeticComparison.css_matches || !cosmeticComparison.procedural_matches || !cosmeticComparison.scriptlet_filters_match) process.exitCode = 1;
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
