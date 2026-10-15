// Keep access failures visible: a matching filter decision on an error or
// challenge page does not establish coverage of the requested site.
export function isExpectedSiteURL(requestedURL, finalURL) {
    const requestedHost = new URL(requestedURL).hostname.toLowerCase().replace(/^www\./, '');
    const final = new URL(finalURL);
    const finalHost = final.hostname.toLowerCase().replace(/^www\./, '');
    return /^https?:$/.test(final.protocol)
        && (finalHost === requestedHost || finalHost.endsWith(`.${requestedHost}`));
}

export function navigationObservation(requestedURL, result, snapshot, events) {
    const responses = events.filter(event => event.method === 'Network.responseReceived'
        && event.params.type === 'Document'
        && event.params.frameId === result.frameId);
    const response = responses.at(-1)?.params.response;
    const url = snapshot.url || requestedURL;
    const status = response?.status ?? null;
    const loadError = result.errorText || (url.startsWith('chrome-error:') ? 'Browser navigation failed' : '');
    const evidence = [];
    const title = snapshot.title || '';
    const text = snapshot.body_text_sample || '';
    if (/^(?:just a moment|access denied|attention required|robot check|security check|pardon our interruption)\b/i.test(title)) {
        evidence.push(`Challenge title: ${title}`);
    }
    const challenge = text.match(/you(?:'|’)ve been blocked by network security|your request has been blocked|enable javascript and cookies to continue|please enable js and disable any ad blocker|verify (?:that )?you (?:are|'re) (?:a human|not a robot)|whoa there, pardner|press (?:&|and) hold to confirm|click the button below to continue shopping|enter the characters you see below/i);
    if (challenge) evidence.push(`Access check: ${challenge[0]}`);
    const consent = /^(?:before you continue to|consent required)/i.test(title)
        || /^(?:consent|consent\.youtube)\./i.test(new URL(url).hostname);
    let coverage = 'page';
    if (loadError || (status !== null && status >= 400) || !/^https?:/.test(url)) coverage = 'error';
    else if (evidence.length) coverage = 'challenge';
    else if (consent) coverage = 'consent';
    else if (!isExpectedSiteURL(requestedURL, url)) coverage = 'unexpected-origin';
    else if (!snapshot.body_text_length) coverage = 'empty';
    return {
        requested_url: requestedURL, url, title, status,
        ready_state: snapshot.ready_state || '',
        body_text_length: snapshot.body_text_length || 0,
        body_text_sample: text,
        element_count: snapshot.element_count || 0,
        challenge_detected: evidence.length > 0,
        challenge_evidence: evidence,
        load_error: loadError, coverage,
    };
}
