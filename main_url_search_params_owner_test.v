module main

import browserjs
import domurl
import html

fn test_native_page_script_query_binding_reaches_real_records_and_dom_replay() {
	$if !darwin { return }
	document := html.parse_document('<div id="result">pending</div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-query.example.test/page.html', [
		'globalThis.actualQuery=new URLSearchParams("?%EF%BB%BFname=%EF%BB%BFvalue&a=1&a=2");actualQuery.delete("a","1");actualQuery.append("extra","a b");result.textContent=actualQuery.toString();',
		'addEventListener("load",()=>result.textContent+=" ready");',
	], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == '%EF%BB%BFname=%EF%BB%BFvalue&a=2&extra=a+b ready'
	actual := runtime.evaluate_host_value('actualQuery')!
	params := runtime.native_url_search_params(actual)!
	assert params.params() == [
		domurl.QueryParam{
			name:  '\ufeffname'
			value: '\ufeffvalue'
		},
		domurl.QueryParam{
			name:  'a'
			value: '2'
		},
		domurl.QueryParam{
			name:  'extra'
			value: 'a b'
		},
	]
	assert !runtime.libjs_vm().has_running_execution_context()
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
}
