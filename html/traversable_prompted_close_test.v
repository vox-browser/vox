module html

import dom
import page
import webdriver

@[heap]
struct PromptedCloseObservation {
mut:
	before_unloads int
	unloads        int
}

fn prompted_close_fixture(address string) !(&TraversableNavigable, &dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native_window := document.get_window() or { return error('missing actual Window') }
	window := unsafe { &WindowModel(native_window) }
	native := document.navigable() or { return error('missing actual Navigable') }
	model := navigable_model_for_host(native) or { return error('missing actual local Navigable') }
	entry := model.active_session_history_entry() or { return error('missing actual history entry') }
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(native)
	traversable.active_document_ = document
	traversable.active_session_history_entry_ = entry
	traversable.session_history_entries_ = [entry]
	mut context := window.browsing_context()
	context.set_top_level_traversable(traversable)
	assert traversable.is_top_level_traversable()
	assert document.is_fully_active()
	assert unsafe { &dom.EventTarget(document) }.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	assert native_window.has_sticky_activation()
	return traversable, document, window
}

fn prompted_close_set_handler(handler webdriver.PromptHandler) {
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.before_unload: webdriver.PromptHandlerConfiguration{
			handler: handler
		}
	})
}

fn prompted_close_restore_handler(snapshot ?map[webdriver.PromptType]webdriver.PromptHandlerConfiguration) {
	webdriver.set_user_prompt_handler(snapshot or { map[webdriver.PromptType]webdriver.PromptHandlerConfiguration{} })
}

fn prompted_close_observe_unload(window &WindowModel, observation &PromptedCloseObservation) {
	target := unsafe { &dom.EventTarget(window) }
	target.add_event_listener_without_options('unload', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [observation] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut state := unsafe { &PromptedCloseObservation(observation) }
			state.unloads++
			return dom.js_undefined()
		}
	}))
}

fn test_canceled_actual_beforeunload_close_resets_native_closing_and_allows_a_later_close() {
	mut traversable, mut document, window := prompted_close_fixture('https://prompted-close.example/retry')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		prompted_close_restore_handler(snapshot)
		document.finalize()
	}
	state := &PromptedCloseObservation{}
	prompted_close_observe_unload(window, state)
	target := unsafe { &dom.EventTarget(window) }
	target.set_event_handler_attribute('beforeunload', &dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observation := unsafe { &PromptedCloseObservation(state) }
			observation.before_unloads++
			return dom.js_string('keep this page open')
		}
	})
	prompted_close_set_handler(.dismiss)
	native := document.navigable()?
	traversable.close_top_level_traversable()
	assert traversable.is_closing() && native.is_closing() && window.closed()
	assert !traversable.has_been_destroyed()
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert state.before_unloads == 1 && state.unloads == 0
	assert !traversable.is_closing() && !native.is_closing() && !window.closed()
	assert !traversable.close_steps_have_been_appended_
	assert traversable.traversal_queue_.queue.len == 0
	assert !traversable.has_been_destroyed() && !document.has_been_destroyed()
	assert voidptr(traversable.active_document()?) == voidptr(document)
	prompted_close_set_handler(.accept)
	traversable.close_top_level_traversable()
	assert traversable.is_closing() && native.is_closing() && window.closed()
	event_loop.process()
	assert state.before_unloads == 2 && state.unloads == 0
	assert traversable.close_steps_have_been_appended_
	assert traversable.traversal_queue_.queue.len == 1
	assert !traversable.has_been_destroyed()
	traversable.process_session_history_traversal_queue()
	assert state.unloads == 1
	assert traversable.has_been_destroyed() && document.has_been_destroyed()
	assert traversable.active_document() == none
	assert window.closed() && native.is_closing()
}

fn test_source_direct_definitely_close_keeps_outer_closing_owner_and_appends_once_after_overlapping_checks() {
	mut traversable, mut document, window := prompted_close_fixture('https://prompted-close.example/direct')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		prompted_close_restore_handler(snapshot)
		document.finalize()
	}
	state := &PromptedCloseObservation{}
	prompted_close_observe_unload(window, state)
	prompted_close_set_handler(.accept)
	native := document.navigable()?
	traversable.definitely_close_top_level_traversable()
	traversable.definitely_close_top_level_traversable()
	// Only close_top_level_traversable writes is_closing in pinned Source.
	assert !traversable.is_closing() && !native.is_closing() && !window.closed()
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	event_loop.process()
	assert traversable.close_steps_have_been_appended_
	assert traversable.traversal_queue_.queue.len == 1
	assert !traversable.is_closing() && !window.closed()
	traversable.process_session_history_traversal_queue()
	assert state.unloads == 1
	assert traversable.has_been_destroyed() && document.has_been_destroyed()
	assert window.closed() && !native.is_closing()
}

fn test_canceled_overlapping_prompt_does_not_reset_a_close_already_appended_to_history() {
	mut traversable, mut document, window := prompted_close_fixture('https://prompted-close.example/overlap')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		prompted_close_restore_handler(snapshot)
		document.finalize()
	}
	state := &PromptedCloseObservation{}
	prompted_close_observe_unload(window, state)
	target := unsafe { &dom.EventTarget(window) }
	target.set_event_handler_attribute('beforeunload', &dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observation := unsafe { &PromptedCloseObservation(state) }
			observation.before_unloads++
			if observation.before_unloads == 1 {
				return dom.js_undefined()
			}
			return dom.js_string('cancel only this later prompted attempt')
		}
	})
	prompted_close_set_handler(.dismiss)
	traversable.close_top_level_traversable()
	// Source's outer re-entrancy guard ignores this additional ordinary close.
	traversable.close_top_level_traversable()
	traversable.definitely_close_top_level_traversable()
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert state.before_unloads == 1
	assert traversable.close_steps_have_been_appended_
	assert traversable.traversal_queue_.queue.len == 1
	event_loop.process()
	assert state.before_unloads == 2 && state.unloads == 0
	assert traversable.is_closing() && window.closed()
	assert traversable.close_steps_have_been_appended_
	assert traversable.traversal_queue_.queue.len == 1
	traversable.process_session_history_traversal_queue()
	assert state.unloads == 1
	assert traversable.has_been_destroyed() && document.has_been_destroyed()
}
