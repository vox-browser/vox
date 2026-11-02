import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import { packedArray, packedMap, readPackedValue, encodePackedTable } from './lazy_snapshot.mjs';
import { encodeSnapshot } from './snapshot.mjs';

test('array queries decode only requested values, while mutation restores dense array semantics', () => {
    const source = [0, null, false, 'a\0b', '😀', '\uD800', '\uFEFFtext'];
    let reads = 0;
    const array = packedArray(encodePackedTable(source, 1), (...args) => {
        ++reads; return readPackedValue(...args);
    });
    assert.equal(Array.isArray(array), true);
    assert.equal(array.length, source.length);
    assert.equal(array[5], source[5]); assert.equal(array[5], source[5]);
    assert.equal(reads, 1);
    assert.equal(4 in array, true); assert.equal(reads, 1);
    array.push('appended');
    assert.deepEqual(array, [...source, 'appended']);
    assert.equal(reads, source.length);
    delete array[2]; assert.equal(2 in array, false);
    array.length = 2; assert.deepEqual(array, source.slice(0, 2));
});

test('reflection, freezing, serialization and iteration materialize exact array values', () => {
    for (const action of [
        a => JSON.stringify(a), a => [...a], a => Object.getOwnPropertyDescriptors(a),
        a => Object.keys(a), a => Object.freeze(a), a => a.slice(),
        a => Object.defineProperty(a, '0', {value: 'replaced'}),
    ]) {
        const source = [1, 'selector', null];
        const expected = source.slice(), actual = packedArray(encodePackedTable(source, 1), readPackedValue);
        assert.deepEqual(action(actual), action(expected));
        assert.deepEqual(actual, expected);
    }
});

test('maps preserve key identity, missing values, nulls and insertion order after mutation', () => {
    for (const source of [new Map([['z', null], ['a', 'zero\0😀\uD800'], ['b', 3]]),
        new Map([[9, null], [0, false], [17, 'number-key']])]) {
        let reads = 0;
        const array = encodePackedTable(source, typeof source.keys().next().value === 'string' ? 2 : 3);
        const map = packedMap(array, (...args) => { ++reads; return readPackedValue(...args); });
        assert.equal(map instanceof Map, true); assert.equal(map.size, source.size);
        const [key, value] = source.entries().next().value;
        assert.equal(map.get(key), value); assert.equal(map.has(key), true); assert.equal(reads, 1);
        for (const missing of [undefined, null, NaN, Infinity, -1, -0.5, 'missing', {}, Symbol()]) {
            assert.equal(map.has(missing), source.has(missing));
            assert.equal(map.get(missing), source.get(missing));
        }
        map.set('added', undefined); assert.equal(map.has('added'), true);
        source.set('added', undefined);
        assert.deepEqual([...map], [...source]);
        map.delete(key); source.delete(key);
        assert.deepEqual([...map.keys()], [...source.keys()]);
        const visited = []; map.forEach((value, key, owner) => {
            assert.equal(owner, map); visited.push([key, value]);
        });
        assert.deepEqual(visited, [...source]);
        map.clear(); assert.equal(map.size, 0); assert.equal(map.has('added'), false);
    }
});

test('packed map eager restoration and values iteration match ordinary maps', () => {
    const source = new Map([['first', 'a'], ['second', 'b']]);
    for (const eager of [false, true]) {
        const map = packedMap(encodePackedTable(source, 2), readPackedValue, eager);
        assert.deepEqual([...map.values()], [...source.values()]);
        assert.deepEqual([...map.entries()], [...source.entries()]);
    }
});

test('only recognized cosmetics tables are packed; restores own their lookup mutations', () => {
    const values = Array.from({length: 1200}, (_, index) => 'selector-' + index);
    const source = {cosmetics: {strSlots: values, linkedLists: values.map((_, i) => i),
        lowlyGeneric: new Map(values.map((value, i) => [i, value]))}, ordinary: values};
    const encoded = encodeSnapshot(source, {lazyCosmetics: true});
    assert.match(encoded.source, /packedArray/); assert.match(encoded.source, /packedMap/);
    assert.equal(JSON.parse(encoded.metadata).cosmetics.strSlots, null);
    assert.deepEqual(JSON.parse(encoded.metadata).ordinary, values);
    const context = vm.createContext({TextDecoder, binary: Uint8Array.from(encoded.binary), metadata: encoded.metadata});
    vm.runInContext('globalThis.voxAdblockReadSnapshotMetadata=()=>JSON.parse(metadata);globalThis.voxAdblockSnapshotBytes=new Uint8Array(binary);', context);
    vm.runInContext(encoded.source.replace('export default ', 'globalThis.snapshot='), context);
    const first = context.snapshot.restore(), second = context.snapshot.restore();
    first.cosmetics.strSlots[4] = 'changed'; first.cosmetics.lowlyGeneric.set(4, 'changed');
    assert.equal(second.cosmetics.strSlots[4], values[4]);
    assert.equal(second.cosmetics.lowlyGeneric.get(4), values[4]);
    assert.equal(second.cosmetics.linkedLists[1199], 1199);
});

