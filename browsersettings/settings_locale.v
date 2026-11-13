module browsersettings

// Validation-message localization tables. English stays the single source of
// truth where validation runs; localize_error maps known messages at the
// display edge through per-locale tables, so validation logic never branches
// on locale. The caller passes the already-resolved UI locale (see
// browserui.ui_locale), so error text always matches the chrome language.
// Unknown locales and unmapped messages pass through unchanged.
//
// How to add a locale `xx`:
//   1. Add a `xx_error_messages` table (e.g. in `settings_locale_xx.v`)
//      covering every message in `tools/check_browser_locale.py`'s
//      `SETTINGS_ERRORS`.
//   2. List `'xx'` in `supported_error_locales()` and serve the table from
//      `error_table()`.

pub fn supported_error_locales() []string {
	return ['en', 'fa']
}

pub fn default_error_locale() string {
	return 'en'
}

fn error_table(locale string) map[string]string {
	if locale == 'fa' {
		return fa_error_messages
	}
	return map[string]string{}
}

pub fn localize_error(locale string, message string) string {
	if locale != default_error_locale() {
		if s := error_table(locale)[message] {
			return s
		}
	}
	return message
}
