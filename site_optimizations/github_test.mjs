import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import { buildGithubResources, chunkFactories, withoutGithubResourceReporter, withoutGithubSelectorObserverReporter } from './github_builder.mjs';
import { githubFilters, githubResources } from './github_resources.js';
import { defaultEngine, moduleReferences } from '../tools/adblock/audit_scripts.mjs';

const policy = await buildGithubResources();
const request = url => ({ url, source_url: 'https://github.com/vlang/v', request_type: 'script' });
const factories = source => new Map(chunkFactories(source).map(node => [node.key.name, source.slice(node.start, node.end)]));

test('GitHub resources reproduce from pinned sources and preserve all other chunk factories and exports', async () => {
    assert.equal(githubFilters, '\n' + policy.filters + '\n');
    assert.deepEqual([...githubResources], [...policy.resources]);
    for (const record of policy.reviewed) {
        const replacement = policy.resources.get(record.resource);
        const before = factories(record.source), after = factories(replacement);
        assert.deepEqual([...after.keys()], [...before.keys()]);
        for (const [id, source] of before) if (!record.factories.includes(id)) assert.equal(after.get(id), source, id);
        const originalModule = await moduleReferences(record.source, record.url);
        const replacementModule = await moduleReferences(replacement, record.url);
        assert.deepEqual(replacementModule.exports, originalModule.exports);
        const imports = module => module.imports.map(({ kind, url, specifier }) => ({ kind, target: url ?? specifier }));
        assert.deepEqual(imports(replacementModule), imports(originalModule));
        assert.ok(Buffer.byteLength(replacement) < record.bytes);
    }
});

test('compiled rules redirect only the reviewed GitHub script versions in GitHub documents', async () => {
    const { check } = await defaultEngine();
    for (const record of policy.reviewed) {
        for (const suffix of ['', '?worker_version=42']) {
            const decision = check(request(record.url + suffix));
            assert.equal(decision.error, '');
            assert.equal(decision.blocked, true);
            assert.equal(decodeURIComponent(decision.redirect_url.split(',').slice(1).join(',')), policy.resources.get(record.resource));
        }
        for (const overrides of [{ source_url: 'https://example.org/' }, { request_type: 'main_frame' }, { request_type: 'xmlhttprequest' }]) {
            assert.equal(check({ ...request(record.url), ...overrides }).blocked, false);
        }
        for (const address of [record.url.replace(/-[^-]+\.js$/, '-unknown.js'), record.url.toUpperCase(),
            record.url + '/other.js', record.url.replace('githubassets.com/', 'githubassets.com.evil.test/')]) {
            assert.equal(check(request(address)).blocked, false, address);
        }
    }
    for (const name of ['code-view-5d65cb0f8c6bfda9.js', 'repositories-a438beb69a24b971.js',
        'high-contrast-cookie-19546c435025711b.js', 'codespaces-d62a3027389c6869.js']) {
        assert.equal(check(request('https://github.githubassets.com/assets/' + name)).blocked, false);
    }
    assert.equal(check(request('https://github.com/vlang/v')).blocked, false);
});

function loadFactory(id, dependencies, globals = {}) {
    const source = policy.reviewed.map(record => factories(policy.resources.get(record.resource)).get(id)).find(Boolean);
    const context = vm.createContext(globals);
    const factory = vm.runInContext('({' + source + '})', context)[id];
    const exports = {};
    const require = name => {
        assert.ok(Object.hasOwn(dependencies, name), 'Unexpected dependency: ' + name);
        return dependencies[name];
    };
    require.d = (target, getters, values = {}) => {
        Object.defineProperties(target, Object.fromEntries(Object.entries(getters).map(([name, get]) => [name, { get, enumerable: true }])));
        Object.assign(target, values);
    };
    factory({}, exports, require);
    return exports;
}

test('event and impression sinks install no listeners, timers, collectors or imports', () => {
    assert.deepEqual(Object.keys(loadFactory('dB', {})), []);
    const hydro = loadFactory('XG', {});
    assert.deepEqual(Object.keys(hydro).sort(), ['$3', 'HV', 'Vb']);
    for (const fn of Object.values(hydro)) assert.equal(fn({}), undefined);
    const analytics = loadFactory('D0', {});
    assert.deepEqual(Object.keys(analytics).sort(), ['BI', 'Ti', 'lA', 'zQ']);
    for (const name of ['BI', 'lA', 'zQ']) assert.equal(analytics[name]('click', { key: 'value' }), undefined);
    assert.equal(JSON.stringify(analytics.Ti({ a: 1, b: 'two' })), '{"a":"1","b":"\\"two\\""}');
});

