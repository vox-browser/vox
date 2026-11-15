#!/usr/bin/env python3
"""Generate native LibJS locale tables from the pinned Unicode CLDR JSON tree.

Input: unicode-org/cldr-json, tag 48.2.0, commit below. No host locale/ICU
queries, JavaScript execution or fixture-derived substitutions are used.
"""
from pathlib import Path
import argparse
import hashlib
import json

REVISION = 'bb334e8d6250c9363e957e131bf7e6d08ec72f91'
RELEASE = '48.2.0'


def generate(source: Path, destination: Path):
    hashes = {}

    def read(relative):
        data = (source / relative).read_bytes()
        hashes[relative] = hashlib.sha256(data).hexdigest()
        return json.loads(data)

    def supplemental(name):
        return read(f'cldr-json/cldr-core/supplemental/{name}.json')['supplemental']

    def strings(data):
        return {k: v if isinstance(v, str) else v['_value']
                for k, v in data.items() if isinstance(v, str) or '_value' in v}

    def names(data):
        return {f'{width}_{kind}': value
                for width in ['short', 'long'] for kind, value in data.get(width, {}).items()}

    def flatten_zones(data, prefix=''):
        result = {}
        for key, value in data.items():
            path = f'{prefix}/{key}' if prefix else key
            if not isinstance(value, dict):
                continue
            if 'exemplarCity' in value or 'long' in value or 'short' in value:
                result[path] = dict(names(value), city=value.get('exemplarCity', ''))
            else:
                result.update(flatten_zones(value, path))
        return result

    def encode(value):
        return json.dumps(value, ensure_ascii=False, separators=(',', ':'), sort_keys=True).encode()

    destination.mkdir(parents=True, exist_ok=True)
    zone_aliases = {}
    for value in read('cldr-json/cldr-bcp47/bcp47/timezone.json')['keyword']['u']['tz'].values():
        if not isinstance(value, dict) or '_alias' not in value:
            continue
        values = value['_alias'].split()
        primary = value.get('_iana', values[0])
        if primary in ['Etc/UTC', 'Etc/GMT']:
            primary = 'UTC'
        for alias in values + [primary]:
            zone_aliases[alias.lower()] = primary
    for alias in ['UTC', 'GMT', 'Etc/UTC', 'Etc/GMT', 'UCT', 'Universal', 'Zulu', 'Greenwich']:
        zone_aliases[alias.lower()] = 'UTC'
    spans, records, full_records = {}, bytearray(), {}
    locales = read('cldr-json/cldr-core/availableLocales.json')['availableLocales']['full']
    for locale in sorted(locales):
        calendar_path = f'cldr-json/cldr-dates-full/main/{locale}/ca-gregorian.json'
        if not (source / calendar_path).exists():
            continue
        calendar = read(calendar_path)['main'][locale]['dates']['calendars']['gregorian']
        zones = read(f'cldr-json/cldr-dates-full/main/{locale}/timeZoneNames.json')['main'][locale]['dates']['timeZoneNames']
        numbers = read(f'cldr-json/cldr-numbers-full/main/{locale}/numbers.json')['main'][locale]['numbers']
        record = {
            'months': {f'{context}_{width}': [values[str(i)] for i in range(1, 13)]
                       for context, widths in calendar['months'].items() for width, values in widths.items()},
            'weekdays': {f'{context}_{width}': [values[i] for i in ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat']]
                         for context, widths in calendar['days'].items() for width, values in widths.items()},
            'eras': {width: [values[str(i)] for i in range(2)] for width, values in calendar['eras'].items()},
            'periods': {f'{context}_{width}_{key}': value for context, widths in calendar['dayPeriods'].items()
                        for width, values in widths.items() for key, value in values.items() if '-alt-' not in key},
            'date_formats': strings(calendar['dateFormats']),
            'time_formats': strings(calendar['timeFormats']),
            'combinations': strings(calendar['dateTimeFormats']),
            'at_time': strings(calendar.get('dateTimeFormats-atTime', {}).get('standard', {})),
            'available': strings(calendar['dateTimeFormats']['availableFormats']),
            'zone_names': flatten_zones(zones.get('zone', {})),
            'meta_zone_names': {key: names(value) for key, value in zones.get('metazone', {}).items()},
            'gmt_format': zones['gmtFormat'], 'gmt_zero': zones['gmtZeroFormat'],
            'hour_format': zones['hourFormat'], 'region_format': zones['regionFormat'],
            'numbering_system': numbers['defaultNumberingSystem'],
            'decimal': {key.removeprefix('symbols-numberSystem-'): value.get('decimal', '.')
                        for key, value in numbers.items() if key.startswith('symbols-numberSystem-')},
        }
        for name, value in list(record['zone_names'].items()):
            primary = zone_aliases.get(name.lower(), name)
            if primary not in record['zone_names']:
                record['zone_names'][primary] = value
        full_records[locale] = record
    parents = supplemental('parentLocales')['parentLocales']['parentLocale']
    visiting = set()

    def emit(locale):
        if locale in spans:
            return
        assert locale not in visiting, 'CLDR parent cycle'
        visiting.add(locale)
        parent = parents.get(locale, '')
        if parent not in full_records:
            parent = locale.rsplit('-', 1)[0] if '-' in locale else ''
            while parent and parent not in full_records:
                parent = parent.rsplit('-', 1)[0] if '-' in parent else ''
        base = full_records.get(parent, {})
        if parent:
            emit(parent)
        delta = {'parent': parent, 'removed': {}}
        for key, value in full_records[locale].items():
            old = base.get(key)
            if value == old:
                continue
            if isinstance(value, dict) and isinstance(old, dict):
                delta[key] = {k: v for k, v in value.items() if k not in old or old[k] != v}
                missing = sorted(set(old) - set(value))
                if missing:
                    delta['removed'][key] = missing
            else:
                delta[key] = value
        data = encode(delta)
        spans[locale] = {'offset': len(records), 'length': len(data)}
        records.extend(data + b'\n')
        visiting.remove(locale)

    for locale in sorted(full_records):
        emit(locale)
    # CLDR omits default-content directories (e.g. en-US) because their
    # data lives in the parent, but Intl still negotiates these identifiers.
    for locale in read('cldr-json/cldr-core/defaultContent.json')['defaultContent']:
        parent = locale
        while parent not in spans and '-' in parent:
            parent = parent.rsplit('-', 1)[0]
        if parent in spans:
            spans[locale] = spans[parent]
    aliases = supplemental('aliases')['metadata']['alias']
    type_aliases = {}
    for name in ['calendar', 'collation', 'number', 'variant']:
        tree = read(f'cldr-json/cldr-bcp47/bcp47/{name}.json')['keyword']['u']
        for key, values in tree.items():
            if not isinstance(values, dict):
                continue
            for kind, record in values.items():
                if not isinstance(record, dict):
                    continue
                preferred = record.get('_preferred', kind)
                if preferred != kind:
                    type_aliases[f'{key}:{kind}'] = preferred
                for alias in record.get('_alias', '').split():
                    type_aliases[f'{key}:{alias.lower()}'] = preferred
    meta_zones = {}

    def flatten_meta(tree, prefix=''):
        for key, value in tree.items():
            path = f'{prefix}/{key}' if prefix else key
            if isinstance(value, list):
                meta_zones[path] = [{'name': item['usesMetazone']['_mzone'],
                                     'start': item['usesMetazone'].get('_from', ''),
                                     'end': item['usesMetazone'].get('_to', '')} for item in value]
            else:
                flatten_meta(value, path)

    flatten_meta(supplemental('metaZones')['metaZones']['metazoneInfo']['timezone'])
    for name, periods in list(meta_zones.items()):
        primary = zone_aliases.get(name.lower(), name)
        if primary not in meta_zones:
            meta_zones[primary] = periods
    periods = supplemental('dayPeriods')['dayPeriodRuleSet']
    language_rules = []
    for key, value in aliases['languageAlias'].items():
        if '-' not in key:
            continue
        parts = key.split('-'); language = parts.pop(0).lower()
        script = parts.pop(0).title() if parts and len(parts[0]) == 4 and parts[0].isalpha() else ''
        region = parts.pop(0).upper() if parts and ((len(parts[0]) == 2 and parts[0].isalpha()) or (len(parts[0]) == 3 and parts[0].isdigit())) else ''
        if any(not (5 <= len(v) <= 8 or (len(v) == 4 and v[0].isdigit())) for v in parts):
            continue
        language_rules.append({'language': language, 'script': script, 'region': region,
                               'variants': [v.lower() for v in parts], 'replacement': value['_replacement'].split()[0]})
    language_rules.sort(key=lambda r: (-len(r['variants']) - bool(r['script']) - bool(r['region']) - (r['language'] != 'und'), r['language'], r['replacement']))
    core = {
        'schema': 1, 'release': RELEASE, 'revision': REVISION, 'locale_spans': spans,
        'language_rules': language_rules,
        'language_alias': {k.lower(): v['_replacement'].split()[0] for k, v in aliases['languageAlias'].items()},
        'script_alias': {k.lower(): v['_replacement'] for k, v in aliases['scriptAlias'].items()},
        'region_alias': {k.upper(): v['_replacement'].split() for k, v in aliases['territoryAlias'].items()},
        'variant_alias': {k.lower(): v['_replacement'] for k, v in aliases['variantAlias'].items()},
        'likely_subtags': supplemental('likelySubtags')['likelySubtags'],
        'hour_cycles': {k: v['_preferred'] for k, v in supplemental('timeData')['timeData'].items()},
        'numbering_systems': {k: v['_digits'] for k, v in supplemental('numberingSystems')['numberingSystems'].items()
                              if v['_type'] == 'numeric'},
        'type_alias': type_aliases, 'zone_alias': zone_aliases, 'meta_zones': meta_zones,
        'day_periods': {locale: [{'name': name, 'at': value.get('_at', ''), 'start': value.get('_from', ''),
                                  'end': value.get('_before', '')} for name, value in rules.items()]
                       for locale, rules in periods.items()},
    }
    (destination / 'core.dat').write_bytes(encode(core) + b'\n')
    (destination / 'locales.dat').write_bytes(records)
    license_data = (source / 'LICENSE').read_bytes()
    (destination / 'LICENSE').write_bytes(license_data)
    hashes['LICENSE'] = hashlib.sha256(license_data).hexdigest()
    provenance = [f'Unicode CLDR JSON {RELEASE}, unicode-org/cldr-json commit {REVISION}',
                  'Source: https://github.com/unicode-org/cldr-json/tree/' + REVISION,
                  'Generated with tools/generate_libjs_intl_data.py; source file SHA-256:']
    provenance += [f'{digest}  {name}' for name, digest in sorted(hashes.items())]
    (destination / 'SOURCES').write_text('\n'.join(provenance) + '\n')
    print(f'{len(spans)} locales, {len(records):,} locale bytes, {(destination / "core.dat").stat().st_size:,} core bytes')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parent.parent / 'libjs/intl_data')
    args = parser.parse_args()
    generate(args.source, args.output)
