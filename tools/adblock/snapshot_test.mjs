import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { encodeSnapshot } from './snapshot.mjs';

function restore(encoded, bytes = encoded.binary) {
    const context = vm.createContext({ sourceBytes: Uint8Array.from(bytes), metadata: encoded.metadata });
    vm.runInContext('globalThis.voxAdblockReadSnapshotMetadata=()=>JSON.parse(metadata);',context);
    vm.runInContext('globalThis.voxAdblockSnapshotBytes=new Uint8Array(sourceBytes);delete globalThis.sourceBytes;', context);
    vm.runInContext(encoded.source.replace('export default ', 'globalThis.snapshot='), context);
    return { context, value: context.snapshot.restore() };
}

test('restores all uBO snapshot value types, including aligned typed views', () => {
    const snapshot = {
        bytes: new Uint8Array([255, 0, 128]),
        words: new Uint32Array([0, 0xFFFFFFFF, 0x80000000]),
        signed: new Int32Array([-2147483648, -1, 2147483647]),
        map: new Map([['named', 7], [11, new Map([[13, 'nested']])]]),
        set: new Set(['first', 'second']), re: /advert\d+/gi,
        list: [null, undefined, true, false, '\0😀𐀀', '\uFEFFhi', '\uD800'],
    };
    const encoded = encodeSnapshot(snapshot);
    assert.match(encoded.metadata, /^[\x00-\x7F]*$/);
    assert.doesNotMatch(encoded.source, /JSON\.parse/);
    const { value } = restore(encoded);
    assert.deepEqual(Array.from(value.bytes), Array.from(snapshot.bytes));
    assert.deepEqual(Array.from(value.words), Array.from(snapshot.words));
    assert.deepEqual(Array.from(value.signed), Array.from(snapshot.signed));
    assert.equal(value.map.get('named'), 7);
    assert.equal(value.map.get(11).get(13), 'nested');
    assert.deepEqual(Array.from(value.set), ['first', 'second']);
    assert.equal(value.re.source, snapshot.re.source);
    assert.equal(value.re.flags, snapshot.re.flags);
    assert.deepEqual(Array.from(value.list), snapshot.list);
    assert.equal(encoded.layout.views[1].offset % 4, 0);
});

test('each restoration owns mutable arrays and maps while bundle bytes remain reusable', () => {
    const encoded = encodeSnapshot({ words: new Uint32Array([1, 2, 3]), map: new Map([['key', 5]]) });
    const { context, value } = restore(encoded);
    value.words[0] = 99; value.map.set('key', 42);
    const again = context.snapshot.restore();
    assert.equal(again.words[0], 1);
    assert.equal(again.map.get('key'), 5);
    assert.notEqual(again.words.buffer, value.words.buffer);
    assert.deepEqual(Array.from(context.voxAdblockSnapshotBytes), Array.from(encoded.binary));
});

test('requires the complete native snapshot before restoring', () => {
    const encoded = encodeSnapshot({ words: new Int32Array([1, -2, 3]) });
    const context = vm.createContext();
    vm.runInContext(encoded.source.replace('export default ', 'globalThis.snapshot='), context);
    assert.throws(() => context.snapshot.restore(), /Invalid bundled/);
    assert.throws(() => restore(encoded, encoded.binary.subarray(1)), /Invalid bundled/);
});

test('rejects cyclic or unsupported future snapshot types during generation', () => {
    const cyclic = {}; cyclic.self = cyclic;
    assert.throws(() => encodeSnapshot(cyclic), /Cyclic filter snapshot/);
    assert.throws(() => encodeSnapshot(new Float64Array([1])), /Unsupported snapshot view/);
    assert.throws(() => encodeSnapshot(new Date()), /Unsupported snapshot object/);
});


test('native metadata owns its text, restores fresh graphs and rejects malformed input', { skip: process.platform !== 'darwin' }, () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'vox-adblock-metadata-test-'));
    const binary = path.join(directory, 'metadata-test');
    try {
        execFileSync('cc', ['-O2', '-framework', 'JavaScriptCore', '-framework', 'CoreFoundation', '-lz',
            fileURLToPath(new URL('./snapshot_metadata_native_test.c', import.meta.url)), '-o', binary], { stdio: 'pipe' });
        assert.match(execFileSync(binary, { encoding: 'utf8' }), /PASS native snapshot metadata/);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

test('native snapshot bytes retain ownership and native checksums match the unchanged JS algorithm', { skip: process.platform !== 'darwin' }, () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'vox-adblock-snapshot-test-'));
    const binary = path.join(directory, 'snapshot-test');
    try {
        execFileSync('cc', ['-O2', '-framework', 'JavaScriptCore', '-framework', 'CoreFoundation', '-lz',
            fileURLToPath(new URL('./snapshot_native_test.c', import.meta.url)), '-o', binary], { stdio: 'pipe' });
        assert.match(execFileSync(binary, { encoding: 'utf8' }), /PASS native snapshot/);
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});