test('metrics sinks preserve app identity, staff and automation helpers without collection side effects', () => {
    const flags = [];
    const metrics = loadFactory('m', {
        F: { g5: () => 'navigation-1' },
        u: { XC: { head: { querySelector: selector => selector.includes('user-staff') ? { content: '1' } : null } } },
        vK: { G7: key => { flags.push(key); return true; } },
        d: { H: () => true },
        Bu: { fX: () => 'repository' },
    });
    assert.deepEqual(Object.keys(metrics).sort(), ['Tq', 'UR', 'Xl', 'au', 'gZ', 'iv', 'kO', 'sV']);
    assert.equal(metrics.gZ(), 'repository');
    metrics.UR('code-view', 'navigation-2');
    assert.equal(metrics.gZ(), 'code-view');
    assert.equal(metrics.Xl(), true);
    assert.equal(metrics.Tq(), true);
    assert.equal(metrics.Tq(), true);
    assert.deepEqual(flags, ['suppress_automated_browser_vitals']);
    assert.equal(metrics.sV(), false);
    for (const name of ['au', 'iv', 'kO']) assert.equal(metrics[name]({ name: 'metric', value: 1 }), undefined);
});

test('resource telemetry removal preserves fetch nonce and defensive DOM setup', async () => {
    const calls = [];
    class Node {
        removeChild(child) { calls.push('remove'); return child; }
        insertBefore(child) { calls.push('insert'); return child; }
    }
    const response = { ok: true, headers: { get: () => 'nonce' } };
    const fetch = async () => response;
    const window = { fetch, addEventListener() { throw Error('Unexpected telemetry listener'); } };
    const document = { documentElement: { hasAttribute: () => false } };
    const dependencies = { B: {}, f: {}, K: { Bb: () => calls.push('init') },
        WN: { $r: nonce => calls.push(nonce), pS: () => calls.push('nonce-setup') },
        u: { cg: window }, m: { iv() {}, au() {} }, j: { kt: () => ({}) },
        E: { kt: () => calls.push('request-setup') }, D0: { BI() { throw Error('Unexpected telemetry'); } } };
    assert.deepEqual(Object.keys(loadFactory('L', dependencies, { window, document, fetch, Node,
        PerformanceObserver: class { constructor() { throw Error('Unexpected resource collector'); } } })), []);
    assert.deepEqual(calls, ['init', 'nonce-setup', 'request-setup']);
    assert.equal(await window.fetch('https://github.com/vlang/v'), response);
    assert.equal(calls.at(-1), 'nonce');
    const parent = new Node();
    const child = { parentNode: parent };
    assert.equal(parent.removeChild(child), child);
    assert.equal(calls.at(-1), 'remove');
    assert.equal(parent.insertBefore(child, child), child);
    assert.equal(calls.at(-1), 'insert');
    const count = calls.length;
    assert.equal(parent.removeChild({ parentNode: null }).parentNode, null);
    assert.equal(parent.insertBefore(child, { parentNode: null }), child);
    assert.equal(calls.length, count);
    const core = policy.reviewed.find(record => record.url.includes('/core-'));
    const original = chunkFactories(core.source).find(factory => factory.key.name === 'L');
    const changed = withoutGithubResourceReporter(core.source, original);
    const untouched = core.source.slice(original.start, original.end);
    const at = untouched.indexOf('function(){if("u"<typeof PerformanceObserver');
    assert.equal(changed, untouched.slice(0, at) + 'void 0}}');
});

test('selector telemetry removal preserves observer registration, callbacks and abort', () => {
    const flags = [], calls = [], selectors = [];
    class Element {}
    const document = { nodeType: 9, readyState: 'complete', defaultView: { Element },
        documentElement: { addEventListener() {} },
        createElement: () => ({ setAttribute() {} }),
        querySelector() { throw Error('Unexpected route telemetry query'); } };
    const observer = loadFactory('vs', {
        ua: { A: class { add(selector) { selectors.push(selector); } remove(selector) { calls.push(selector); } } },
        vK: { G7: key => { flags.push(key); return true; } },
        D0: { BI() { throw Error('Unexpected selector telemetry'); } },
    }, { window: { document }, document, MutationObserver: class { observe() {} disconnect() {} } });
    const result = { add() {}, remove() {} };
    const registered = observer.l('.example', function (...args) {
        assert.equal(this, undefined);
        calls.push(args);
        return result;
    });
    assert.deepEqual(selectors, ['.example']);
    assert.equal(registered.initialize('element', 42), result);
    assert.deepEqual(calls, [['element', 42]]);
    registered.abort();
    assert.deepEqual(calls, [['element', 42], '.example']);
    assert.deepEqual(flags, []);
    const core = policy.reviewed.find(record => record.url.includes('/core-'));
    const factory = chunkFactories(core.source).find(node => node.key.name === 'vs');
    const original = core.source.slice(factory.start, factory.end);
    const changed = withoutGithubSelectorObserverReporter(core.source, factory);
    const start = original.indexOf('!function(e){if(!(0,g.G7)("selector_observer_stats"))');
    const end = original.indexOf('}(e),t(...n)', start) + '}(e)'.length;
    assert.equal(changed, original.slice(0, start) + 'void 0' + original.slice(end));
});
