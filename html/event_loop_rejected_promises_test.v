module html

import dom

fn rejected_promise_settings(event_loop &EventLoop) (&EnvironmentSettingsObject, &UniversalGlobalScopeMixin) {
	realm := &ScriptingRealm{}
	environment := Environment.create('checkpoint-test', dom.url_about_blank(), none, none, none)
	mut settings := create_environment_settings(realm, environment, .snapshot, event_loop)
	target := &dom.EventTarget{}
	scope := UniversalGlobalScopeMixin.create(target, realm, none)
	settings.global_object_ = target
	settings.universal_global_scope_ = scope
	return settings, scope
}

fn test_checkpoint_notifies_each_related_global_after_draining_microtasks() {
	mut event_loop := EventLoop.create(.worker)
	settings1, mut scope1 := rejected_promise_settings(event_loop)
	settings2, mut scope2 := rejected_promise_settings(event_loop)
	first := dom.Promise.rejected(dom.js_string('first'))
	second := dom.Promise.rejected(dom.js_string('second'))
	scope1.push_onto_about_to_be_notified_rejected_promises_list(first)
	scope2.push_onto_about_to_be_notified_rejected_promises_list(second)
	event_loop.enqueue_microtask(Task.create(.microtask, none, fn [first] () {
		mut handled := unsafe { &dom.Promise(first) }
		handled.mark_handled()
	}))
	event_loop.perform_a_microtask_checkpoint()
	assert event_loop.microtask_queue_empty()
	assert scope1.about_to_be_notified_rejected_promises_.len == 0
	assert scope2.about_to_be_notified_rejected_promises_.len == 0
	assert settings1.realm().reported_exceptions.len == 0
	assert settings2.realm().reported_exceptions.len == 0
	mut queue := event_loop.task_queue()
	first_task := queue.take_first_runnable_matching(fn (task &Task) bool {
		return task.source == .dom_manipulation
	}) or { panic('first notification missing') }
	second_task := queue.take_first_runnable_matching(fn (task &Task) bool {
		return task.source == .dom_manipulation
	}) or { panic('second notification missing') }
	first_task.execute()
	second_task.execute()
	assert settings1.realm().reported_exceptions.len == 0
	assert settings2.realm().reported_exceptions.len == 1
	assert scope2.remove_from_outstanding_rejected_promises_weak_set(second)
	event_loop.perform_a_microtask_checkpoint()
	assert queue.take_first_runnable_matching(fn (task &Task) bool {
		return task.source == .dom_manipulation
	}) == none
}

fn test_rejection_delivery_rechecks_handling_and_honors_event_cancellation() {
	mut event_loop := EventLoop.create(.window)
	settings, mut scope := rejected_promise_settings(event_loop)
	mut handled_later := dom.Promise.rejected(dom.js_string('handled later'))
	uncaught := dom.Promise.rejected(dom.js_string('cancel console reporting'))
	scope.event_target.add_event_listener_without_options('unhandledrejection', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_event := unsafe { &dom.Event(event) }
			mutable_event.prevent_default()
			return dom.js_undefined()
		}
	}))
	scope.push_onto_about_to_be_notified_rejected_promises_list(handled_later)
	scope.push_onto_about_to_be_notified_rejected_promises_list(uncaught)
	event_loop.perform_a_microtask_checkpoint()
	handled_later.mark_handled()
	mut queue := event_loop.task_queue()
	notification := queue.take_first_runnable_matching(fn (task &Task) bool {
		return task.source == .dom_manipulation
	}) or { panic('notification missing') }
	notification.execute()
	assert settings.realm().reported_exceptions.len == 0
	assert !scope.remove_from_outstanding_rejected_promises_weak_set(handled_later)
	assert scope.remove_from_outstanding_rejected_promises_weak_set(uncaught)
}
