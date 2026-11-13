module requestserver

import browsersettings
import os

fn test_fetch_host_advertises_configured_languages() {
	directory := os.join_path(os.temp_dir(), 'vox-fetch-languages-${os.getpid()}')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'settings.json')
	browsersettings.initialize(path)!
	assert preferred_fetch_languages() == ['en-US']
	browsersettings.save(browsersettings.Proxy{ languages: 'fa, en' })!
	assert browsersettings.current().languages == 'fa, en'
	assert preferred_fetch_languages() == ['fa', 'en']
	browsersettings.save(browsersettings.Proxy{ languages: '' })!
	assert preferred_fetch_languages() == ['en-US']
}
