// Audit saved scripts without executing author code or downloading resources.
import fs from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import { gunzipSync } from 'node:zlib';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const lexerPath = path.join(root, 'browserjs/vendor/es-module-lexer-1.7.0/lexer.asm.js');
const lexer = await import('data:text/javascript;base64,' + (await fs.readFile(lexerPath)).toString('base64'));
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const hints = /(?:^|[-_.\/])(analytics|telemetry|tracking|tracker|sentry|statsig|datadog|segment)(?:[-_.\/]|$)/i;

export function trackingHint(address) {
    const url = new URL(address);
    let text = url.hostname + url.pathname;
    try { text = decodeURIComponent(text); } catch { /* Retain malformed escapes verbatim. */ }
    return text.match(hints)?.[1].toLowerCase() ||
        (/(?:^|[-_.\/])performance[-_.]metrics(?:[-_.\/]|$)/i.test(text) ? 'performance_metrics' : null) ||
        (/\/events\/(?:business|performance|statsc\/flush)\/?$/i.test(url.pathname) ? 'event_endpoint' : null);
}

function fetchURL(address) {
    const url = new URL(address);
    url.hash = '';
    return url.href;
}

export async function moduleReferences(source, address) {
    const [imports, exports] = await lexer.parse(source, address);
    return {
        imports: imports.filter(entry => entry.d !== -2).map(entry => {
            // Bare specifiers require the document's import map. Computed
            // imports likewise cannot be resolved from the saved file alone.
            const specifier = typeof entry.n === 'string' ? entry.n : null;
            const resolvable = specifier !== null && /^(?:\.{0,2}\/|[a-z][a-z\d+.-]*:)/i.test(specifier);
            return { specifier, kind: entry.d === -1 ? 'static' : 'dynamic',
                url: resolvable ? new URL(specifier, address).href : null };
        }),
        exports: exports.map(entry => typeof entry === 'string' ? entry : entry.n),
    };
}

export async function defaultEngine() {
    const files = ['adblock/engine.js.gz', 'adblock/engine.snapshot.bin',
        'adblock/engine.snapshot.json.gz', 'adblock/lists/manifest.json'];
    const bodies = await Promise.all(files.map(name => fs.readFile(path.join(root, name))));
    const context = vm.createContext({ sourceBytes: Uint8Array.from(bodies[1].subarray(16)),
        metadata: gunzipSync(bodies[2]).toString() });
    vm.runInContext('globalThis.voxAdblockReadSnapshotMetadata=()=>JSON.parse(metadata);' +
        'globalThis.voxAdblockSnapshotBytes=new Uint8Array(sourceBytes);delete globalThis.sourceBytes;', context);
    vm.runInContext(gunzipSync(bodies[0]).toString(), context);
    const info = JSON.parse(context.voxAdblockInitialize());
    return { info, inputs: Object.fromEntries(files.map((name, i) => [name, digest(bodies[i])])),
        check: request => JSON.parse(context.voxAdblockCheck(request)) };
}

function checkDecision(check, request) {
    const decision = check(request);
    if (decision.error || typeof decision.blocked !== 'boolean' || typeof decision.exception !== 'boolean') {
        throw new Error('Filter evaluation failed for ' + request.url + ': ' + JSON.stringify(decision));
    }
    return decision;
}

