module browsersettings

const settings_error_messages = [
	'Enter a proxy hostname or IP address, without a URL scheme.',
	'Enter a port between 1 and 65535.',
	'Enter a valid proxy hostname or IP address.',
	'Enter site hostnames without schemes, paths, ports or wildcards.',
	'Enter at least one site, or leave the field empty for all sites.',
	'Settings have not been initialized.',
	'Enter language codes separated by commas (e.g. fa, en), or leave empty for the system language.',
]

fn test_settings_error_localization() {
	assert default_error_locale() == 'en'
	assert 'en' in supported_error_locales()
	for message in settings_error_messages {
		assert localize_error('en', message) == message
	}
	assert localize_error('en', 'unmapped message') == 'unmapped message'
	assert localize_error('de', settings_error_messages[1]) == settings_error_messages[1]
}
