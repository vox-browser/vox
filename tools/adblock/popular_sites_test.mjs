import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { promisify } from 'node:util';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { assessReport } from './popular_sites.mjs';

const execute = promisify(execFile);
const runner = fileURLToPath(new URL('./popular_sites.mjs', import.meta.url));

function cleanReport() {
    return {
        url: 'https://example.com/', input: { mode: 'live-brave-network' },
        counts: { requests: 2, blocked: 0, allowed: 2, mismatches: 0, oracle_disagreements: 0 },
        navigation: { url: 'https://example.com/', coverage: 'page', status: 200, title: 'A page', challenge_detected: false },
        cosmetic: { css_matches: true, procedural_matches: true, scriptlet_filters_match: true },
        requests: ['/', '/page.css'].map(part => ({ url: 'https://example.com' + part, expected: { blocked: false, exception: false }, actual: { blocked: false, exception: false, error: '' } })),
    };
}

test('a legitimate clean site passes without any blocked requests', () => {
    const result = assessReport(cleanReport(), { minRequests: 2 });
    assert.equal(result.status, 'pass');
    assert.equal(result.coverage, 'page');
    assert.equal(result.counts.blocked, 0);
});

test('matching filter decisions do not turn challenge pages or weak corpora into site coverage', () => {
    const challenge = cleanReport();
    challenge.navigation = { coverage: 'challenge', challenge_detected: true, status: 200, title: 'Just a moment' };
    const result = assessReport(challenge, { minRequests: 2 });
    assert.equal(result.parity, 'pass');
    assert.equal(result.status, 'coverage-failure');
    assert.equal(result.coverage, 'challenge');
    assert.equal(assessReport(cleanReport(), { minRequests: 10 }).coverage, 'insufficient');
    const error = cleanReport();
    error.navigation = { coverage: 'page', status: 403 };
    assert.equal(assessReport(error, { minRequests: 2 }).coverage, 'error');
    for (const coverage of ['consent', 'empty', 'unexpected-origin']) {
        const unavailable = cleanReport();
        unavailable.navigation = { coverage, status: 200 };
        const assessment = assessReport(unavailable, { minRequests: 2 });
        assert.equal(assessment.coverage, coverage);
        assert.equal(assessment.status, 'coverage-failure');
    }
});

test('individual mismatches, cosmetic differences, oracle disagreements, and missing comparisons fail', () => {
    const mismatch = cleanReport();
    mismatch.requests[0].actual.blocked = true;
    assert.equal(assessReport(mismatch, { minRequests: 2 }).status, 'parity-failure');
    const cosmetic = cleanReport();
    cosmetic.cosmetic.scriptlet_filters_match = false;
    assert.equal(assessReport(cosmetic, { minRequests: 2 }).parity, 'fail');
    const oracle = cleanReport();
    oracle.counts.oracle_disagreements = 1;
    assert.equal(assessReport(oracle, { minRequests: 2 }).parity, 'fail');
    const missing = cleanReport();
    delete missing.requests[0].actual;
    assert.equal(assessReport(missing, { minRequests: 2 }).status, 'invalid-report');
    const noCosmetics = cleanReport();
    noCosmetics.cosmetic = null;
    assert.equal(assessReport(noCosmetics, { minRequests: 2 }).status, 'invalid-report');
});

test('stored successful reports cannot substitute a different final site', () => {
    const report = cleanReport();
    report.navigation.url = 'https://parking.example/';
    assert.equal(assessReport(report, { minRequests: 2 }).coverage, 'unexpected-origin');
    delete report.navigation.url;
    assert.equal(assessReport(report, { minRequests: 2 }).coverage, 'unknown');
});

test('recorded Vox traffic establishes filtering parity, with no claim of page coverage', () => {
    const report = cleanReport();
    report.navigation = null;
    report.cosmetic = null;
    assert.equal(assessReport(report, { minRequests: 2 }).status, 'invalid-report');
    const result = assessReport(report, { minRequests: 2, recorded: true });
    assert.equal(result.status, 'pass');
    assert.equal(result.coverage, 'filtering-only');
});

test('request and response phases cannot inflate the minimum distinct-resource coverage', () => {
    const report = cleanReport();
    report.common_stream = { distinct_requests: 1, matches: true };
    const result = assessReport(report, { minRequests: 2 });
    assert.equal(result.status, 'coverage-failure');
    assert.equal(result.coverage, 'insufficient');
    assert.match(result.issues[0], /Only 1 distinct requests/);
    assert.equal(assessReport(report, { minRequests: 1 }).status, 'pass');
    // Reports from the earlier request-only harness retain their old meaning.
    delete report.common_stream;
    assert.equal(assessReport(report, { minRequests: 2 }).status, 'pass');
});

