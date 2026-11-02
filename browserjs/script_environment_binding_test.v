module browserjs

import dom
import html
import libjs

@[heap]
struct ScriptEnvironmentCalls {
mut:
	values []string
}

fn script_environment_document() &dom.Document {
	url := dom.URL{value: 'https://script-environment.example.test/'}
	return &dom.Document{url: url, origin_: url.origin()}
}

fn test_browser_realm_attachment_pops_initial_context_and_cleans_up_after_real_author_frames() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	window := html.WindowModel.create_top_level(script_environment_document(), none, 'source-context')!
	settings := unsafe { &html.EnvironmentSettingsObject(window.associated_document().relevant_settings_object()) }
	mut event_loop := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
	mut seen := &ScriptEnvironmentCalls{}
	assert runtime.libjs_vm().execution_context_stack().len == 1
	runtime.bind_scripting_environment(settings)!
	assert runtime.libjs_vm().execution_context_stack().len == 0
	runtime.bind_scripting_environment(settings)!
	owner_handle := voidptr(runtime)
	runtime.define_value_host_function('__sourceScriptContext', fn [owner_handle, settings, mut seen] (_ voidptr, _ []voidptr) !voidptr {
		mut owner := unsafe { &Runtime(owner_handle) }
		vm := owner.libjs_vm()
		assert settings.realm().script_execution_depth == 1
		assert vm.execution_context_stack().len == 2
		assert !vm.get_active_script_or_module().is_empty()
		previous_jobs := seen.values.len
		mut event_loop := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
		event_loop.enqueue_microtask(html.Task.create(.microtask, none, fn [owner_handle, settings, mut seen] () {
			owner := unsafe { &Runtime(owner_handle) }
			assert !owner.libjs_vm().has_running_execution_context()
			assert settings.realm().script_execution_depth == 0
			seen.values << 'source job'
		}))
		owner.evaluate_host('globalThis.nestedHostEntry=true')!
		assert seen.values.len == previous_jobs
		assert vm.execution_context_stack().len == 2
		return C.vox_jsc_JSValueMakeUndefined(owner.context)
	})!
	runtime.evaluate('__sourceScriptContext();')!
	assert seen.values == ['source job']
	assert !runtime.libjs_vm().has_running_execution_context()
	assert settings.realm().script_execution_depth == 0
	assert event_loop.microtask_queue_empty()
	if _ := runtime.evaluate('__sourceScriptContext();throw new Error("source abrupt completion")') { assert false }
	assert seen.values == ['source job', 'source job']
	assert !runtime.libjs_vm().has_running_execution_context()
	runtime.close()
	assert !event_loop.has_running_execution_context()
}

fn test_browser_realm_attachment_rejects_active_outer_context_without_popping_it() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	window := html.WindowModel.create_top_level(script_environment_document(), none, 'active-context')!
	mut vm := unsafe { &libjs.VM(runtime.libjs_vm()) }
	mut outer := libjs.ExecutionContext.create(0, [], 0)
	vm.push_execution_context_checked(mut outer)!
	if _ := runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(window.associated_document().relevant_settings_object()) }) { assert false }
	assert vm.execution_context_stack().len == 2
	assert voidptr(vm.running_execution_context()) == voidptr(outer)
	vm.pop_execution_context()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(window.associated_document().relevant_settings_object()) })!
	assert vm.execution_context_stack().len == 0
	assert runtime.evaluate('21*2')! == '42'
	assert !vm.has_running_execution_context()
}

fn test_two_browser_realms_preserve_outer_context_gating_and_detach_only_their_own_vm() {
	$if !darwin { return }
	mut first := Runtime.create()
	mut second := Runtime.create()
	defer { first.close(); second.close() }
	first_window := html.WindowModel.create_top_level(script_environment_document(), none, 'first-realm')!
	second_window := html.WindowModel.create_top_level(script_environment_document(), none, 'second-realm')!
	first_settings := unsafe { &html.EnvironmentSettingsObject(first_window.associated_document().relevant_settings_object()) }
	second_settings := unsafe { &html.EnvironmentSettingsObject(second_window.associated_document().relevant_settings_object()) }
	assert voidptr(first_settings.responsible_event_loop()) == voidptr(second_settings.responsible_event_loop())
	first.bind_scripting_environment(first_settings)!
	second.bind_scripting_environment(second_settings)!
	mut event_loop := unsafe { &html.EventLoop(first_settings.responsible_event_loop()) }
	mut first_vm := unsafe { &libjs.VM(first.libjs_vm()) }
	mut outer := libjs.ExecutionContext.create(0, [], 0)
	first_vm.push_execution_context_checked(mut outer)!
	assert event_loop.has_running_execution_context()
	mut seen := &ScriptEnvironmentCalls{}
	event_loop.enqueue_microtask(html.Task.create(.microtask, none, fn [mut seen] () { seen.values << 'both idle' }))
	mut second_realm := unsafe { &html.ScriptingRealm(second_settings.realm()) }
	html.prepare_to_run_script(mut second_realm)
	html.clean_up_after_running_script(mut second_realm)
	assert seen.values.len == 0
	assert voidptr(first_vm.running_execution_context()) == voidptr(outer)
	second.close()
	assert event_loop.has_running_execution_context()
	first_vm.pop_execution_context()
	mut first_realm := unsafe { &html.ScriptingRealm(first_settings.realm()) }
	html.prepare_to_run_script(mut first_realm)
	html.clean_up_after_running_script(mut first_realm)
	assert seen.values == ['both idle']
	assert !event_loop.has_running_execution_context()
}
