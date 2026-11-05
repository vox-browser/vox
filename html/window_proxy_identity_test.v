module html

import dom
import page

fn window_proxy_identity_document(address string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(native) }
}

fn test_actual_document_browsing_context_and_typed_window_share_source_proxy() {
	mut document, window := window_proxy_identity_document('https://window-proxy-identity.example/creation')!
	defer { document.finalize() }
	context := window.browsing_context()
	proxy := context.window_proxy()?
	native_context := document.get_browsing_context()?
	native_proxy := native_context.window_proxy()
	assert native_proxy == proxy.dom_proxy()
	assert native_proxy.window()? == document.get_window()?
	assert proxy.window() == window
	assert context.active_window()? == window
	assert native_context.active_document()? == document
}

fn test_source_proxy_native_and_typed_reassociation_updates_context_and_property_owner() {
	mut original, original_window := window_proxy_identity_document('https://window-proxy-identity.example/original')!
	mut replacement, replacement_window := window_proxy_identity_document('https://replacement-proxy.example/current')!
	defer {
		original.finalize()
		replacement.finalize()
	}
	mut context := unsafe { &BrowsingContextModel(original_window.browsing_context()) }
	mut proxy := context.window_proxy()?
	native_proxy := original.get_browsing_context()?.window_proxy()
	replacement_native := replacement.get_window()?
	native_proxy.set_window(replacement_native)
	assert proxy.window() == replacement_window
	assert context.active_window()? == replacement_window
	assert proxy.associated_browsing_context() == replacement_window.browsing_context()
	assert proxy.internal_set(replacement.origin(), 'currentOwner', dom.js_string('replacement'))!
	assert replacement_window.named_property('currentOwner').string_data == 'replacement'
	assert original_window.named_property('currentOwner').is_undefined()
	if _ := proxy.internal_get(original.origin(), 'currentOwner') {
		assert false, 'old Window origin must not authorize current proxy property access'
	} else {
		assert err.msg().starts_with('SecurityError:')
	}
	proxy.set_window(original_window)
	assert native_proxy.window()? == original.get_window()?
	assert context.active_window()? == original_window
	context.set_active_window(replacement_window)
	assert native_proxy.window()? == replacement.get_window()?
	assert proxy.window() == replacement_window
	context.set_active_window(original_window)
	assert native_proxy.window()? == original.get_window()?
	assert proxy.window() == original_window
	assert original.get_window()? == unsafe { &dom.Window(original_window) }
}

fn test_actual_navigation_retains_native_context_proxy_and_updates_current_window() {
	mut original, original_window := window_proxy_identity_document('https://window-proxy-identity.example/before')!
	defer { original.finalize() }
	context := original_window.browsing_context()
	proxy := context.window_proxy()?
	native_context := original.get_browsing_context()?
	native_proxy := native_context.window_proxy()
	navigable := original.navigable()?
	url := dom.URL{value: 'https://next-proxy.example/after'}
	mut replacement := create_navigation_document_for_page(url, url.origin(), original, original.page())!
	defer { replacement.finalize() }
	replacement_native := replacement.get_window()?
	replacement_window := unsafe { &WindowModel(replacement_native) }
	assert replacement_native != original.get_window()?
	assert replacement_window.browsing_context() == context
	assert context.window_proxy()? == proxy
	assert replacement.get_browsing_context()? == native_context
	assert native_context.window_proxy() == native_proxy
	assert native_proxy == proxy.dom_proxy()
	assert native_context.active_document()? == replacement
	assert context.active_document()? == replacement
	assert native_proxy.window()? == replacement_native
	assert proxy.window() == replacement_window
	assert context.active_window()? == replacement_window
	assert replacement.navigable()? == navigable
	assert navigable.active_document_is(replacement)
	assert !navigable.active_document_is(original)
	assert original.navigable() == none
	assert original.get_window()? == unsafe { &dom.Window(original_window) }
	assert original.get_browsing_context()?.window_proxy().window()? == replacement_native
}
