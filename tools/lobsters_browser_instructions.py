#!/usr/bin/env python3
"""Compare sealed Lobsters homepage launch/capture instructions with full uBO.

Uses the CNN full-uBO harness and its seven-pair conservative acceptance gate.
The dated guest DOM, all story identities and image sources, filter provenance,
and original live pixel reference must remain unchanged.
"""
import hashlib
import json
import sys

import cnn_home_browser_instructions as harness
from measure_sealed_github_instructions import FixtureHTML, text_content
from page_archive import load_archive

SITE = 'lobsters'
URL = 'https://lobste.rs/'
SCOPE = harness.SCOPE
SELECTORS = [dict(name='body', selector='body', limit=1, attributes=[]),
             dict(name='stories', selector='li.story', limit=1000,
                  attributes=['id', 'data-shortid']),
             dict(name='titles', selector='li.story .u-url', limit=1000, attributes=['href']),
             dict(name='images', selector='img', limit=1000, attributes=['src', 'srcset']),
             dict(name='all', selector='*', limit=0, attributes=[])]


def fixture_expectations(archive):
    manifest = load_archive(archive)
    harness.browser.require(manifest['url'] == URL, 'Expected Lobsters homepage archive')
    entry = manifest['responses'][URL]
    harness.browser.require(entry['status'] == 200, 'Lobsters main response must succeed')
    parser = FixtureHTML()
    parser.feed((archive / 'bodies' / entry['sha256']).read_text())
    harness.browser.require(not any(n['tag'] == 'script' for n in parser.nodes),
                            'This workload requires the script-free frozen DOM')
    stories = [n for n in parser.nodes if n['tag'] == 'li'
               and 'story' in (n['attrs'].get('class') or '').split()]
    titles = [n for n in parser.nodes if 'u-url' in (n['attrs'].get('class') or '').split()]
    ids = [n['attrs']['id'] for n in stories]
    title = next(text_content(n) for n in parser.nodes if n['tag'] == 'title')
    harness.browser.require(title == 'Lobsters' and len(ids) == 25 and len(set(ids)) == 25
                            and len(titles) == 25, 'Incomplete Lobsters story inventory')
    capture = archive / 'capture.json'
    harness.browser.require(harness.browser.sha(capture) == manifest['capture_report_sha256'],
                            'Lobsters capture provenance changed')
    provenance = json.loads(capture.read_text())
    harness.check_filters(provenance)
    lists = json.loads((harness.REPO / 'adblock/lists/manifest.json').read_text())
    harness.browser.require(provenance['engine'] == lists['engine'] and provenance['lists'] ==
                            [{k: row[k] for k in ('name', 'sha256')} for row in lists['lists']],
                            'Lobsters filter provenance differs from current lists')
    return dict(url=URL, title=title, story_ids=ids,
                story_shortids=[n['attrs']['data-shortid'] for n in stories],
                titles=[' '.join(text_content(n).split()) for n in titles],
                links=[n['attrs']['href'] for n in titles],
                images=sorted((n['attrs'].get('src', ''), n['attrs'].get('srcset', ''))
                              for n in parser.nodes if n['tag'] == 'img'),
                html_sha256=entry['sha256'], html_bytes=entry['bytes'],
                manifest_sha256=harness.browser.sha(archive / 'manifest.json'),
                responses=len(manifest['responses']), workload=manifest.get('workload'))


def validate_document(audit, expected):
    require = harness.browser.require
    require(audit.get('url') == URL and audit.get('title') == expected['title']
            and audit.get('ready') == 'complete'
            and [audit.get('viewport_width'), audit.get('viewport_height')] == [1024, 768],
            'Lobsters document identity, readiness or viewport failed')
    selections = {row['name']: row for row in audit.get('selections', [])}
    require(set(selections) >= {s['name'] for s in SELECTORS}, 'Missing Lobsters audit')
    for name in ('body', 'stories', 'titles', 'images'):
        require(selections[name]['count'] == len(selections[name]['elements']),
                'Truncated Lobsters ' + name + ' inventory')
    stories, titles = (selections[n]['elements'] for n in ('stories', 'titles'))
    require([n['attributes'].get('id') for n in stories] == expected['story_ids']
            and [n['attributes'].get('data-shortid') for n in stories] == expected['story_shortids'],
            'Lobsters stories missing, changed or reordered')
    require([' '.join(n['text'].split()) for n in titles] == expected['titles']
            and [n['attributes'].get('href') for n in titles] == expected['links'],
            'Lobsters story titles or destinations changed')
    images = selections['images']['elements']
    require(sorted((n['attributes'].get('src', ''), n['attributes'].get('srcset', ''))
                   for n in images) == expected['images'], 'Lobsters image inventory changed')
    body = selections['body']['elements']
    require(len(body) == 1 and len(body[0]['text']) > 1000 and selections['all']['count'] > 500,
            'Lobsters body or DOM incomplete')
    require(audit.get('fonts_status') == 'loaded', 'Lobsters fonts not ready')
    visible = 0
    for row in images:
        r = row['rect']
        if r['width'] <= 0 or r['height'] <= 0 or r['x'] >= 1024 or r['y'] >= 768 or r['x'] + r['width'] <= 0 or r['y'] + r['height'] <= 0:
            continue
        image = row.get('image') or {}
        require((image.get('complete') and image.get('natural_width', 0) > 0)
                or (image.get('paint_decoded') and image.get('paint_width', 0) > 0),
                'Lobsters visible image not decoded')
        visible += 1
    require(visible > 0, 'Lobsters visible avatars missing')
    return dict(passed=True, stories=len(stories), images=len(images), visible_images=visible,
                dom_elements=selections['all']['count'],
                body_text_sha256=hashlib.sha256(body[0]['text'].encode()).hexdigest())


def audit_expression():
    return harness.audit_expression(SELECTORS)


if __name__ == '__main__':
    raise SystemExit(harness.main(workload=sys.modules[__name__]))
