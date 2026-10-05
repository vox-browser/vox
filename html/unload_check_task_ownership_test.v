module html

import dom
import page
import webdriver

@[heap]
struct UnloadCheckTaskObservation {
mut:
	completions    int
	before_unloads int
	result         CheckIfUnloadingIsCanceledResult
}

fn unload_check_owner_document(address string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(native) }
}

fn unload_check_owner_traversable(document &dom.Document) &TraversableNavigable {
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(document.navigable() or { panic('missing actual Navigable') })
	traversable.active_document_ = document
	return traversable
}

fn unload_check_owner_observe(window &WindowModel, state &UnloadCheckTaskObservation) {
	target := unsafe { &dom.EventTarget(window) }
	target.add_event_listener_without_options('beforeunload', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observation := unsafe { &UnloadCheckTaskObservation(state) }
			observation.before_unloads++
			return dom.js_undefined()
		}
	}))
}

fn unload_check_owner_queue(traversable &TraversableNavigable, documents []&dom.Document, observation &UnloadCheckTaskObservation) {
	traversable.check_if_unloading_is_canceled(documents, fn [observation] (result CheckIfUnloadingIsCanceledResult) {
		mut state := unsafe { &UnloadCheckTaskObservation(observation) }
		state.completions++
		state.result = result
	})
}

fn test_unload_check_task_retains_document_but_stays_runnable_after_actual_navigation_replacement() {
	mut original, window := unload_check_owner_document('https://unload-check-owner.example/original')!
	traversable := unload_check_owner_traversable(original)
	state := &UnloadCheckTaskObservation{}
	unload_check_owner_observe(window, state)
	assert original.is_fully_active()
	native := original.navigable()?
	unload_check_owner_queue(traversable, [original], state)
	mut event_loop := main_thread_event_loop()
	queue := event_loop.task_queue()
	task := queue.last_added_task()?
	assert task.source() == .navigation_and_traversal
	assert task.document() == none && task.is_runnable()
	url := dom.URL{value: 'https://unload-check-owner.example/replacement'}
	mut replacement := create_navigation_document(url, url.origin(), original)!
	defer {
		original.finalize()
		replacement.finalize()
	}
	assert voidptr(replacement.navigable()?) == voidptr(native)
	assert !original.is_fully_active() && replacement.is_fully_active()
	assert !original.has_been_destroyed()
	assert task.document() == none && task.is_runnable()
	event_loop.process()
	assert state.completions == 1 && state.result == .continue_
	assert state.before_unloads == 0
	assert original.get_unload_counter() == 0 && replacement.get_unload_counter() == 0
	event_loop.process()
	assert state.completions == 1
}

fn test_unload_check_task_survives_actual_document_destruction_and_finishes_without_dispatch() {
	mut document, window := unload_check_owner_document('https://unload-check-owner.example/destroyed')!
	defer { document.finalize() }
	traversable := unload_check_owner_traversable(document)
	state := &UnloadCheckTaskObservation{}
	unload_check_owner_observe(window, state)
	unload_check_owner_queue(traversable, [document], state)
	mut event_loop := main_thread_event_loop()
	queue := event_loop.task_queue()
	task := queue.last_added_task()?
	assert task.document() == none
	document.destroy()
	assert document.has_been_destroyed() && !document.is_fully_active()
	// Document::destroy removes tasks associated with the destroyed document;
	// Source's null-document unload check must survive that cleanup.
	assert queue.tasks.any(voidptr(it) == voidptr(task))
	assert task.is_runnable() && !task.is_permanently_unrunnable()
	event_loop.process()
	assert state.completions == 1 && state.result == .continue_
	assert state.before_unloads == 0 && document.get_unload_counter() == 0
	event_loop.process()
	assert state.completions == 1
}

fn test_unload_check_phase_two_completes_all_actual_documents_and_retains_one_prompt_result() {
	mut first, first_window := unload_check_owner_document('https://unload-check-owner.example/first')!
	mut second, second_window := unload_check_owner_document('https://unload-check-owner.example/second')!
	mut destroyed, destroyed_window := unload_check_owner_document('https://unload-check-owner.example/third')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		webdriver.set_user_prompt_handler(snapshot or { map[webdriver.PromptType]webdriver.PromptHandlerConfiguration{} })
		first.finalize()
		second.finalize()
		destroyed.finalize()
	}
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.before_unload: webdriver.PromptHandlerConfiguration{
			handler: .dismiss
		}
	})
	traversable := unload_check_owner_traversable(first)
	state := &UnloadCheckTaskObservation{}
	for document in [first, second, destroyed] {
		assert unsafe { &dom.EventTarget(document) }.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
		assert document.get_window()?.has_sticky_activation()
	}
	first_target := unsafe { &dom.EventTarget(first_window) }
	first_target.set_event_handler_attribute('beforeunload', &dom.CallbackType{
		associated_window: unsafe { &dom.Window(first_window) }
		handle_event:      fn [state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observation := unsafe { &UnloadCheckTaskObservation(state) }
			observation.before_unloads++
			return dom.js_string('cancel the shared unload check')
		}
	})
	unload_check_owner_observe(second_window, state)
	unload_check_owner_observe(destroyed_window, state)
	unload_check_owner_queue(traversable, [first, second, destroyed], state)
	mut event_loop := main_thread_event_loop()
	queue := event_loop.task_queue()
	tasks := queue.tasks.filter(it.source() == .navigation_and_traversal)
	assert tasks.len == 3
	for task in tasks {
		assert task.document() == none
	}
	destroyed.destroy()
	event_loop.process()
	assert state.before_unloads == 1 && state.completions == 0
	event_loop.process()
	assert state.before_unloads == 2 && state.completions == 0
	event_loop.process()
	assert state.before_unloads == 2 && state.completions == 1
	assert state.result == .canceled_by_before_unload
	assert first.get_unload_counter() == 0 && second.get_unload_counter() == 0
	event_loop.process()
	assert state.completions == 1
}
