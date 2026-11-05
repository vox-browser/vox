module browserjs

import dom
import html

fn test_named_import_filter_recognizes_only_property_and_tightly_delimited_member_forms() {
	for source in ['object.import(value)', 'object?.import(value)',
		'class Store{first(){}import(value){return value}}',
		'class Store{first(){}import(_value1){return _value1}}',
		'class Store{first(){}import($value){return $value}};store.import(value)',
		'"@import";class Store{first(){}import(value){return value}}'] {
		assert classic_source_has_only_named_import_candidates(source), source
	}
	for source in ['', '"@import"', 'import(value)', '...import(value)',
		'f(...import(value))', 'class Store extends import(value){}',
		'{}import(value)\n{}', '{}import(value)\r{}',
		'{}import(value)/*\n*/{}', '{}import(value)\u2028{}',
		'{}import(value)\u2029{}', '{}import(value) {}',
		'class Store{first(){}import(value){}};import(value)',
		'object.import(value);import(value)', '{}import(value/*comment*/){',
		'class Store{first(){}import(é){}}', '{}import(value)',
		'import /* comment */ (value)', 'import.meta.url', 'import.source(value)'] {
		assert !classic_source_has_only_named_import_candidates(source), source
	}
}

fn test_named_import_filter_keeps_methods_and_property_calls_on_the_original_native_parse_path() {
	$if !darwin { return }
	mut document := html.create_navigation_document(dom.URL{value:'https://named-import.test/page'},
		dom.URL{value:'https://named-import.test/'}.origin(), none)!
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	seen := &ModuleTestRequests{}
	mut host := ModuleHost.create(settings, module_test_transport({}, seen))
	host.install(mut runtime)!
	code := 'class Store{first(){}import(value){return value+1}};const store=new Store;globalThis.namedImportResult=store.import(41);'
	assert classic_source_has_only_named_import_candidates(code)
	assert host.rewrite(code,document.url.serialize(),document.url.serialize(),false)! == code
	assert host.transform_classic(ScriptSource{url:document.url.serialize(),code:code})!.code == code
	assert runtime.run_document_scripts_collect_errors([ScriptSource{url:document.url.serialize(),code:code}]) == []string{}
	assert runtime.evaluate_host('namedImportResult===42')! == 'true'
	assert seen.urls.len == 0
}

fn test_named_import_filter_preserves_later_imports_class_heritage_and_asi_before_a_block() {
	$if !darwin { return }
	mut document := html.create_navigation_document(dom.URL{value:'https://named-import.test/page'},
		dom.URL{value:'https://named-import.test/'}.origin(), none)!
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	mut scope := settings.universal_global_scope()
	map_ := html.parse_import_map_string('{"imports":{"named-value":"/value.js"}}', document.url)!
	scope.set_import_map(&map_)
	seen := &ModuleTestRequests{}
	mut host := ModuleHost.create(settings, module_test_transport({
		'https://named-import.test/value.js':'export default 42;'
	}, seen))
	host.install(mut runtime)!
	for index, statement in ['import(namedSpecifier);',
		'{}import(namedSpecifier)\n{globalThis.namedASIBlock=true;}',
		'try{class Child extends import(namedSpecifier){}}catch(error){globalThis.namedHeritageError=error instanceof TypeError;}'] {
		code := 'globalThis.namedSpecifier="named-value";{class Store{first(){}import(value){return value}}const store=new Store;store.import(1);}${statement}import(namedSpecifier).then(ns=>globalThis.namedDone${index}=ns.default===42);'
		assert !classic_source_has_only_named_import_candidates(code)
		source := ScriptSource{url:document.url.serialize(),code:code}
		assert host.transform_classic(source)!.code == host.rewrite(code,source.url,source.url,false)!
		assert host.transform_classic(source)!.code != code
		assert runtime.run_document_scripts_collect_errors([source]) == []string{}
		module_test_until(host,runtime,'globalThis.namedDone${index}===true')
	}
	assert runtime.evaluate_host('namedASIBlock===true&&namedHeritageError===true')! == 'true'
	// No ASI is possible between an adjacent ){. Let JSC reject the unchanged
	// invalid expression spelling instead of interpreting it as a real import.
	assert runtime.run_document_scripts_collect_errors([ScriptSource{code:'{}import(namedSpecifier){}'}]).len == 1
	assert seen.urls == ['https://named-import.test/value.js']
	assert host.errors() == []string{}
}
