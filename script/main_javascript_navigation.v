module main

import contentsecuritypolicy as csp
import html
import url

// LocalNavigable::evaluate_javascript_url: non-string completion values leave
// the active document in place. In particular, javascript:void(0) is not a fetch.
fn (mut app BrowserApp) navigate_javascript_url(address url.URL) {
	if app.document == unsafe { nil } || app.js_runtime == unsafe { nil }
		|| !compact_document_can_run_script(app.document) {
		return
	}
	settings_pointer := app.document.relevant_settings_object()
	if settings_pointer != unsafe { nil } {
		settings := unsafe { &html.EnvironmentSettingsObject(settings_pointer) }
		mut global := settings.fetch_request_client_csp_global()
		mut request := csp.new_request(address)
		request.policy_list = global.policy_list
		if csp.should_navigation_request_of_type_be_blocked_by_content_security_policy(mut global,
			&request, .other) == .blocked {
			return
		}
	}
	mut runtime := app.js_runtime
	source := url.percent_decode(address.serialize(false)['javascript:'.len..]).bytestr()
	value := runtime.evaluate_host_value(source) or {
		app.js_messages << 'JavaScript URL: ${err.msg()}'
		runtime.mark_document_state_dirty()
		app.poll_javascript_tasks()
		return
	}
	// Read the completion without coercing objects or undefined to markup.
	markup := if text := runtime.native_utf16_string(value) { ?string(text.str()) } else { none }
	retained_markup := markup or { '' }
	defer {
		$if gcboehm ? { C.GC_reachable_here(retained_markup.str) }
	}
	runtime.release_javascript_value(value)
	generation := app.navigation_generation
	current_url := app.document.url.serialize()
	runtime.mark_document_state_dirty()
	app.poll_javascript_tasks()
	if app.navigation_generation != generation || app.deferred_navigation_input != none { return }
	if replacement := markup {
		loaded := LoadedPage{
			url:                   current_url
			markup:                replacement
			content_type:          'text/html'
			status:                app.load_status
			javascript_url_source: app.document
		}
		app.install_loaded_page(loaded, false)
		app.update_current_history_entry(loaded)
	}
}
