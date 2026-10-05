module html

import dom
import highresolutiontime
import page

@[heap]
struct UniversalScopeOwnerObservation {
mut:
	steps      []string
	rejections int
}

fn universal_scope_owner_window(address string, owner &page.Page) !(&dom.Document, &WindowModel) {
	url := dom.URL{value: address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(native) }
}

fn test_universal_scope_microtasks_capture_current_native_window_document_at_queue_time() {
	owner := page.Page.create(1)!
	mut original, window := universal_scope_owner_window('https://universal-owner.example/original', owner)!
	mut replacement, _ := universal_scope_owner_window('https://universal-owner.example/replacement', owner)!
	defer {
		original.finalize()
		replacement.finalize()
	}
	mut native := original.get_window()?
	scope := window.environment_settings_.settings.universal_global_scope()
	state := &UniversalScopeOwnerObservation{}
	mut event_loop := main_thread_event_loop()
	start := event_loop.microtask_queue.len
	scope.queue_microtask(fn [state] () {
		mut observation := unsafe { &UniversalScopeOwnerObservation(state) }
		observation.steps << 'original'
	})
	native.set_associated_document(replacement)
	scope.queue_microtask(fn [state] () {
		mut observation := unsafe { &UniversalScopeOwnerObservation(state) }
		observation.steps << 'replacement'
	})
	native.set_associated_document(original)
	assert event_loop.microtask_queue.len == start + 2
	first := event_loop.microtask_queue[start]
	second := event_loop.microtask_queue[start + 1]
	assert first.source() == .microtask && first.document()? == original
	assert second.source() == .microtask && second.document()? == replacement
	event_loop.microtask_queue.delete(start)
	event_loop.microtask_queue.delete(start)
	first.execute()
	second.execute()
	assert state.steps == ['original', 'replacement']
}

fn test_universal_scope_created_before_document_uses_later_actual_window_association() {
	owner := page.Page.create(1)!
	url := dom.URL{value: 'https://universal-owner.example/creation'}
	context := BrowsingContextModel.create_for_page(unsafe { &dom.Page(owner) }, none, 'before-document')
	window := create_window_global_before_document(context, url, url.origin(), url, url.origin())
	settings := window.environment_settings_.settings
	scope := settings.universal_global_scope()
	assert settings.responsible_document() == none
	mut document := construct_document_in_global(window, context, url, url.origin())!
	defer { document.finalize() }
	assert settings.universal_global_scope() == scope
	mut event_loop := main_thread_event_loop()
	start := event_loop.microtask_queue.len
	scope.queue_microtask(fn () {})
	task := event_loop.microtask_queue[start]
	assert task.document()? == document
	event_loop.microtask_queue.delete(start)
	task.execute()
}

fn test_universal_scope_rejection_task_uses_current_document_and_logical_parent_full_activity() {
	owner := page.Page.create(1)!
	mut original, mut window := universal_scope_owner_window('https://universal-owner.example/original', owner)!
	mut replacement, _ := universal_scope_owner_window('https://universal-owner.example/replacement', owner)!
	mut parent_document, _ := universal_scope_owner_window('https://universal-owner.example/logical-parent', owner)!
	defer {
		original.finalize()
		replacement.finalize()
		parent_document.finalize()
	}
	mut replacement_navigable := replacement.navigable()?
	mut parent_navigable := parent_document.navigable()?
	replacement_navigable.parent_ = parent_navigable
	replacement_navigable.is_top_level_traversable_ = false
	parent_navigable.set_active_document(none)
	assert replacement.is_active() && !replacement.is_fully_active()
	assert original.is_fully_active()
	mut settings := window.environment_settings_.settings
	mut owner_loop := EventLoop.create(.window)
	settings.responsible_event_loop_ = owner_loop
	mut scope := settings.universal_global_scope()
	window.set_associated_document(replacement)
	state := &UniversalScopeOwnerObservation{}
	native := original.get_window()?
	scope.event_target.add_event_listener_without_options('unhandledrejection', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: native
		handle_event:      fn [replacement, window, state] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert voidptr(event.target() or { panic('current Document target') }) == voidptr(replacement)
			assert (window.event() or { panic('actual rejection event') }) == event
			mut mutable_event := unsafe { &dom.Event(event) }
			mutable_event.prevent_default()
			mut observation := unsafe { &UniversalScopeOwnerObservation(state) }
			observation.rejections++
			return dom.js_undefined()
		}
	}))
	promise := dom.Promise.rejected(dom.js_string('current document rejection'))
	scope.push_onto_about_to_be_notified_rejected_promises_list(promise)
	scope.notify_about_rejected_promises()
	mut queue := owner_loop.task_queue()
	task := queue.last_added_task()?
	assert task.source() == .dom_manipulation && task.document()? == replacement
	assert !task.is_runnable()
	assert queue.take_first_runnable_matching(fn [task] (candidate &Task) bool {
		return candidate.id == task.id
	}) == none
	parent_navigable.set_active_document(parent_document)
	assert replacement.is_fully_active() && task.is_runnable()
	runnable := queue.take_first_runnable_matching(fn [task] (candidate &Task) bool {
		return candidate.id == task.id
	})?
	runnable.execute()
	assert state.rejections == 1
	assert scope.remove_from_outstanding_rejected_promises_weak_set(promise)
	assert settings.realm().reported_exceptions.len == 0
	window.set_associated_document(original)
	replacement_navigable.parent_ = none
	replacement_navigable.is_top_level_traversable_ = true
}

fn test_universal_scope_actual_worker_microtask_and_rejection_tasks_have_no_document() {
	owner := page.Page.create(1)!
	mut document, window := universal_scope_owner_window('https://universal-owner.example/outside', owner)!
	defer { document.finalize() }
	mut realm := &ScriptingRealm{}
	mut worker := WorkerGlobalScope.create(dom.URL{value: 'https://universal-owner.example/worker.js'}, .classic, 'worker', realm)
	defer { worker.close_a_worker() }
	worker_settings := WorkerEnvironmentSettingsObject.setup(worker, mut realm, window.environment_settings_.settings.serialize(), highresolutiontime.unsafe_shared_current_time())
	mut scope := worker_settings.settings.universal_global_scope()
	assert scope.event_target == worker.this_impl()
	mut event_loop := main_thread_event_loop()
	start := event_loop.microtask_queue.len
	scope.queue_microtask(fn () {})
	microtask := event_loop.microtask_queue[start]
	assert microtask.source() == .microtask && microtask.document() == none
	event_loop.microtask_queue.delete(start)
	microtask.execute()
	promise := dom.Promise.rejected(dom.js_string('worker rejection'))
	scope.push_onto_about_to_be_notified_rejected_promises_list(promise)
	scope.notify_about_rejected_promises()
	mut queue := worker.event_loop.task_queue()
	task := queue.last_added_task()?
	assert task.source() == .dom_manipulation && task.document() == none && task.is_runnable()
	runnable := queue.take_first_runnable_matching(fn [task] (candidate &Task) bool {
		return candidate.id == task.id
	})?
	runnable.execute()
	assert worker_settings.settings.realm().reported_exceptions.len == 1
	assert scope.remove_from_outstanding_rejected_promises_weak_set(promise)
}