test('stored common-stream conflicts and invalid resource counts cannot pass reports-only assessment', () => {
    const report = cleanReport();
    report.common_stream = { distinct_requests: 2, matches: false };
    assert.equal(assessReport(report, { minRequests: 2 }).status, 'parity-failure');
    for (const distinct_requests of [-1, 1.5, 3, '2']) {
        report.common_stream = { distinct_requests, matches: true };
        assert.equal(assessReport(report, { minRequests: 2 }).status, 'invalid-report');
    }
    report.common_stream = { distinct_requests: 2 };
    assert.equal(assessReport(report, { minRequests: 2 }).status, 'invalid-report');
});

test('CLI removes stale output, continues after a harness failure, and returns a failing aggregate', async () => {
    const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'vox-adblock-matrix-test-'));
    try {
        const catalog = path.join(temporary, 'sites.json');
        const harness = path.join(temporary, 'harness.mjs');
        const output = path.join(temporary, 'output');
        await fs.mkdir(output);
        await fs.writeFile(catalog, JSON.stringify({ sites: [
            { id: 'fails', name: 'Unavailable', url: 'https://fails.example/', min_requests: 2 },
            { id: 'works', name: 'Available', url: 'https://example.com/', min_requests: 2 },
        ] }));
        await fs.writeFile(path.join(output, 'fails.json'), JSON.stringify(cleanReport()));
        await fs.writeFile(harness, `import fs from 'node:fs/promises';
const args=Object.fromEntries(Array.from({length:(process.argv.length-2)/2},(_,i)=>[process.argv[2+i*2],process.argv[3+i*2]]));
if(args['--url']==='https://fails.example/') { console.error('Navigation unavailable'); process.exitCode=2; }
else await fs.writeFile(args['--output'],JSON.stringify(${JSON.stringify(cleanReport())}));
`);
        await assert.rejects(execute(process.execPath, [runner, '--catalog', catalog, '--harness', harness, '--output', output]), error => error.code === 1);
        const summary = JSON.parse(await fs.readFile(path.join(output, 'summary.json'), 'utf8'));
        assert.deepEqual(summary.counts, { sites: 2, passed: 1, failed: 1 });
        assert.equal(summary.sites[0].comparisons[0].status, 'harness-failure');
        assert.equal(summary.sites[1].comparisons[0].status, 'pass');
        await assert.rejects(fs.access(path.join(output, 'fails.json')), { code: 'ENOENT' });
        assert.match(await fs.readFile(path.join(output, 'fails.log'), 'utf8'), /Navigation unavailable/);
    } finally {
        await fs.rm(temporary, { recursive: true, force: true });
    }
});

test('reports-only respects site selection and rejects a report for a different site', async () => {
    const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'vox-adblock-existing-test-'));
    try {
        const catalog = path.join(temporary, 'sites.json');
        await fs.writeFile(catalog, JSON.stringify({ sites: [
            { id: 'chosen', url: 'https://example.com/', min_requests: 2 },
            { id: 'ignored', url: 'https://other.example/', min_requests: 2 },
        ] }));
        await fs.writeFile(path.join(temporary, 'chosen.json'), JSON.stringify(cleanReport()));
        await execute(process.execPath, [runner, '--catalog', catalog, '--sites', 'chosen', '--reports-only', '--output', temporary]);
        let summary = JSON.parse(await fs.readFile(path.join(temporary, 'summary.json'), 'utf8'));
        assert.deepEqual(summary.counts, { sites: 1, passed: 1, failed: 0 });
        const report = cleanReport();
        report.url = 'https://wrong.example/';
        await fs.writeFile(path.join(temporary, 'chosen.json'), JSON.stringify(report));
        await assert.rejects(execute(process.execPath, [runner, '--catalog', catalog, '--sites', 'chosen', '--reports-only', '--output', temporary]), error => error.code === 1);
        summary = JSON.parse(await fs.readFile(path.join(temporary, 'summary.json'), 'utf8'));
        assert.match(summary.sites[0].comparisons[0].issues[0], /Expected report for/);
    } finally {
        await fs.rm(temporary, { recursive: true, force: true });
    }
});
