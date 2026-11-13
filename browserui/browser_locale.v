module browserui

import os

// Browser chrome localization system.
//
// String tables live per locale (`en_chrome_strings` below; see
// `browser_locale_fa.v` for an example follow-up locale). Every table must
// cover exactly the same keys; `tools/check_browser_locale.py` enforces the
// parity and `browser_locale_test.v` covers the fallback behavior.
//
// How to add a locale `xx`:
//   1. Add a `xx_chrome_strings` table with exactly the `en` keys.
//   2. List `'xx'` in `supported_locales()` and serve the table from
//      `locale_table()`.
//   3. If `xx` uses non-Latin digits, shape them in `format_digits()`.
//   4. Add `browser_locale_xx_test.v` plus checker spot checks.
// The active locale resolves as: `VOX_LANG` (developer override), then the
// explicit user list (settings, most preferred first), then the OS locale,
// then English. The resolved value is cached per process (see
// `refresh_locale`); the settings UI applies a change through
// `set_preferred_languages`.

__global (
	cached_chrome_locale = ''
	explicit_chrome_languages = []string{}
)

pub fn supported_locales() []string {
	return ['en', 'fa']
}

pub fn default_locale() string {
	return 'en'
}

// normalize_locale_code reduces values like `fa_IR.UTF-8`, `FA-ir` or
// `en_US` to their base language subtag in lowercase (`fa`, `en`).
pub fn normalize_locale_code(code string) string {
	c := code.to_lower().trim_space()
	for i in 0 .. c.len {
		b := c[i]
		if b == `_` || b == `-` || b == `.` {
			return c[..i]
		}
	}
	return c
}

pub fn locale_from_code(code string) string {
	base := normalize_locale_code(code)
	if base in supported_locales() {
		return base
	}
	return default_locale()
}

pub fn ui_locale() string {
	if cached_chrome_locale == '' {
		return refresh_locale()
	}
	return cached_chrome_locale
}

// set_preferred_languages overrides the UI locale with an explicit ordered
// list (most preferred first), as chosen in settings. An empty list clears
// the override. The cache is dropped so the next lookup re-resolves.
pub fn set_preferred_languages(langs []string) {
	mut clean := []string{}
	for lang in langs {
		tag := lang.trim_space()
		if tag == '' || tag in clean {
			continue
		}
		clean << tag
	}
	explicit_chrome_languages = clean.clone()
	cached_chrome_locale = ''
}

// refresh_locale re-resolves the active locale from the current
// configuration. Production code resolves once and caches: the process
// locale never changes at runtime, while a settings panel or tab strip
// formats dozens of strings per render and each resolution scans the
// environment. Tests call this after changing VOX_LANG/LANG or the
// preferred list.
pub fn refresh_locale() string {
	cached_chrome_locale = resolve_locale()
	return cached_chrome_locale
}

fn resolve_locale() string {
	if code := os.getenv_opt('VOX_LANG') {
		return locale_from_code(code)
	}
	for lang in explicit_chrome_languages {
		base := normalize_locale_code(lang)
		if base in supported_locales() {
			return base
		}
	}
	if explicit_chrome_languages.len > 0 {
		return default_locale()
	}
	// The OS default already folds an explicitly exported LANG in on every
	// platform, so tests stay deterministic and real GUI launches follow
	// the system region and language settings.
	if tag := platform_locale_tag() {
		base := normalize_locale_code(tag)
		if base in supported_locales() {
			return base
		}
		return default_locale()
	}
	return default_locale()
}

// platform_locale_tag reports the OS locale as a BCP47 tag (e.g. `fa-IR`,
// `en-US`), or none when it cannot be determined. An explicitly exported
// LANG wins over the system default on every platform; otherwise Unix
// follows LC_ALL > LC_MESSAGES > LANG, macOS reads the AppleLanguages
// preference, and Windows reads the user locale.
fn platform_locale_tag() ?string {
	$if windows {
		if code := os.getenv_opt('LANG') {
			if code.trim_space() != '' {
				return code
			}
		}
		return windows_locale_tag()
	}
	$if macos {
		if code := os.getenv_opt('LANG') {
			if code.trim_space() != '' {
				return code
			}
		}
		return macos_locale_tag()
	}
	for name in ['LC_ALL', 'LC_MESSAGES', 'LANG'] {
		if code := os.getenv_opt(name) {
			if code.trim_space() != '' {
				return code
			}
		}
	}
	return none
}

