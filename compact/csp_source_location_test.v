module main

import browserjs
import html
import url as _

@[heap]
struct CSPSourceLocationObservation {
mut:
	url string
	line u32
	column u32
}

fn test_csp_global_uses_the_actual_native_javascript_callsite() {
	mut document := html.parse_document('<!doctype html><div></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,'https://csp-location.test/page.html',[],runtime,mut messages)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	observed := &CSPSourceLocationObservation{}
	runtime.define_value_host_function('__captureCSPCallsite',fn [settings,observed] (_ voidptr, _ []voidptr) !voidptr {
		global := settings.fetch_request_client_csp_global()
		mut observation := unsafe { &CSPSourceLocationObservation(observed) }
		observation.url = if source := global.source_file { source.serialize(false) } else { '' }
		observation.line = global.line_number
		observation.column = global.column_number
		return unsafe { nil }
	})!
	errors := runtime.run_document_scripts_collect_errors([
		browserjs.ScriptSource{code:'\n    __captureCSPCallsite();',url:'https://csp-location.test/source.js',starting_line:30},
	])
	assert errors.len == 0,errors.str()
	assert observed.url == 'https://csp-location.test/source.js',observed.url
	assert observed.line == 31 && observed.column > 0,'${observed.line}:${observed.column}'
}
