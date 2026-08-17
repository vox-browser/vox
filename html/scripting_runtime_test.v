@[has_globals]
module html

import dom

__global scripting_test_module_changes int

fn scripting_test_evaluate(source string, realm &ScriptingRealm) !dom.JSValue {
	_ = realm
	if source == 'throw' {
		return error('boom')
	}
	return dom.js_string(source)
}

fn scripting_test_parse(source string, filename string, line usize) ! {
	_ = filename
	_ = line
	if source == 'invalid' {
		return error('syntax error')
	}
}

fn scripting_test_module_changed(entry ModuleMapEntry) {
	if entry.type_ == .failed {
		scripting_test_module_changes++
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
	module_map.wait_for_change(url, 'javascript', scripting_test_module_changed)
	assert module_map.set(url, 'javascript', ModuleMapEntry{ type_: .failed }) or { panic(err) }
	assert module_map.is_failed(url, 'javascript')
	assert scripting_test_module_changes == 1

	mut context := TemporaryExecutionContext.create(mut realm, .yes)
	assert realm.script_execution_depth == 1
	assert realm.callback_execution_depth == 1
	context.close()
	assert realm.script_execution_depth == 0
	assert realm.callback_execution_depth == 0
}
