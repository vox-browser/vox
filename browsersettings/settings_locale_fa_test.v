module browsersettings

import os

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
]

fn test_settings_error_fa_localization() {
	old_vox := os.getenv_opt('VOX_LANG')
	old_lang := os.getenv_opt('LANG')
	defer {
		if v := old_vox {
			os.setenv('VOX_LANG', v, true)
		} else {
			os.unsetenv('VOX_LANG')
		}
		if v := old_lang {
			os.setenv('LANG', v, true)
		} else {
			os.unsetenv('LANG')
		}
	}
	os.setenv('VOX_LANG', 'fa_IR.UTF-8', true)
	assert settings_locale() == 'fa'
	for message in fa_settings_error_messages {
		fa := localize_error(message)
		assert fa != '' && fa != message
	}
	assert localize_error('unmapped message') == 'unmapped message'
	assert localize_error('Enter a port between 1 and 65535.') == 'درگاه بین 1 تا 65535 وارد کنید.'
}
