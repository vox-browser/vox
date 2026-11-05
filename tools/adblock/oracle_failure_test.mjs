import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {recordOracleFailure} from './oracle_failure.mjs';

test('the original comparison error survives a second failure during shutdown', async t => {
    const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'oracle-failure-'));
    t.after(() => fs.rm(directory, {recursive:true, force:true}));
    const primary = Error('Debugger timed out before the page could load');
    const secondary = Error('Owned browser helpers survived shutdown');
    const messages = [];
    const original = console.error;
    console.error = (...args) => messages.push(args.join(' '));
    t.after(() => { console.error = original; });
    const output = path.join(directory, 'nested', 'comparison.json');
    await assert.rejects(async () => {
        try {
            try { throw primary; }
            catch (error) { await recordOracleFailure(output, error); throw error; }
        } finally { throw secondary; }
    }, error => error === secondary);
    const receipt = JSON.parse(await fs.readFile(output + '.failure.json', 'utf8'));
    assert.equal(receipt.status, 'failed');
    assert.equal(receipt.error.message, primary.message);
    assert.equal(receipt.error.stack, primary.stack);
    assert(messages.some(message => message.includes(primary.message)));
});

test('an unwritable receipt still logs and preserves the primary error', async t => {
    const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'oracle-failure-'));
    t.after(() => fs.rm(directory, {recursive:true, force:true}));
    const file = path.join(directory, 'file');
    await fs.writeFile(file, 'not a directory');
    const primary = Error('Missing visible image');
    const messages = [];
    const original = console.error;
    console.error = (...args) => messages.push(args.join(' '));
    t.after(() => { console.error = original; });
    await assert.rejects(async () => {
        try { throw primary; }
        catch (error) { await recordOracleFailure(path.join(file, 'report'), error); throw error; }
    }, error => error === primary);
    assert(messages.some(message => message.includes(primary.message)));
    assert(messages.some(message => message.includes('Cannot retain oracle failure')));
});
