import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import { installGithubStylesheetAliases } from './github_css.js';
import { buildGithubStylesheetResources } from './github_css_builder.mjs';
import { moduleReferences, defaultEngine } from '../tools/adblock/audit_scripts.mjs';

const policy = await buildGithubStylesheetResources();

function link(url, changes = {}) {
    const attrs = {};
    return Object.defineProperties({ rel: 'stylesheet', href: url, disabled: false, media: 'all',
        sheet: { disabled: false, media: { mediaText: 'all' } },
        getAttribute: key => key === 'href' ? url : attrs[key] ?? null,
        hasAttribute: key => Object.hasOwn(attrs, key),
        removeAttribute: key => { delete attrs[key]; } }, Object.getOwnPropertyDescriptors(changes));
}

function actualRuntime(document) {
    const context = vm.createContext({ document, URL, setTimeout, clearTimeout,
        window: { location: { origin: 'https://github.com' } }, performance: { mark() {} } });
    const source = policy.reviewed.runtime.source.replaceAll('import.meta.url', JSON.stringify(policy.reviewed.runtime.url))
        .replace('export{s as __webpack_require__};', 'globalThis.runtime=s;');
    vm.runInContext(source, context);
    return context.runtime;
}

test('reviewed CSS bodies differ only in their trailing source-map comment', async () => {
    const strip = text => text.replace(/\/\*# sourceMappingURL=[^*]*\*\/\s*$/, '').trimEnd();
    assert.equal(policy.reviewed.pairs.length, 4);
    for (const pair of policy.reviewed.pairs) assert.equal(strip(pair.chunk.source), strip(pair.entry.source));
    assert.deepEqual([...policy.reviewed.primer.source.matchAll(/@layer\s+([^ {;]+)/g)].map(match => match[1]),
        ['primer-react', 'primer.components.IssueLabel']);
    const v = await (await import('node:fs/promises')).readFile(new URL('./initial_stylesheets.v', import.meta.url), 'utf8');
    assert.ok(v.includes(policy.reviewed.primer.url));
});

test('the original CSS loader resolves all four existing sheets without inserting or fetching another link', async () => {
    let insertions = 0;
    const links = Object.values(policy.aliases).map(alias => link(alias.url));
    const document = { getElementsByTagName: name => { assert.equal(name, 'link'); return links; },
        createElement() { insertions++; throw Error('Unexpected duplicate CSS request'); } };
    const runtime = actualRuntime(document);
    const seen = [];
    assert.equal(installGithubStylesheetAliases(runtime, document, policy.aliases, chunk => seen.push(chunk)), true);
    for (const [id, alias] of Object.entries(policy.aliases)) {
        assert.equal(runtime.k(id), alias.filename);
        const pending = [];
        runtime.f.css(id, pending);
        await Promise.all(pending);
    }
    assert.equal(insertions, 0);
    assert.deepEqual(seen.sort(), Object.keys(policy.aliases).sort().flatMap(id => [id, id]));
});

test('disabled, conditional, pending, missing and unreadable sheets keep the original request', () => {
    const [id, alias] = Object.entries(policy.aliases)[0];
    for (const changes of [{ disabled: true }, { media: 'print' }, { sheet: null },
        { sheet: { disabled: true, media: { mediaText: 'all' } } },
        { sheet: { disabled: false, media: { mediaText: 'print' } } },
        { hasAttribute: () => true }, { href: alias.url + '?changed=1' },
        { get sheet() { throw Error('Unavailable CSSOM'); } }]) {
        const document = { getElementsByTagName: () => [link(alias.url, changes)] };
        const runtime = { k: () => alias.chunk };
        installGithubStylesheetAliases(runtime, document, policy.aliases);
        assert.equal(runtime.k(id), alias.chunk);
    }
});

test('unreviewed chunk names and original call semantics remain unchanged', () => {
    const [id] = Object.keys(policy.aliases);
    let receiver, args;
    const runtime = { k(...values) { receiver = this; args = values; return 'new-version.css'; } };
    installGithubStylesheetAliases(runtime, {}, policy.aliases);
    assert.equal(runtime.k(id, 42), 'new-version.css');
    assert.equal(receiver, runtime);
    assert.deepEqual(args, [id, 42]);
    assert.equal(installGithubStylesheetAliases({}, {}, policy.aliases), false);
});

test('the loader redirect retains its public export and leaves the original runtime query unredirected', async () => {
    const replacement = [...policy.resources.values()][0];
    const originalModule = await moduleReferences(policy.reviewed.runtime.source, policy.reviewed.runtime.url);
    const module = await moduleReferences(replacement, policy.reviewed.runtime.url);
    assert.deepEqual(module.exports, originalModule.exports);
    assert.equal(module.imports.length, 1);
    assert.equal(module.imports[0].url, policy.originalURL);
    const { check } = await defaultEngine();
    const request = { source_url: 'https://github.com/vlang/v', request_type: 'script', url: policy.reviewed.runtime.url };
    assert.equal(check(request).blocked, true);
    assert.equal(check({ ...request, url: policy.originalURL }).blocked, false);
    assert.equal(check({ ...request, source_url: 'https://example.org/' }).blocked, false);
    assert.equal(check({ ...request, request_type: 'stylesheet' }).blocked, false);
    assert.equal(check({ ...request, url: request.url.replace('b3589eeb1e6a309e', 'unknown') }).blocked, false);
});
