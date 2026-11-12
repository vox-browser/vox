module browsersettings

import os

// Validation-message localization registry. English stays the single source
// of truth where validation runs; localize_error maps known messages at the
// display edge through per-locale tables, so validation logic never branches
// on locale. Unknown locales and unmapped messages pass through unchanged.
//
// How to add a locale `xx`:
//   1. Add a `xx_error_messages` table (e.g. in `settings_locale_xx.v`)
//      covering every message in `tools/check_browser_locale.py`'s
//      `SETTINGS_ERRORS`.
//   2. List `'xx'` in `supported_error_locales()` and serve the table from
//      `error_table()`, and mirror the locale variants in
//      `settings_normalize_code()` if they differ from the base subtag rule.

pub fn supported_error_locales() []string {
	return ['en']
}

pub fn default_error_locale() string {
	return 'en'
}

// settings_normalize_code reduces values like `fa_IR.UTF-8` or `EN-us` to
// their base language subtag in lowercase (`fa`, `en`).
pub fn settings_normalize_code(code string) string {
	c := code.to_lower().trim_space()
	for i in 0 .. c.len {
		b := c[i]
		if b == `_` || b == `-` || b == `.` {
			return c[..i]
		}
	}
	return c
}

fn error_table(_locale string) map[string]string {
	return map[string]string{}
}

pub fn settings_locale() string {
	if code := os.getenv_opt('VOX_LANG') {
		base := settings_normalize_code(code)
		if base in supported_error_locales() {
			return base
		}
		return default_error_locale()
	}
	if code := os.getenv_opt('LANG') {
		base := settings_normalize_code(code)
		if base in supported_error_locales() {
			return base
		}
		return default_error_locale()
	}
	return default_error_locale()
}

pub fn localize_error(message string) string {
	locale := settings_locale()
	if locale != default_error_locale() {
		if s := error_table(locale)[message] {
			return s
		}
	}
	return message
}
