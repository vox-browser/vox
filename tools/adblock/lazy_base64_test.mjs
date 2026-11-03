import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
import {build} from 'esbuild';
import {base64Stub} from './lazy_base64.mjs';

const bundle=await build({entryPoints:[fileURLToPath(new URL('./base64.js',import.meta.url))],
    bundle:true,platform:'browser',format:'iife',target:'safari16.4',
    minify:true,legalComments:'eof',write:false});
const source=bundle.outputFiles[0].text;
function realm(globals={}) {
    const context=vm.createContext(globals);let loads=0;
    context.voxAdblockLoadBase64=()=>{++loads;vm.runInContext(source,context);};
    vm.runInContext(base64Stub(),context);
    return {context,loads:()=>loads};
}

test('base64 codecs stay unloaded until read and retain the original codec and exception behavior',()=>{
    const original=vm.createContext({});vm.runInContext(source,original);
    for(const first of ['atob','btoa','DOMException']) {
        const {context,loads}=realm();assert.equal(loads(),0);
        assert.equal(typeof context[first],'function');assert.equal(loads(),1);
        const binary=String.fromCharCode(...Array.from({length:256},(_,i)=>i));
        const encoded=Buffer.from(binary,'latin1').toString('base64');
        assert.equal(context.btoa(binary),encoded);assert.equal(context.atob(encoded),binary);
        assert.equal(context.atob(' d m9 4\n'),'vox');
        assert.throws(()=>context.atob(),error=>error.name==='TypeError');
        assert.throws(()=>context.btoa(),error=>error.name==='TypeError');
        for(const invalid of ['!','a','a===','===='])
            assert.throws(()=>context.atob(invalid),error=>error.name==='InvalidCharacterError'
                && error instanceof context.DOMException);
        assert.throws(()=>context.btoa('😀'),error=>error.name==='InvalidCharacterError');
        for(const name of ['atob','btoa']) {
            assert.equal(context[name].length,1);
            const descriptor=Object.getOwnPropertyDescriptor(context,name);
            assert.equal(descriptor.configurable,true);assert.equal(descriptor.writable,true);
            assert.equal(descriptor.enumerable,Object.getOwnPropertyDescriptor(original,name).enumerable);
            assert.equal(descriptor.get,undefined);
        }
        assert.equal(loads(),1);
    }
});

test('host globals remain available and assignments before first use survive codec installation',()=>{
    const originalAtob=()=>42,originalBtoa=()=>43;
    const existing=realm({atob:originalAtob,btoa:originalBtoa,DOMException:class ExistingException{}});
    assert.equal(existing.context.atob,originalAtob);assert.equal(existing.context.btoa,originalBtoa);
    assert.equal(existing.loads(),0);
    const {context,loads}=realm();const replacement=()=>44;
    context.btoa=replacement;assert.equal(loads(),1);
    assert.equal(context.btoa,replacement);assert.equal(context.atob('dm94'),'vox');
    assert.equal(context.btoa,replacement);assert.equal(loads(),1);
});
