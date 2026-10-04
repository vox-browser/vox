module html

import dom
import page

@[heap]
struct UnloadOriginGateObservation {
mut:
	events      []string
	completions int
	result      CheckIfUnloadingIsCanceledResult
}

fn unload_origin_gate_fixture(address string) !(&TraversableNavigable, &dom.Document, &WindowModel, &NavigableModel) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	window := unsafe { &WindowModel(document.get_window() or { return error('missing actual Window') }) }
	native := document.navigable() or { return error('missing actual Navigable') }
	model := navigable_model_for_host(native) or { return error('missing actual local owner') }
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(native)
	traversable.active_document_ = document
	// Current Window Navigation selection is a separate source owner slice;
	// this gate fixture supplies the existing bridge its genuine actual object.
	traversable.set_navigation(window.navigation())
	return traversable, document, window, model
}

fn unload_origin_gate_entry(document &dom.Document, address string) &SessionHistoryEntry {
	return &SessionHistoryEntry{
		url:            dom.URL{address}
		document_state: &DocumentState{
			document:     document
			document_id_: document.unique_id()
			origin:       document.origin()
		}
	}
}

fn unload_origin_gate_observe(window &WindowModel, observation &UnloadOriginGateObservation, cancel_navigate bool) {
	window_target := unsafe { &dom.EventTarget(window) }
	window_target.add_event_listener_without_options('beforeunload', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [observation] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut state := unsafe { &UnloadOriginGateObservation(observation) }
			state.events << 'beforeunload'
			return dom.js_undefined()
		}
	}))
	navigation := window.navigation()
	navigation_target := unsafe { &dom.EventTarget(navigation) }
	navigation_target.add_event_listener_without_options('navigate', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [observation, navigation_target, cancel_navigate] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert voidptr(event.target() or { panic('missing actual Navigation event target') }) == voidptr(navigation_target)
			mut state := unsafe { &UnloadOriginGateObservation(observation) }
			state.events << 'navigate'
			if cancel_navigate {
				assert event.cancelable()
				mut mutable_event := unsafe { &dom.Event(event) }
				mutable_event.prevent_default()
			}
			return dom.js_undefined()
		}
	}))
}

fn unload_origin_gate_queue(traversable &TraversableNavigable, document &dom.Document, target &SessionHistoryEntry, observation &UnloadOriginGateObservation) {
	traversable.check_if_unloading_is_canceled_for_history_step([document], target, .none_, fn [observation] (result CheckIfUnloadingIsCanceledResult) {
		mut state := unsafe { &UnloadOriginGateObservation(observation) }
		state.completions++
		state.result = result
	})
}

fn test_unload_history_same_origin_fires_actual_traverse_event_after_beforeunload_and_retains_cancellation() {
	traversable, mut document, window, _ := unload_origin_gate_fixture('https://unload-origin-gate.example/current')!
	defer { document.finalize() }
	target := unload_origin_gate_entry(document, 'https://unload-origin-gate.example/target')
	mut state := &UnloadOriginGateObservation{}
	unload_origin_gate_observe(window, state, true)
	unload_origin_gate_queue(traversable, document, target, state)
	mut event_loop := main_thread_event_loop()
	assert voidptr(event_loop.task_queue().last_added_task()?.document()?) == voidptr(document)
	event_loop.process()
	assert state.events == ['beforeunload', 'navigate']
	assert state.completions == 1 && state.result == .canceled_by_navigate
	assert document.get_unload_counter() == 0
}

fn test_unload_history_cross_origin_stays_in_document_phase_without_traverse_event() {
	traversable, mut document, window, _ := unload_origin_gate_fixture('https://unload-origin-gate.example/cross-current')!
	defer { document.finalize() }
	target := unload_origin_gate_entry(document, 'https://foreign-unload-origin.example/target')
	mut target_state := unsafe { &DocumentState(target.document_state?) }
	target_state.origin = target.url.origin()
	mut state := &UnloadOriginGateObservation{}
	unload_origin_gate_observe(window, state, false)
	unload_origin_gate_queue(traversable, document, target, state)
	mut event_loop := main_thread_event_loop()
	assert event_loop.task_queue().last_added_task()?.document() == none
	event_loop.process()
	assert state.events == ['beforeunload']
	assert state.completions == 1 && state.result == .continue_
}

