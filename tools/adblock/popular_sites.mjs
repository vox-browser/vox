// Reuse the full-uBO parity harness across a repeatable set of real sites.
// A clean filter comparison on a challenge page is not a successful site test.
import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { isExpectedSiteURL } from './navigation.mjs';

const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(directory, '../..');

export function assessReport(report, { minRequests = 10, recorded = false } = {}) {
    const issues = [];
    const counts = report?.counts;
    const validCount = value => Number.isSafeInteger(value) && value >= 0;
    if (!counts || !['requests', 'blocked', 'allowed', 'mismatches', 'oracle_disagreements'].every(key => validCount(counts[key]))) {
        return { status: 'invalid-report', parity: 'unknown', coverage: recorded ? 'filtering-only' : 'unknown', issues: ['Missing or invalid network counts'] };
    }
    if (counts.requests !== counts.blocked + counts.allowed || !Array.isArray(report.requests) || report.requests.length !== counts.requests) {
        return { status: 'invalid-report', parity: 'unknown', coverage: recorded ? 'filtering-only' : 'unknown', issues: ['Request counts do not match the recorded corpus'] };
    }
    if (report.requests.some(entry => !entry || !['expected', 'actual'].every(key => typeof entry[key]?.blocked === 'boolean' && typeof entry[key]?.exception === 'boolean'))) {
        return { status: 'invalid-report', parity: 'unknown', coverage: recorded ? 'filtering-only' : 'unknown', issues: ['Missing individual engine decisions'] };
    }
    const errors = report.requests.filter(entry => entry.actual?.error).length;
    const differences = report.requests.filter(entry => entry.actual.blocked !== entry.expected.blocked || entry.actual.exception !== entry.expected.exception).length;
    let parity = 'pass';
    if (counts.mismatches || counts.oracle_disagreements || errors || differences) {
        parity = 'fail';
        issues.push(`${Math.max(counts.mismatches, differences)} decision mismatches; ${counts.oracle_disagreements} oracle disagreements; ${errors} engine errors`);
    }
    const cosmetic = report.cosmetic;
    if (!recorded && (!cosmetic || !['css_matches', 'procedural_matches', 'scriptlet_filters_match'].every(key => typeof cosmetic[key] === 'boolean'))) {
        if (parity !== 'fail') parity = 'unknown';
        issues.push('Missing cosmetic and scriptlet comparison');
    } else if (cosmetic && (!cosmetic.css_matches || !cosmetic.procedural_matches || !cosmetic.scriptlet_filters_match)) {
        parity = 'fail';
        issues.push('Cosmetic, procedural, or scriptlet selection differs');
    }
    let coverage = recorded ? 'filtering-only' : report.navigation?.coverage || 'unknown';
    if (!recorded) {
        const navigation = report.navigation;
        if (navigation?.challenge_detected || coverage === 'challenge') coverage = 'challenge';
        else if (navigation?.load_error || coverage === 'error' || (navigation?.status && navigation.status >= 400)) coverage = 'error';
        else if (!['page', 'consent', 'empty', 'unexpected-origin'].includes(coverage)) coverage = 'unknown';
        if (coverage === 'page') {
            try {
                if (!navigation.url) coverage = 'unknown';
                else if (!isExpectedSiteURL(report.url, navigation.url)) coverage = 'unexpected-origin';
            } catch { coverage = 'unknown'; }
        }
        if (coverage !== 'page') issues.push(`Live page coverage: ${coverage}`);
    }
    if (counts.requests < minRequests) {
        issues.push(`Only ${counts.requests} distinct requests; at least ${minRequests} required`);
        if (coverage === 'page' || recorded) coverage = 'insufficient';
    }
    let status = 'pass';
    if (parity === 'fail') status = 'parity-failure';
    else if (parity === 'unknown') status = 'invalid-report';
    else if (coverage !== (recorded ? 'filtering-only' : 'page')) status = 'coverage-failure';
    return { status, parity, coverage, counts, issues };
}

