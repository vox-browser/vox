// Count both engines on one request corpus. Browser popup counters cannot be
// compared across independent visits: JavaScript, redirects, timing and retries
// can produce different requests, and Vox checks a request at several gates.
export function resourceIdentity(request) {
    return JSON.stringify([
        request.url, request.source_url || '', request.request_type,
        (request.method || 'GET').toUpperCase(),
    ]);
}

function headersIdentity(headers = []) {
    // Header order is meaningful: uBO uses the first occurrence of a name.
    return headers.map(({ name, value }) => [name.toLowerCase(), value]);
}

export function requestIdentity(request) {
    const phase = request.phase || 'request';
    return JSON.stringify([
        resourceIdentity(request), phase,
        ...(phase === 'response' ? [headersIdentity(request.response_headers), headersIdentity(request.request_headers)] : []),
    ]);
}

export function hasHeaderFilter(filter) {
    return /(?:\$|,)(?:response|request)header(?:=|,|$)/.test(filter?.raw || '');
}

function decisionIdentity(decision) {
    return JSON.stringify([decision.blocked, decision.exception, decision.error || '']);
}

export function summarizeRequestParity(entries) {
    const unique = new Map();
    const conflicts = new Set();
    for (const entry of entries) {
        if (!entry || typeof entry.url !== 'string' || typeof entry.request_type !== 'string'
            || !['request', 'response'].includes(entry.phase || 'request')
            || (entry.phase === 'response' && !Array.isArray(entry.response_headers))
            || !['actual', 'expected'].every(key => typeof entry[key]?.blocked === 'boolean'
                && typeof entry[key]?.exception === 'boolean')) {
            throw new Error('Request-stream counts require both engine decisions for every request');
        }
        const key = requestIdentity(entry);
        const previous = unique.get(key);
        if (previous && (decisionIdentity(previous.actual) !== decisionIdentity(entry.actual)
            || decisionIdentity(previous.expected) !== decisionIdentity(entry.expected))) {
            conflicts.add(key);
        }
        if (!previous) unique.set(key, entry);
    }
    const requests = [...unique.values()];
    const resources = new Map();
    for (const entry of requests) {
        const key = resourceIdentity(entry);
        if (!resources.has(key)) resources.set(key, []);
        resources.get(key).push(entry);
    }
    const count = (entries, key) => ({
        blocked: entries.filter(entry => entry[key].blocked).length,
        allowed: entries.filter(entry => !entry[key].blocked).length,
        errors: entries.filter(entry => entry[key].error).length,
    });
    const mismatches = requests.filter(entry => entry.actual.blocked !== entry.expected.blocked
        || entry.actual.exception !== entry.expected.exception).length;
    const final = [...resources.values()].map(entries => {
        // A successful synthetic replacement can still pass the response
        // gate after the original ad was blocked. Neither that nor an allowed
        // header check undoes a block at the request gate.
        return Object.fromEntries(['actual', 'expected'].map(key => [key, {
            blocked: entries.some(entry => entry[key].blocked),
            error: entries.some(entry => entry[key].error),
        }]));
    });
    const actual = count(final, 'actual');
    const expected = count(final, 'expected');
    return {
        unit: 'distinct URL, initiating-document URL, request type, and method tuples',
        population: 'one shared captured stream; these are not browser popup totals',
        blocked_definition: 'a resource tuple is blocked if any request or response check blocks it',
        input_checks: entries.length,
        distinct_requests: resources.size,
        distinct_checks: requests.length,
        repeated_checks: entries.length - requests.length,
        phases: Object.fromEntries(['request', 'response'].map(phase => {
            const entries = requests.filter(entry => (entry.phase || 'request') === phase);
            return [phase, { checks: entries.length, vox: count(entries, 'actual'), full_ublock_origin: count(entries, 'expected') }];
        })),
        vox: actual,
        full_ublock_origin: expected,
        equal_block_counts: actual.blocked === expected.blocked,
        decision_mismatches: mismatches,
        conflicting_duplicates: [...conflicts].map(key => JSON.parse(key)),
        matches: requests.length > 0 && mismatches === 0 && conflicts.size === 0
            && actual.errors === 0 && expected.errors === 0,
    };
}