export async function auditArchive(archive, check, requests = []) {
    const manifestBytes = await fs.readFile(path.join(archive, 'manifest.json'));
    const manifest = JSON.parse(manifestBytes);
    const document = new URL(manifest.url).href;
    if (!['http:', 'https:'].includes(new URL(document).protocol) || manifest.version !== 1 ||
        !manifest.responses || typeof manifest.responses !== 'object') throw new Error('Invalid page archive');
    const inputs = { 'manifest.json': digest(manifestBytes) }, scripts = [];
    for (const [address, response] of Object.entries(manifest.responses)) {
        const url = new URL(address);
        const mime = response.headers?.find(header => header.name.toLowerCase() === 'content-type')?.value || '';
        if (!/\.(?:m?js)$/i.test(url.pathname) && !/(?:java|ecma)script/i.test(mime)) continue;
        if (!['http:', 'https:'].includes(url.protocol) || !/^[a-f0-9]{64}$/.test(response.sha256)) {
            throw new Error('Invalid script archive entry: ' + address);
        }
        const bytes = await fs.readFile(path.join(archive, 'bodies', response.sha256));
        if (digest(bytes) !== response.sha256 || bytes.length !== response.bytes) {
            throw new Error('Changed archived script: ' + address);
        }
        inputs['bodies/' + response.sha256] = response.sha256;
        const decision = checkDecision(check, { url: address, source_url: document, request_type: 'script', method: 'GET' });
        const row = { url: address, sha256: response.sha256, bytes: bytes.length,
            name_hint: trackingHint(address), decision, imports: [], exports: [],
            static_importers: [], dynamic_importers: [] };
        try { Object.assign(row, await moduleReferences(bytes.toString(), address)); }
        catch (error) { row.parse_error = error.message; }
        scripts.push(row);
    }
    scripts.sort((a, b) => a.url.localeCompare(b.url));
    const byURL = new Map(scripts.map(row => [fetchURL(row.url), row]));
    for (const row of scripts) for (const entry of row.imports) {
        const target = entry.url && byURL.get(fetchURL(entry.url));
        if (target) {
            const importers = target[entry.kind + '_importers'];
            if (!importers.includes(row.url)) importers.push(row.url);
        }
    }
    for (const row of scripts) {
        row.static_importers.sort(); row.dynamic_importers.sort();
        row.action = row.decision.blocked
            ? row.decision.redirect_url ? 'existing_replacement' : 'existing_block'
            : row.decision.exception ? 'existing_exception' : 'review_only';
        row.skip_safety = row.decision.blocked ? 'existing_filter_policy' : 'not_established';
    }
    const grouped = new Map();
    for (const request of requests) {
        if (request.phase === 'response' || typeof request.url !== 'string' || !trackingHint(request.url)) continue;
        const method = request.method || 'GET', type = request.request_type || null;
        const source = request.source_url || document;
        const key = JSON.stringify([request.url, source, method, type]);
        if (grouped.has(key)) { grouped.get(key).observations++; continue; }
        const types = type ? [type] : ['xmlhttprequest', 'ping'];
        grouped.set(key, { url: request.url, source_url: source, method, observations: 1,
            request_type: type, type_policy: type ? 'recorded' : 'probes_only; replay logs do not distinguish Fetch from Beacon',
            decisions: types.map(request_type => ({ request_type,
                ...checkDecision(check, { url: request.url, source_url: source, method, request_type }) })) });
    }
    // Existing block decisions describe policy, not measured savings. Name
    // hints never authorize suppressing a module or replacing its exports.
    return { document, inputs, scripts,
        candidates: scripts.filter(row => row.name_hint || row.decision.blocked).map(row => row.url),
        requests: [...grouped.values()].sort((a, b) => a.url.localeCompare(b.url) || a.method.localeCompare(b.method)),
        totals: { scripts: scripts.length, script_bytes: scripts.reduce((sum, row) => sum + row.bytes, 0),
            blocked_scripts: scripts.filter(row => row.decision.blocked).length,
            blocked_original_bytes: scripts.filter(row => row.decision.blocked).reduce((sum, row) => sum + row.bytes, 0),
            name_candidates: scripts.filter(row => row.name_hint).length,
            parse_errors: scripts.filter(row => row.parse_error).length,
            unresolved_imports: scripts.reduce((sum, row) => sum + row.imports.filter(entry => !entry.url).length, 0) },
        policy: 'Read-only offline audit. Author scripts are parsed, never executed. URL/name hints are review leads, not semantic detection. '
            + 'Exports and static importers expose dependency risks. Unreferenced modules can still be entry points, workers or computed imports. '
            + 'No browser policy changes, generated blocking rules or instruction-saving claim.' };
}

async function main(args) {
    const options = {};
    while (args.length) {
        const name = args.shift();
        if (!['--archive', '--output', '--requests'].includes(name) || !args.length || options[name]) {
            throw new Error('Usage: node tools/adblock/audit_scripts.mjs --archive DIR --output REPORT.json [--requests LOG.jsonl]');
        }
        options[name] = args.shift();
    }
    if (!options['--archive'] || !options['--output']) throw new Error('--archive and --output are required');
    const engine = await defaultEngine();
    let requests = [], logHash;
    if (options['--requests']) {
        const raw = await fs.readFile(options['--requests']); logHash = digest(raw);
        requests = raw.toString().split('\n').filter(Boolean).map(line => JSON.parse(line));
    }
    const archive = path.resolve(options['--archive']);
    const report = await auditArchive(archive, engine.check, requests);
    report.archive = archive;
    report.engine = { ...engine.info, inputs: engine.inputs };
    report.tool_inputs = { 'tools/adblock/audit_scripts.mjs': digest(await fs.readFile(fileURLToPath(import.meta.url))),
        'browserjs/vendor/es-module-lexer-1.7.0/lexer.asm.js': digest(await fs.readFile(lexerPath)) };
    if (logHash) report.request_log = { path: path.resolve(options['--requests']), sha256: logHash };
    // Reject changing files instead of silently auditing mixed inputs.
    for (const [name, hash] of Object.entries(report.inputs)) {
        if (digest(await fs.readFile(path.join(archive, name))) !== hash) throw new Error('Archive changed: ' + name);
    }
    for (const [name, hash] of Object.entries({ ...engine.inputs, ...report.tool_inputs })) {
        if (digest(await fs.readFile(path.join(root, name))) !== hash) throw new Error('Audit input changed: ' + name);
    }
    if (logHash && digest(await fs.readFile(options['--requests'])) !== logHash) throw new Error('Request log changed');
    await fs.writeFile(options['--output'], JSON.stringify(report, null, 2) + '\n', { flag: 'wx' });
    console.log(JSON.stringify(report.totals));
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
    main(process.argv.slice(2)).catch(error => { console.error(error.message); process.exitCode = 1; });
}