function parseArguments(args) {
    const options = {
        catalog: path.join(directory, 'popular-sites.json'),
        harness: path.join(directory, 'brave_parity.mjs'),
        output: path.join(root, 'Build/comparisons/adblock-popular'),
        sites: '', settle: '15', timeout: '300', 'vox-logs': '',
        'reports-only': false, help: false,
    };
    for (let i = 0; i < args.length; i++) {
        const key = args[i].replace(/^--/, '');
        if (key === 'reports-only' || key === 'help') { options[key] = true; continue; }
        if (!(key in options) && !['brave', 'checker', 'extension'].includes(key)) throw new Error(`Unknown option: ${args[i]}`);
        if (!args[i].startsWith('--') || args[i + 1] === undefined || args[i + 1].startsWith('--')) throw new Error(`Missing --${key} value`);
        options[key] = args[++i];
    }
    if (!(Number(options.settle) > 0 && Number(options.settle) <= 120)) throw new Error('--settle must be 1..120 seconds');
    if (!(Number(options.timeout) >= 1 && Number(options.timeout) <= 3600)) throw new Error('--timeout must be 1..3600 seconds per comparison');
    return options;
}

function execute(file, args, timeout) {
    return new Promise(resolve => {
        const grouped = process.platform !== 'win32';
        const child = spawn(process.execPath, [file, ...args], { cwd: root, detached: grouped, stdio: ['ignore', 'pipe', 'pipe'] });
        let stdout = '', stderr = '', timedOut = false, force;
        const terminate = signal => {
            try { if (grouped) process.kill(-child.pid, signal); else child.kill(signal); } catch (error) { if (error.code !== 'ESRCH') throw error; }
        };
        const limit = 256 * 1024;
        child.stdout.on('data', data => { stdout = (stdout + data).slice(-limit); });
        child.stderr.on('data', data => { stderr = (stderr + data).slice(-limit); });
        const timer = setTimeout(() => {
            timedOut = true;
            terminate('SIGTERM');
            force = setTimeout(() => terminate('SIGKILL'), 5000);
        }, timeout);
        child.once('error', error => { clearTimeout(timer); clearTimeout(force); resolve({ exit_code: null, error: error.message, stdout, stderr }); });
        child.once('close', (code, signal) => {
            clearTimeout(timer); clearTimeout(force);
            resolve({ exit_code: code, signal, timed_out: timedOut, stdout, stderr });
        });
    });
}

