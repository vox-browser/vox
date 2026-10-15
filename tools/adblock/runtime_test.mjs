import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import vm from 'node:vm';
import { gunzipSync } from 'node:zlib';
import test from 'node:test';
const code = gunzipSync(await fs.readFile(new URL('../../adblock/engine.js.gz', import.meta.url))).toString();
const bytes = gunzipSync(await fs.readFile(new URL('../../adblock/engine.snapshot.bin.gz', import.meta.url)));
function engine(custom) {
    const context = vm.createContext({ sourceBytes: Uint8Array.from(bytes) });
    vm.runInContext('globalThis.voxAdblockSnapshotBytes=new Uint8Array(sourceBytes);delete globalThis.sourceBytes;', context);
    // Exercise the Web API polyfills and the no-host checksum fallback.
    vm.runInContext(code, context);
    const info = JSON.parse(context.voxAdblockInitialize(custom));
    return { context, info, check: request => JSON.parse(context.voxAdblockCheck(request)) };
}

test('bundled snapshot retains the recorded full-uBO Brave request decisions', async () => {
    const fixture = JSON.parse(await fs.readFile(new URL('./fixtures/theverge.json', import.meta.url)));
    const { info, check } = engine();
    assert.equal(info.list_count, fixture.lists.length);
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
