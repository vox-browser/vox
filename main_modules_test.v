module main

import browserjs
import dom
import html
import time

fn test_compact_module_startup_uses_parser_import_map_and_waits_before_dom_ready() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document_with_response_time('<!doctype html><div id="result">pending</div><script type="importmap">{"imports":{"fixture":"data:text/javascript,export%20const%20value%3D42"}}</script><script>document.addEventListener("DOMContentLoaded",()=>result.textContent+=":ready");</script><script type="module">import {value} from "fixture";if(document.currentScript!==null)throw new Error("module currentScript");result.textContent=String(value);</script>', dom.URL{ value: 'https://module-startup.test/' }, none, none, 1000)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	sources := script_sources(document, document.url.serialize(), {}, mut messages)
	run_document_script_sources(document, document.url.serialize(), sources, runtime, mut messages)
	assert messages == []string{}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut loop := settings.responsible_event_loop()
	deadline := time.sys_mono_now() + 5 * time.second
	loop.spin_until(fn [runtime, deadline] () bool {
		return (runtime.evaluate_host('result.textContent==="42:ready"') or { 'false' }) == 'true'
			|| time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host('result.textContent')! == '42:ready'
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_runtime_state(document, state, runtime, mut messages)
	assert messages == []string{}
	assert document.get_element_by_id('result')?.as_node().text_content()? == '42:ready'
}