async function main() {
    const options = parseArguments(process.argv.slice(2));
    if (options.help) {
        console.log(`Usage: node tools/adblock/popular_sites.mjs [options]
  --sites bbc,cnn          Select catalog IDs (default: all catalog sites)
  --output DIR            Per-site reports and summary.json
  --reports-only          Assess existing reports without opening Brave
  --vox-logs FILE          JSON map of site ID to Vox audit JSONL; adds recorded comparisons
  --settle SECONDS         Page settle time (default: 15)
  --timeout SECONDS        Limit each comparison (default: 300)
  --brave PATH --extension PATH --checker PATH
  --catalog FILE          Alternate site catalog
  --harness FILE          Alternate compatible harness (useful for tooling tests)

Live reports are ID.json; recorded comparisons are ID.vox.json. Recorded
comparisons verify filtering only and do not establish that Vox rendered a page.
Challenge pages, insufficient traffic, missing reports, and mismatches fail the run.`);
        return;
    }
    const catalog = JSON.parse(await fs.readFile(options.catalog, 'utf8'));
    if (!Array.isArray(catalog.sites) || !catalog.sites.length) throw new Error('Catalog must contain a nonempty sites array');
    const ids = new Set();
    for (const site of catalog.sites) {
        if (!site || !/^[a-z0-9][a-z0-9-]*$/.test(site.id) || ids.has(site.id)) throw new Error('Site IDs must be unique lowercase names');
        ids.add(site.id);
        if (!/^https?:$/.test(new URL(site.url).protocol)) throw new Error(`Invalid site URL: ${site.id}`);
        if (!Number.isSafeInteger(site.min_requests) || site.min_requests < 1) throw new Error(`Invalid min_requests: ${site.id}`);
    }
    const selected = options.sites ? options.sites.split(',').filter(Boolean) : [...ids];
    if (!selected.length || new Set(selected).size !== selected.length || selected.some(id => !ids.has(id))) throw new Error(`Unknown or repeated site selection: ${options.sites}`);
    const sites = selected.map(id => catalog.sites.find(site => site.id === id));
    const voxLogs = options['vox-logs'] ? JSON.parse(await fs.readFile(options['vox-logs'], 'utf8')) : {};
    if (!voxLogs || Array.isArray(voxLogs) || typeof voxLogs !== 'object' || Object.entries(voxLogs).some(([id, file]) => !ids.has(id) || typeof file !== 'string' || !file)) throw new Error('--vox-logs must map catalog site IDs to JSONL paths');
    const output = path.resolve(options.output);
    await fs.mkdir(output, { recursive: true });
    const summary = { started_at: new Date().toISOString(), catalog: path.resolve(options.catalog), mode: options['reports-only'] ? 'existing-reports' : 'live', sites: [] };
    const save = async () => {
        summary.counts = { sites: summary.sites.length, passed: summary.sites.filter(site => site.status === 'pass').length, failed: summary.sites.filter(site => site.status !== 'pass').length };
        await fs.writeFile(path.join(output, 'summary.json'), JSON.stringify(summary, null, 2) + '\n');
    };
    for (const site of sites) {
        const entry = { id: site.id, name: site.name, url: site.url, comparisons: [] };
        for (const recorded of [false, ...(voxLogs[site.id] ? [true] : [])]) {
            const reportFile = path.join(output, `${site.id}${recorded ? '.vox' : ''}.json`);
            let execution = null;
            if (!options['reports-only']) {
                // Never mistake a previous run's report for output from a failed navigation.
                await fs.rm(reportFile, { force: true });
                const args = ['--url', site.url, '--output', reportFile, '--settle', String(options.settle)];
                for (const key of ['brave', 'checker', 'extension']) if (options[key]) args.push(`--${key}`, path.resolve(options[key]));
                if (recorded) args.push('--vox-log', path.resolve(voxLogs[site.id]));
                execution = await execute(path.resolve(options.harness), args, Number(options.timeout) * 1000);
                await fs.writeFile(reportFile.replace(/\.json$/, '.log'), [execution.stdout, execution.stderr].filter(Boolean).join('\n'));
            }
            let comparison;
            try {
                const report = JSON.parse(await fs.readFile(reportFile, 'utf8'));
                if (report.url !== site.url) throw new Error(`Expected report for ${site.url}; found ${report.url}`);
                const expectedMode = recorded ? 'recorded-vox-network' : 'live-brave-network';
                if (report.input?.mode !== expectedMode) throw new Error(`Expected ${expectedMode} report`);
                comparison = { ...assessReport(report, { minRequests: site.min_requests, recorded }), navigation: report.navigation ?? null };
                if (execution && execution.exit_code !== 0 && comparison.status === 'pass') {
                    comparison.status = 'harness-failure';
                    comparison.issues.push(execution.timed_out ? 'Parity harness timed out' : `Parity harness exited with ${execution.exit_code ?? execution.signal ?? execution.error}`);
                }
            } catch (error) {
                comparison = { status: 'harness-failure', parity: 'unknown', coverage: recorded ? 'filtering-only' : 'unknown', issues: [execution?.timed_out ? 'Parity harness timed out' : `Report unavailable: ${error.message}`] };
            }
            entry.comparisons.push({ mode: recorded ? 'recorded-vox-network' : 'live-brave-network', report: reportFile, ...comparison, ...(execution ? { execution: { exit_code: execution.exit_code, signal: execution.signal, timed_out: execution.timed_out, error: execution.error } } : {}) });
        }
        entry.status = entry.comparisons.every(comparison => comparison.status === 'pass') ? 'pass' : 'fail';
        summary.sites.push(entry);
        await save();
        console.log(`${site.id}: ${entry.comparisons.map(comparison => `${comparison.mode}: ${comparison.status} (parity=${comparison.parity}, coverage=${comparison.coverage})`).join('; ')}`);
    }
    summary.finished_at = new Date().toISOString();
    await save();
    console.log(JSON.stringify({ summary: path.join(output, 'summary.json'), ...summary.counts }));
    if (summary.counts.failed) process.exitCode = 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
