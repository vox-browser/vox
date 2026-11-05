module html

import dom
import page

@[heap]
struct UnloadActiveWindowObservation {
mut:
	events      []string
	completions int
	result      CheckIfUnloadingIsCanceledResult
}

fn unload_active_window_document(address string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	return document, unsafe { &WindowModel(document.get_window() or { return error('missing actual Window') }) }
}

fn unload_active_window_traversable(document &dom.Document) &TraversableNavigable {
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(document.navigable() or { panic('missing actual Navigable') })
	// Retain a deliberately old adapter snapshot to prove actual owner reads.
	traversable.active_document_ = document
	return traversable
}

fn unload_active_window_entry(document &dom.Document) &SessionHistoryEntry {
	return &SessionHistoryEntry{
		url:            dom.URL{value: 'https://unload-active-window.example/target'}
		document_state: &DocumentState{
			document:     document
			document_id_: document.unique_id()
			origin:       document.origin()
		}
	}
}

fn unload_active_window_observe(window &WindowModel, name string, observation &UnloadActiveWindowObservation, cancel bool, retarget ?&WindowModel) {
	target := unsafe { &dom.EventTarget(window) }
	target.add_event_listener_without_options('beforeunload', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [window, name, observation, retarget] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert voidptr(event.current_target() or { panic('missing Window current target') }) == voidptr(window)
			mut state := unsafe { &UnloadActiveWindowObservation(observation) }
			state.events << '${name}:beforeunload'
			if replacement := retarget {
				proxy := window.browsing_context().window_proxy() or { panic('missing actual WindowProxy') }
				proxy.dom_proxy().set_window(unsafe { &dom.Window(replacement) })
			}
			return dom.js_undefined()
		}
	}))
	navigation := window.navigation()
	navigation_target := unsafe { &dom.EventTarget(navigation) }
	navigation_target.add_event_listener_without_options('navigate', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [name, observation, navigation_target, cancel] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert voidptr(event.target() or { panic('missing actual Navigation event target') }) == voidptr(navigation_target)
			mut state := unsafe { &UnloadActiveWindowObservation(observation) }
			state.events << '${name}:navigate'
			if cancel {
				assert event.cancelable()
				mut mutable_event := unsafe { &dom.Event(event) }
				mutable_event.prevent_default()
			}
			return dom.js_undefined()
		}
	}))
}

fn unload_active_window_queue(traversable &TraversableNavigable, documents []&dom.Document, target &SessionHistoryEntry, observation &UnloadActiveWindowObservation) {
	traversable.check_if_unloading_is_canceled_for_history_step(documents, target, .none_, fn [observation] (result CheckIfUnloadingIsCanceledResult) {
		mut state := unsafe { &UnloadActiveWindowObservation(observation) }
		state.completions++
		state.result = result
	})
}

fn test_unload_phase_one_uses_actual_window_navigation_without_an_adapter_navigation() {
	mut document, window := unload_active_window_document('https://unload-active-window.example/actual')!
	defer { document.finalize() }
	traversable := unload_active_window_traversable(document)
	assert traversable.legacy_navigation_ == none
	assert voidptr(traversable.active_window()?) == voidptr(window)
	state := &UnloadActiveWindowObservation{}
	unload_active_window_observe(window, 'actual', state, true, none)
	unload_active_window_queue(traversable, [document], unload_active_window_entry(document), state)
	mut event_loop := main_thread_event_loop()
	assert voidptr(event_loop.task_queue().last_added_task()?.document()?) == voidptr(document)
	event_loop.process()
	assert state.events == ['actual:beforeunload', 'actual:navigate']
	assert state.completions == 1 && state.result == .canceled_by_navigate
}

fn test_unload_phase_one_retains_queue_time_global_document_after_temporary_association() {
	mut document, mut window := unload_active_window_document('https://unload-active-window.example/queue-global')!
	mut queued_document, _ := unload_active_window_document('https://unload-active-window.example/queued-document')!
	defer {
		document.finalize()
		queued_document.finalize()
	}
	traversable := unload_active_window_traversable(document)
	state := &UnloadActiveWindowObservation{}
	unload_active_window_observe(window, 'active', state, true, none)
	window.set_associated_document(queued_document)
	unload_active_window_queue(traversable, [document], unload_active_window_entry(document), state)
	mut event_loop := main_thread_event_loop()
	task := event_loop.task_queue().last_added_task()?
	assert voidptr(task.document()?) == voidptr(queued_document)
	window.set_associated_document(document)
	assert voidptr(task.document()?) == voidptr(queued_document)
	event_loop.process()
	assert state.events == ['active:beforeunload', 'active:navigate']
	assert state.completions == 1 && state.result == .canceled_by_navigate
}

