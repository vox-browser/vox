// Rewrite reviewed collector factories, retaining the rest of GitHub's chunks.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import { gunzipSync } from 'node:zlib';
import { createRequire } from 'node:module';
const { parse } = createRequire(new URL('../tools/adblock/package.json', import.meta.url))('acorn');

const fixture = new URL('../tools/adblock/fixtures/github-20261108.json.gz', import.meta.url);
const escape = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replaceAll('/', '\\/');
const parseModule = source => parse(source, { sourceType: 'module', ecmaVersion: 'latest' });

export function chunkFactories(source) {
    const declaration = parseModule(source).body.flatMap(node => node.declaration?.declarations ?? [])
        .find(node => node.id.name === '__webpack_modules__');
    if (!declaration || declaration.init.type !== 'ObjectExpression') throw Error('Unreviewed chunk structure');
    return declaration.init.properties;
}

function functions(source, factory, names) {
    return names.map(name => {
        const node = factory.value.body.body.find(node => node.type === 'FunctionDeclaration' && node.id.name === name);
        if (!node) throw Error('Missing reviewed function: ' + name);
        return source.slice(node.start, node.end);
    }).join('\n');
}

// This factory also owns fetch nonces and defensive DOM patches. Remove only
// its final resource-timing reporter; keep every byte of the functional setup.
export function withoutGithubResourceReporter(source, factory) {
    const outer = factory.value.body.body.at(-1);
    const expression = outer?.type === 'IfStatement' && outer.consequent.body.at(-1)?.expression;
    const call = expression?.type === 'SequenceExpression' && expression.expressions.at(-1);
    if (call?.type !== 'CallExpression' || call.callee.type !== 'FunctionExpression') {
        throw Error('Changed GitHub resource reporter structure');
    }
    const reporter = source.slice(call.start, call.end);
    if (!reporter.includes('new PerformanceObserver(') || !reporter.includes('"bundle-stats"')) {
        throw Error('Missing reviewed GitHub resource reporter');
    }
    return source.slice(factory.start, call.start) + 'void 0' + source.slice(call.end, factory.end);
}

// Keep selector-observer's lifecycle and callback wrapper. Its reporting IIFE
// still queries route metadata even when the analytics sink itself is disabled.
export function withoutGithubSelectorObserverReporter(source, factory) {
    const wrapper = factory.value.body.body.find(node => node.type === 'FunctionDeclaration' && node.id.name === '$');
    const callback = wrapper?.body.body[0]?.argument;
    const sequence = callback?.type === 'ArrowFunctionExpression' && callback.body;
    const reporter = sequence?.type === 'SequenceExpression' && sequence.expressions[0];
    const text = reporter && source.slice(reporter.start, reporter.end);
    if (sequence?.expressions?.length !== 2 || reporter?.type !== 'UnaryExpression' ||
        !text.includes('"selector_observer_stats"') || !text.includes('"selector-observer.observe"')) {
        throw Error('Changed GitHub selector observer reporter structure');
    }
    return source.slice(factory.start, reporter.start) + 'void 0' + source.slice(reporter.end, factory.end);
}

export async function buildGithubResources() {
    const { responses } = JSON.parse(gunzipSync(await fs.readFile(fixture)));
    const resources = new Map(), filters = [], reviewed = [];
    for (const record of responses) {
        const { source, url } = record;
        if (Buffer.byteLength(source) !== record.bytes ||
            crypto.createHash('sha256').update(source).digest('hex') !== record.sha256) throw Error('Changed reviewed GitHub source');
        const factories = chunkFactories(source);
        const edits = [];
        for (const factory of factories) {
            const id = factory.key.name;
            let replacement;
            if (url.includes('/core-')) {
                // dB only installs click/impression observers. XG only forwards
                // Hydro events. Neither owns navigation, focus, or hydration.
                if (id === 'dB') replacement = 'dB(e,t,n){}';
                if (id === 'XG') replacement = 'XG(e,t,n){n.d(t,{},{$3(){},HV(){},Vb(){}})}';
                if (id === 'L') replacement = withoutGithubResourceReporter(source, factory);
                if (id === 'vs') replacement = withoutGithubSelectorObserverReporter(source, factory);
            } else if (id === 'D0') {
                // Retain the pure context serializer; acknowledge event calls
                // without batching, timers, listeners, retries or RUM imports.
                replacement = 'D0(e,t,a){a.d(t,{zQ:()=>L,BI:()=>q,lA:()=>x,Ti:()=>$});' +
                    'function L(){} function q(){} function x(){}' + functions(source, factory, ['$']) + '}';
            } else if (id === 'm') {
                // Preserve staff/automation queries and the current app name.
                // Metrics and RUM sinks need no metric catalog or observers.
                replacement = 'm(e,t,a){let n;' +
                    'a.d(t,{gZ:()=>C,Tq:()=>T,sV:()=>S,Xl:()=>$,au:()=>A,kO:()=>N,iv:()=>x,UR:()=>R});' +
                    'var i=a("F"),o=a("u"),s=a("vK"),d=a("d"),h=a("Bu");' +
                    functions(source, factory, ['T', 'v', 'C', '$']) +
                    'let I=v(),O=(0,i.g5)();function R(e,t){I=v(e);O=t??(0,i.g5)()}' +
                    'function S(){return false} function A(){} function N(){} function x(){}}';
            }
            if (replacement) edits.push({ start: factory.start, end: factory.end, replacement, id });
        }
        if (edits.length !== (url.includes('/core-') ? 4 : 2)) throw Error('Missing reviewed collectors');
        // A redirect is a data URL. Resolve all relative ES module specifiers
        // against the original URL, including each chunk's self registration.
        for (const node of parseModule(source).body) {
            if (node.type === 'ImportDeclaration' && node.source.value.startsWith('.')) {
                edits.push({ start: node.source.start, end: node.source.end,
                    replacement: JSON.stringify(new URL(node.source.value, url).href) });
            }
        }
        let code = source;
        for (const edit of edits.sort((a, b) => b.start - a.start)) code = code.slice(0, edit.start) + edit.replacement + code.slice(edit.end);
        parseModule(code);
        const resource = 'vox-github-' + url.split('/').pop();
        resources.set(resource, code);
        filters.push(`/^${escape(url)}(?:\\?[^#]*)?$/$script,match-case,domain=github.com,redirect=${resource}`);
        reviewed.push({ ...record, resource, factories: edits.filter(edit => edit.id).map(edit => edit.id) });
    }
    return { filters: filters.join('\n'), resources, reviewed };
}

export async function writeGithubResources() {
    const { filters, resources } = await buildGithubResources();
    await fs.writeFile(new URL('./github_resources.js', import.meta.url),
        '// Generated by github_builder.mjs from reviewed originals.\n' +
        'export const githubFilters = ' + JSON.stringify('\n' + filters + '\n') + ';\n' +
        'export const githubResources = new Map(' + JSON.stringify([...resources]) + ');\n');
}
