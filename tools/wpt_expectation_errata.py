"""Apply explicit, hash-pinned expectation errata to served test pages only.

The exported upstream fixtures remain immutable. Errata may replace one literal
expected-value line per listed page; they cannot change harnesses, test names,
registration, deadlines or JavaScript control flow.
"""
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit


def load_expectation_errata(path, root, revision, cases):
    data = json.loads(Path(path).read_text())
    if (data.get('format') != 'vox-wpt-expectation-errata-v1'
            or data.get('ladybird_revision') != revision):
        raise ValueError('Expectation errata format or fixture revision differs')
    corrections = data.get('corrections')
    if not isinstance(corrections, list) or not corrections:
        raise ValueError('Expectation errata must contain corrections')
    selected = {case['id']: case for case in cases}
    root = Path(root).resolve()
    overrides, applied = {}, []
    literal = re.compile(r'  expected: "[^"\\\r\n<>]+"')
    for entry in corrections:
        case = selected.get(entry['case'])
        if case is None:
            raise ValueError('Erratum is outside the selected cohort: ' + entry['case'])
        address = urlsplit(case['url'])
        url = address.path
        if (address.query or address.fragment
                or sum(urlsplit(item['url']).path == url for item in cases) != 1):
            raise ValueError('Errata cannot implicitly modify other query variants')
        source = (root / unquote(url).lstrip('/')).resolve()
        if not source.is_relative_to(root) or source.suffix != '.html' or url in overrides:
            raise ValueError('Errata require distinct test HTML paths inside the fixture root')
        original = source.read_bytes()
        digest = hashlib.sha256(original).hexdigest()
        if digest != entry['source_sha256']:
            raise ValueError('Erratum source hash differs: ' + entry['case'])
        before, after = entry['original_assertion'], entry['corrected_assertion']
        if (not literal.fullmatch(before) or not literal.fullmatch(after)
                or before == after or not entry.get('reason', '').strip()):
            raise ValueError('Errata may change only a literal expected-value line')
        text = original.decode('utf-8')
        if len(re.findall('^' + re.escape(before) + '$', text, re.M)) != 1:
            raise ValueError('Erratum must match exactly one complete assertion line')
        corrected = re.sub('^' + re.escape(before) + '$', lambda _: after, text,
                           count=1, flags=re.M).encode('utf-8')
        overrides[url] = (corrected, 'text/html; charset=utf-8')
        applied.append(dict(case=case['id'], url=url, source_sha256=digest,
                            served_sha256=hashlib.sha256(corrected).hexdigest(),
                            original_assertion=before, corrected_assertion=after,
                            reason=entry['reason']))
    return overrides, applied