$if macos {
	fn macos_locale_tag() ?string {
		result := os.execute('defaults read -g AppleLanguages')
		if result.exit_code != 0 {
			return none
		}
		return parse_apple_languages(result.output)
	}
}

// parse_apple_languages extracts the first entry of
// `defaults read -g AppleLanguages` output, e.g. `(\n    "fa-IR",\n    en\n)`.
fn parse_apple_languages(output string) ?string {
	for line in output.split_into_lines() {
		token := line.trim_space().trim(',').trim('"')
		if token == '' || token == '(' || token == ')' {
			continue
		}
		if token.len >= 2 {
			return token
		}
	}
	return none
}

$if windows {
	#include <windows.h>
	fn C.GetLocaleInfoA(locale int, lctype u32, lcdata &char, cchdata int) int
	fn windows_locale_tag() ?string {
		// LOCALE_USER_DEFAULT, LOCALE_SISO639LANGNAME, LOCALE_SISO3166CTRYNAME.
		mut lang := []u8{len: 16}
		if C.GetLocaleInfoA(0x0400, 0x59, &char(lang.data), lang.len) <= 0 {
			return none
		}
		language := unsafe { cstring_to_vstring(&char(lang.data)) }
		if language == '' {
			return none
		}
		mut country := []u8{len: 16}
		if C.GetLocaleInfoA(0x0400, 0x5a, &char(country.data), country.len) <= 0 {
			return language
		}
		region := unsafe { cstring_to_vstring(&char(country.data)) }
		if region == '' {
			return language
		}
		return '${language}-${region}'
	}
}

// locale_table serves the string table for a supported locale. Unknown
// locales fall back to English; add one arm per locale file.
fn locale_table(locale string) map[string]string {
	if locale == 'fa' {
		return fa_chrome_strings
	}
	return en_chrome_strings
}

// tr resolves a chrome string id for the current UI locale. Unknown ids
// return the id itself so a missing entry is visible, never blank.
pub fn tr(key string) string {
	return tr_for(ui_locale(), key)
}

pub fn tr_for(locale string, key string) string {
	if locale != default_locale() {
		if s := locale_table(locale)[key] {
			return s
		}
	}
	return en_chrome_strings[key] or { key }
}

// trf resolves a pattern string and substitutes `{name}` placeholders.
pub fn trf(key string, args map[string]string) string {
	return trf_for(ui_locale(), key, args)
}

pub fn trf_for(locale string, key string, args map[string]string) string {
	mut s := tr_for(locale, key)
	for name, value in args {
		s = s.replace('{' + name + '}', value)
	}
	return s
}

// format_digits renders display-only digits for a locale. The default is the
// identity; locales with non-Latin digits override it in their locale file.
pub fn format_digits(locale string, input string) string {
	if locale == 'fa' {
		return fa_digits(input)
	}
	return input
}

// find_status_text mirrors FindBar.status with locale-aware counts. Counts
// stay ASCII in validation-adjacent strings but use the locale digits here:
// this label is display-only and never parsed back.
pub fn find_status_text(query string, searched bool, current int, total int) string {
	locale := ui_locale()
	if query == '' || !searched {
		return ''
	}
	if total == 0 {
		return tr_for(locale, 'find.notfound')
	}
	return trf_for(locale, 'find.status', {
		'current': format_digits(locale, current.str())
		'total':   format_digits(locale, total.str())
	})
}

pub fn update_version_text(latest string, current string) string {
	locale := ui_locale()
	return trf_for(locale, 'update.version', {
		'latest':  latest
		'current': current
	})
}

// window_button_text prefers a per-action key (`window.close`) when the
// locale provides one and falls back to the generic pattern otherwise, so
// locales with their own word order need no code change.
pub fn window_button_text(action string) string {
	locale := ui_locale()
	specific := tr_for(locale, 'window.${action}')
	if specific != 'window.${action}' {
		return specific
	}
	return trf_for(locale, 'window.button', {
		'action': action
	})
}

