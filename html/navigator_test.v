@[has_globals]
module html

import dom
import fetch
import loader

__global navigator_test_beacon_request &fetch.Request

fn navigator_test_capture_beacon(request &fetch.Request) {
	navigator_test_beacon_request = request
}

fn test_navigator_lazily_creates_singletons_and_plugins() {
	mut navigator := Navigator.create(NavigatorHostConfiguration{
		pdf_viewer_supported: true
		webdriver_active:     true
	})
	assert navigator.cookie_enabled()
	assert !navigator.java_enabled()
	assert navigator.pdf_viewer_enabled()
	assert navigator.webdriver()
	assert navigator.plugins().length() == 5
	assert navigator.mime_types().length() == 2
	assert voidptr(navigator.clipboard()) == voidptr(navigator.clipboard())
	assert voidptr(navigator.service_worker()) == voidptr(navigator.service_worker())
	battery := navigator.get_battery()
	assert battery.rejected
	assert battery.exception_name == 'NotAllowedError'
	assert battery.reason == 'Battery Status API is not yet implemented'
	assert voidptr(battery) == voidptr(navigator.get_battery())

	mut worker := WorkerNavigator.create()
	assert voidptr(worker.serial()) == voidptr(worker.serial())
	assert worker.media_capabilities().name == 'mediaCapabilities'
}

fn test_navigator_beacon_builds_keepalive_fetch_request() {
	mut navigator := Navigator.create(NavigatorHostConfiguration{})
	mut context := NavigatorBeaconContext.create(dom.URL{ value: 'https://example.test/base/' }, dom.Origin{
		value: 'https://example.test'
	})
	context.fetch_hook = navigator_test_capture_beacon
	navigator.configure_beacon_context(context)
	assert navigator.send_beacon('collect', BeaconBody{
		bytes:        'payload'.bytes()
		content_type: 'application/json'
	}) or { panic(err) }
	request := navigator_test_beacon_request
	assert request != unsafe { nil }
	assert request.method == 'POST'
	assert request.keepalive
	assert request.mode == .cors
	assert request.credentials_mode == .include
	assert request.current_url().serialize() == 'https://example.test/base/collect'
	assert request.body.bytes.bytestr() == 'payload'
	assert navigator_beacon_partial_send_beacon(mut navigator, 'collect-again', none)!

	assert !(navigator.send_beacon('/too-large', BeaconBody{
		bytes: []u8{len: int(keepalive_maximum_size)}
	}) or { panic(err) })
	if _ := navigator.send_beacon('file:///tmp/beacon', none) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
}

fn test_navigator_languages_come_from_the_resource_loader() {
	if !loader.is_initialized() {
		loader.initialize()
	}
	mut resource_loader := loader.ResourceLoader.the()
	resource_loader.set_preferred_languages(['fr-CA', 'en']) or { panic(err) }
	navigator := Navigator.create(NavigatorHostConfiguration{})
	assert navigator.language() == 'fr-CA'
	assert navigator.languages() == ['fr-CA', 'en']
}
