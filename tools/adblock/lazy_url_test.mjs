import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import {build} from 'esbuild';
import {fileURLToPath} from 'node:url';
import {installLazyURL} from './lazy_url.mjs';

const polyfill = (await build({entryPoints:[fileURLToPath(new URL('./url.js',import.meta.url))],
    bundle:true,write:false,platform:'browser',format:'iife',target:'safari16.4',
    define:{global:'globalThis'},minify:true})).outputFiles[0].text;

function context(globals = {}) {
    const result = vm.createContext({...globals});
    result.loads = 0;
    result.load = () => { result.loads++; vm.runInContext(polyfill,result); };
    vm.runInContext(`(${installLazyURL})(load)`,result);
    return result;
}

test('the original URL polyfill remains unloaded until a URL operation', () => {
    const scope = context();
    assert.equal(scope.loads,0);
    assert.equal(vm.runInContext('Object.getOwnPropertyDescriptor(globalThis,"URL").enumerable',scope),false);
    assert.equal(vm.runInContext('new URL("../file?q=1", "https://example.test/a/b").href',scope),
        'https://example.test/file?q=1');
    assert.equal(scope.loads,1);
    assert.equal(vm.runInContext('new URLSearchParams("a=1&a=2").getAll("a").join(",")',scope),'1,2');
    assert.equal(scope.loads,1);
    assert.equal(vm.runInContext('typeof Object.getOwnPropertyDescriptor(globalThis,"URL").get',scope),'undefined');
});

test('URLSearchParams can load first and preserves URL query coupling', () => {
    const scope = context();
    assert.equal(vm.runInContext('new URLSearchParams([["space key","space value"]]).toString()',scope),'space+key=space+value');
    assert.equal(vm.runInContext('let u=new URL("https://example.test/?a=1");u.searchParams.append("b","two words");u.href',scope),
        'https://example.test/?a=1&b=two+words');
    assert.equal(scope.loads,1);
});

test('assignment loads the companion implementation before replacing a global', () => {
    const scope = context();
    vm.runInContext('globalThis.URL=42',scope);
    assert.equal(scope.loads,1);
    assert.equal(scope.URL,42);
    assert.equal(vm.runInContext('new URLSearchParams("x=7").get("x")',scope),'7');
    assert.equal(scope.loads,1);
});

test('available host implementations remain untouched before first loading', () => {
    const host = function HostURL() {};
    const scope = context({URL:host});
    assert.equal(scope.URL,host);
    assert.equal(scope.loads,0);
    vm.runInContext('new URLSearchParams("x=7")',scope);
    assert.equal(scope.loads,1);
    // core-js now performs its ordinary host conformance checks and replaces
    // this deliberately incomplete host implementation.
    assert.equal(vm.runInContext('new URL("/path","https://example.test").href',scope),'https://example.test/path');
});
