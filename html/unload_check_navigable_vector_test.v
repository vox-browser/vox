module html

import dom
import page
import webdriver

@[heap]
struct UnloadNavigableVectorObservation {
mut:
	events       []string
	completions  int
	result       CheckIfUnloadingIsCanceledResult
	prompt_shown UnloadPromptShown = .no
}

fn unload_navigable_vector_document(address string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	return document, unsafe { &WindowModel(document.get_window() or { return error('missing actual Window') }) }
}

fn unload_navigable_vector_traversable(document &dom.Document) &TraversableNavigable {
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(document.navigable() or { panic('missing actual Navigable') })
	traversable.active_document_ = document
	return traversable
}

fn unload_navigable_vector_entry(document &dom.Document) &SessionHistoryEntry {
	return &SessionHistoryEntry{
		url:            dom.URL{value: 'https://unload-navigable-vector.example/target'}
		document_state: &DocumentState{
			document:     document
			document_id_: document.unique_id()
			origin:       document.origin()
		}
	}
}

fn unload_navigable_vector_observe(window &WindowModel, name string, observation &UnloadNavigableVectorObservation, cancel bool) {
	window_target := unsafe { &dom.EventTarget(window) }
	window_target.add_event_listener_without_options('beforeunload', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [name, observation, cancel] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &UnloadNavigableVectorObservation(observation) }
			observed.events << '${name}:beforeunload'
			if cancel {
				mut mutable_event := unsafe { &dom.Event(event) }
				mutable_event.prevent_default()
			}
			return dom.js_undefined()
		}
	}))
	navigation_target := unsafe { &dom.EventTarget(window.navigation()) }
	navigation_target.add_event_listener_without_options('navigate', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [name, observation, cancel] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &UnloadNavigableVectorObservation(observation) }
			observed.events << '${name}:navigate'
			if cancel {
				assert event.cancelable()
				mut mutable_event := unsafe { &dom.Event(event) }
				mutable_event.prevent_default()
			}
			return dom.js_undefined()
		}
	}))
}

fn unload_navigable_vector_completion(observation &UnloadNavigableVectorObservation) TraversableUnloadCheckCompletion {
	return fn [observation] (result CheckIfUnloadingIsCanceledResult, prompt_shown UnloadPromptShown) {
		mut observed := unsafe { &UnloadNavigableVectorObservation(observation) }
		observed.completions++
		observed.result = result
		observed.prompt_shown = prompt_shown
	}
}

fn test_unload_native_vector_uses_current_document_of_retained_actual_host_when_invoked() {
	mut original, original_window := unload_navigable_vector_document('https://unload-navigable-vector.example/original')!
	defer { original.finalize() }
	native := original.navigable()?
	observation := &UnloadNavigableVectorObservation{}
	unload_navigable_vector_observe(original_window, 'old', observation, false)
	url := dom.URL{value: 'https://unload-navigable-vector.example/new'}
	mut replacement := create_navigation_document_for_page(url, url.origin(), original, original.page())!
	defer { replacement.finalize() }
	replacement_window := unsafe { &WindowModel(replacement.get_window()?) }
	unload_navigable_vector_observe(replacement_window, 'new', observation, false)
	assert voidptr(replacement.navigable()?) == voidptr(native)
	check_if_unloading_is_canceled([native], none, none, none, .no, unload_navigable_vector_completion(observation))
	mut event_loop := main_thread_event_loop()
	assert event_loop.task_queue().last_added_task()?.document() == none
	event_loop.process()
	assert observation.events == ['new:beforeunload']
	assert observation.completions == 1 && observation.result == .continue_ && observation.prompt_shown == .no
}

fn test_unload_native_vector_retains_selected_document_after_queue_and_skips_replaced_inactive_owner() {
	mut original, original_window := unload_navigable_vector_document('https://unload-navigable-vector.example/captured')!
	defer { original.finalize() }
	observation := &UnloadNavigableVectorObservation{}
	unload_navigable_vector_observe(original_window, 'old', observation, false)
	check_if_unloading_is_canceled([original.navigable()?], none, none, none, .no, unload_navigable_vector_completion(observation))
	url := dom.URL{value: 'https://unload-navigable-vector.example/later-replacement'}
	mut replacement := create_navigation_document_for_page(url, url.origin(), original, original.page())!
	defer { replacement.finalize() }
	unload_navigable_vector_observe(unsafe { &WindowModel(replacement.get_window()?) }, 'new', observation, false)
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert observation.events.len == 0
	assert observation.completions == 1 && observation.result == .continue_ && observation.prompt_shown == .no
}

