module html

import dom
import webidl
import highresolutiontime

@[heap]
struct InterceptState {
mut:
	order             []string
	events            []&NavigateEvent
	promises          []&webidl.Promise
	successes         int
	errors            []dom.JSValue
	reentered         bool
	results           []NavigationResult
	error_information []ErrorInformation
	event_timestamps  []f64
}

fn source_navigation_owner() !(&dom.Document, &WindowModel, &Navigation) {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/start' })
	document.set_origin(document.url.origin())
	document.set_is_initial_about_blank(false)
	document.populate_with_html_head_and_body()!
	document.load_timing_info.navigation_start_time = highresolutiontime.unsafe_shared_current_time()
	window := WindowModel.create_top_level(document, none, 'intercept-owner')!
	mut navigation := unsafe { &Navigation(window.navigation()) }
	model := window.navigable_model()
	entry := model.active_session_history_entry() or { panic('actual active session entry') }
	navigation.initialize_the_navigation_api_entries_for_a_new_document(model.get_session_history_entries(),
		entry)
	assert !navigation.has_entries_and_events_disabled()
	return document, window, navigation
}

fn observe_source_interception(navigation &Navigation, state &InterceptState) {
	navigation.set_onnavigatesuccess(&dom.CallbackType{
		handle_event: fn [state] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &InterceptState(state) }
			observed.order << 'success'
			observed.successes++
			observed.event_timestamps << event.time_stamp()
			return dom.js_undefined()
		}
	})
	navigation.set_onnavigateerror(&dom.CallbackType{
		handle_event: fn [state] (base &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert base.interface_ == .error_event
			event := unsafe { &dom.ErrorEvent(base) }
			mut observed := unsafe { &InterceptState(state) }
			observed.order << 'error'
			observed.errors << event.error()
			observed.error_information << ErrorInformation{
				message:  event.message()
				filename: event.filename()
				lineno:   uint(event.lineno())
				colno:    uint(event.colno())
				error:    event.error()
			}
			return dom.js_undefined()
		}
	})
	navigation.set_oncurrententrychange(&dom.CallbackType{
		handle_event: fn [state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &InterceptState(state) }
			observed.order << 'change'
			return dom.js_undefined()
		}
	})
}

fn install_pending_source_handler(navigation &Navigation, state &InterceptState) {
	context := navigation.promise_context()
	navigation.set_onnavigate(&dom.CallbackType{
		handle_event: fn [state, context] (base &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut event := unsafe { &NavigateEvent(base) }
			mut observed := unsafe { &InterceptState(state) }
			observed.order << 'navigate'
			observed.events << event
			pending := webidl.create_promise_for(context)
			observed.promises << pending
			event.intercept(NavigationInterceptOptions{
				focus_reset: .manual
				scroll:      .manual
				callback:    webidl.CallbackType{
					callback: fn [state, pending] (receiver webidl.Value, arguments []webidl.Value) !webidl.Value {
						assert receiver.kind == .undefined
						assert arguments.len == 0
						mut invoked := unsafe { &InterceptState(state) }
						invoked.order << 'handler'
						return webidl.promise_value(pending)
					}
				}
			}) or { panic(err) }
			return dom.js_undefined()
		}
	})
}