fn test_unload_phase_one_re_reads_native_proxy_window_after_queueing() {
	mut document, window := unload_active_window_document('https://unload-active-window.example/proxy-before')!
	mut replacement, replacement_window := unload_active_window_document('https://unload-active-window.example/proxy-after')!
	defer {
		document.finalize()
		replacement.finalize()
	}
	mut traversable := unload_active_window_traversable(document)
	traversable.set_navigation(window.navigation())
	state := &UnloadActiveWindowObservation{}
	unload_active_window_observe(window, 'old', state, false, none)
	unload_active_window_observe(replacement_window, 'replacement', state, true, none)
	unload_active_window_queue(traversable, [], unload_active_window_entry(replacement), state)
	mut event_loop := main_thread_event_loop()
	assert voidptr(event_loop.task_queue().last_added_task()?.document()?) == voidptr(document)
	native_proxy := document.get_browsing_context()?.window_proxy()
	replacement_native := replacement.get_window()?
	native_proxy.set_window(replacement_native)
	assert voidptr(traversable.active_window()?) == voidptr(replacement_window)
	event_loop.process()
	assert state.events == ['replacement:navigate']
	assert state.completions == 1 && state.result == .canceled_by_navigate
}

fn test_unload_phase_one_re_reads_actual_navigation_after_beforeunload_changes_proxy_slot() {
	mut document, window := unload_active_window_document('https://unload-active-window.example/dispatch-before')!
	mut replacement, replacement_window := unload_active_window_document('https://unload-active-window.example/dispatch-after')!
	defer {
		document.finalize()
		replacement.finalize()
	}
	mut traversable := unload_active_window_traversable(document)
	traversable.set_navigation(window.navigation())
	state := &UnloadActiveWindowObservation{}
	unload_active_window_observe(window, 'old', state, false, replacement_window)
	unload_active_window_observe(replacement_window, 'replacement', state, true, none)
	unload_active_window_queue(traversable, [document], unload_active_window_entry(replacement), state)
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert state.events == ['old:beforeunload', 'replacement:navigate']
	assert state.completions == 1 && state.result == .canceled_by_navigate
	assert document.get_unload_counter() == 0
}

fn test_unload_phase_one_reads_native_active_document_after_real_navigation_replacement() {
	mut original, mut original_window := unload_active_window_document('https://unload-active-window.example/original')!
	mut queue_owner, _ := unload_active_window_document('https://unload-active-window.example/queue-owner')!
	defer {
		original.finalize()
		queue_owner.finalize()
	}
	traversable := unload_active_window_traversable(original)
	state := &UnloadActiveWindowObservation{}
	unload_active_window_observe(original_window, 'old', state, false, none)
	target := unload_active_window_entry(original)
	// A distinct actual global association makes the queued Source task remain
	// runnable when navigation replaces its original active Document.
	original_window.set_associated_document(queue_owner)
	unload_active_window_queue(traversable, [original], target, state)
	mut event_loop := main_thread_event_loop()
	task := event_loop.task_queue().last_added_task()?
	assert voidptr(task.document()?) == voidptr(queue_owner)
	original_window.set_associated_document(original)
	url := dom.URL{value: 'https://unload-active-window.example/navigation-replacement'}
	mut replacement := create_navigation_document_for_page(url, url.origin(), original, original.page())!
	defer { replacement.finalize() }
	replacement_window := unsafe { &WindowModel(replacement.get_window()?) }
	unload_active_window_observe(replacement_window, 'new', state, true, none)
	mut target_state := unsafe { &DocumentState(target.document_state?) }
	target_state.document = replacement
	target_state.document_id_ = replacement.unique_id()
	assert !original.is_fully_active() && replacement.is_fully_active()
	assert voidptr(traversable.active_document()?) == voidptr(replacement)
	assert traversable.active_document_id()? == replacement.unique_id()
	assert voidptr(traversable.active_window()?) == voidptr(replacement_window)
	assert voidptr(task.document()?) == voidptr(queue_owner)
	event_loop.process()
	assert state.events == ['new:beforeunload', 'new:navigate']
	assert state.completions == 1 && state.result == .canceled_by_navigate
}

fn test_traversable_native_null_active_document_does_not_reuse_an_old_adapter_snapshot() {
	mut document, _ := unload_active_window_document('https://unload-active-window.example/null-owner')!
	defer { document.finalize() }
	traversable := unload_active_window_traversable(document)
	mut host := document.navigable()?
	host.set_active_document(none)
	assert traversable.active_document_ != none
	assert traversable.active_document() == none
	assert traversable.active_document_id() == none
	assert traversable.active_window() == none
}
