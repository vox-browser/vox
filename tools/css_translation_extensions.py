"""Compatibility properties not yet present in the LibWeb source snapshot."""

PROPERTIES = {
    'interpolate-size': {
        'style-group': 'InheritedUIValues', 'affects-layout': False, 'animation-type': 'none',
        'inherited': True, 'initial': 'numeric-only', 'requires-computation': 'never',
        'valid-identifiers': ['numeric-only', 'allow-keywords'],
    },
    'grid-lanes-pack': {
        'initial':'normal','animation-type':'discrete','requires-computation':'never',
        'valid-identifiers':['normal','dense'],
    },
    'flow-tolerance': {'legacy-alias-for':'fit-tolerance'},
    'grid-lanes-direction': {
        'initial': 'normal', 'animation-type': 'discrete', 'requires-computation': 'never',
        'max-values': 3, 'valid-identifiers': ['normal','row','column','fill-reverse','track-reverse'],
    },
    'fit-tolerance': {
        'initial': 'normal', 'animation-type': 'by-computed-value', 'requires-computation': 'cascaded-value',
        'valid-types': ['length [0,∞]','percentage [0,∞]'],
        'valid-identifiers': ['normal','infinite'], 'percentages-resolve-to': 'length',
    },
    'overscroll-behavior': {
        'initial': 'auto', 'longhands': ['overscroll-behavior-x','overscroll-behavior-y'],
        'positional-value-list-shorthand': True,
    },
    **{'overscroll-behavior-'+axis: {
        'initial': 'auto', 'animation-type': 'discrete', 'affects-layout': False,
        'requires-computation': 'never', 'valid-identifiers': ['auto','contain','none','chain'],
    } for axis in ['x','y','inline','block']},
    'alignment-baseline': {
        'animation-type': 'discrete', 'initial': 'baseline',
        'requires-computation': 'never',
        'valid-identifiers': ['baseline', 'text-bottom', 'alphabetic', 'ideographic',
                              'middle', 'central', 'mathematical', 'hanging', 'text-top'],
    },
    'baseline-shift': {
        'animation-type': 'by-computed-value', 'initial': '0px',
        'requires-computation': 'cascaded-value',
        'valid-types': ['length [-∞,∞]', 'percentage [-∞,∞]'],
        'valid-identifiers': ['sub', 'super', 'top', 'center', 'bottom'],
        'percentages-resolve-to': 'length',
    },
    'baseline-source': {
        'animation-type': 'discrete', 'initial': 'auto',
        'requires-computation': 'never', 'valid-identifiers': ['auto','first','last'],
    },
    'border-shape': {
        'animation-type': 'by-computed-value',
        'affects-layout': False,
        'initial': 'none',
        'requires-computation': 'cascaded-value',
        'valid-identifiers': ['none'],
    },
    'text-orientation': {
        'animation-type': 'discrete',
        'inherited': True,
        'initial': 'mixed',
        'requires-computation': 'never',
        'valid-identifiers': ['mixed', 'upright', 'sideways'],
    },
    'forced-color-adjust': {
        'animation-type': 'discrete',
        'affects-layout': False,
        'initial': 'auto',
        'inherited': True,
        'requires-computation': 'never',
        'valid-identifiers': ['auto', 'none'],
    },
    'font-palette': {
        'style-group': 'FontValues',
        'animation-type': 'by-computed-value',
        'affects-layout': False,
        'inherited': True,
        'initial': 'normal',
        'requires-computation': 'cascaded-value',
        'valid-types': ['string'],
        'valid-identifiers': ['normal', 'light', 'dark'],
    },
    'font-size-adjust': {
        'style-group': 'FontValues',
        'animation-type': 'by-computed-value',
        'inherited': True,
        'initial': 'none',
        'requires-computation': 'cascaded-value',
        'valid-types': ['number [0,∞]'],
        'valid-identifiers': ['none'],
    },
    # Ladybird 2919bf87: position-try shorthand, absent from the older working snapshot.
    'position-try': {
        'initial': 'normal none',
        'longhands': ['position-try-order', 'position-try-fallbacks'],
    },
    'animation-range': {
        'affects-layout': False,
        'initial': 'normal',
        'multiplicity': 'coordinating-list',
        'longhands': ['animation-range-start', 'animation-range-end'],
    },
    **{
        'animation-range-' + name: {
            'style-group': 'AnimationValues',
            'affects-layout': False,
            'animation-type': 'none',
            'initial': 'normal',
            'inherited': False,
            'requires-computation': 'cascaded-value',
            'valid-types': ['length', 'percentage'],
            'valid-identifiers': ['normal'],
            'percentages-resolve-to': 'length',
            'multiplicity': 'coordinating-list',
        }
        for name in ['start', 'end']
    },
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
    'text-align-last': {
        'animation-type': 'discrete', 'inherited': True, 'initial': 'auto',
        'requires-computation': 'never',
        'valid-identifiers': ['auto', 'start', 'end', 'left', 'right', 'center', 'justify',
                              'match-parent'],
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

KEYWORDS = ['any', 'numeric-only', 'allow-keywords', 'dense', 'grid-lanes', 'inline-grid-lanes', 'fill-reverse', 'track-reverse', 'chain', 'first', 'mixed', 'sideways', 'manual', 'oblique-only', 'cap', 'ex', 'trim-start', 'trim-end', 'trim-both', 'flow-start', 'flow-end', 'flip-x', 'flip-y']


def extend_properties(properties):
    result = dict(properties)
    for name, definition in PROPERTIES.items():
        result.setdefault(name, definition)
    animation = dict(result['animation'])
    animation['longhands'] = list(animation['longhands'])
    for name in ['animation-range-start', 'animation-range-end']:
        if name not in animation['longhands']:
            animation['longhands'].append(name)
    result['animation'] = animation
    font = dict(result['font'])
    font['longhands'] = list(font['longhands'])
    if 'font-size-adjust' not in font['longhands']:
        font['longhands'].append('font-size-adjust')
    result['font'] = font
    return result


def extend_shorthand_tables(tables):
    for table in ['longhands_for_shorthand', 'expanded_longhands_for_shorthand']:
        for shorthand, values in tables[table]:
            if shorthand == 'font' and 'font_size_adjust' not in values:
                values.append('font_size_adjust')
            if shorthand == 'animation':
                for name in ['animation_range_start', 'animation_range_end']:
                    if name not in values:
                        values.append(name)
    for name, definition in PROPERTIES.items():
        if definition.get('legacy-alias-for'):
            continue
        identifier = name.replace('-', '_')
        longhands = definition.get('longhands')
        if longhands:
            for table in ['longhands_for_shorthand', 'expanded_longhands_for_shorthand']:
                tables[table].append((identifier, [value.replace('-', '_') for value in longhands]))
            for longhand in longhands:
                for property_name, shorthands in tables['shorthands_for_longhand']:
                    if property_name == longhand.replace('-', '_') and identifier not in shorthands:
                        shorthands.insert(0, identifier)
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
            if name in ['animation-range-start', 'animation-range-end']:
                shorthands.insert(0, 'animation')
            if name == 'font-size-adjust':
                shorthands.insert(0, 'font')
            tables['shorthands_for_longhand'].append((identifier, shorthands + ['all']))
    return tables
