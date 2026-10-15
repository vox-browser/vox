import test from 'node:test';
import assert from 'node:assert/strict';
import { hasHeaderFilter, requestIdentity, summarizeRequestParity } from './request_stream.mjs';

function request(path, blocked, expectedBlocked = blocked) {
    return {
        url: `https://pikabu.ru/${path}`, source_url: 'https://pikabu.ru/',
        request_type: 'script', method: 'GET',
        actual: { blocked, exception: false, error: '' },
        expected: { blocked: expectedBlocked, exception: false },
    };
}

test('counts the same captured requests for both engines without multiplying native gate checks', () => {
    const ad = request('ads.js', true);
    const content = request('content.js', false);
    const result = summarizeRequestParity([ad, content, { ...ad }]);
    assert.equal(result.input_checks, 3);
    assert.equal(result.distinct_requests, 2);
    assert.equal(result.repeated_checks, 1);
    assert.deepEqual(result.vox, { blocked: 1, allowed: 1, errors: 0 });
    assert.deepEqual(result.full_ublock_origin, result.vox);
    assert.equal(result.matches, true);
});

test('equal totals cannot hide different blocked resources', () => {
    const result = summarizeRequestParity([request('ads.js', true, false), request('content.js', false, true)]);
    assert.equal(result.equal_block_counts, true);
    assert.equal(result.decision_mismatches, 2);
    assert.equal(result.matches, false);
});

test('request identity preserves initiator and type while normalizing the method', () => {
    const entry = request('resource', true);
    assert.equal(requestIdentity(entry), requestIdentity({ ...entry, method: 'get' }));
    assert.notEqual(requestIdentity(entry), requestIdentity({ ...entry, source_url: 'https://other.example/' }));
    assert.notEqual(requestIdentity(entry), requestIdentity({ ...entry, request_type: 'image' }));
    assert.notEqual(requestIdentity(entry), requestIdentity({ ...entry, method: 'POST' }));
});

test('conflicting gate checks remain a failure instead of silently keeping the last result', () => {
    const result = summarizeRequestParity([request('ads.js', true), request('ads.js', false)]);
    assert.equal(result.equal_block_counts, true);
    assert.equal(result.conflicting_duplicates.length, 1);
    assert.equal(result.matches, false);
});

test('exceptions, engine errors, empty streams, and absent decisions cannot pass', () => {
    const exception = request('content.js', false);
    exception.actual.exception = true;
    assert.equal(summarizeRequestParity([exception]).matches, false);
    const error = request('content.js', false);
    error.actual.error = 'Initialization failed';
    assert.equal(summarizeRequestParity([error]).matches, false);
    assert.equal(summarizeRequestParity([]).matches, false);
    const missing = request('content.js', false);
    delete missing.expected;
    assert.throws(() => summarizeRequestParity([missing]), /both engine decisions/);
});

test('an allowed request blocked by response headers counts as one blocked resource', () => {
    const before = request('ajax/stories', false);
    before.request_type = 'xmlhttprequest';
    const response = { ...before, phase: 'response', response_headers: [{ name: 'llasalbbubrrl', value: '1' }],
        actual: { blocked: true, exception: false }, expected: { blocked: true, exception: false } };
    const result = summarizeRequestParity([before, response, { ...response }]);
    assert.equal(result.matches, true);
    assert.equal(result.distinct_requests, 1);
    assert.equal(result.distinct_checks, 2);
    assert.equal(result.repeated_checks, 1);
    assert.equal(result.vox.blocked, 1);
    assert.equal(result.phases.request.vox.blocked, 0);
    assert.equal(result.phases.response.vox.blocked, 1);
    assert.deepEqual(result.conflicting_duplicates, []);
});

test('an allowed synthetic response cannot erase the original request block', () => {
    const before = request('ads.js', true);
    const response = { ...before, phase: 'response', response_headers: [{ name: 'content-type', value: 'text/javascript' }],
        actual: { blocked: false, exception: false }, expected: { blocked: false, exception: false } };
    const result = summarizeRequestParity([before, response]);
    assert.equal(result.matches, true);
    assert.equal(result.distinct_requests, 1);
    assert.equal(result.distinct_checks, 2);
    assert.equal(result.vox.blocked, 1);
    assert.equal(result.full_ublock_origin.blocked, 1);
    assert.equal(result.phases.request.vox.blocked, 1);
    assert.equal(result.phases.response.vox.blocked, 0);
});

test('different response header values are independent checks, while identical headers preserve conflict detection', () => {
    const before = request('ajax/stories', false);
    const response = { ...before, phase: 'response', response_headers: [{ name: 'Server', value: 'content' }] };
    const same = { ...response, response_headers: [{ name: 'server', value: 'content' }] };
    assert.equal(requestIdentity(response), requestIdentity(same));
    const other = { ...response, response_headers: [{ name: 'server', value: 'ads' }],
        actual: { blocked: true, exception: false }, expected: { blocked: true, exception: false } };
    const result = summarizeRequestParity([response, other]);
    assert.equal(result.distinct_checks, 2);
    assert.equal(result.distinct_requests, 1);
    assert.equal(result.matches, true);
    assert.equal(result.vox.blocked, 1);
});

test('header-filter logs can be separated from before-request decisions', () => {
    assert.equal(hasHeaderFilter({ raw: '||pikabu.ru/ajax/$xmlhttprequest,responseheader=llasalbbubrrl' }), true);
    assert.equal(hasHeaderFilter({ raw: '@@||example.test/$requestheader=x-allow' }), true);
    assert.equal(hasHeaderFilter({ raw: '||example.test/$script' }), false);
    assert.equal(hasHeaderFilter({ raw: '||example.test/responseheader=value' }), false);
});
