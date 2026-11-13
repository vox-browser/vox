#!/usr/bin/env python3
"""Check the browser chrome localization for consistency.

Verifies that every registered locale table covers exactly the English keys,
that every locale error table covers all user-facing validation messages,
and that no moved English literal survives in non-test UI sources (tests
keep asserting the English default). Adding a locale means adding its
`<locale>_chrome_strings` / `<locale>_error_messages` tables; this checker
picks them up automatically. Run from the repository root:

    python3 tools/check_browser_locale.py
"""
import re
import sys
from pathlib import Path

LOCALE = Path('browserui/browser_locale.v')
LOCALE_GLOB = 'browserui/browser_locale*.v'
LOCALE_TEST = Path('browserui/browser_locale_test.v')
SETTINGS_GLOB = 'browsersettings/settings_locale*.v'

SETTINGS_ERRORS = [
    'Enter a proxy hostname or IP address, without a URL scheme.',
    'Enter a port between 1 and 65535.',
    'Enter a valid proxy hostname or IP address.',
    'Enter site hostnames without schemes, paths, ports or wildcards.',
    'Enter at least one site, or leave the field empty for all sites.',
    'Settings have not been initialized.',
    'Enter language codes separated by commas (e.g. fa, en), or leave empty for the system language.',
]

EN_SPOT_CHECKS = {
    'nav.back': 'Back',
    'find.notfound': 'Not found',
    'settings.apply': 'Apply',
}

# Per-locale spot checks, e.g. 'fa': {'nav.back': 'قبلی'}. Locales without
# an entry here still get full key-parity and non-empty checks.
LOCALE_SPOT_CHECKS: dict[str, dict[str, str]] = {}

# (relative source, English literal) pairs that tr() has replaced. Test
# files are intentionally excluded: they keep asserting English output.
MOVED_LITERALS = [
    ('browserapp/link_context_menu.v', 'Open Link in New Tab'),
    ('browserapp/link_context_menu.v', 'Copy Link URL'),
    ('browserapp/browser_chrome.v', "'Settings…'"),
    ('browserapp/browser_settings.v', "'Browsing'"),
    ('browserapp/browser_settings.v', "'Use SOCKS5 proxy'"),
    ('browserui/navigation_icons.v', "'Back'"),
    ('browserui/find_bar.v', "'Find in page'"),
    ('browserui/find_bar.v', "'Not found'"),
    ('browserui/tabs.v', "'New tab'"),
    ('browserui/update_notice.v', "'Vox update available'"),
    ('browserui/status_bar.v', "'Build time (UTC)'"),
    ('browserui/tab_title_editor.v', "'Rename Tab'"),
    ('browserui/address_field.v', "'Enter a URL'"),
    ('browserui/address_info_icon.v', "'Page information'"),
    ('browserui/address_suggestions.v', "'Address suggestions'"),
]


def fail(message):
    print(f'error: {message}')
    return 1


def parse_string_map(text, const_name):
    """Extract the {'k': 'v'} entries of one top-level const map."""
    match = re.search(r'const ' + re.escape(const_name) + r'\s*=\s*\{', text)
    if match is None:
        return None
    depth = 0
    body_start = match.end() - 1
    for i in range(body_start, len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                body = text[body_start + 1:i]
                break
    else:
        return None
    return dict(re.findall(r"'((?:[^'\\]|\\.)*)'\s*:\s*'((?:[^'\\]|\\.)*)'", body))


def collect_const_tables(repo, glob, suffix):
    """Find every `<locale><suffix>` const (e.g. `fa_chrome_strings`)."""
    tables = {}
    for path in sorted((repo).glob(glob)):
        try:
            text = path.read_text(encoding='utf-8')
        except OSError as err:
            return None, fail(f'cannot read {path}: {err}')
        for name in re.findall(r'const (\w+' + re.escape(suffix) + r')\s*=\s*\{', text):
            locale = name[: -len(suffix)]
            parsed = parse_string_map(text, name)
            if parsed is None:
                return None, fail(f'cannot parse {name} in {path}')
            if locale in tables:
                return None, fail(f'duplicate table for locale {locale!r} in {path}')
            tables[locale] = parsed
    return tables, 0


def main():
    repo = Path(__file__).resolve().parent.parent
    failures = 0

    chrome, err = collect_const_tables(repo, LOCALE_GLOB, '_chrome_strings')
    if chrome is None:
        return err
    if 'en' not in chrome:
        print('error: no en_chrome_strings table found')
        return 1
    en = chrome['en']
    for key, value in en.items():
        if not value:
            print(f'error: empty en string for {key}')
            failures += 1
    for key, want in EN_SPOT_CHECKS.items():
        if en.get(key) != want:
            print(f'error: en[{key}] is {en.get(key)!r}, want {want!r}')
            failures += 1
    for locale, table in sorted(chrome.items()):
        if locale == 'en':
            continue
        if set(table) != set(en):
            print(f'error: {locale} key mismatch: only-en={sorted(set(en) - set(table))} '
                  f'only-{locale}={sorted(set(table) - set(en))}')
            failures += 1
        for key, value in table.items():
            if not value:
                print(f'error: empty {locale} string for {key}')
                failures += 1
        for key, want in LOCALE_SPOT_CHECKS.get(locale, {}).items():
            if table.get(key) != want:
                print(f'error: {locale}[{key}] is {table.get(key)!r}, want {want!r}')
                failures += 1

    errors, err = collect_const_tables(repo, SETTINGS_GLOB, '_error_messages')
    if errors is None:
        return err
    for locale, table in sorted(errors.items()):
        if locale == 'en':
            continue
        for message in SETTINGS_ERRORS:
            if not table.get(message):
                print(f'error: no {locale} message for {message!r}')
                failures += 1

    for rel, literal in MOVED_LITERALS:
        try:
            text = (repo / rel).read_text(encoding='utf-8')
        except OSError as err:
            return fail(f'cannot read {rel}: {err}')
        if literal in text:
            print(f'error: {rel} still embeds {literal}; use tr()')
            failures += 1

    if failures:
        print(f'{failures} problem(s) found.')
        return 1
    locales = sorted(l for l in chrome if l != 'en')
    print(f'browser chrome locale is consistent '
          f'({len(en)} keys, locales: {", ".join(["en", *locales])}, '
          f'{len(SETTINGS_ERRORS)} error messages).')
    return 0


if __name__ == '__main__':
    sys.exit(main())
