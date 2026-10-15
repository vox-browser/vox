// The full extension has a second static-network stage once response headers
// arrive. Keep its header order and duplicate-field semantics in the engine.
export function checkResponseHeaders(snfe, fctx, details, headers = []) {
    const type = details.request_type === 'fetch' ? 'xmlhttprequest' : details.request_type || 'other';
    // traffic.js treats top-level documents in its separate response policy
    // path and does not call PageStore.filterOnHeaders for them.
    if (type === 'main_frame') return { blocked: false, exception: false, rule: '', redirect_url: '', error: '' };
    fctx.setURL(details.url).setDocOriginFromURL(details.source_url || details.url)
        .setTabOriginFromURL(details.source_url || details.url).setType(type).setMethod(details.method || 'GET');
    const result = snfe.matchHeaders(fctx, headers);
    const log = result === 0 ? undefined : snfe.toLogData();
    return { blocked: result === 1, exception: result === 2, rule: log?.raw || '', redirect_url: '', error: '' };
}
