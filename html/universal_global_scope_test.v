module html

import dom

struct UniversalGlobalScopeTestState {
mut:
	did_run bool
}

fn test_universal_global_scope_base64_and_clone() {
	target := &dom.EventTarget{}
	realm := &ScriptingRealm{}
	scope := UniversalGlobalScopeMixin.create(target, realm)
	assert scope.btoa('hello')! == 'aGVsbG8='
	assert scope.atob(' aGVs\nbG8= ')! == 'hello'
	if _ := scope.btoa('€') {
		assert false
	} else {
		assert err.msg().contains('InvalidCharacterError')
	}
	cloned := scope.structured_clone(dom.js_string('copy'), StructuredSerializeOptions{})!
	assert cloned.string_data == 'copy'
	assert scope.count_queuing_strategy_size() == 1
	assert scope.byte_length_queuing_strategy_size(23) == 23
	count_size := scope.count_queuing_strategy_size_function()
	byte_size := scope.byte_length_queuing_strategy_size_function()
	assert count_size(QueuingStrategyChunk{ byte_length: 99 }) == 1
	assert byte_size(QueuingStrategyChunk{ byte_length: 23 }) == 23
}

fn test_universal_global_scope_microtasks_and_rejected_promises() {
	target := &dom.EventTarget{}
	mut realm := &ScriptingRealm{}
	mut scope := UniversalGlobalScopeMixin.create(target, realm)
	state := &UniversalGlobalScopeTestState{}
	scope.queue_microtask(fn [state] () {
		mut mutable_state := unsafe { &UniversalGlobalScopeTestState(state) }
		mutable_state.did_run = true
	})
	mut event_loop := main_thread_event_loop()
	event_loop.perform_a_microtask_checkpoint()
	assert state.did_run

	mut promise := dom.Promise.rejected(dom.js_string('failure'))
	scope.push_onto_about_to_be_notified_rejected_promises_list(promise)
	scope.notify_about_rejected_promises()
	assert realm.reported_exceptions.len == 0
	mut queue := event_loop.task_queue()
	notification := queue.take_first_runnable_matching(fn (task &Task) bool { return task.source == .dom_manipulation }) or { panic('missing notification task') }
	notification.execute()
	assert realm.reported_exceptions.len == 1
	assert scope.remove_from_outstanding_rejected_promises_weak_set(promise)
	promise.mark_handled()
	scope.push_onto_about_to_be_notified_rejected_promises_list(promise)
	scope.notify_about_rejected_promises()
	handled_notification := queue.take_first_runnable_matching(fn (task &Task) bool { return task.source == .dom_manipulation }) or { panic('missing handled notification task') }
	handled_notification.execute()
	assert realm.reported_exceptions.len == 1
}

fn test_universal_global_scope_import_map_and_experimental_flag() {
	mut scope := UniversalGlobalScopeMixin.create(&dom.EventTarget{}, &ScriptingRealm{})
	import_map :=
		parse_import_map_string('{"imports":{"x":"/x.js"}}', dom.URL{'https://example.test/'})!
	scope.set_import_map(import_map)
	assert scope.import_map().imports.entries.len == 1
	set_experimental_interfaces_exposed(true)
	assert expose_experimental_interfaces()
	set_experimental_interfaces_exposed(false)
	UniversalGlobalScopeMixin.set_experimental_interfaces_exposed(true)
	assert UniversalGlobalScopeMixin.expose_experimental_interfaces()
	UniversalGlobalScopeMixin.set_experimental_interfaces_exposed(false)
}
