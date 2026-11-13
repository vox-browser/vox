module browsersettings

// Canonical validation messages mirrored from settings_locale_test.v. Test
// files compile independently, so this list is repeated here instead of
// shared; tools/check_browser_locale.py is the single source of truth.
const fa_settings_error_messages = [
	'Enter a proxy hostname or IP address, without a URL scheme.',
	'Enter a port between 1 and 65535.',
	'Enter a valid proxy hostname or IP address.',
	'Enter site hostnames without schemes, paths, ports or wildcards.',
	'Enter at least one site, or leave the field empty for all sites.',
	'Settings have not been initialized.',
	'Enter language codes separated by commas (e.g. fa, en), or leave empty for the system language.',
]

fn test_settings_error_fa_localization() {
	for message in fa_settings_error_messages {
		fa := localize_error('fa', message)
		assert fa != '' && fa != message
	}
	assert localize_error('fa', 'unmapped message') == 'unmapped message'
	assert localize_error('fa', 'Enter a port between 1 and 65535.') == 'درگاه بین 1 تا 65535 وارد کنید.'
	assert localize_error('en', 'Enter a port between 1 and 65535.') == 'Enter a port between 1 and 65535.'
}
