import assert from 'node:assert/strict';
import { test } from 'node:test';
import { navigationObservation } from './navigation.mjs';

const snapshot = { url: 'https://example.org/', title: 'Example', body_text_length: 20, body_text_sample: 'News and other stories', element_count: 8, ready_state: 'complete' };
const event = (frameId, status) => ({ method: 'Network.responseReceived', params: { type: 'Document', frameId, response: { status } } });

test('uses the final main document response and ignores subframe errors', () => {
    const result = navigationObservation('http://example.org', { frameId: 'main' }, snapshot, [event('main', 301), event('main', 200), event('child', 403)]);
    assert.equal(result.url, snapshot.url);
    assert.equal(result.status, 200);
    assert.equal(result.coverage, 'page');
});
test('preserves failed navigation and HTTP failure coverage', () => {
    assert.equal(navigationObservation(snapshot.url, { frameId: 'main', errorText: 'net::ERR_CONNECTION_RESET' }, snapshot, []).coverage, 'error');
    assert.equal(navigationObservation(snapshot.url, { frameId: 'main' }, snapshot, [event('main', 403)]).coverage, 'error');
});
test('distinguishes a challenge and a consent interstitial from site content', () => {
    const challenge = navigationObservation(snapshot.url, {}, { ...snapshot, body_text_sample: "You've been blocked by network security." }, []);
    assert.equal(challenge.coverage, 'challenge');
    assert.equal(challenge.challenge_detected, true);
    assert.equal(navigationObservation(snapshot.url, {}, { ...snapshot, title: 'Before you continue to YouTube' }, []).coverage, 'consent');
    assert.equal(navigationObservation(snapshot.url, {}, { ...snapshot, title: 'Robot Check' }, []).coverage, 'challenge');
    assert.equal(navigationObservation(snapshot.url, {}, { ...snapshot, title: 'Amazon.com', body_text_sample: 'Click the button below to continue shopping' }, []).coverage, 'challenge');
});
test('a small content page is useful while an empty document is not', () => {
    assert.equal(navigationObservation(snapshot.url, {}, snapshot, []).coverage, 'page');
    assert.equal(navigationObservation(snapshot.url, {}, { url: snapshot.url }, []).coverage, 'empty');
    assert.equal(navigationObservation(snapshot.url, {}, { ...snapshot, body_text_length: 0, element_count: 100 }, []).coverage, 'empty');
});
test('accepts site subdomains but rejects a successful unrelated redirect', () => {
    assert.equal(navigationObservation('https://www.example.org/', {}, { ...snapshot, url: 'https://edition.example.org/' }, []).coverage, 'page');
    assert.equal(navigationObservation(snapshot.url, {}, { ...snapshot, url: 'https://parking.example/' }, []).coverage, 'unexpected-origin');
    assert.equal(navigationObservation(snapshot.url, {}, { ...snapshot, url: 'https://example.org.parking.example/' }, []).coverage, 'unexpected-origin');
});
