import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import test from 'node:test';
import { parse } from 'acorn';
import { gunzipSync } from 'node:zlib';
import { buildBasicResources } from './build_chatgpt_basic.mjs';
import { basicSiteFilters, basicSiteResources } from './chatgpt_basic_resources.js';
import { defaultEngine, moduleReferences } from './audit_scripts.mjs';

const policy = await buildBasicResources();
const data = source => 'data:text/javascript;base64,' + Buffer.from(source).toString('base64');
const fixture = JSON.parse(gunzipSync(await fs.readFile(new URL('./fixtures/chatgpt-basic-20261106.json.gz', import.meta.url))));
const request = url => ({url, source_url:'https://chatgpt.com/', request_type:'script'});
const namespace = `export function r(values){return Object.defineProperties({},Object.fromEntries(Object.entries(values).map(([key,get])=>[key,{get}])));}`;

function mockImports(source, resolve) {
    const imports = parse(source, {ecmaVersion:'latest', sourceType:'module'}).body.filter(node => node.type === 'ImportDeclaration');
    for (const node of imports.reverse()) {
        source = source.slice(0, node.source.start) + JSON.stringify(data(resolve(node))) + source.slice(node.source.end);
    }
    return source;
}

test('generated basic resources reproduce exactly from pinned sources and retain ES module exports', async () => {
    assert.equal(basicSiteFilters, '\n' + policy.filters + '\n');
    assert.deepEqual([...basicSiteResources], [...policy.resources]);
    for (const record of policy.reviewed) {
        const before = await moduleReferences(record.source, record.url);
        const after = await moduleReferences(policy.resources.get(record.resource), record.url);
        assert.deepEqual(after.exports.sort(), before.exports.sort(), record.url);
        parse(policy.resources.get(record.resource), {sourceType:'module', ecmaVersion:'latest'});
        const localeBytes = record.kind === 'startup'
            ? fixture.releases.find(release => release.version === record.version).modules.locale.bytes : 0;
        assert.ok(Buffer.byteLength(policy.resources.get(record.resource)) < record.bytes + localeBytes || record.kind === 'client');
    }
});

test('compiled filters replace only reviewed script URLs and leave startup fallback and unknown deployments alone', async () => {
    const {check} = await defaultEngine();
    for (const record of policy.reviewed) {
        for (const suffix of ['', '?worker_version=123']) {
            const result = check(request(record.url + suffix));
            assert.equal(result.blocked, true, record.url);
            assert.equal(decodeURIComponent(result.redirect_url.split(',').slice(1).join(',')), policy.resources.get(record.resource));
        }
        for (const extra of [{request_type:'main_frame'}, {request_type:'xmlhttprequest'}, {source_url:'https://example.org/'}]) {
            assert.equal(check({...request(record.url), ...extra}).blocked, false, record.url);
        }
        for (const url of [record.url + '/unreviewed.js', record.url.replace(/-[^-]+\.js$/, '-unreviewed.js'),
            record.url.replace('chatgpt.com/', 'chatgpt.com.evil.test/'), record.url.toUpperCase()]) {
            assert.equal(check(request(url)).blocked, false, url);
        }
        if (record.kind === 'startup') assert.equal(check(request(record.url + '?vox-full=1')).blocked, false);
    }
    for (const release of fixture.releases) assert.equal(check(request(release.modules.locale.url)).blocked, false,
        'Full locale catalogs remain available to deferred features');
});

test('optional surfaces keep callable components, namespaces and disposal contracts without importing their dependencies', async () => {
    for (const record of policy.reviewed.filter(record => ['beacon','trending','product','login','sheet','onetap','cta','tracking'].includes(record.kind))) {
        const source = policy.resources.get(record.resource);
        assert.deepEqual((await moduleReferences(source, record.url)).imports, []);
        const module = await import(data(source));
        if (record.kind === 'sheet') {
            assert.deepEqual(Object.keys(module.a).sort(), ['BottomSheet','BottomSheetExternalContent','BottomSheetFrame','BottomSheetIconButton','mountBottomSheet']);
            assert.equal(module.a.BottomSheet, module.t);
            assert.equal(typeof (await module.i()).dispose, 'function');
        } else if (record.kind === 'onetap') {
            assert.equal(typeof module.installOctaneDesktopOneTap(), 'function');
        } else if (record.kind === 'cta') {
            const value = Object.freeze({imagePickerSkip:Object.freeze({})});
            assert.equal(module.t(value), value);
            assert.equal(typeof module.r(), 'function');
        } else if (record.kind === 'tracking') {
            assert.equal(module.o({name:'Page'}), false);
            assert.equal(module.r([], {}, {}), true);
            assert.equal(module.s('https://example.org/?token=secret'), undefined);
        } else for (const fn of Object.values(module)) assert.equal(fn(), undefined);
    }
});

