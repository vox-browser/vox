import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import fs from 'node:fs/promises';
import path from 'node:path';

const exec = promisify(execFile);
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));

export async function requestOracleBrowserClose(control, ...connections) {
    // Release page/extension debugger clients before browser teardown. Keep
    // only the browser connection until its close request has been delivered.
    for (const connection of connections) connection?.close();
    try {
        if (!control) throw Error('No browser debugger');
        await control.send('Browser.close');
    } finally {
        control?.close();
    }
}

export function parseOracleProcessSnapshot(stdout) {
    return stdout.split('\n').filter(line=>line.trim()).map(line => {
        const fields = line.trim().split(/\s+/);
        if (fields.length < 9 || !/^\d+$/.test(fields[0]) || !/^\d+$/.test(fields[1]))
            throw Error('Invalid oracle process identity');
        return {pid:Number(fields[0]), parent:Number(fields[1]), state:fields[2],
            started:fields.slice(3,8).join(' '), executable:fields.slice(8).join(' ')};
    });
}

export async function oracleProcessSnapshot() {
    const {stdout} = await exec('ps', ['-axo', 'pid=,ppid=,stat=,lstart=,comm=']);
    return parseOracleProcessSnapshot(stdout);
}

// A parent exit alone does not close a Chromium profile: helpers can outlive
// it. Retain observed creation identities across reparenting and wait for the
// complete owned tree. The outer memory guard remains responsible for killing
// a timed-out job; this function never signals an unrelated or recycled PID.
export async function closeOracleBrowser(browser, requestClose, {
    snapshot=oracleProcessSnapshot, timeoutMs=8000, pollMs=25, receiptFile,
}={}) {
    const startedAt = Date.now(), deadline = startedAt + timeoutMs;
    const owned = new Map();
    const receipt = {status:'failed', root_pid:browser.pid, initial_owned:[], remaining_owned:[]};
    const observe = async () => {
        const rows = await snapshot();
        const current = new Map(rows.map(row => [row.pid, row]));
        for (const [pid, started] of owned)
            if (current.get(pid)?.started !== started) owned.delete(pid);
        const root = current.get(browser.pid);
        if (root && browser.exitCode === null && browser.signalCode === null)
            owned.set(root.pid, root.started);
        let changed;
        do {
            changed = false;
            for (const row of rows) if (owned.has(row.parent) && !owned.has(row.pid)) {
                owned.set(row.pid, row.started);
                changed = true;
            }
        } while (changed);
        receipt.remaining_owned = [...owned.keys()].map(pid=>current.get(pid));
    };
    let closeError;
    try {
        await observe();
        receipt.initial_owned = receipt.remaining_owned;
        Promise.resolve().then(requestClose).catch(error => { closeError=error; });
        let terminated = false;
        do {
            await observe();
            if (browser.exitCode !== null || browser.signalCode !== null) {
                if (!owned.size) {
                    if (browser.exitCode !== 0 || browser.signalCode !== null)
                        throw Error('Oracle browser exited abnormally: '+(browser.signalCode ?? browser.exitCode));
                    receipt.status = 'closed';
                    return receipt;
                }
            } else if (closeError && !terminated) {
                browser.kill('SIGTERM');
                terminated = true;
            }
            if (Date.now() >= deadline)
                throw Error('Oracle shutdown left owned processes running: '+[...owned.keys()].join(', '));
            await pause(pollMs);
        } while (true);
    } catch(error) {
        receipt.error = {name:error?.name || 'Error', message:error?.message || String(error)};
        throw error;
    } finally {
        receipt.exit_code = browser.exitCode;
        receipt.signal = browser.signalCode;
        receipt.close_request_error = closeError?.message || null;
        receipt.elapsed_ms = Date.now() - startedAt;
        if (receiptFile) {
            try {
                await fs.mkdir(path.dirname(path.resolve(receiptFile)), {recursive:true});
                await fs.writeFile(receiptFile, JSON.stringify(receipt,null,2)+'\n');
            } catch(error) {
                if (receipt.status === 'closed') throw error;
                console.error('Cannot retain oracle shutdown receipt:', error);
            }
        }
    }
}
