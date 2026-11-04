import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import test from 'node:test';
import { auditArchive, defaultEngine, moduleReferences, trackingHint } from './audit_scripts.mjs';

const allow = () => ({ blocked: false, exception: false, rule: '', redirect_url: '', error: '' });
async function archive(files, run) {
    const folder = await fs.mkdtemp(path.join(os.tmpdir(), 'vox-script-audit-'));
    const responses = {};
    await fs.mkdir(path.join(folder, 'bodies'));
    for (const [name, code] of Object.entries(files)) {
        const body = Buffer.from(code), sha256 = crypto.createHash('sha256').update(body).digest('hex');
        responses['https://site.test/' + name] = { bytes: body.length, sha256,
            headers: [{ name: 'Content-Type', value: 'text/javascript' }] };
        await fs.writeFile(path.join(folder, 'bodies', sha256), body);
    }
    await fs.writeFile(path.join(folder, 'manifest.json'), JSON.stringify({ version: 1,
        url: 'https://site.test/', responses }));
    try { return await run(folder, responses); }
    finally { await fs.rm(folder, { recursive: true, force: true }); }
}

test('name and endpoint hints are bounded review leads', () => {
    assert.equal(trackingHint('https://cdn.test/analytics-v1.js'), 'analytics');
    assert.equal(trackingHint('https://www.google-analytics.com/ga.js'), 'analytics');
    assert.equal(trackingHint('https://site.test/unauth-mweb/events/performance?x=1'), 'event_endpoint');
    assert.equal(trackingHint('https://site.test/performance-metrics-v1.js'), 'performance_metrics');
    assert.equal(trackingHint('https://site.test/myanalyticsapp.js'), null);
    assert.equal(trackingHint('https://site.test/app.js?file=analytics.js'), null);
    assert.equal(trackingHint('https://site.test/calendar/events/today'), null);
});

test('real module lexer distinguishes code from comments and ordinary strings', async () => {
    const result = await moduleReferences(`// import './fake.js';
        const text="import './also-fake.js'";
        import { track } from './analytics.js'; export { other } from './shared.js';
        import('./optional.js'); import('./' + name); import.meta.url;
        import x from 'mapped-name'; export function ready() {}`,
    'https://site.test/app.js');
    assert.deepEqual(result.exports.sort(), ['other', 'ready']);
    assert.deepEqual(result.imports.map(row => row.url), ['https://site.test/analytics.js',
        'https://site.test/shared.js', 'https://site.test/optional.js', null, null]);
    assert.equal(result.imports[2].kind, 'dynamic');
});

test('analytics module imported by the app is never declared safe to skip', async () => {
    await archive({ 'app.js': `import {track} from './analytics.js#v'; import('./optional.js');`,
        'analytics.js': `export function track() {}`, 'optional.js': `export const ok=1;` }, async folder => {
        const report = await auditArchive(folder, allow);
        const row = report.scripts.find(row => row.name_hint);
        assert.deepEqual(row.static_importers, ['https://site.test/app.js']);
        assert.deepEqual(row.exports, ['track']);
        assert.equal(row.action, 'review_only');
        assert.equal(row.skip_safety, 'not_established');
        assert.deepEqual(report.scripts.find(row => row.url.endsWith('optional.js')).dynamic_importers,
            ['https://site.test/app.js']);
    });
});

test('current blocking, replacements and exceptions stay distinct', async () => {
    await archive({ 'tracker.js': 'export const data=1;', 'analytics.js': 'export const data=2;',
        'allowed-telemetry.js': 'export const data=3;' }, async folder => {
        const report = await auditArchive(folder, request => ({ ...allow(),
            blocked: !request.url.includes('allowed-'), exception: request.url.includes('allowed-'),
            redirect_url: request.url.endsWith('analytics.js') ? 'data:text/javascript,void 0' : '' }));
        assert.equal(report.scripts.find(row => row.url.endsWith('/tracker.js')).action, 'existing_block');
        assert.equal(report.scripts.find(row => row.url.endsWith('/analytics.js')).action, 'existing_replacement');
        assert.equal(report.scripts.find(row => row.url.includes('allowed-')).action, 'existing_exception');
        assert.equal(report.totals.blocked_scripts, 2);
        assert.ok(report.totals.blocked_original_bytes < report.totals.script_bytes);
    });
});

test('author script is parsed without executing it', async () => {
    globalThis.voxAuditExecuted = false;
    await archive({ 'tracking.js': 'globalThis.voxAuditExecuted=true; throw new Error("must not run");' },
        async folder => { await auditArchive(folder, allow); });
    assert.equal(globalThis.voxAuditExecuted, false);
    delete globalThis.voxAuditExecuted;
});

test('unresolvable imports and lexical errors remain visible', async () => {
    await archive({ 'app.js': 'import("./"+name); import x from "bare";',
        'broken.js': 'import "unterminated' }, async folder => {
        const report = await auditArchive(folder, allow);
        assert.equal(report.totals.unresolved_imports, 2);
        assert.equal(report.totals.parse_errors, 1);
    });
});

test('script hash and byte-size mismatches are rejected', async () => {
    await archive({ 'app.js': 'export const ok=1;' }, async (folder, responses) => {
        const response = responses['https://site.test/app.js'];
        await fs.appendFile(path.join(folder, 'bodies', response.sha256), 'modified');
        await assert.rejects(auditArchive(folder, allow), /Changed archived script/);
    });
});

test('filter failures do not become allowed recommendations', async () => {
    await archive({ 'app.js': 'export const ok=1;' }, async folder => {
        await assert.rejects(auditArchive(folder, () => ({ error: 'unavailable' })), /Filter evaluation failed/);
    });
});

test('replay logs use explicit request-type probes, preserve method and count observations', async () => {
    await archive({}, async folder => {
        const request = { url: 'https://site.test/events/business', method: 'POST' };
        const seen = [];
        const report = await auditArchive(folder, request => { seen.push(request); return allow(); },
            [request, request, { ...request, phase: 'response' }]);
        assert.equal(report.requests[0].observations, 2);
        assert.equal(report.requests[0].request_type, null);
        assert.deepEqual(seen.map(row => row.request_type), ['xmlhttprequest', 'ping']);
        assert.ok(seen.every(row => row.method === 'POST'));
    });
});

test('pinned default uBO engine recognizes an existing tracker and allows application scripts', async () => {
    const engine = await defaultEngine();
    const check = (url, request_type = 'script') => engine.check({ url,
        source_url: 'https://www.theverge.com/', request_type, method: 'GET' });
    const tracker = check('https://www.google-analytics.com/analytics.js');
    assert.equal(tracker.error, ''); assert.equal(tracker.blocked, true);
    assert.match(tracker.redirect_url, /^data:/);
    assert.equal(check('https://www.theverge.com/app.js').blocked, false);
});
