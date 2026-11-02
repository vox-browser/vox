import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import vm from 'node:vm';
import { gunzipSync } from 'node:zlib';
import test from 'node:test';
const code = gunzipSync(await fs.readFile(new URL('../../adblock/engine.js.gz', import.meta.url))).toString();
const nativeSnapshot = await fs.readFile(new URL('../../adblock/engine.snapshot.bin', import.meta.url));
const bytes = nativeSnapshot.subarray(16);
const metadata = gunzipSync(await fs.readFile(new URL('../../adblock/engine.snapshot.json.gz', import.meta.url))).toString();
function engine(custom, nativeClone = false, eager = false) {
    const context = vm.createContext({ sourceBytes: Uint8Array.from(bytes), metadata,
        voxAdblockEagerSnapshotTables:eager });
    vm.runInContext('globalThis.voxAdblockReadSnapshotMetadata=()=>JSON.parse(metadata);',context);
    vm.runInContext('globalThis.voxAdblockSnapshotBytes=new Uint8Array(sourceBytes);delete globalThis.sourceBytes;', context);
    if (nativeClone) vm.runInContext('globalThis.cloneCalls=0;globalThis.voxAdblockCloneSnapshotView=view=>{cloneCalls++;return new view.constructor(view);};', context);
    // Exercise the Web API polyfills and the no-host checksum fallback.
    vm.runInContext(code, context);
    const info = JSON.parse(context.voxAdblockInitialize(custom));
    return { context, info, check: request => JSON.parse(context.voxAdblockCheck(request)) };
}

test('default matching stays parser-free and custom filters load the original parser', async () => {
    const defaults = engine();
    assert.equal(typeof defaults.context.voxAdblockParser, 'undefined');
    assert.equal(defaults.check({url:'https://news.ycombinator.com/',source_url:'https://news.ycombinator.com/',request_type:'main_frame'}).blocked,false);
    for (const origin of ['https://news.ycombinator.com','http://127.0.0.1:54321']) {
        for (const [path,type] of [['/hn.js?Z6eHuL4AiZDrSCqdz7DG','script'],['/news.css?Z6eHuL4AiZDrSCqdz7DG','stylesheet'],['/triangle.svg','image']])
            defaults.check({url:origin+path,source_url:origin+'/',request_type:type});
    }
    const archive=JSON.parse(await fs.readFile(new URL('../../Tests/Browser/Brave/hn-home-instructions/manifest.json',import.meta.url)));
    for(const [url,response] of Object.entries(archive.responses)) {
        const type=url.includes('.css')?'stylesheet':url.includes('.js')?'script':url.endsWith('/')?'main_frame':'image';
        defaults.context.voxAdblockCheckResponse({url,source_url:archive.url,request_type:type},response.headers);
    }
    assert.equal(typeof defaults.context.voxAdblockParser, 'undefined');
    defaults.context.voxDocumentFilters('https://news.ycombinator.com/', ['.title','.content','#hnmain']);
    defaults.context.voxAdblockInitialize('||metrics.example^$script\n##.advert');
    assert.equal(typeof defaults.context.voxAdblockParser.AstFilterParser, 'function');
    assert.equal(defaults.check({url:'https://metrics.example/ad.js',source_url:'https://news.ycombinator.com/',request_type:'script'}).blocked,true);
});

test('lazy tables preserve complete eager cosmetic, scriptlet and request decisions across the site corpus', async () => {
    const lazy = engine(), eager = engine(undefined, false, true);
    const fixture = JSON.parse(await fs.readFile(new URL('./fixtures/popular-sites.json', import.meta.url)));
    const sites = [...fixture.sites.map(site => site.url), 'https://news.ycombinator.com/',
        'https://www.theverge.com/', 'https://pikabu.ru/', 'https://www.youtube.com/watch?v=test'];
    for (const url of sites) {
        for (const tokens of [[], ['.ad-banner','#advertisement','.ads','.sponsor'], ['.title','.content','#hnmain']]) {
            assert.deepEqual(JSON.parse(JSON.stringify(lazy.context.voxDocumentFilters(url,tokens))),
                JSON.parse(JSON.stringify(eager.context.voxDocumentFilters(url,tokens))), url);
        }
    }
    for (const request of fixture.requests) assert.deepEqual(lazy.check(request),eager.check(request));
});

test('native snapshot clones preserve full request decisions and repeated default restoration', async () => {
    const fallback = engine();
    const native = engine(undefined, true);
    assert.ok(native.context.cloneCalls >= 7);
    const fixture = JSON.parse(await fs.readFile(new URL('./fixtures/theverge.json', import.meta.url)));
    for (const request of fixture.requests) assert.deepEqual(native.check(request), fallback.check(request));
    native.context.voxAdblockInitialize('||advert.example^');
    assert.equal(native.check({url:'https://advert.example/ad.js',source_url:'https://example.com/',request_type:'script'}).blocked, true);
    native.context.voxAdblockInitialize();
    for (const request of fixture.requests) assert.deepEqual(native.check(request), fallback.check(request));
    assert.deepEqual(JSON.parse(JSON.stringify(native.context.voxDocumentFilters(fixture.url, ['.ad-banner']))),
        JSON.parse(JSON.stringify(fallback.context.voxDocumentFilters(fixture.url, ['.ad-banner']))));
});

