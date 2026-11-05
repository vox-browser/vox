module browserjs

import dom
import html

fn test_classic_import_call_filter_keeps_plain_source_and_classic_parse_goal() {
	$if !darwin { return }
	mut document := html.create_navigation_document(dom.URL{value: 'https://call-scan.test/page'},
		dom.URL{value: 'https://call-scan.test/'}.origin(), none)!
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	seen := &ModuleTestRequests{}
	mut host := ModuleHost.create(settings, module_test_transport({}, seen))
	host.install(mut runtime)!
	plain := ScriptSource{url: 'https://call-scan.test/plain.js', code: r'
globalThis.importText=["@import","dynamic-import","Please add import \"reflect-metadata\""];
const loader={};loader.import=async value=>value;
globalThis.importTextDone=importText.length===3&&typeof loader.import==="function";
'}
	assert host.transform_classic(plain)!.code == plain.code
	assert runtime.run_document_scripts_collect_errors([plain]) == []string{}
	assert runtime.evaluate_host('importTextDone')! == 'true'
	for code in ['import value from "./value.js";', 'import "./value.js";',
		'import.meta.url;', 'import', r'import\u0061', 'import /* unterminated'] {
		assert runtime.run_document_scripts_collect_errors([ScriptSource{code: code}]).len == 1, code
	}
	assert seen.urls.len == 0
}

fn test_classic_import_call_filter_retains_comments_unicode_whitespace_and_later_imports() {
	$if !darwin { return }
	mut document := html.create_navigation_document(dom.URL{value: 'https://call-scan.test/page'},
		dom.URL{value: 'https://call-scan.test/'}.origin(), none)!
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	seen := &ModuleTestRequests{}
	mut host := ModuleHost.create(settings, module_test_transport({
		'https://call-scan.test/value.js': 'export default 42;'
	}, seen))
	host.install(mut runtime)!
	for index, gap in [' /* comment */ ', ' // comment\n ', '\u00a0', '\uFEFF',
		' // comment\u2028 ', ' // comment\u2029 '] {
		code := '"@import";"dynamic-import";globalThis.scanDone${index}=false;import${gap}("./value.js").then(ns=>globalThis.scanDone${index}=ns.default===42);'
		source := ScriptSource{url: 'https://call-scan.test/call.js', code: code}
		assert classic_source_may_need_import_rewrite(code), 'gap ${index}'
		// The trusted lexer can leave a source unchanged (for example, a
		// BOM between import and its opening parenthesis). Keep its exact
		// result and require actual native import execution in every case.
		expected := host.rewrite(code, source.url, source.url, false)!
		assert host.transform_classic(source)!.code == expected, 'gap ${index}'
		assert runtime.run_document_scripts_collect_errors([source]) == []string{}
		module_test_until(host, runtime, 'globalThis.scanDone${index}===true')
	}
	assert host.errors() == []string{}
	assert seen.urls == ['https://call-scan.test/value.js']
}
