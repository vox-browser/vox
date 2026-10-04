module html

import dom
import page
import webdriver

@[heap]
struct UnloadTimeoutObservation {
mut:
	owner          &CheckUnloadingCanceledState = unsafe { nil }
	completions    int
	before_unloads int
	navigates      int
	result         CheckIfUnloadingIsCanceledResult
}

fn unload_timeout_document(address string) !(&dom.Document, &WindowModel) {
	page_owner := page.Page.create(1)!
	url := dom.URL{address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(page_owner) })!
	return document, unsafe { &WindowModel(document.get_window() or { return error('missing actual Window') }) }
}

fn unload_timeout_traversable(document &dom.Document) &TraversableNavigable {
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(document.navigable() or { panic('missing actual Navigable') })
	traversable.active_document_ = document
	return traversable
}

fn unload_timeout_state(traversable &TraversableNavigable, documents []&dom.Document, target ?&SessionHistoryEntry, observation &UnloadTimeoutObservation) &CheckUnloadingCanceledState {
	state := CheckUnloadingCanceledState.create(traversable, documents, target, .none_, .no, fn [observation] (result CheckIfUnloadingIsCanceledResult, _ UnloadPromptShown) {
		mut observed := unsafe { &UnloadTimeoutObservation(observation) }
		assert observed.owner.completed
		assert !observed.owner.timeout_.is_active()
		assert !observed.owner.timeout_.has_activity_root()
		observed.completions++
		observed.result = result
	})
	mut observed := unsafe { &UnloadTimeoutObservation(observation) }
	observed.owner = state
	assert state.timeout_.interval() == 15000
	assert state.timeout_.is_single_shot()
	assert state.timeout_.is_active() && state.timeout_.has_activity_root()
	return state
}

fn unload_timeout_observe(window &WindowModel, observation &UnloadTimeoutObservation, cancel_before_unload bool) {
	window_target := unsafe { &dom.EventTarget(window) }
	window_target.add_event_listener_without_options('beforeunload', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [observation, cancel_before_unload] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &UnloadTimeoutObservation(observation) }
			observed.before_unloads++
			if cancel_before_unload {
				mut mutable_event := unsafe { &dom.Event(event) }
				mutable_event.prevent_default()
			}
			return dom.js_undefined()
		}
	}))
	navigation := window.navigation()
	navigation_target := unsafe { &dom.EventTarget(navigation) }
	navigation_target.add_event_listener_without_options('navigate', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &UnloadTimeoutObservation(observation) }
			observed.navigates++
			assert event.cancelable()
			mut mutable_event := unsafe { &dom.Event(event) }
			mutable_event.prevent_default()
			return dom.js_undefined()
		}
	}))
}

fn test_unload_check_empty_phase_stops_actual_timer_before_completion_callback() {
	mut document, _ := unload_timeout_document('https://unload-timeout.example/empty')!
	defer { document.finalize() }
	observation := &UnloadTimeoutObservation{}
	mut state := unload_timeout_state(unload_timeout_traversable(document), [], none, observation)
	state.start_document_tasks()
	assert observation.completions == 1 && observation.result == .continue_
	state.timeout_.fire()
	state.finish(.canceled_by_navigate)
	assert observation.completions == 1 && observation.result == .continue_
}

fn test_unload_check_deadline_completes_a_real_phase_one_task_blocked_by_navigation_replacement() {
	mut original, original_window := unload_timeout_document('https://unload-timeout.example/original')!
	defer { original.finalize() }
	observation := &UnloadTimeoutObservation{}
	unload_timeout_observe(original_window, observation, false)
	target := &SessionHistoryEntry{
		url:            dom.URL{'https://unload-timeout.example/target'}
		document_state: &DocumentState{
			document:     original
			document_id_: original.unique_id()
			origin:       original.origin()
		}
	}
	mut state := unload_timeout_state(unload_timeout_traversable(original), [], target, observation)
	state.needs_before_unload = true
	state.start_traverse_event_task()
	mut event_loop := main_thread_event_loop()
	task := event_loop.task_queue().last_added_task()?
	assert voidptr(task.document()?) == voidptr(original) && task.is_runnable()
	mut native := original.navigable()?
	url := dom.URL{'https://unload-timeout.example/replacement'}
	mut replacement := create_navigation_document_for_page(url, url.origin(), original, original.page())!
	defer { replacement.finalize() }
	assert !original.is_fully_active() && replacement.is_fully_active()
	assert !task.is_runnable()
	event_loop.process()
	assert observation.completions == 0 && observation.before_unloads == 0
	state.timeout_.fire()
	assert observation.completions == 1 && observation.result == .continue_
	assert observation.navigates == 0
	// Source does not discard already queued steps at timeout. A late genuine
	// canceled Navigation event still cannot complete the check a second time.
	native.set_active_document(original)
	original.get_browsing_context()?.window_proxy().set_window(unsafe { &dom.Window(original_window) })
	assert task.is_runnable()
	event_loop.process()
	assert observation.before_unloads == 1 && observation.navigates == 1
	assert observation.completions == 1 && observation.result == .continue_
	state.timeout_.fire()
	assert observation.completions == 1
}

fn test_unload_check_completed_beforeunload_cancellation_stops_timer_and_preserves_result() {
	mut document, window := unload_timeout_document('https://unload-timeout.example/canceled')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		webdriver.set_user_prompt_handler(snapshot or { map[webdriver.PromptType]webdriver.PromptHandlerConfiguration{} })
		document.finalize()
	}
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.before_unload: webdriver.PromptHandlerConfiguration{ handler: .dismiss }
	})
	assert unsafe { &dom.EventTarget(document) }.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	assert document.get_window()?.has_sticky_activation()
	observation := &UnloadTimeoutObservation{}
	unload_timeout_observe(window, observation, true)
	mut state := unload_timeout_state(unload_timeout_traversable(document), [document], none, observation)
	state.start_document_tasks()
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert observation.before_unloads == 1
	assert observation.completions == 1 && observation.result == .canceled_by_before_unload
	state.timeout_.fire()
	assert observation.completions == 1 && observation.result == .canceled_by_before_unload
}

fn test_unload_check_timeout_returns_source_continue_during_partial_canceled_phase_two() {
	mut first, first_window := unload_timeout_document('https://unload-timeout.example/phase-two-first')!
	mut second, second_window := unload_timeout_document('https://unload-timeout.example/phase-two-second')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		webdriver.set_user_prompt_handler(snapshot or { map[webdriver.PromptType]webdriver.PromptHandlerConfiguration{} })
		first.finalize()
		second.finalize()
	}
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.before_unload: webdriver.PromptHandlerConfiguration{ handler: .dismiss }
	})
	assert unsafe { &dom.EventTarget(first) }.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	observation := &UnloadTimeoutObservation{}
	unload_timeout_observe(first_window, observation, true)
	unload_timeout_observe(second_window, observation, false)
	mut state := unload_timeout_state(unload_timeout_traversable(first), [first, second], none, observation)
	state.start_document_tasks()
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert state.final_status == .canceled_by_before_unload && state.unload_prompt_shown == .yes
	assert state.remaining_documents == 1 && observation.completions == 0
	state.timeout_.fire()
	assert observation.completions == 1 && observation.result == .continue_
	assert state.unload_prompt_shown == .yes
	event_loop.process()
	assert state.remaining_documents == 0 && observation.before_unloads == 2
	assert observation.completions == 1 && observation.result == .continue_
}
