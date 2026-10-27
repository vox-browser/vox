@[has_globals]
module html

import dom

__global scripting_test_module_changes int
__global scripting_test_module_failures int

fn scripting_test_evaluate(source string, realm &ScriptingRealm) !dom.JSValue {
	_ = realm
	if source == 'throw' {
		return error('boom')
	}
	return dom.js_string(source)
}

fn scripting_test_parse(source string, filename string, line uint) ! {
	_ = filename
	_ = line
	if source == 'invalid' {
		return error('syntax error')
	}
}

fn scripting_test_module_changed(script ?&Script) {
	if script != none {
		scripting_test_module_changes++
	} else {
		scripting_test_module_failures++
	}
}

fn test_classic_script_lifecycle_and_error_modes() {
	mut realm := &ScriptingRealm{}
	mut script := ClassicScript.create_with_parser('test.js', 'ok', realm, dom.URL{
		value: 'https://example.test/test.js'
	}, 1, .no, scripting_test_parse)
	script.set_evaluator(scripting_test_evaluate)
	result := script.run(.no) or { panic(err) }
	assert result.string_data == 'ok'
	assert realm.script_execution_depth == 0
	assert realm.microtask_checkpoint_count == 1

	mut throwing := ClassicScript.create('test.js', 'throw', realm, dom.url_about_blank(), 1, .no)
	throwing.set_evaluator(scripting_test_evaluate)
	if _ := throwing.run(.no) {
		assert false
	}
	assert realm.reported_exceptions.len == 1

	mut muted := ClassicScript.create('cross-origin.js', 'throw', realm, dom.URL{
		value: 'https://other.test/'
	}, 1, .yes)
	muted.set_evaluator(scripting_test_evaluate)
	if _ := muted.run(.yes) {
		assert false
	} else {
		assert err.msg().starts_with('NetworkError:')
	}
	assert muted.base_url or { panic('missing URL') } == dom.url_about_blank()

	preparsed := ClassicScript.create_from_pre_parsed('cached.js', 'ok', realm, dom.URL{
		value: 'https://example.test/cached.js'
	}, scripting_test_parse, .no)
	assert preparsed.parse_error == none
	broken_preparsed := ClassicScript.create_from_pre_parsed('cached.js', 'invalid', realm, dom.url_about_blank(), scripting_test_parse, .no)
	assert broken_preparsed.parse_error? == 'syntax error'
	compiled := ClassicScript.create_from_pre_compiled('compiled.js', 'ok', realm, dom.url_about_blank(), CompiledProgram{ program_type: .script, line_number_offset: 1 }, .no)
	assert compiled.compiled_program?.program_type == .script
	mut visitor := dom.CellVisitor{}
	unsafe { &Script(preparsed) }.visit_host_defined_self(mut visitor)
}

fn test_module_script_module_map_and_temporary_context() {
	mut realm := &ScriptingRealm{}
	mut module_script := JavaScriptModuleScript.create('module.js', 'value', realm, dom.URL{
		value: 'https://example.test/module.js'
	})
	module_script.set_evaluator(scripting_test_evaluate)
	evaluation := module_script.run(.no)
	assert evaluation.state == .fulfilled
	assert evaluation.value.string_data == 'value'

	mut module_map := ModuleMap.create()
	url := dom.URL{
		value: 'https://example.test/module.js'
	}
	scripting_test_module_changes = 0
	scripting_test_module_failures = 0
	module_map.begin_fetch(url, 'javascript-or-wasm', [scripting_test_module_changed])!
	module_map.append_fetch_callback(url, 'javascript-or-wasm', scripting_test_module_changed)!
	assert module_map.is_fetching(url, 'javascript-or-wasm')
	module_map.complete_fetch(url, 'javascript-or-wasm', &module_script.ModuleScript)!
	assert scripting_test_module_changes == 2
	assert module_map_is(module_map, url, 'javascript-or-wasm', .module_script)

	retry_url := dom.URL{ value: 'https://example.test/retry.js' }
	module_map.begin_fetch(retry_url, 'javascript-or-wasm', [scripting_test_module_changed])!
	module_map.complete_fetch(retry_url, 'javascript-or-wasm', none)!
	assert module_map.get(retry_url, 'javascript-or-wasm') == none
	assert scripting_test_module_changes == 2
	assert scripting_test_module_failures == 1
	preparsed_module := JavaScriptModuleScript.create_from_pre_parsed('cached-module.js', 'value', realm, url, scripting_test_parse)
	assert preparsed_module.parse_error == none
	compiled_module := JavaScriptModuleScript.create_from_pre_compiled('compiled-module.js', 'value', realm, url, CompiledProgram{ program_type: .module })
	assert compiled_module.compiled_program?.program_type == .module

	mut context := TemporaryExecutionContext.create(mut realm, .yes)
	assert realm.script_execution_depth == 1
	assert realm.callback_execution_depth == 1
	context.close()
	assert realm.script_execution_depth == 0
	assert realm.callback_execution_depth == 0
}

fn test_document_temporary_execution_context_bridge_uses_the_window_realm() {
	document := dom.Document.create(dom.url_about_blank())
	window := WindowModel.create_top_level(document, none, 'execution-context-test') or {
		panic('${err}')
	}
	realm := window.scripting_realm_
	checkpoint_count := realm.microtask_checkpoint_count

	context := document.begin_temporary_execution_context()
	assert context != unsafe { nil }
	assert realm.script_execution_depth == 1
	document.end_temporary_execution_context(context)

	assert realm.script_execution_depth == 0
	assert realm.microtask_checkpoint_count == checkpoint_count + 1
}