test('raw public suffix text is decoded on demand without entering the engine source', () => {
    const text = '// PSL Unicode and exceptions\n*.ck\n!www.ck\nрф\nco.uk\n';
    const encoded = encodeSnapshot({}, {publicSuffixText:text});
    assert.doesNotMatch(encoded.source, /www\.ck/);
    assert.equal(encoded.metadata, '{}');
    const context = vm.createContext({TextDecoder,binary:Uint8Array.from(encoded.binary),metadata:encoded.metadata});
    vm.runInContext('globalThis.voxAdblockReadSnapshotMetadata=()=>JSON.parse(metadata);globalThis.voxAdblockSnapshotBytes=new Uint8Array(binary);',context);
    vm.runInContext(encoded.source.replace('export default ', 'globalThis.snapshot='),context);
    assert.equal(context.snapshot.publicSuffixText(), text);
});

test('large numeric network buckets retain request lookup, mutation and insertion order', () => {
    const bucket = new Map(Array.from({length:512},(_,index)=>[index * 7,index + 1]));
    const encoded = encodeSnapshot({network:{bitsToBucket:new Map([[16,bucket]])}}, {lazyNetworkBuckets:true});
    assert.equal(JSON.parse(encoded.metadata).network.bitsToBucket[0][1],null);
    const context = vm.createContext({TextDecoder,binary:Uint8Array.from(encoded.binary),metadata:encoded.metadata});
    vm.runInContext('globalThis.voxAdblockReadSnapshotMetadata=()=>JSON.parse(metadata);globalThis.voxAdblockSnapshotBytes=new Uint8Array(binary);',context);
    vm.runInContext(encoded.source.replace('export default ', 'globalThis.snapshot='),context);
    const restored = context.snapshot.restore().network.bitsToBucket.get(16);
    assert.equal(restored.get(77),12); assert.equal(restored.has(78),false);
    restored.set(9000,42); bucket.set(9000,42);
    assert.deepEqual(JSON.parse(JSON.stringify([...restored])),[...bucket]);
});

test('native lookup reader matches the portable reader and rejects corrupt storage', {skip: process.platform !== 'darwin'}, () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'vox-packed-snapshot-'));
    try {
        const tables = [[['s\0😀\uD800', null, false, 9], 1],
            [new Map([['z', null], ['\uD800', '\uFEFF\0'], ['a', 'text'], ['😀', false]]), 2],
            [new Map([[400, 'long'], [0, null], [17, false], [4294967295, 'last']]), 3]];
        const scripts = [`const packedArray=${packedArray},packedMap=${packedMap};
            const assert=(condition)=>{if(!condition)throw new Error('Packed table assertion failed');};`];
        for (const [values, kind] of tables) {
            const bytes = encodePackedTable(values, kind);
            const expected = kind === 1 ? values : [...values];
            scripts.push(`(()=>{const original=${JSON.stringify(expected)};
                const raw=new Uint8Array(${JSON.stringify([...bytes])});
                const backing=new Uint8Array(raw.length+7);backing.set(raw,3);
                const bytes=backing.subarray(3,3+raw.length);
                const result=${kind === 1 ? 'packedArray' : 'packedMap'}(bytes,readPackedValue);
                for(const [key,value] of ${kind === 1 ? 'original.entries()' : 'original'})
                    assert(${kind === 1 ? 'result[key]' : 'result.get(key)'}===value);
                assert(JSON.stringify([...result])===JSON.stringify(original));
                for(const key of [undefined,NaN,Infinity,-1,{},Symbol()])assert(readPackedValue(bytes,key)===undefined);
                for(const index of [0,4,8,12]){const bad=raw.slice();bad.fill(255,index,index+4);
                    let threw=false;try{readPackedValue(bad,0,true);}catch(error){threw=true;}
                    assert(threw);}
                assert(readPackedValue(bytes,999999,true)===undefined);
            })();`);
        }
        scripts.push('true;');
        const script = path.join(directory, 'fixture.js'); fs.writeFileSync(script, scripts.join('\n'));
        for (const sanitizer of [false, true]) {
            const binary = path.join(directory, sanitizer ? 'sanitized' : 'optimized');
            execFileSync('clang', ['-O2', ...(sanitizer ? ['-fsanitize=address,undefined', '-fno-omit-frame-pointer'] : []),
                '-framework', 'JavaScriptCore', '-framework', 'CoreFoundation', '-lz',
                fileURLToPath(new URL('./snapshot_packed_native_test.c', import.meta.url)), '-o', binary]);
            assert.match(execFileSync(binary, [script], {encoding:'utf8',env:{...process.env,ASAN_OPTIONS:'detect_leaks=0'}}), /PASS native packed lookups/);
        }
    } finally { fs.rmSync(directory, {recursive:true,force:true}); }
});
