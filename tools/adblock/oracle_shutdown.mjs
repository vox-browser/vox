import {execFile} from 'node:child_process';
import {promisify} from 'node:util';

const exec = promisify(execFile);
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));

export async function oracleProcessSnapshot() {
    const {stdout} = await exec('ps', ['-axo', 'pid=,ppid=,lstart=']);
    return stdout.trim().split('\n').map(line => {
        const match = line.trim().match(/^(\d+)\s+(\d+)\s+(.+)$/);
        if (!match) throw Error('Invalid oracle process identity');
        return {pid:Number(match[1]), parent:Number(match[2]), started:match[3]};
    });
}

// A parent exit alone does not close a Chromium profile: helpers can outlive
// it. Retain observed creation identities across reparenting and wait for the
// complete owned tree. The outer memory guard remains responsible for killing
// a timed-out job; this function never signals an unrelated or recycled PID.
export async function closeOracleBrowser(browser, requestClose, {
    snapshot=oracleProcessSnapshot, timeoutMs=8000, pollMs=25,
}={}) {
    const deadline = Date.now() + timeoutMs;
    const owned = new Map();
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
    };
    await observe();
    let closeError;
    Promise.resolve().then(requestClose).catch(error => { closeError=error; });
    let terminated = false;
    do {
        await observe();
        if (browser.exitCode !== null || browser.signalCode !== null) {
            if (!owned.size) return;
        } else if (closeError && !terminated) {
            browser.kill('SIGTERM');
            terminated = true;
        }
        if (Date.now() >= deadline)
            throw Error('Oracle shutdown left owned processes running: '+[...owned.keys()].join(', '));
        await pause(pollMs);
    } while (true);
}