fn test_interception_commits_actual_history_before_awaiting_owned_handler() {
	document, window, mut navigation := source_navigation_owner()!
	state := &InterceptState{}
	observe_source_interception(navigation, state)
	install_pending_source_handler(navigation, state)
	initial := window.navigable_model().active_session_history_entry() or { panic('initial') }
	result := navigation.navigate('/next', NavigationNavigateOptions{
		history: .push
		state:   dom.js_number(42)
	})
	assert document.url.serialize() == 'https://example.test/next'
	actual := window.navigable_model().active_session_history_entry() or { panic('actual') }
	assert voidptr(actual) != voidptr(initial)
	assert voidptr(navigation.current_entry()?.session_history_entry()) == voidptr(actual)
	assert navigation.current_entry()?.get_state()!.number_data == 42
	assert state.order == ['navigate', 'change', 'handler']
	assert state.events[0].time_stamp() >= 0 && state.events[0].time_stamp() < 10000
	assert result.committed.state() == .fulfilled && result.finished.state() == .pending
	assert webidl.promise_realm(result.finished.webidl_promise()?) == u64(voidptr(window.scripting_realm_))
	assert state.events[0].interception_state() == .committed
	assert state.events[0].has_started_navigate_event_intercept_commit_handler_steps()
	transition := navigation.transition() or { panic('transition') }
	assert transition.finished().state() == .pending
	mut pending := state.promises[0]
	pending.resolve(webidl.undefined_value())
	perform_a_microtask_checkpoint()
	assert state.order == ['navigate', 'change', 'handler', 'success']
	assert state.event_timestamps.len == 1 && state.event_timestamps[0] >= 0
	assert state.event_timestamps[0] < 10000
	assert result.finished.state() == .fulfilled
	assert transition.finished().state() == .fulfilled
	assert navigation.ongoing_navigate_event() == none && navigation.transition() == none
	assert state.events[0].interception_state() == .finished
}

fn test_interception_rejection_retains_actual_dom_exception_record() {
	_, _, mut navigation := source_navigation_owner()!
	state := &InterceptState{}
	observe_source_interception(navigation, state)
	install_pending_source_handler(navigation, state)
	result := navigation.navigate('/failure', NavigationNavigateOptions{ history: .replace })
	transition := navigation.transition() or { panic('transition') }
	record := webidl.DOMException.create_record('InvalidStateError', 'original handler failure')
	reason := webidl.dom_exception_value_for_record(record)
	mut pending := state.promises[0]
	pending.reject(reason)
	perform_a_microtask_checkpoint()
	assert state.errors.len == 1 && state.successes == 0
	assert voidptr(state.errors[0].as_webidl_value()!.dom_exception_?) == voidptr(record)
	assert voidptr(result.finished.result().as_webidl_value()!.dom_exception_?) == voidptr(record)
	assert voidptr(transition.finished().result().as_webidl_value()!.dom_exception_?) == voidptr(record)
	assert result.committed.state() == .fulfilled && result.finished.state() == .rejected
	assert state.events[0].interception_state() == .finished
	assert navigation.ongoing_navigate_event() == none && navigation.transition() == none
}

fn test_interception_supersession_aborts_old_wait_without_settling_new_tracker() {
	_, _, mut navigation := source_navigation_owner()!
	state := &InterceptState{}
	observe_source_interception(navigation, state)
	install_pending_source_handler(navigation, state)
	first := navigation.navigate('/first', NavigationNavigateOptions{ history: .push })
	second := navigation.navigate('/second', NavigationNavigateOptions{ history: .push })
	assert first.finished.state() == .rejected && second.finished.state() == .pending
	assert state.events[0].signal().aborted() && !state.events[1].signal().aborted()
	assert state.errors.len == 1
	assert voidptr(first.finished.result().as_webidl_value()!.dom_exception_?) == voidptr(state.events[0].signal().abort_reason.as_webidl_value()!.dom_exception_?)
	mut stale := state.promises[0]
	stale.resolve(webidl.undefined_value())
	perform_a_microtask_checkpoint()
	assert second.finished.state() == .pending && state.successes == 0
	assert voidptr(navigation.ongoing_navigate_event()?) == voidptr(state.events[1])
	mut current := state.promises[1]
	current.resolve(webidl.undefined_value())
	perform_a_microtask_checkpoint()
	assert second.finished.state() == .fulfilled && state.successes == 1
}

fn test_interception_completion_checks_actual_document_activity() {
	document, window, mut navigation := source_navigation_owner()!
	state := &InterceptState{}
	observe_source_interception(navigation, state)
	install_pending_source_handler(navigation, state)
	result := navigation.navigate('/pending', NavigationNavigateOptions{ history: .push })
	mut model := unsafe { &NavigableModel(window.navigable_model()) }
	model.set_active_document(none)
	assert !document.is_fully_active()
	mut pending := state.promises[0]
	pending.resolve(webidl.undefined_value())
	perform_a_microtask_checkpoint()
	assert result.finished.state() == .pending && state.successes == 0
	assert state.events[0].interception_state() == .committed
	assert navigation.ongoing_navigate_event() != none
}

