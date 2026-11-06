@[has_globals]
module bindings

import dom
import html

@[heap]
struct BindingsTestState {
mut:
	job_calls      int
	reaction_calls int
}

fn bindings_test_job_callback(_ dom.JSValue, arguments []dom.JSValue) !dom.JSValue {
	return arguments[0]
}

fn bindings_test_create_global(realm &html.ScriptingRealm) voidptr {
	return voidptr(realm)
}

fn test_main_thread_vm_agents_host_guards_jobs_and_realms() {
	reset_main_thread_vm_for_testing()
	mut vm := initialize_main_thread_vm(.similar_origin_window) or { panic(err) }
	assert vm.agent_type == .similar_origin_window
	assert vm.agent.can_block == .no
	window_agent := vm.window_agent or { panic('missing window agent') }
	assert main_thread_similar_origin_window_agent() == window_agent
	vm.host_ensure_can_add_private_element(.ordinary) or { panic(err) }
	if _ := vm.host_ensure_can_add_private_element(.window_proxy) {
		assert false
	}
	if _ := vm.host_ensure_can_compile_strings(false) {
		assert false
	}
	assert vm.host_get_code_for_eval(TrustedScript{'trusted()'}) or { '' } == 'trusted()'
	assert vm.host_get_code_for_eval(none) == none

	mut realm := create_a_principal_javascript_realm()
	settings := principal_host_defined_environment_settings_object(realm)
	stack_depth := vm.execution_context_stack_.len
	script := html.ClassicScript.create('callback.js', '', realm, dom.URL{
		value: 'https://example.test/callback.js'
	}, 1, .no)
	vm.set_active_script(unsafe { &html.Script(script) })
	assert active_script() or { panic('missing active script') } == unsafe { &html.Script(script) }
	callback := vm.host_make_job_callback(bindings_test_job_callback, settings)
	result := vm.host_call_job_callback(callback, dom.js_undefined(), [
		dom.js_string('called'),
	]) or { panic(err) }
	assert result.string_data == 'called'
	assert realm.callback_execution_depth == 0
	assert vm.execution_context_stack_.len == stack_depth

	context := create_a_new_javascript_realm(bindings_test_create_global,
		bindings_test_create_global)
	assert context.global_object == voidptr(context.realm)
	assert context.global_this == voidptr(context.realm)
	simple_realm := create_a_simple_javascript_realm()
	assert host_defined_wrapper_world(simple_realm).type_() == .internal
	assert html.principal_realm(simple_realm) != simple_realm
	assert principal_host_defined_environment_settings_object(simple_realm).realm() == html.principal_realm(simple_realm)
}

fn test_main_thread_vm_promise_jobs_imports_and_buffers() {
	reset_main_thread_vm_for_testing()
	mut vm := initialize_main_thread_vm(.similar_origin_window) or { panic(err) }
	state := &BindingsTestState{}
	mut realm := &html.ScriptingRealm{}
	vm.host_enqueue_finalization_registry_cleanup_job(fn [state] () ! {
		mut mutable_state := unsafe { &BindingsTestState(state) }
		mutable_state.job_calls++
	}, realm, none)
	mut event_loop := html.main_thread_event_loop()
	for state.job_calls == 0 {
		event_loop.process()
	}
	vm.host_enqueue_promise_job(fn [state] () !dom.JSValue {
		mut mutable_state := unsafe { &BindingsTestState(state) }
		mutable_state.job_calls++
		return dom.js_bool(true)
	}, realm, none)
	assert !vm.host_promise_job_queue_is_empty()
	html.perform_a_microtask_checkpoint()
	assert state.job_calls == 2
	assert vm.host_promise_job_queue_is_empty()
	assert realm.script_execution_depth == 0
	assert realm.callback_execution_depth == 0

	base_url := dom.URL{
		value: 'https://example.test/app/main.js'
	}
	import_map := html.parse_import_map_string('{"imports":{"pkg":"./dependency.js"}}', base_url) or {
		panic(err)
	}
	module_script := html.JavaScriptModuleScript.create('main.js', '', realm, base_url)
	meta := vm.host_get_import_meta_properties(unsafe { &html.Script(module_script) }, &import_map) or {
		panic(err)
	}
	assert meta.url == base_url.serialize()
	assert meta.resolve('pkg') or { panic(err) } == 'https://example.test/app/dependency.js'
	assert vm.host_get_supported_import_attributes() == ['type']
	loaded := vm.host_load_imported_module(ModuleRequest{
		specifier:  'pkg'
		attributes: {
			'type': 'javascript-or-wasm'
		}
	}, &import_map, base_url, .window, false) or { panic(err) }
	assert loaded.url.serialize() == 'https://example.test/app/dependency.js'
	assert loaded.module_type == 'javascript-or-wasm'
	if _ := vm.host_load_imported_module(ModuleRequest{
		specifier:  'pkg'
		attributes: {
			'integrity': 'sha256'
		}
	}, &import_map, base_url, .window, false)
	{
		assert false
	}
	if _ := vm.host_load_imported_module(ModuleRequest{ specifier: 'pkg' }, &import_map, base_url,
		.service_worker, false)
	{
		assert false
	}

	mut buffer := HostArrayBuffer{
		max_byte_length: 8
		data:            [u8(1), 2]
	}
	buffer.host_resize_array_buffer(5) or { panic(err) }
	assert buffer.data == [u8(1), 2, 0, 0, 0]
	mut shared_buffer := HostArrayBuffer{
		shared:          true
		max_byte_length: 6
		data:            [u8(9)]
	}
	shared_buffer.host_grow_shared_array_buffer(3) or { panic(err) }
	assert shared_buffer.data == [u8(9), 0, 0]
	vm.host_unrecognized_date_string('not-a-date')
	assert vm.unrecognized_date_strings == ['not-a-date']
}

fn test_mutation_microtask_and_custom_element_reaction_dispatch() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	queue_mutation_observer_microtask(document)
	assert html.relevant_similar_origin_window_agent().mutation_observer_microtask_queued
	html.perform_a_microtask_checkpoint()
	assert !html.relevant_similar_origin_window_agent().mutation_observer_microtask_queued

	mut element := document.create_element('div') or { panic(err) }
	mut definition := dom.CustomElementDefinition.create('x-reaction', 'div', [], false, false, false)
	definition.lifecycle_callbacks_ = ['connectedCallback']
	element.set_custom_element_definition(definition)
	element.enqueue_a_custom_element_callback_reaction('connectedCallback', [])
	state := &BindingsTestState{}
	mut queue := [&dom.Element(element)]
	invoke_custom_element_reactions(mut queue, fn [state] (_ &dom.Element, _ dom.CustomElementCallbackReaction) ! {
		mut mutable_state := unsafe { &BindingsTestState(state) }
		mutable_state.reaction_calls++
	}, none)
	assert queue.len == 0
	assert state.reaction_calls == 1
	assert element.ensure_custom_element_reaction_queue().len == 0
}