fn test_unload_native_vector_without_traversable_keeps_initial_prompt_across_multiple_actual_documents() {
	mut first, first_window := unload_navigable_vector_document('https://unload-navigable-vector.example/first')!
	mut second, second_window := unload_navigable_vector_document('https://unload-navigable-vector.example/second')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		webdriver.set_user_prompt_handler(snapshot or { map[webdriver.PromptType]webdriver.PromptHandlerConfiguration{} })
		first.finalize()
		second.finalize()
	}
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.before_unload: webdriver.PromptHandlerConfiguration{ handler: .dismiss }
	})
	observation := &UnloadNavigableVectorObservation{}
	for pair in [first, second] {
		assert unsafe { &dom.EventTarget(pair) }.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	}
	unload_navigable_vector_observe(first_window, 'first', observation, true)
	unload_navigable_vector_observe(second_window, 'second', observation, true)
	check_if_unloading_is_canceled([first.navigable()?, second.navigable()?], none, none, none, .yes, unload_navigable_vector_completion(observation))
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert observation.completions == 0
	event_loop.process()
	assert observation.events == ['first:beforeunload', 'second:beforeunload']
	assert observation.completions == 1 && observation.result == .continue_ && observation.prompt_shown == .yes
}

fn test_unload_native_vector_containing_traversable_removes_its_document_from_phase_two() {
	mut top, top_window := unload_navigable_vector_document('https://unload-navigable-vector.example/top')!
	mut other, other_window := unload_navigable_vector_document('https://unload-navigable-vector.example/other')!
	defer {
		top.finalize()
		other.finalize()
	}
	observation := &UnloadNavigableVectorObservation{}
	unload_navigable_vector_observe(top_window, 'top', observation, false)
	unload_navigable_vector_observe(other_window, 'other', observation, false)
	check_if_unloading_is_canceled([top.navigable()?, other.navigable()?], unload_navigable_vector_traversable(top), unload_navigable_vector_entry(top), UserNavigationInvolvement.none_, .no, unload_navigable_vector_completion(observation))
	mut event_loop := main_thread_event_loop()
	assert voidptr(event_loop.task_queue().last_added_task()?.document()?) == voidptr(top)
	event_loop.process()
	assert observation.events == ['top:beforeunload', 'top:navigate'] && observation.completions == 0
	event_loop.process()
	assert observation.events == ['top:beforeunload', 'top:navigate', 'other:beforeunload']
	assert observation.completions == 1 && observation.result == .continue_ && observation.prompt_shown == .no
}

fn test_unload_native_vector_omitting_traversable_runs_its_navigation_then_only_supplied_document() {
	mut top, top_window := unload_navigable_vector_document('https://unload-navigable-vector.example/omitted-top')!
	mut supplied, supplied_window := unload_navigable_vector_document('https://unload-navigable-vector.example/supplied')!
	defer {
		top.finalize()
		supplied.finalize()
	}
	observation := &UnloadNavigableVectorObservation{}
	unload_navigable_vector_observe(top_window, 'top', observation, false)
	unload_navigable_vector_observe(supplied_window, 'supplied', observation, false)
	check_if_unloading_is_canceled([supplied.navigable()?], unload_navigable_vector_traversable(top), unload_navigable_vector_entry(top), UserNavigationInvolvement.none_, .no, unload_navigable_vector_completion(observation))
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert observation.events == ['top:navigate'] && observation.completions == 0
	event_loop.process()
	assert observation.events == ['top:navigate', 'supplied:beforeunload']
	assert observation.completions == 1 && observation.result == .continue_
}

fn test_unload_native_vector_source_result_only_projection_keeps_actual_beforeunload_cancellation() {
	mut document, window := unload_navigable_vector_document('https://unload-navigable-vector.example/result-projection')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		webdriver.set_user_prompt_handler(snapshot or { map[webdriver.PromptType]webdriver.PromptHandlerConfiguration{} })
		document.finalize()
	}
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.before_unload: webdriver.PromptHandlerConfiguration{ handler: .dismiss }
	})
	assert unsafe { &dom.EventTarget(document) }.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	observation := &UnloadNavigableVectorObservation{}
	unload_navigable_vector_observe(window, 'actual', observation, true)
	check_if_unloading_is_canceled_for_navigables([document.navigable()?], fn [observation] (result CheckIfUnloadingIsCanceledResult) {
		mut observed := unsafe { &UnloadNavigableVectorObservation(observation) }
		observed.completions++
		observed.result = result
	})
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert observation.events == ['actual:beforeunload']
	assert observation.completions == 1 && observation.result == .canceled_by_before_unload
}
