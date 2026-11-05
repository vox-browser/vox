module browserjs

import dom
import html

fn test_keyword_free_module_filter_keeps_specifier_words_and_lexically_ambiguous_sources() {
	for source in ['', '(()=>{const exports={};exports.value=42;})();',
		'const importer=1,exported=2;globalThis.answer=importer+exported;',
		'await Promise.resolve();', 'function {', r'im\u0070ort("x")'] {
		assert !module_source_may_need_specifier_lexer(source), source
	}
	for source in ['import("./x.js")', 'import.meta.url', 'import source from "x";',
		'export const value=42;', 'export {value} from "x";', 'export * from "x";',
		'"import"', '/* export */', 'éimport', 'exporté',
		'#!/usr/bin/env node\nglobalThis.answer=42;', '"<!--"', '"-->"', 'a\x00b'] {
		assert module_source_may_need_specifier_lexer(source), source
	}
}

// Instrument the actual private transform's lexer call, preserving all its
// implementation and native resolution. No diagnostic changes reach authors.
fn install_counted_keyword_module_transform(mut host ModuleHost, mut runtime Runtime) ! {
	factory_source := module_source_factory()
	assert factory_source.count('parse(source,key)') == 1
	counted := factory_source.replace('parse(source,key)',
		'(globalThis.__keywordModuleLexerCalls++,parse(source,key))')
	runtime.evaluate_host('globalThis.__keywordModuleLexerCalls=0')!
	owner := voidptr(host)
	resolver := runtime.make_value_host_function(fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &ModuleHost(owner) }
		return host.runtime.binding_string(host.resolve(host.runtime.binding_dom_string(args[0])!,
			host.runtime.binding_dom_string(args[1])!,host.runtime.binding_dom_string(args[2])!)!)
	})!
	factory := runtime.evaluate_host_value(counted)!
	defer { runtime.release_javascript_value(factory) }
	functions := runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context),[resolver,runtime.binding_string(host.helper_name)])!)!
	defer { runtime.release_javascript_value(functions) }
	mut exception := unsafe { nil }
	transform := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context,functions,0,&exception)
	assert exception == unsafe { nil }
	runtime.release_javascript_value(host.transform)
	host.transform = runtime.retain_javascript_value(transform)!
}

fn trusted_keyword_module_transform(host &ModuleHost, code string, is_module bool) !string {
	value := host.runtime.call_javascript_function(host.transform,
		C.vox_jsc_JSValueMakeUndefined(host.runtime.context),[
			host.runtime.binding_string(code),host.runtime.binding_string(host.settings.api_base_url().serialize()),
			host.runtime.binding_string(host.settings.api_base_url().serialize()),
			C.vox_jsc_JSValueMakeBoolean(host.runtime.context,is_module),
			C.vox_jsc_JSValueMakeBoolean(host.runtime.context,false),
		])!
	return host.runtime.binding_dom_string(value)
}

fn test_keyword_free_module_bypass_matches_trusted_bytes_and_avoids_actual_lexer_calls() {
	$if !darwin { return }
	mut document := html.create_navigation_document(dom.URL{value:'https://keyword.test/page'},
		dom.URL{value:'https://keyword.test/'}.origin(),none)!
	mut runtime := Runtime.create()
	defer { runtime.close();document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	mut host := ModuleHost.create(settings,module_test_transport({},&ModuleTestRequests{}))
	host.install(mut runtime)!
	install_counted_keyword_module_transform(mut host,mut runtime)!
	for code in ['', '(()=>{const exports={};exports.value=42;})();',
		'globalThis.keywordLiteral="é😀";', 'function importer(){return 42}globalThis.keywordResult=importer();'] {
		expected := trusted_keyword_module_transform(host,code,true)!
		before := runtime.evaluate_host('__keywordModuleLexerCalls')!.int()
		actual := host.rewrite(code,settings.api_base_url().serialize(),settings.api_base_url().serialize(),true)!
		after := runtime.evaluate_host('__keywordModuleLexerCalls')!.int()
		assert actual == expected
		assert actual.starts_with('import.meta.url=')
		assert after-before == if disable_keyword_free_module_lexer { 1 } else { 0 }
	}
	// Syntax failure, special comments, hashbangs, actual keywords and the
	// classic parse goal keep the original lexer and its exact byte output.
	for code in ['/* unterminated', 'function {', r'im\u0070ort("x")',
		'await Promise.resolve();', '"<!--";', '#!/usr/bin/env node\nglobalThis.hashbang=42;',
		'import.meta.url;', 'export const value=42;', 'export {value} from "./value.js";'] {
		expected := trusted_keyword_module_transform(host,code,true)!
		before := runtime.evaluate_host('__keywordModuleLexerCalls')!.int()
		actual := host.rewrite(code,settings.api_base_url().serialize(),settings.api_base_url().serialize(),true)!
		assert actual == expected
		assert runtime.evaluate_host('__keywordModuleLexerCalls')!.int() == before+1
	}
	before := runtime.evaluate_host('__keywordModuleLexerCalls')!.int()
	assert host.rewrite('globalThis.classicValue=42;',settings.api_base_url().serialize(),
		settings.api_base_url().serialize(),false)! == 'globalThis.classicValue=42;'
	assert runtime.evaluate_host('__keywordModuleLexerCalls')!.int() == before+1
	runtime.close()
	if _ := host.rewrite('',settings.api_base_url().serialize(),settings.api_base_url().serialize(),true) {
		assert false, 'closed runtime must fail before a native syntax check'
	}
}

fn test_keyword_free_modules_still_execute_once_with_module_parse_goal_and_no_syntax_probe_effects() {
	$if !darwin { return }
	mut document := html.create_navigation_document(dom.URL{value:'https://keyword.test/page'},
		dom.URL{value:'https://keyword.test/'}.origin(),none)!
	mut runtime := Runtime.create()
	defer { runtime.close();document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	seen := &ModuleTestRequests{}
	mut host := ModuleHost.create(settings,module_test_transport({},seen))
	host.install(mut runtime)!
	code := 'let keywordPrivate=42;globalThis.keywordRuns=(globalThis.keywordRuns||0)+1;globalThis.keywordValue=keywordPrivate;globalThis.keywordTopThis=this===undefined;try{keywordUndeclared=1}catch(error){globalThis.keywordStrict=error instanceof ReferenceError;}'
	_ = host.rewrite(code,document.url.serialize(),document.url.serialize(),true)!
	assert runtime.evaluate_host('globalThis.keywordRuns===undefined')! == 'true'
	source := ScriptSource{source_type:.module,url:'https://keyword.test/module.js',code:code}
	assert runtime.run_document_scripts_collect_errors([source]) == []string{}
	module_test_until(host,runtime,'globalThis.keywordRuns===1')
	assert runtime.evaluate_host('keywordValue===42&&typeof keywordPrivate==="undefined"&&keywordTopThis&&keywordStrict&&typeof keywordUndeclared==="undefined"')! == 'true'
	assert runtime.run_document_scripts_collect_errors([source]) == []string{}
	module_test_until(host,runtime,'!globalThis.moduleError')
	assert runtime.evaluate_host('keywordRuns===1')! == 'true'
	assert seen.urls.len == 0
	assert host.errors() == []string{}
}
