module html

import dom
import page

fn module_script_owner_fixture(value string) !(&page.Page, &dom.Document, &ScriptingRealm) {
	owner := page.Page.create(1)!
	url := dom.URL{value: value}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	return owner, document, settings.realm()
}

fn module_owner_evaluate(source string, realm &ScriptingRealm) !dom.JSValue {
	assert realm.script_execution_depth == 1
	return dom.js_string(source)
}

fn test_source_module_create_applies_actual_page_preference_webui_and_sandbox() {
	mut owner, mut document, realm := module_script_owner_fixture('https://module-owner.example/')!
	owner.set_is_scripting_enabled(false)
	source := 'import "./dependency.js";export const answer=42;'
	disabled := JavaScriptModuleScript.create('module.js', source, realm, document.url)
	assert disabled.source == '' && disabled.requested_modules().len == 0
	document.set_url(dom.URL{value: 'about:settings'})
	internal := JavaScriptModuleScript.create('settings.js', source, realm, document.url)
	assert internal.source == source && internal.requested_modules().len == 1
	document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_scripts))
	assert JavaScriptModuleScript.create('sandbox.js', source, realm, document.url).source == ''
	document.set_active_sandboxing_flag_bits(0)
	document.set_url(dom.URL{value: 'about:settings#'})
	assert JavaScriptModuleScript.create('fragment.js', source, realm, document.url).source == ''
}

fn test_source_module_preparsed_compiled_and_cache_paths_retain_existing_source_while_disabled() {
	mut owner, document, realm := module_script_owner_fixture('https://module-owner.example/')!
	owner.set_is_scripting_enabled(false)
	source := 'import "./dependency.js";'
	preparsed := JavaScriptModuleScript.create_from_pre_parsed('parsed.js', source, realm, document.url, fn (actual string, _ string, _ uint) ! {
		if actual != '' { return error('existing parse failure') }
	})
	assert preparsed.source == source && preparsed.parse_error? == 'existing parse failure'
	parsed := JavaScriptModuleScript.create_from_parsed_program('program.js', source, realm, document.url, ParsedProgram{})
	assert parsed.source == source && parsed.requested_modules().len == 1
	mut compiled := JavaScriptModuleScript.create_from_pre_compiled('compiled.js', source, realm, document.url, CompiledProgram{ program_type: .module })
	assert compiled.source == source && compiled.requested_modules().len == 1
	compiled.set_evaluator(module_owner_evaluate)
	blocked := compiled.run(.no)
	assert blocked.state == .fulfilled && blocked.value.kind == .undefined
	owner.set_is_scripting_enabled(true)
	assert compiled.run(.no).value.string_data == source
	owner.set_is_scripting_enabled(false)
	cached := JavaScriptModuleScript.create_from_bytecode_cache('cache.js', source, realm, document.url, [], fn (_ []u8, _ string, _ string, _ uint, _ ScriptProgramType) !&ScriptExecutable {
		return error('cache failure')
	})
	assert cached.source == source && cached.parse_error? == 'cache failure'
}

fn test_source_module_run_checks_actual_activity_and_preference_before_errors_or_context() {
	mut owner, document, realm := module_script_owner_fixture('https://module-owner.example/')!
	mut script := JavaScriptModuleScript.create('module.js', 'source', realm, document.url)
	script.error_to_rethrow = 'original module failure'
	before := realm.microtask_checkpoint_count
	owner.set_is_scripting_enabled(false)
	blocked := script.run(.no)
	assert blocked.state == .fulfilled && blocked.value.kind == .undefined
	assert realm.reported_exceptions.len == 0 && realm.script_execution_depth == 0
	assert realm.microtask_checkpoint_count == before
	owner.set_is_scripting_enabled(true)
	mut navigable := document.navigable()?
	navigable.is_top_level_traversable_ = false
	assert script.run(.no).state == .fulfilled
	assert realm.reported_exceptions.len == 0 && realm.microtask_checkpoint_count == before
	navigable.is_top_level_traversable_ = true
	failed := script.run(.yes)
	assert failed.state == .rejected && failed.error == 'original module failure'
	assert realm.microtask_checkpoint_count == before + 1
}

fn test_source_module_owned_create_and_run_ignore_standalone_adapter_flags() {
	_, document, mut realm := module_script_owner_fixture('https://module-owner.example/')!
	realm.can_run = false
	realm.scripting_enabled = false
	mut script := JavaScriptModuleScript.create('module.js', 'actual module owner', realm, document.url)
	script.set_evaluator(module_owner_evaluate)
	assert script.source == 'actual module owner'
	assert script.run(.no).value.string_data == 'actual module owner'
}
