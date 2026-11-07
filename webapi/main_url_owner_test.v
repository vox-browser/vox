module main

import browserjs
import html

fn test_native_page_url_binding_retains_query_identity_and_replays_document_text() {
	$if !darwin { return }
	document := html.parse_document('<div id="result">pending</div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-url.example.test/root/page.html', [
		'globalThis.actualAddress=new URL("../target??name=value","https://native-url.example.test/root/page.html");const query=actualAddress.searchParams;query.append("extra","a b");result.textContent=actualAddress.href;',
		'addEventListener("load",()=>result.textContent+=" ready");',
	], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'https://native-url.example.test/target?%3Fname=value&extra=a+b ready'
	actual := runtime.evaluate_host_value('actualAddress')!
	url := runtime.native_url(actual)!
	assert url.href() == 'https://native-url.example.test/target?%3Fname=value&extra=a+b'
	assert voidptr(url.search_params()) == voidptr(runtime.native_url_search_params(runtime.evaluate_host_value('actualAddress.searchParams')!)!)
	assert !runtime.libjs_vm().has_running_execution_context()
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
}