fn test_interception_currententrychange_reentrancy_keeps_captured_event_and_tracker() {
	document, _, mut navigation := source_navigation_owner()!
	state := &InterceptState{}
	observe_source_interception(navigation, state)
	install_pending_source_handler(navigation, state)
	owner_handle := voidptr(navigation)
	navigation.set_oncurrententrychange(&dom.CallbackType{
		handle_event: fn [state, owner_handle] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &InterceptState(state) }
			observed.order << 'change'
			if !observed.reentered {
				observed.reentered = true
				mut owner := unsafe { &Navigation(owner_handle) }
				observed.results << owner.navigate('/reentrant', NavigationNavigateOptions{
					history: .push
				})
			}
			return dom.js_undefined()
		}
	})
	first := navigation.navigate('/first', NavigationNavigateOptions{ history: .push })
	assert first.committed.state() == .fulfilled && first.finished.state() == .rejected
	assert state.results.len == 1 && state.results[0].finished.state() == .pending
	assert document.url.serialize() == 'https://example.test/reentrant'
	assert state.events[0].signal().aborted() && !state.events[1].signal().aborted()
	// Pinned source fallback still invokes the old handler when entry-update
	// reentrancy prevented its start; its completion is suppressed by abort.
	assert state.order.filter(it == 'handler').len == 2
	mut old := state.promises[0]
	old.resolve(webidl.undefined_value())
	perform_a_microtask_checkpoint()
	assert state.results[0].finished.state() == .pending && state.successes == 0
	mut current := state.promises[1]
	current.resolve(webidl.undefined_value())
	perform_a_microtask_checkpoint()
	assert state.results[0].finished.state() == .fulfilled && state.successes == 1
}

fn test_interception_zero_handlers_waits_for_a_reaction_after_change_and_dispose() {
	_, window, mut navigation := source_navigation_owner()!
	state := &InterceptState{}
	observe_source_interception(navigation, state)
	initial := navigation.current_entry() or { panic('initial') }
	initial.set_ondispose(&dom.CallbackType{
		handle_event: fn [state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &InterceptState(state) }
			observed.order << 'dispose'
			return dom.js_undefined()
		}
	})
	navigation.set_onnavigate(&dom.CallbackType{
		handle_event: fn [state] (base &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut event := unsafe { &NavigateEvent(base) }
			mut observed := unsafe { &InterceptState(state) }
			observed.order << 'navigate'
			observed.events << event
			event.intercept(NavigationInterceptOptions{ focus_reset: .manual, scroll: .manual }) or {
				panic(err)
			}
			return dom.js_undefined()
		}
	})
	mut realm := window.scripting_realm_
	mut author_context := TemporaryExecutionContext.create(mut realm, .yes)
	result := navigation.navigate('/replaced', NavigationNavigateOptions{ history: .replace })
	assert state.order == ['navigate', 'change', 'dispose']
	assert result.committed.state() == .fulfilled && result.finished.state() == .pending
	assert state.events[0].has_started_navigate_event_intercept_commit_handler_steps()
	author_context.close()
	assert state.order == ['navigate', 'change', 'dispose', 'success']
	assert result.finished.state() == .fulfilled
}

