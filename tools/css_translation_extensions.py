"""Compatibility properties not yet present in the LibWeb source snapshot."""

PROPERTIES = {
    'font-synthesis': {
        'initial': 'weight style small-caps position',
        'longhands': ['font-synthesis-weight', 'font-synthesis-style',
                      'font-synthesis-small-caps', 'font-synthesis-position'],
        'valid-types': ['string'],
    },
    **{
        'font-synthesis-' + name: {
            'animation-type': 'discrete',
            'initial': 'auto',
            'inherited': True,
            'requires-computation': 'never',
            'valid-identifiers': ['auto', 'none'] +
                                 (['oblique-only'] if name == 'style' else []),
        }
        for name in ['weight', 'style', 'small-caps', 'position']
    },
    'hyphens': {
        'style-group': 'InheritedTextValues',
        'animation-type': 'discrete',
        'initial': 'manual',
        'inherited': True,
        'requires-computation': 'never',
        'valid-identifiers': ['none', 'manual', 'auto'],
    },
    'text-box-trim': {
        'animation-type': 'discrete',
        'initial': 'none',
        'inherited': False,
        'requires-computation': 'never',
        'valid-identifiers': ['none', 'trim-start', 'trim-end', 'trim-both'],
    },
    'text-box-edge': {
        'animation-type': 'discrete',
        'initial': 'auto',
        'inherited': True,
        'requires-computation': 'never',
        'valid-types': ['string'],
    },
}

KEYWORDS = ['manual', 'oblique-only', 'cap', 'ex', 'trim-start', 'trim-end', 'trim-both']


def extend_properties(properties):
    result = dict(properties)
    for name, definition in PROPERTIES.items():
        result.setdefault(name, definition)
    return result


def extend_shorthand_tables(tables):
    for name, definition in PROPERTIES.items():
        if definition.get('legacy-alias-for'):
            continue
        identifier = name.replace('-', '_')
        longhands = definition.get('longhands')
        if longhands:
            for table in ['longhands_for_shorthand', 'expanded_longhands_for_shorthand']:
                tables[table].append((identifier, [value.replace('-', '_') for value in longhands]))
            continue
        for table in ['longhands_for_shorthand', 'expanded_longhands_for_shorthand']:
            for shorthand, values in tables[table]:
                if shorthand == 'all' and identifier not in values:
                    # Preserve the generated CSS-name order (vendor-prefixed
                    # names sort before ordinary properties).
                    def css_name(value):
                        prefix = '-' if value.startswith('webkit_') else ''
                        return prefix + value.rstrip('_').replace('_', '-')
                    position = next((index for index, value in enumerate(values)
                                     if css_name(value) > name), len(values))
                    values.insert(position, identifier)
        if not any(property_name == identifier for property_name, _ in tables['shorthands_for_longhand']):
            shorthands = [shorthand.replace('-', '_') for shorthand, value in PROPERTIES.items()
                          if name in value.get('longhands', [])]
            tables['shorthands_for_longhand'].append((identifier, shorthands + ['all']))
    return tables
