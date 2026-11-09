module main

import browserjs

import dom
import html

fn test_csp_source_location_maps_native_setter_positions_to_authored_statement_start() {
	url := dom.URL{value: 'https://source-position.test/page'}
	mut document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	settings.set_policy_container(&html.PolicyContainer{csp_list: [html.parse_response_csp_policy("script-src 'self'", .enforce, url.origin())]})
	runtime.bind_scripting_environment(settings)!
	runtime.define_host_function('captureSourcePosition', fn [settings] (_ string) !string {
		provider := settings.realm().current_source_location_ or { return error('missing source provider') }
		location := provider() or { return error('missing source location') }
		return '${location.url}:${location.line}:${location.column}'
	})!
	runtime.evaluate_host('globalThis.target = {set value(v) {globalThis.capturedPosition = captureSourcePosition("")}};')!
	runtime.run_document_scripts([browserjs.ScriptSource{
		code: '(() => {\n    target.value = 1;\n})();'
		url: url.serialize()
		starting_line: 9
	}])!
	assert runtime.evaluate_host('capturedPosition')! == '${url.serialize()}:10:5'
}
