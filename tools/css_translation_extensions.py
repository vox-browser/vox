"""Compatibility properties not yet present in the LibWeb source snapshot."""

PROPERTIES = {
    'hyphens': {
        'style-group': 'InheritedTextValues',
        'animation-type': 'discrete',
        'initial': 'manual',
        'inherited': True,
        'requires-computation': 'never',
        'valid-identifiers': ['none', 'manual', 'auto'],
    },
}

KEYWORDS = ['manual']


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
            tables['shorthands_for_longhand'].append((identifier, ['all']))
    return tables
