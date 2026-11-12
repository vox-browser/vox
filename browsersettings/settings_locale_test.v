module browsersettings

import os

const settings_error_messages = [
	'Enter a proxy hostname or IP address, without a URL scheme.',
	'Enter a port between 1 and 65535.',
	'Enter a valid proxy hostname or IP address.',
	'Enter site hostnames without schemes, paths, ports or wildcards.',
	'Enter at least one site, or leave the field empty for all sites.',
	'Settings have not been initialized.',
]

fn test_settings_error_localization() {
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
	os.setenv('VOX_LANG', 'en', true)
	assert settings_locale() == 'en'
	for message in settings_error_messages {
		assert localize_error(message) == message
	}
	assert localize_error('unmapped message') == 'unmapped message'
	os.setenv('VOX_LANG', 'de_DE.UTF-8', true)
	assert settings_locale() == 'en'
	for message in settings_error_messages {
		assert localize_error(message) == message
	}
	os.unsetenv('VOX_LANG')
	os.setenv('LANG', 'en_US.UTF-8', true)
	assert settings_locale() == 'en'
}