test('analytics keeps its facade and exploration utilities while admitting no events to collectors', async () => {
    for (const record of policy.reviewed.filter(record => record.kind === 'analytics')) {
        const source = mockImports(policy.resources.get(record.resource), node => {
            if (node.source.value.includes('rolldown-runtime-')) return namespace;
            if (node.source.value.includes('octane-shell-shared-')) return `export function zt(sink){return {track(name,payload){sink({name,payload})}}} ` +
                ['Dr','dr','fr','gr','vr','wr'].map(name => `export function ${name}(){throw Error('collector must not run')}`).join('\n');
            return 'export function r(){return false}';
        });
        const module = await import(data(source));
        assert.equal(module.n.analytics, module.t);
        for (const name of ['Page','conversation_turn_started','ChatgptExploreFeedViewed']) module.t.track(name, {});
        assert.equal(module.s(new URL('https://chatgpt.com/?force_explore_feed=control')), 'control');
        assert.equal(module.l('mixed'), 'mixed');
        assert.equal(module.l('unreviewed'), undefined);
    }
});

test('compact English startup packs retain every original message, digest and stale-pack check', async () => {
    for (const record of policy.reviewed.filter(record => record.kind === 'startup')) {
        const release = fixture.releases.find(release => release.version === record.version);
        const locale = release.modules.locale;
        const original = locale.source ?? await fs.readFile(new URL('../../Tests/Browser/Brave/archives/chatgpt-home-20261104-v2/archive/bodies/' + locale.sha256, import.meta.url), 'utf8');
        const pack = (await import(data(original))).default['app.startup'];
        const module = await import(data(policy.resources.get(record.resource)));
        const packs = await module.default('en-US');
        assert.equal(module.kind, 'locale');
        assert.deepEqual(packs, {'app.startup':pack});
        assert.deepEqual(module.getScopePack(packs, 'app.startup', 'en-US').messages, pack.messages);
        assert.throws(() => module.getScopePack({'app.startup':{...pack,packDigest:'stale'}}, 'app.startup', 'en-US'), /Stale/);
    }
});

test('other startup locales and explicit recovery URLs use the original loader on demand', async () => {
    globalThis.voxLocaleFallbackCalls = [];
    try {
        const record = policy.reviewed.find(record => record.kind === 'startup');
        const fallback = data(`globalThis.voxLocaleFallbackCalls.push('import');export default function(...args){globalThis.voxLocaleFallbackCalls.push(args);return {original:true}} export function getScopePack(...args){return args}`);
        const module = await import(data(policy.resources.get(record.resource).replace(JSON.stringify(record.url + '?vox-full=1'), JSON.stringify(fallback))));
        await module.default('en-US');
        assert.deepEqual(globalThis.voxLocaleFallbackCalls, []);
        assert.deepEqual(await module.default('it-IT', true), {original:true});
        assert.deepEqual(await module.default('en-US', false, 'https://chatgpt.com/recovery.js'), {original:true});
        assert.deepEqual(globalThis.voxLocaleFallbackCalls, ['import',['it-IT',true,undefined],['en-US',false,'https://chatgpt.com/recovery.js']]);
        assert.deepEqual(module.getScopePack({}, 'app.startup', 'it-IT'), [{},'app.startup','it-IT']);
    } finally { delete globalThis.voxLocaleFallbackCalls; }
});

test('locale cache separates startup and deferred packs so later conversation strings can load', async () => {
    for (const record of policy.reviewed.filter(record => record.kind === 'client')) {
        globalThis.voxLocaleCacheTest = {scopes:[], messages:new Map(), loads:[]};
        try {
            const loader = scope => data(`export const kind='locale';export async function defaultLoader(){globalThis.voxLocaleCacheTest.loads.push(${JSON.stringify(scope)});return {${JSON.stringify(scope)}:{scope:${JSON.stringify(scope)},locale:'en-US',catalogDigest:'same',messages:{${JSON.stringify(scope)}:[]}}}}export {defaultLoader as default};export function getScopePack(packs,scope){if(!packs[scope])throw Error('Shared locale cache hid '+scope);return packs[scope]}`);
            let source = policy.resources.get(record.resource)
                .replace(/\.\/app\.startup-[\w-]+\.js/g, loader('app.startup'))
                .replace(/\.\/client-i18n-scopes-[\w-]+\.js/g, loader('deferred.auth'));
            source = mockImports(source, node => {
                if (node.source.value.includes('rolldown-runtime-')) return namespace;
                if (node.source.value.includes('octane-shell-shared-')) return 'export function mn(){throw Error("Unexpected retry")}';
                if (node.source.value.includes('a-CxiQ9aJq')) return 'export function t(load){return load()}';
                return `export function a(){return globalThis.voxLocaleCacheTest.scopes}export function i(){return globalThis.voxLocaleCacheTest}export function o(packs){for(const p of packs){globalThis.voxLocaleCacheTest.scopes.push(p.scope);for(const [k,v] of Object.entries(p.messages))globalThis.voxLocaleCacheTest.messages.set(k,v)}}`;
            });
            const previous = globalThis.document;
            globalThis.document = {documentElement:{lang:'en-US'}};
            try {
                const module = await import(data(source));
                await module.n('en-US', ['app.startup']);
                await module.n('en-US', ['deferred.auth']);
                assert.deepEqual(globalThis.voxLocaleCacheTest.loads, ['app.startup','deferred.auth']);
                assert.deepEqual(globalThis.voxLocaleCacheTest.scopes, ['app.startup','deferred.auth']);
            } finally { globalThis.document = previous; }
        } finally { delete globalThis.voxLocaleCacheTest; }
    }
});
