module html

fn test_navigator_id_chrome_and_webkit_values() {
	chrome := NavigatorIDMixin{
		environment_default_user_agent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
		platform_value:                 'Linux x86_64'
		compatibility_mode:             .chrome
	}
	assert chrome.app_code_name() == 'Mozilla'
	assert chrome.app_name() == 'Netscape'
	assert chrome.app_version() == '5.0 (X11; Linux x86_64) AppleWebKit/537.36'
	assert chrome.platform() == 'Linux x86_64'
	assert chrome.product() == 'Gecko'
	assert chrome.product_sub() == '20030107'
	assert chrome.user_agent() == chrome.environment_default_user_agent
	assert chrome.vendor() == 'Google Inc.'
	assert chrome.vendor_sub() == ''

	webkit := NavigatorIDMixin{
		compatibility_mode: .webkit
	}
	assert webkit.product_sub() == '20030107'
	assert webkit.vendor() == 'Apple Computer, Inc.'
}

fn test_navigator_id_gecko_app_version() {
	mac := NavigatorIDMixin{
		environment_default_user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:128.0) Gecko/20100101'
		compatibility_mode:             .gecko
	}
	assert mac.app_version() == '5.0 (Macintosh)'
	assert mac.product_sub() == '20100101'
	assert mac.vendor() == ''

	windows := NavigatorIDMixin{
		environment_default_user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101'
		compatibility_mode:             .gecko
	}
	assert windows.app_version() == '5.0 (Windows)'
	invalid := NavigatorIDMixin{
		environment_default_user_agent: 'Ladybird/1.0'
		compatibility_mode:             .gecko
	}
	assert invalid.app_version() == ''
}