test('bundled snapshot retains the recorded full-uBO Brave request decisions', async () => {
    const fixture = JSON.parse(await fs.readFile(new URL('./fixtures/theverge.json', import.meta.url)));
    const { info, check } = engine();
    const manifest = JSON.parse(await fs.readFile(new URL('../../adblock/lists/manifest.json', import.meta.url)));
    assert.equal(info.list_count, manifest.lists.length);
    for (const recorded of fixture.lists) assert.ok(manifest.lists.some(list => list.name === recorded.name && list.sha256 === recorded.sha256));
    assert.ok(info.filter_count > 250000);
    for (const request of fixture.requests) {
        const result = check(request);
        assert.equal(result.error, '');
        assert.deepEqual({ blocked: result.blocked, exception: result.exception, rule: result.rule }, request.expected, request.url);
    }
    assert.equal(check({ url: 'https://securepubads.g.doubleclick.net/tag/js/gpt.js', source_url: fixture.url, request_type: 'script' }).blocked, true);
});

test('default cosmetics, generic exceptions and scriptlet decisions survive native-data restore', () => {
    const { context } = engine();
    const filters = context.voxDocumentFilters('https://www.theverge.com/', ['.ad-banner']);
    assert.match(filters.css, /div\[data-concert\]/);
    assert.match(filters.css, /\.duet--layout--rail/);
    assert.ok(filters.filters.some(rule => rule.includes('abort-current-script')));
    assert.ok(filters.filters.some(rule => rule.includes('csg_uid')));
    assert.ok(filters.filters.some(rule => rule.includes('vmidv1')));
    assert.match(filters.scriptlets, /const scriptletGlobals =/);
    vm.runInNewContext(filters.scriptlets, { console: { error() {} } });
    const custom = engine('##.advert\nexample.test##.specific\n@@||example.test^$generichide');
    const customFilters = custom.context.voxDocumentFilters('https://example.test/', ['.advert']);
    assert.doesNotMatch(customFilters.css, /\.advert/);
    assert.match(customFilters.css, /\.specific/);
});

test('custom filters compile normally and repeated default restores get fresh mutable engine data', () => {
    const initial = engine();
    const baseline = initial.check({ url: 'https://securepubads.g.doubleclick.net/tag/js/gpt.js', source_url: 'https://www.theverge.com/', request_type: 'script' });
    const raw = '||advert.example^$third-party,script,domain=theverge.com\n@@||advert.example/allowed.js$script\n||important.example^$important\n@@||important.example^\n||disabled.example^\n||disabled.example^$badfilter\n||first.example^$first-party\n/collect\\d+/$xmlhttprequest\n||redirect.example^$script,redirect=noop.js\n||query.example^$removeparam=tracking\n##.advert\n##.allowed\nexample.test#@#.allowed\nexample.test##.specific';
    initial.context.voxAdblockInitialize(raw);
    const cases = [
        ['https://advert.example/ad.js','https://www.theverge.com/','script',true],
        ['https://advert.example/allowed.js','https://www.theverge.com/','script',false],
        ['https://advert.example/ad.js','https://other.example/','script',false],
        ['https://advert.example/ad.png','https://www.theverge.com/','image',false],
        ['https://important.example/ad.js','https://www.theverge.com/','script',true],
        ['https://disabled.example/ad.js','https://www.theverge.com/','script',false],
        ['https://first.example/ad.js','https://sub.first.example/','script',true],
        ['https://first.example/ad.js','https://www.theverge.com/','script',false],
        ['https://metrics.example/collect123/','https://www.theverge.com/','xmlhttprequest',true],
    ];
    for (const [url, source_url, request_type, blocked] of cases) {
        const result = initial.check({ url, source_url, request_type });
        assert.equal(result.error, ''); assert.equal(result.blocked, blocked, url);
    }
    assert.equal(initial.check({url:'https://advert.example/allowed.js',source_url:'https://www.theverge.com/',request_type:'script'}).exception,true);
    assert.match(initial.check({url:'https://redirect.example/ad.js',source_url:'https://www.theverge.com/',request_type:'script'}).redirect_url,/^data:/);
    assert.equal(initial.check({url:'https://query.example/article?tracking=id&content=story',source_url:'https://www.theverge.com/',request_type:'xmlhttprequest'}).redirect_url,'https://query.example/article?content=story');
    const cosmetic=initial.context.voxDocumentFilters('https://example.test/',['.advert','.allowed']);
    assert.match(cosmetic.css,/\.advert/); assert.match(cosmetic.css,/\.specific/); assert.doesNotMatch(cosmetic.css,/\.allowed/);
    for (let index=0;index<2;index++) {
        assert.deepEqual(JSON.parse(initial.context.voxAdblockInitialize()),initial.info);
        assert.deepEqual(initial.check({url:'https://securepubads.g.doubleclick.net/tag/js/gpt.js',source_url:'https://www.theverge.com/',request_type:'script'}),baseline);
    }
});


test('restored scriptlet functions and dependencies execute in the page', () => {
    const {context}=engine('example.test##+js(set, voxSentinel, 42)');
    const filters=context.voxDocumentFilters('https://example.test/');
    assert.match(filters.scriptlets,/voxSentinel/);
    const page=vm.createContext({document:{currentScript:{},readyState:'complete'},console,Request,EventTarget,fetch,XMLHttpRequest:class {}});
    vm.runInContext('globalThis.self=globalThis;globalThis.window=globalThis;',page);
    vm.runInContext(filters.scriptlets,page);
    page.document.currentScript=null;
    assert.equal(page.voxSentinel,42);
});
