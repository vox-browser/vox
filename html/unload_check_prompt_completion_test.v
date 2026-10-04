module html

import dom
import page
import webdriver

@[heap]
struct UnloadPromptCompletionObservation {
mut:
	completions    int
	before_unloads int
	result         CheckIfUnloadingIsCanceledResult
	prompt_shown   UnloadPromptShown = .no
}

fn unload_prompt_completion_document(address string) !(&dom.Document, &WindowModel, &TraversableNavigable) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	window := unsafe { &WindowModel(document.get_window() or { return error('missing actual Window') }) }
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(document.navigable() or { return error('missing actual Navigable') })
	traversable.active_document_ = document
	return document, window, traversable
}

fn unload_prompt_completion_listener(window &WindowModel, observation &UnloadPromptCompletionObservation) {
	window_target := unsafe { &dom.EventTarget(window) }
	window_target.add_event_listener_without_options('beforeunload', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &UnloadPromptCompletionObservation(observation) }
			observed.before_unloads++
			mut mutable_event := unsafe { &dom.Event(event) }
			mutable_event.prevent_default()
			return dom.js_undefined()
		}
	}))
}

fn unload_prompt_completion_callback(observation &UnloadPromptCompletionObservation) TraversableUnloadCheckCompletion {
	return fn [observation] (result CheckIfUnloadingIsCanceledResult, prompt_shown UnloadPromptShown) {
		mut observed := unsafe { &UnloadPromptCompletionObservation(observation) }
		observed.completions++
		observed.result = result
		observed.prompt_shown = prompt_shown
	}
}

fn test_unload_check_full_history_completion_carries_actual_phase_one_prompt_result() {
	mut document, window, traversable := unload_prompt_completion_document('https://unload-prompt-completion.example/phase-one')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		webdriver.set_user_prompt_handler(snapshot or { map[webdriver.PromptType]webdriver.PromptHandlerConfiguration{} })
		document.finalize()
	}
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.before_unload: webdriver.PromptHandlerConfiguration{ handler: .dismiss }
	})
	assert unsafe { &dom.EventTarget(document) }.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	observation := &UnloadPromptCompletionObservation{}
	unload_prompt_completion_listener(window, observation)
	target := &SessionHistoryEntry{
		url:            dom.URL{'https://unload-prompt-completion.example/target'}
		document_state: &DocumentState{
			document:     document
			document_id_: document.unique_id()
			origin:       document.origin()
		}
	}
	traversable.check_if_unloading_is_canceled_for_history_step_with_prompt([document], target, .none_, .no, unload_prompt_completion_callback(observation))
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert observation.before_unloads == 1 && observation.completions == 1
	assert observation.result == .canceled_by_before_unload && observation.prompt_shown == .yes
}

fn test_unload_check_initial_yes_prevents_another_actual_phase_two_prompt_and_survives_completion() {
	mut document, window, traversable := unload_prompt_completion_document('https://unload-prompt-completion.example/initial-yes')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		webdriver.set_user_prompt_handler(snapshot or { map[webdriver.PromptType]webdriver.PromptHandlerConfiguration{} })
		document.finalize()
	}
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.before_unload: webdriver.PromptHandlerConfiguration{ handler: .dismiss }
	})
	assert unsafe { &dom.EventTarget(document) }.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	observation := &UnloadPromptCompletionObservation{}
	unload_prompt_completion_listener(window, observation)
	current := traversable.current_session_history_entry()?
	traversable.check_if_unloading_is_canceled_for_history_step_with_prompt([document], current, .none_, .yes, unload_prompt_completion_callback(observation))
	mut event_loop := main_thread_event_loop()
	assert event_loop.task_queue().last_added_task()?.document() == none
	event_loop.process()
	assert observation.before_unloads == 1 && observation.completions == 1
	assert observation.result == .continue_ && observation.prompt_shown == .yes
}

fn test_unload_check_empty_phase_preserves_source_initial_prompt_enum_in_both_cases() {
	mut document, _, traversable := unload_prompt_completion_document('https://unload-prompt-completion.example/empty')!
	defer { document.finalize() }
	for initial in [UnloadPromptShown.no, .yes] {
		observation := &UnloadPromptCompletionObservation{}
		mut state := CheckUnloadingCanceledState.create(traversable, [], none, .none_, initial, unload_prompt_completion_callback(observation))
		state.start_document_tasks()
		assert observation.completions == 1 && observation.result == .continue_
		assert observation.prompt_shown == initial
		assert !state.timeout_.is_active() && !state.timeout_.has_activity_root()
		state.timeout_.fire()
		assert observation.completions == 1
	}
}

fn test_unload_check_timeout_returns_continue_and_actual_prompt_yes_after_partial_phase_two() {
	mut first, first_window, traversable := unload_prompt_completion_document('https://unload-prompt-completion.example/first')!
	mut second, second_window, _ := unload_prompt_completion_document('https://unload-prompt-completion.example/second')!
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
	observation := &UnloadPromptCompletionObservation{}
	unload_prompt_completion_listener(first_window, observation)
	unload_prompt_completion_listener(second_window, observation)
	mut state := CheckUnloadingCanceledState.create(traversable, [first, second], none, .none_, .no, unload_prompt_completion_callback(observation))
	state.start_document_tasks()
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert state.final_status == .canceled_by_before_unload && state.unload_prompt_shown == .yes
	assert observation.completions == 0
	state.timeout_.fire()
	assert observation.completions == 1 && observation.result == .continue_ && observation.prompt_shown == .yes
	event_loop.process()
	assert observation.before_unloads == 2 && observation.completions == 1
	assert observation.result == .continue_ && observation.prompt_shown == .yes
}

fn test_unload_check_source_result_only_overload_projects_actual_cancellation_without_changing_it() {
	mut document, window, traversable := unload_prompt_completion_document('https://unload-prompt-completion.example/projection')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		webdriver.set_user_prompt_handler(snapshot or { map[webdriver.PromptType]webdriver.PromptHandlerConfiguration{} })
		document.finalize()
	}
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.before_unload: webdriver.PromptHandlerConfiguration{ handler: .dismiss }
	})
	assert unsafe { &dom.EventTarget(document) }.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	observation := &UnloadPromptCompletionObservation{}
	unload_prompt_completion_listener(window, observation)
	traversable.check_if_unloading_is_canceled([document], fn [observation] (result CheckIfUnloadingIsCanceledResult) {
		mut observed := unsafe { &UnloadPromptCompletionObservation(observation) }
		observed.completions++
		observed.result = result
	})
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert observation.completions == 1 && observation.result == .canceled_by_before_unload
}