fn test_unload_history_compares_actual_current_entry_identity_instead_of_a_different_active_entry() {
	traversable, mut document, window, mut model := unload_origin_gate_fixture('https://unload-origin-gate.example/identity')!
	defer { document.finalize() }
	active := model.active_session_history_entry()?
	current := unload_origin_gate_entry(document, 'https://foreign-unload-origin.example/current')
	mut current_state := unsafe { &DocumentState(current.document_state?) }
	current_state.origin = current.url.origin()
	model.set_current_session_history_entry(current)
	assert voidptr(model.active_session_history_entry()?) == voidptr(active)
	mut state := &UnloadOriginGateObservation{}
	unload_origin_gate_observe(window, state, false)
	unload_origin_gate_queue(traversable, document, current, state)
	mut event_loop := main_thread_event_loop()
	assert event_loop.task_queue().last_added_task()?.document() == none
	event_loop.process()
	assert state.events == ['beforeunload']
	assert state.completions == 1 && state.result == .continue_
}

fn test_unload_history_optional_origins_distinguish_both_absent_from_one_absent() {
	traversable, mut document, window, model := unload_origin_gate_fixture('https://unload-origin-gate.example/optional')!
	defer { document.finalize() }
	mut current_state := unsafe { &DocumentState(model.current_session_history_entry()?.document_state?) }
	current_state.origin = none
	target := unload_origin_gate_entry(document, 'https://unload-origin-gate.example/optional-target')
	mut target_state := unsafe { &DocumentState(target.document_state?) }
	target_state.origin = none
	mut state := &UnloadOriginGateObservation{}
	unload_origin_gate_observe(window, state, false)
	unload_origin_gate_queue(traversable, document, target, state)
	mut event_loop := main_thread_event_loop()
	assert voidptr(event_loop.task_queue().last_added_task()?.document()?) == voidptr(document)
	event_loop.process()
	assert state.events == ['beforeunload', 'navigate'] && state.completions == 1
	state.events.clear()
	target_state.origin = document.origin()
	unload_origin_gate_queue(traversable, document, target, state)
	assert event_loop.task_queue().last_added_task()?.document() == none
	event_loop.process()
	assert state.events == ['beforeunload'] && state.completions == 2
}

fn test_unload_history_origin_equality_uses_opaque_nonce_identity() {
	traversable, mut document, window, model := unload_origin_gate_fixture('https://unload-origin-gate.example/opaque')!
	defer { document.finalize() }
	mut current_state := unsafe { &DocumentState(model.current_session_history_entry()?.document_state?) }
	opaque := dom.origin_create_opaque()
	current_state.origin = opaque
	target := unload_origin_gate_entry(document, 'https://unload-origin-gate.example/opaque-target')
	mut target_state := unsafe { &DocumentState(target.document_state?) }
	target_state.origin = opaque
	mut state := &UnloadOriginGateObservation{}
	unload_origin_gate_observe(window, state, false)
	unload_origin_gate_queue(traversable, document, target, state)
	mut event_loop := main_thread_event_loop()
	assert voidptr(event_loop.task_queue().last_added_task()?.document()?) == voidptr(document)
	event_loop.process()
	assert state.events == ['beforeunload', 'navigate'] && state.completions == 1
	state.events.clear()
	different := dom.origin_create_opaque()
	assert opaque.serialize_for_ipc() != different.serialize_for_ipc()
	target_state.origin = different
	unload_origin_gate_queue(traversable, document, target, state)
	assert event_loop.task_queue().last_added_task()?.document() == none
	event_loop.process()
	assert state.events == ['beforeunload'] && state.completions == 2
}
