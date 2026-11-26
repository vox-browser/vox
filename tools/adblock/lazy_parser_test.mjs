import test from 'node:test';
import assert from 'node:assert/strict';
import {eagerParserFunctions, lazyParserFunction, lazyParserObject, parserStub} from './lazy_parser.mjs';
import * as parserExports from '../../adblock/vendor/ublock/js/static-filtering-parser.js';

test('parser function exports preserve calls, construction, subclassing and instance checks', () => {
    let reads = 0;
    class Parser { constructor(value) { this.value = value; } answer() { return this.value; } }
    const actual = {Parser, parse(value) { return this.prefix + value; }};
    const previous = globalThis.voxAdblockLoadParser;
    globalThis.voxAdblockLoadParser = () => { ++reads; return actual; };
    try {
        const Lazy = lazyParserFunction('Parser'), parse = lazyParserFunction('parse');
        assert.equal(reads, 0);
        const result = new Lazy(42);
        assert.equal(result.answer(), 42); assert.ok(result instanceof Parser); assert.ok(result instanceof Lazy);
        class Child extends Lazy {}
        assert.ok(new Child(17) instanceof Child);
        assert.equal(parse.call({prefix:'header:'}, 'value'), 'header:value');
    } finally { globalThis.voxAdblockLoadParser = previous; }
});

test('parser objects preserve collection receivers and unbound nested classes', () => {
    let reads = 0;
    class Preparser { static prune(value) { return value.trim(); } }
    const previous = globalThis.voxAdblockLoadParser;
    globalThis.voxAdblockLoadParser = () => { ++reads; return {map:new Map([['key',3]]),utils:{preparser:Preparser}}; };
    try {
        const map = lazyParserObject('map'), utils = lazyParserObject('utils');
        assert.equal(reads, 0); assert.equal(map.get('key'), 3); assert.equal(map.size, 1);
        assert.equal(utils.preparser.prune(' value '), 'value');
    } finally { globalThis.voxAdblockLoadParser = previous; }
});

test('parser export generation keeps numeric constants eager and rejects unsupported export kinds', () => {
    assert.match(parserStub({FLAG:17}), /export const FLAG=17/);
    assert.throws(()=>parserStub({unsupported:undefined}), /Unsupported parser export/);
});

test('removeparam and redirect value parsers run without loading the parser bundle', () => {
    const stub = parserStub(parserExports);
    const inputs = {
        parseQueryPruneValue: ['', 'utm_source', '~type', '/^utm_/i', '/[/', '|ref', '|[', 'a|b'],
        parseRedirectValue: ['noopjs', ' noopjs:10 ', '%vox-github:-5', 'none', 'noop.txt:x'],
    };
    const previous = globalThis.voxAdblockLoadParser;
    globalThis.voxAdblockLoadParser = () => { throw new Error('parser bundle loaded'); };
    try {
        for (const name of eagerParserFunctions) {
            assert.ok(stub.includes(`export const ${name}=function ${name}(`), name);
            const eager = new Function(`return (${parserExports[name].toString()});`)();
            for (const input of inputs[name]) {
                const expected = parserExports[name](input), actual = eager(input);
                assert.deepEqual({...actual, re: actual.re?.source}, {...expected, re: expected.re?.source}, `${name}(${input})`);
            }
        }
    } finally { globalThis.voxAdblockLoadParser = previous; }
});
