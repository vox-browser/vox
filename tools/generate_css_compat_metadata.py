#!/usr/bin/env python3
"""Add compatibility properties without replacing newer translated metadata.

The local upstream generated C++ can lag behind completed V translations.
Generate candidate tables in a temporary directory, then import only newly
registered compatibility properties and keywords. Existing property semantics,
aliases, shorthand members, and keyword spellings remain owned by the checked
in tables. Register PropertyID entries before running this command.
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from css_translation_extensions import PROPERTIES, KEYWORDS


def block_end(source, opening):
    depth = 0
    quote = None
    i = opening
    while i < len(source):
        char = source[i]
        if quote:
            if char == '\\':
                i += 2
                continue
            if char == quote:
                quote = None
        elif source.startswith('//', i):
            i = source.find('\n', i)
            if i < 0:
                break
            continue
        elif source.startswith('/*', i):
            end = source.find('*/', i + 2)
            if end < 0:
                break
            i = end + 2
            continue
        elif char in "'\"`":
            quote = char
        elif char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError('unterminated V block')


def function_span(source, name):
    match = re.search(r'(?m)^(?:pub )?fn ' + re.escape(name) + r'\([^\n]*\)[^{]*\{', source)
    if not match:
        raise ValueError('function not found: ' + name)
    opening = source.index('{', match.start())
    return opening, block_end(source, opening)


ARM = re.compile(r'(?m)^\t\t(?P<labels>\.\w+(?:\s*,\s*\.\w+)*)\s*\{')


def merge_property_arms(current, generated, identifiers):
    names = re.findall(r'(?m)^(?:pub )?fn (\w+)\(', generated)
    for name in names:
        opening, end = function_span(generated, name)
        body = generated[opening:end]
        additions = []
        for arm in ARM.finditer(body):
            labels = [value for value in re.findall(r'\.(\w+)', arm['labels'])
                      if value in identifiers]
            if not labels:
                continue
            start = body.index('{', arm.start())
            additions.append('\t\t' + ', '.join('.' + value for value in labels) +
                             ' ' + body[start:block_end(body, start)])
        if not additions:
            continue
        target_opening, target_end = function_span(current, name)
        target = current[target_opening:target_end]
        marker = re.search(r'(?:return\s+)?match property_id\s*\{', target)
        if not marker:
            raise ValueError('property match not found in ' + name)
        offset = target_opening + marker.end()
        current = current[:offset] + '\n' + '\n'.join(additions) + current[offset:]
    return current


def merge_all_members(source, identifiers):
    for name in ['generated_longhands_for_shorthand',
                 'generated_expanded_longhands_for_shorthand']:
        opening, end = function_span(source, name)
        body = source[opening:end]
        arm = re.search(r'(?m)^\t\t\.all\s*\{', body)
        if not arm:
            raise ValueError('all shorthand not found in ' + name)
        arm_opening = body.index('{', arm.start())
        arm_end = block_end(body, arm_opening)
        text = body[arm_opening:arm_end]
        members = set(re.findall(r'\.(\w+)', text))
        added = [value for value in sorted(identifiers) if value not in members]
        if added:
            # Compatibility font properties follow font-style in CSS-name order.
            anchor = '.font_style,'
            if all(value.startswith('font_synthesis_') for value in added) and anchor in text:
                text = text.replace(anchor, anchor + '\n\t\t\t\t' +
                                    ', '.join('.' + value for value in added) + ',', 1)
            else:
                index = text.rindex(']')
                text = text[:index] + ', ' + ', '.join('.' + value for value in added) + text[index:]
            offset = opening + arm_opening
            source = source[:offset] + text + source[opening + arm_end:]
    return source


def merge_properties(current, generated, definitions):
    opening, end = function_span(current['calculation'], 'string_from_property_id')
    known = set(re.findall(r"(?m)^\t\t\.(\w+) \{ '[^']*' \}", current['calculation'][opening:end]))
    added = {name.replace('-', '_'): name for name in definitions
             if name.replace('-', '_') not in known}
    if not added:
        return current
    result = dict(current)
    result['calculation'] = merge_property_arms(current['calculation'],
                                              generated['calculation'], set(added))
    opening, _ = function_span(result['calculation'], 'property_id_from_canonical_name')
    checks = ''.join("\n\tif name == '" + css + "' { return ." + identifier + ' }'
                     for identifier, css in added.items())
    result['calculation'] = (result['calculation'][:opening + 1] + checks +
                             result['calculation'][opening + 1:])
    result['shorthand'] = merge_property_arms(current['shorthand'],
                                            generated['shorthand'], set(added))
    longhands = {identifier for identifier, name in added.items()
                 if not definitions[name].get('longhands')}
    result['shorthand'] = merge_all_members(result['shorthand'], longhands)
    return result


def merge_keywords(current, generated, keywords):
    opening, end = function_span(current, 'string_from_keyword')
    known = dict((text, identifier) for identifier, text in
                 re.findall(r"\.(\w+) \{ '([^']*)' \}", current[opening:end]))
    opening, end = function_span(generated, 'string_from_keyword')
    candidates = dict((text, identifier) for identifier, text in
                      re.findall(r"\.(\w+) \{ '([^']*)' \}", generated[opening:end]))
    added = [(text, candidates[text]) for text in keywords if text not in known]
    if not added:
        return current
    match = re.search(r'(?m)^pub enum Keyword \{', current)
    opening = current.index('{', match.start())
    end = block_end(current, opening) - 1
    current = current[:end] + ''.join('\t' + name + '\n' for _, name in added) + current[end:]
    opening, _ = function_span(current, 'string_from_keyword')
    marker = current.index('return match keyword {', opening) + len('return match keyword {')
    current = current[:marker] + ''.join("\n\t\t." + name + " { '" + text + "' }"
                                        for text, name in added) + current[marker:]
    opening, _ = function_span(current, 'keyword_from_string')
    marker = current.index('name := to_ascii_lowercase(input)', opening) + len('name := to_ascii_lowercase(input)')
    current = current[:marker] + ''.join("\n\tif name == '" + text + "' { return ." + name + ' }'
                                        for text, name in added) + current[marker:]
    return current


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ladybird', type=Path, default=Path.home() / 'code/3rd/ladybird')
    parser.add_argument('--translation', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    paths = {'calculation': 'property_calculation_metadata.v',
             'shorthand': 'property_shorthand_metadata.v', 'keywords': 'style_values_core.v'}
    current = {name: (args.translation / 'css' / path).read_text() for name, path in paths.items()}
    with tempfile.TemporaryDirectory(prefix='vox-css-compat-') as directory:
        root = Path(directory)
        (root / 'css').mkdir()
        for name, path in paths.items():
            (root / 'css' / path).write_text(current[name])
        for script in ['generate_css_keywords.py', 'generate_css_calculation_metadata.py',
                       'generate_css_shorthand_metadata.py']:
            subprocess.run([sys.executable, str(Path(__file__).with_name(script)),
                            '--ladybird', str(args.ladybird), '--translation', str(root)], check=True)
        generated = {name: (root / 'css' / path).read_text() for name, path in paths.items()}
    result = merge_properties(current, generated, PROPERTIES)
    result['keywords'] = merge_keywords(current['keywords'], generated['keywords'], KEYWORDS)
    for name, path in paths.items():
        if result[name] != current[name]:
            (args.translation / 'css' / path).write_text(result[name])
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
