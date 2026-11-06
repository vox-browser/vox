import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import { gunzipSync } from 'node:zlib';
import test from 'node:test';
import { defaultEngine, moduleReferences } from './audit_scripts.mjs';
import { siteResources } from './site_resources.js';

const root = new URL('../../Tests/Browser/Brave/archives/chatgpt-home-20261104-v2/archive/', import.meta.url);
const manifest = JSON.parse(await fs.readFile(new URL('manifest.json', root)));
const live = JSON.parse(gunzipSync(await fs.readFile(new URL('./fixtures/chatgpt-telemetry-20261106.json.gz', import.meta.url))));
const base = 'https://chatgpt.com/unauth-mweb/assets/';
const reviewed = [
    ['analytics-ces-business-context-DAjYxggM.js', 'vox-chatgpt-business.js',
        'e4060078e4780dc9ec7b89b3c63d784694f687cf304fca09316ff4288436323a'],
    ['native-performance-bootstrap-DnIgxW1S.js', 'vox-chatgpt-performance.js',
        '2828a2de7a626bb9344f76763d60241e4b5fe806967dc33126cc582207d696c4'],
    ['analytics-ces-business-context-Bx7D-YTR.js', 'vox-chatgpt-business.js',
        '382361615a2984ce9fd8caa12f8e581a60ad6e0375e87b4b194143b3a63ed5c5'],
    ['native-performance-bootstrap-_6lrVRz4.js', 'vox-chatgpt-performance-20261106.js',
        '78cb5cb3156d9ce5ce20f7c92c4d18e4c9aede2032415f93696b3c46fb871cc7'],
];
const request = (url, extra = {}) => ({url, source_url: 'https://chatgpt.com/', request_type: 'script', ...extra});
const dataURL = text => 'data:text/javascript;base64,' + Buffer.from(text).toString('base64');

test('compiled default uBO rules replace only reviewed ChatGPT scripts, including worker versions', async () => {
    const {check} = await defaultEngine();
    for (const [filename, resource] of reviewed) for (const suffix of ['', '?worker_version=123']) {
        const decision = check(request(base + filename + suffix));
        assert.equal(decision.error, '');
        assert.equal(decision.blocked, true);
        assert.ok(decision.rule.includes('chatgpt'));
        assert.match(decision.redirect_url, /^data:text\/javascript,/);
        assert.equal(decodeURIComponent(decision.redirect_url.split(',').slice(1).join(',')), siteResources.get(resource));
    }
    for (const [filename] of reviewed) {
        for (const extra of [{request_type:'main_frame'}, {request_type:'xmlhttprequest'},
            {source_url:'https://example.org/'}]) {
            assert.equal(check(request(base + filename, extra)).blocked, false);
        }
        for (const url of [base + filename.replace(/-[^-]+\.js$/, '-unknown.js'),
            base + filename.toUpperCase(),
            base + filename + '/unreviewed.js',
            base.replace('chatgpt.com/', 'chatgpt.com.evil.test/') + filename]) {
            assert.equal(check(request(url)).blocked, false);
        }
    }
});

test('login, submission, streaming and native lifecycle remain available', async () => {
    const {check} = await defaultEngine();
    for (const [path, type, method] of [
        ['auth/login_with', 'main_frame', 'GET'],
        ['unauth-mweb/conversation', 'main_frame', 'POST'],
        ['backend-api/conversation', 'xmlhttprequest', 'POST'],
        ['backend-api/sentinel/chat-requirements', 'xmlhttprequest', 'POST'],
        ['unauth-mweb/assets/native-telemetry-CLXxBfSg.js', 'script', 'GET'],
        ['unauth-mweb/assets/page-load-performance-CGytc5Xs.js', 'script', 'GET'],
    ]) assert.equal(check(request('https://chatgpt.com/' + path, {request_type:type,method})).blocked, false, path);
});

test('replacement exports match the sealed, reviewed originals and remove collection dependencies', async () => {
    for (const [filename, resource, sha256] of reviewed) {
        const entry = manifest.responses[base + filename] || live.responses.find(r => r.url === base + filename);
        assert.equal(entry.sha256, sha256);
        const original = entry.source ? Buffer.from(entry.source) : await fs.readFile(new URL('bodies/' + sha256, root));
        assert.equal(crypto.createHash('sha256').update(original).digest('hex'), sha256);
        const before = await moduleReferences(original.toString(), base + filename);
        const after = await moduleReferences(siteResources.get(resource), base + filename);
        assert.deepEqual(after.exports, before.exports);
        const dependency = before.imports.find(i => i.url?.includes('/page-load-performance-'));
        assert.ok(after.imports.every(i => i.kind === 'static' && i.url === dependency?.url));
        assert.ok(Buffer.byteLength(siteResources.get(resource)) < original.length);
    }
});

test('business event replacement is a callable ES module with no collection side effects', async () => {
    const module = await import(dataURL(siteResources.get('vox-chatgpt-business.js')));
    assert.equal(module.reportCesBusinessEvent({kind:'conversation_turn_started'}), undefined);
});

test('performance replacement drains initial metrics, installs sinks and completes without retries', async () => {
    const state = {drains:0, reports:[], abandoners:[]};
    globalThis.voxSiteResourceTest = state;
    try {
        const dependency = dataURL(`
            export function takeInitialLongTaskMetrics() { globalThis.voxSiteResourceTest.drains++; }
            export function setPageLoadPerformanceMeasurementReporter(fn) { globalThis.voxSiteResourceTest.reports.push(fn); }
        `);
        const source = siteResources.get('vox-chatgpt-performance.js').replace(base + 'page-load-performance-CGytc5Xs.js', dependency);
        const module = await import(dataURL(source));
        const options = {canStart:()=>true, setPerformanceCollectionAbandoner:fn=>state.abandoners.push(fn)};
        const result = module.startOctanePerformanceMetrics(options);
        assert.equal(state.drains, 0, 'keep the original asynchronous contract');
        assert.equal(await result, true);
        assert.equal(state.drains, 1);
        assert.equal(state.reports.length, 1);
        assert.equal(state.reports[0]({kind:'long-task'}), undefined);
        assert.equal(state.abandoners.length, 1);
        assert.equal(state.abandoners[0](), undefined);
        assert.equal(await module.startOctanePerformanceMetrics({...options, canStart:()=>false}), false);
        assert.equal(state.drains, 1, 'inactive documents do not start collection');
        assert.equal(state.abandoners.length, 1);
    } finally { delete globalThis.voxSiteResourceTest; }
});
