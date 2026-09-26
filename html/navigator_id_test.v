module html

import dom
import loader

fn navigator_id_test_loader(user_agent string, platform string, mode loader.NavigatorCompatibilityMode) {
	if !loader.is_initialized() {
		loader.initialize()
	}
	mut resource_loader := loader.ResourceLoader.the()
	resource_loader.set_user_agent(user_agent)
	resource_loader.set_platform(platform)
	resource_loader.set_navigator_compatibility_mode(mode)
}

fn test_navigator_id_chrome_and_webkit_values() {
	navigator_id_test_loader('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36', 'Linux x86_64',
		.chrome)
	chrome := NavigatorIDMixin{
		navigator_id_global_url: dom.URL{
			value: 'https://example.test/'
		}
	}
	assert chrome.app_code_name() == 'Mozilla'
	assert chrome.app_name() == 'Netscape'
	assert chrome.app_version() == '5.0 (X11; Linux x86_64) AppleWebKit/537.36'
	assert chrome.platform() == 'Linux x86_64'
	assert chrome.product() == 'Gecko'
	assert chrome.product_sub() == '20030107'
	assert chrome.user_agent() == 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
	assert chrome.vendor() == 'Google Inc.'
	assert chrome.vendor_sub() == ''

	navigator_id_test_loader('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36', 'Linux x86_64',
		.webkit)
	webkit := NavigatorIDMixin{}
	assert webkit.product_sub() == '20030107'
	assert webkit.vendor() == 'Apple Computer, Inc.'
}

fn test_navigator_id_gecko_app_version() {
	navigator_id_test_loader('Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:128.0) Gecko/20100101',
		'MacIntel', .gecko)
	mac := NavigatorIDMixin{}
	assert mac.app_version() == '5.0 (Macintosh)'
	assert mac.product_sub() == '20100101'
	assert mac.vendor() == ''

	navigator_id_test_loader('Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101', 'Win32',
		.gecko)
	windows := NavigatorIDMixin{}
	assert windows.app_version() == '5.0 (Windows)'

	navigator_id_test_loader('Ladybird/1.0', 'Win32', .gecko)
	invalid := NavigatorIDMixin{}
	assert invalid.app_version() == ''
}

fn test_navigators_expose_their_id_language_and_hardware_mixins() {
	navigator_id_test_loader('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36', 'Linux x86_64',
		.chrome)
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	navigator := Navigator.create(NavigatorHostConfiguration{
		associated_document: document
	})
	assert navigator.navigator_id_url().serialize() == 'https://example.test/page'
	document.set_url(dom.URL{ value: 'https://example.test/pushed' })
	assert navigator.navigator_id_url().serialize() == 'https://example.test/pushed'
	assert navigator.user_agent() == 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
	assert navigator.hardware_concurrency() > 0
	assert navigator.on_line()

	worker := WorkerNavigator.create(dom.URL{ value: 'https://example.test/worker.js' })
	assert worker.navigator_id_url().serialize() == 'https://example.test/worker.js'
	assert worker.platform() == 'Linux x86_64'
	assert worker.languages().len > 0
	assert worker.hardware_concurrency() > 0
}