pub fn close_tab_text(title string) string {
	locale := ui_locale()
	return trf_for(locale, 'tab.close', {
		'title': title
	})
}

pub fn tab_color_text(color string) string {
	return tr_for(ui_locale(), 'tab.color.${color}')
}

const en_chrome_strings = {
	'nav.back':              'Back'
	'nav.forward':           'Forward'
	'nav.reload':            'Reload'
	'chrome.history':        'History'
	'menu.browser':          'Browser'
	'menu.settings':         'Settings…'
	'menu.history':          'History'
	'menu.devtools':         'Developer Tools'
	'menu.inspect':          'Inspect Element'
	'menu.console':          'JavaScript Console'
	'address.hint':          'Enter a URL'
	'address.info':          'Page information'
	'address.suggestions':   'Address suggestions'
	'tab.new':               'New tab'
	'tab.loading':           'Loading'
	'tab.color.menu':        'Tab Color…'
	'tab.color.group':       'Tab Color'
	'tab.color.default':     'Default'
	'tab.color.red':         'Red'
	'tab.color.orange':      'Orange'
	'tab.color.yellow':      'Yellow'
	'tab.color.green':       'Green'
	'tab.color.blue':        'Blue'
	'tab.color.purple':      'Purple'
	'tab.color.pink':        'Pink'
	'tab.rename.menu':       'Rename Tab…'
	'tab.title.heading':     'Rename Tab'
	'tab.title.hint':        'Tab title'
	'tab.title.a11y':        'Custom tab title'
	'tab.title.help':        'Leave empty to use the page title.'
	'tab.title.use-page':    'Use Page Title'
	'tab.title.cancel':      'Cancel'
	'tab.title.save':        'Save'
	'find.hint':             'Find in page'
	'find.notfound':         'Not found'
	'find.status':           '{current} of {total}'
	'status.build-time':     'Build time (UTC)'
	'update.title':          'Vox update available'
	'update.help':           'OK opens vox-browser.org in your default browser'
	'update.quit-help':      'and closes this version of Vox.'
	'update.error':          'Could not open your browser. Try OK again.'
	'update.later':          'Later'
	'update.version':        'Version {latest} is available (installed: {current}).'
	'window.button':         '{action} window'
	'window.close':          'close window'
	'window.minimize':       'minimize window'
	'window.zoom':           'zoom window'
	'tab.close':             'Close {title}'
	'ctx.open-link':         'Open Link in New Tab'
	'ctx.copy-link':         'Copy Link URL'
	'ctx.inspect':           'Inspect'
	'settings.title':        'Vox Settings'
	'settings.browsing':     'Browsing'
	'settings.tab-coloring': 'Enable tab coloring'
	'settings.custom-titles': 'Enable custom tab titles'
	'settings.network':      'Network'
	'settings.proxy':        'Use SOCKS5 proxy'
	'settings.host':         'Host'
	'settings.port':         'Port'
	'settings.a11y.host':    'SOCKS5 proxy host'
	'settings.a11y.port':    'SOCKS5 proxy port'
	'settings.sites':        'Only for these sites'
	'settings.a11y.sites':   'Only use SOCKS5 proxy for these sites; empty means all sites'
	'settings.sites-help':   'Includes subdomains. Separate with commas; leave empty for all.'
	'settings.other-direct': 'Other sites connect directly. Proxied DNS uses SOCKS5.'
	'settings.apply-note':   'Changes apply to new requests.'
	'settings.advanced':     'Advanced'
	'settings.languages':    'Languages'
	'settings.languages-help': 'Preferred languages, most preferred first. Empty uses the system language.'
	'settings.a11y.languages': 'Preferred user interface languages'
	'settings.gpu':          'GPU-accelerated scrolling'
	'settings.gpu-help':     'Turn off if scrolled pages show drawing errors.'
	'settings.cancel':       'Cancel'
	'settings.apply':        'Apply'
}
