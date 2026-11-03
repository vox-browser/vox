import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
import { classicScript } from './classic_script.mjs';

test('existing classic assets preserve their exact bytes and globals', () => {
    const source = 'globalThis.value = 42;\n';
    assert.equal(classicScript(source), source);
    const context = vm.createContext({});
    vm.runInContext(classicScript(source), context);
    assert.equal(context.value, 42);
});

test('the pinned regex module executes as a deferred classic asset', () => {
    const source = fs.readFileSync(new URL('../../adblock/vendor/ublock/lib/regexanalyzer/regex.js', import.meta.url), 'utf8');
    assert.throws(() => new vm.Script(source), SyntaxError);
    const context = vm.createContext({});
    vm.runInContext(classicScript(source), context);
    assert.equal(context.Regex.VERSION, '1.2.0');
    assert.equal(typeof context.Regex.Analyzer('^advert[0-9]+$', false).tree(), 'object');
});

test('invalid source cannot enter the snapshot payload', () => {
    assert.throws(() => classicScript('export default function {'));
});