fn test_interception_throw_becomes_owned_rejection_with_source_error_information() {
	_, mut window, mut navigation := source_navigation_owner()!
	state := &InterceptState{}
	observe_source_interception(navigation, state)
	record := webidl.DOMException.create_record('OperationError', 'original synchronous throw')
	reason := webidl.dom_exception_value_for_record(record)
	window.scripting_realm_.error_extraction_context_ = fn (_ dom.JSValue) ErrorExtractionContext {
		return ErrorExtractionContext{
			own_message:        'message from owning error extractor'
			exception_is_error: true
			traceback:          [
				ErrorSourceLocation{
					filename: 'handler.js'
					line:     17
					column:   4
				},
			]
		}
	}
	navigation.set_onnavigate(&dom.CallbackType{
		handle_event: fn [reason] (base &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut event := unsafe { &NavigateEvent(base) }
			event.intercept(NavigationInterceptOptions{
				focus_reset: .manual
				scroll:      .manual
				callback:    webidl.CallbackType{
					callback: fn [reason] (_ webidl.Value, _ []webidl.Value) !webidl.Value {
						return webidl.throw_value(reason)
					}
				}
			}) or { panic(err) }
			return dom.js_undefined()
		}
	})
	mut realm := window.scripting_realm_
	mut author_context := TemporaryExecutionContext.create(mut realm, .yes)
	result := navigation.navigate('/throw', NavigationNavigateOptions{ history: .replace })
	assert result.finished.state() == .pending && state.errors.len == 0
	author_context.close()
	assert result.committed.state() == .fulfilled && result.finished.state() == .rejected
	assert state.error_information.len == 1 && state.successes == 0
	info := state.error_information[0]
	assert info.message == 'message from owning error extractor'
	assert info.filename == 'handler.js' && info.lineno == 17 && info.colno == 4
	assert voidptr(info.error.as_webidl_value()!.dom_exception_?) == voidptr(record)
	assert voidptr(result.finished.result().as_webidl_value()!.dom_exception_?) == voidptr(record)
}

fn test_intercepted_reload_commits_existing_owned_history_entry_and_awaits_handler() {
	document, window, mut navigation := source_navigation_owner()!
	state := &InterceptState{}
	observe_source_interception(navigation, state)
	install_pending_source_handler(navigation, state)
	entry := window.navigable_model().active_session_history_entry() or { panic('actual entry') }
	result := navigation.reload(NavigationReloadOptions{})
	assert document.url.serialize() == 'https://example.test/start'
	assert voidptr(navigation.current_entry()?.session_history_entry()) == voidptr(entry)
	assert state.order == ['navigate', 'change', 'handler']
	assert result.committed.state() == .fulfilled && result.finished.state() == .pending
	assert state.events[0].navigation_type() == .reload
	mut pending := state.promises[0]
	pending.resolve(webidl.undefined_value())
	perform_a_microtask_checkpoint()
	assert state.order == ['navigate', 'change', 'handler', 'success']
	assert result.finished.state() == .fulfilled && state.successes == 1
}

fn test_interception_waits_for_every_owned_handler_without_finishing_on_first_fulfillment() {
	_, _, mut navigation := source_navigation_owner()!
	state := &InterceptState{}
	observe_source_interception(navigation, state)
	context := navigation.promise_context()
	navigation.set_onnavigate(&dom.CallbackType{
		handle_event: fn [state, context] (base &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut event := unsafe { &NavigateEvent(base) }
			mut observed := unsafe { &InterceptState(state) }
			observed.events << event
			for _ in 0 .. 2 {
				pending := webidl.create_promise_for(context)
				observed.promises << pending
				event.intercept(NavigationInterceptOptions{
					focus_reset: .manual
					scroll:      .manual
					callback:    webidl.CallbackType{
						callback: fn [pending] (_ webidl.Value, _ []webidl.Value) !webidl.Value {
							return webidl.promise_value(pending)
						}
					}
				}) or { panic(err) }
			}
			return dom.js_undefined()
		}
	})
	result := navigation.navigate('/all', NavigationNavigateOptions{ history: .push })
	mut second := state.promises[1]
	second.resolve(webidl.undefined_value())
	perform_a_microtask_checkpoint()
	assert result.finished.state() == .pending && state.successes == 0
	assert navigation.ongoing_navigate_event() != none
	mut first := state.promises[0]
	first.resolve(webidl.undefined_value())
	perform_a_microtask_checkpoint()
	assert result.finished.state() == .fulfilled && state.successes == 1
	assert navigation.ongoing_navigate_event() == none
}
