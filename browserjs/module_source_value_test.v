module browserjs

import dom
import html
import platform

fn test_module_rewrite_value_roots_source_across_caller_retirement_and_gc() {
	$if !darwin { return }
	mut document := html.create_navigation_document(dom.URL{value:'https://source-value.test/page'},
		dom.URL{value:'https://source-value.test/'}.origin(),none)!
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	mut host := ModuleHost.create(settings,module_test_transport({},&ModuleTestRequests{}))
	host.install(mut runtime)!
	for code in ['', 'export const text="éĀ😀";', r'export const text="\u0000\ud800\udfff";',
		'import value from "./dep.js";export {value};', '/*'+ 'x'.repeat(131072)+'*/export default 42;'] {
		expected := host.rewrite(code,document.url.serialize(),document.url.serialize(),true)!
		before := runtime.protected_values_.len
		work := platform.begin_thread_scratch('module source value caller')
		value := host.rewrite_value(code.clone(),document.url.serialize(),document.url.serialize(),true)!
		work.finish()
		gc_collect()
		assert runtime.binding_dom_string(value)! == expected
		runtime.release_javascript_value(value)
		assert runtime.protected_values_.len == before
	}
	runtime.close()
	assert runtime.protected_values_.len == 0
	if _ := host.rewrite_value('',document.url.serialize(),document.url.serialize(),true) {
		assert false, 'closed runtime accepted module source'
	} else { assert err.msg().contains('closed') }
}

fn test_module_rewrite_value_rejects_non_strings_without_author_conversion() {
	$if !darwin { return }
	mut document := html.create_navigation_document(dom.URL{value:'https://source-value.test/page'},
		dom.URL{value:'https://source-value.test/'}.origin(),none)!
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	mut host := ModuleHost.create(settings,module_test_transport({},&ModuleTestRequests{}))
	host.install(mut runtime)!
	host.transform = runtime.evaluate_host_value(r'(()=>{globalThis.sourceHooks=0;return ()=>({toString(){sourceHooks++;throw 42;}})})()')!
	before := runtime.protected_values_.len
	if _ := host.rewrite_value('export default 42;',document.url.serialize(),document.url.serialize(),true) {
		assert false, 'non-string transform accepted'
	} else { assert err.msg().contains('non-string') }
	assert runtime.protected_values_.len == before
	assert runtime.evaluate_host('sourceHooks')! == '0'
}

fn test_native_module_source_value_rejects_non_strings_without_coercion_or_resolution() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	resolve := runtime.evaluate_host_value('(function(){globalThis.sourceResolved=(globalThis.sourceResolved||0)+1})')!
	inputs := runtime.evaluate_host_value(r'[undefined,null,1,Symbol(),new String("x"),{toString(){globalThis.sourceCoerced=true;throw 1}}]')!
	key := 'https://source-value.test/module.js'
	for index in 0 .. 6 {
		mut exception := unsafe { nil }
		value := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context,inputs,u32(index),&exception)
		assert exception == unsafe { nil }
		result := C.vox_module_loader_supply_value(runtime.context,resolve,value,key.str,uint(key.len),false,&exception)
		assert result == unsafe { nil } && exception == unsafe { nil }
	}
	assert runtime.evaluate_host('!globalThis.sourceResolved&&!globalThis.sourceCoerced')! == 'true'
	empty := runtime.evaluate_host_value('""')!
	mut exception := unsafe { nil }
	result := C.vox_module_loader_supply_value(runtime.context,resolve,empty,key.str,uint(key.len),false,&exception)
	assert result != unsafe { nil } && exception == unsafe { nil }
	assert runtime.evaluate_host('sourceResolved===1&&!globalThis.sourceCoerced')! == 'true'
}

fn test_native_module_source_value_preserves_nul_unicode_and_lone_utf16_units() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	// The literal source contains actual code units, including a NUL and lone
	// surrogates. A UTF-8 intermediary cannot faithfully represent this input.
	source := runtime.evaluate_host_value(r'"globalThis.sourceUnits=Array.from(\""+String.fromCharCode(0,233,256,55357,56832,55296,65,57343)+"\",c=>c.length===2?[c.charCodeAt(0),c.charCodeAt(1)]:c.charCodeAt(0));globalThis.sourceDone=true;"')!
	owner := voidptr(runtime)
	key := 'https://source-value.test/module.js'
	fetcher := runtime.make_value_host_function(fn [owner,source,key] (_ voidptr,args []voidptr) !voidptr {
		assert args.len == 3
		runtime := unsafe { &Runtime(owner) }
		mut exception := unsafe { nil }
		result := C.vox_module_loader_supply_value(runtime.context,args[1],source,key.str,uint(key.len),false,&exception)
		assert exception == unsafe { nil } && result != unsafe { nil }
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	loader := C.vox_module_loader_install(runtime.context,fetcher,unsafe { nil },fn (_ voidptr,_ &char,_ u32,_ bool) {})
	assert loader != unsafe { nil }
	defer { C.vox_module_loader_close(runtime.context,loader) }
	mut exception := unsafe { nil }
	promise := C.vox_module_loader_evaluate(runtime.context,key.str,uint(key.len),&exception)
	assert exception == unsafe { nil } && promise != unsafe { nil }
	defer { C.JSValueUnprotect(runtime.context,promise) }
	actual := runtime.evaluate_host('JSON.stringify([globalThis.sourceDone,globalThis.sourceUnits])')!
	assert actual == '[true,[0,233,256,[55357,56832],55296,65,57343]]'
}

fn test_module_source_value_releases_temporary_root_when_lexer_diagnostic_throws() {
	$if !darwin { return }
	if !module_lexer_diagnostics { return }
	mut document := html.create_navigation_document(dom.URL{value:'https://source-value.test/page'},
		dom.URL{value:'https://source-value.test/'}.origin(),none)!
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	mut host := ModuleHost.create(settings,module_test_transport({},&ModuleTestRequests{}))
	host.install(mut runtime)!
	_ = host.rewrite('export default 42;',document.url.serialize(),document.url.serialize(),true)!
	host.lexer_status = runtime.evaluate_host_value('(function(){throw globalThis.sourceStatusError=new Error("status failed")})')!
	host.lexer_reported = false
	before := runtime.protected_values_.len
	if _ := host.rewrite_value('export default 42;',document.url.serialize(),document.url.serialize(),true) {
		assert false, 'diagnostic exception was swallowed'
	} else { assert err is JavaScriptValueException }
	// The existing exception bridge retains the thrown value. The additional
	// transformed-source root must already be gone on this exceptional exit.
	assert runtime.protected_values_.len == before + 1
	runtime.close()
	assert runtime.protected_values_.len == 0
}
