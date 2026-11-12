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
// The active locale comes from `VOX_LANG` (preferred) or `LANG` and falls
// back to English for unknown codes, so English output is unchanged until a
// locale is selected (e.g. `VOX_LANG=fa`).

pub fn supported_locales() []string {
	return ['en']
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
	if code := os.getenv_opt('VOX_LANG') {
		return locale_from_code(code)
	}
	if code := os.getenv_opt('LANG') {
		return locale_from_code(code)
	}
	return default_locale()
}

// locale_table serves the string table for a supported locale. Unknown
// locales fall back to English; add one arm per locale file.
fn locale_table(_locale string) map[string]string {
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
	'settings.gpu':          'GPU-accelerated scrolling'
	'settings.gpu-help':     'Turn off if scrolled pages show drawing errors.'
	'settings.cancel':       'Cancel'
	'settings.apply':        'Apply'
}
