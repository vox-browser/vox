// Copyright (c) 2026, Ladybird contributors.
// SPDX-License-Identifier: BSD-2-Clause
module html

import dom
import webidl

fn (navigation &Navigation) owning_window() ?&WindowModel {
	document := navigation.associated_document_ or { return none }
	settings_handle := document.relevant_settings_object()
	if settings_handle == unsafe { nil } { return none }
	settings := unsafe { &EnvironmentSettingsObject(settings_handle) }
	global := settings.global_object()
	if global.data.kind != .window { return none }
	window := unsafe { &WindowModel(global) }
	if voidptr(window.navigation()) != voidptr(navigation) { return none }
	return window
}

fn (navigation &Navigation) promise_context() webidl.PromiseContext {
	window := navigation.owning_window() or { return webidl.PromiseContext{} }
	document := window.associated_document()
	return webidl.PromiseContext{
		realm_id:      u64(voidptr(window.scripting_realm_))
		job_scheduler: fn [document] (job fn ()) {
			queue_a_microtask(document, job)
		}
	}
}

fn (navigation &Navigation) navigation_abort_reason() dom.JSValue {
	return dom.js_webidl_value(webidl.dom_exception_value(webidl.DOMException.create('AbortError',
		'This navigation was aborted.')))
}

fn (navigation &Navigation) timestamp_navigation_event(event &dom.Event) {
	window := navigation.owning_window() or { return }
	settings := principal_realm_settings_object(window.scripting_realm_)
	mut base := unsafe { &dom.Event(event) }
	base.set_time_stamp(settings.global_relative_event_timestamp())
}

// Navigation.cpp:1260–1394 for the translated push/replace/reload paths.
// Traversal's asynchronous HistoryExecutor resume remains a separate boundary.
fn (mut navigation Navigation) finish_source_navigate_event(window &WindowModel, event &NavigateEvent,
	api_method_tracker ?&NavigationAPIMethodTracker) bool {
	document := window.associated_document()
	mut realm := window.scripting_realm_
	mut execution_context := TemporaryExecutionContext.create(mut realm, .yes)
	defer { execution_context.close() }
	end_result_is_same_document := event.interception_state() != .none
		|| event.destination().same_document()
	if event.interception_state() != .none {
		mut mutable_event := unsafe { &NavigateEvent(event) }
		mutable_event.set_interception_state(.committed)
		from := navigation.current_entry() or { panic('VERIFY(fromNHE != nullptr)') }
		context := navigation.promise_context()
		mut committed := dom.Promise.from_webidl(webidl.create_promise_for(context))
		mut finished := dom.Promise.from_webidl(webidl.create_promise_for(context))
		committed.mark_handled()
		finished.mark_handled()
		navigation.transition_ = NavigationTransition.create(event.navigation_type(), from,
			event.destination(), committed, finished)
		if event.navigation_type() in [.push, .replace] {
			perform_url_and_history_update_steps(document, event.destination().raw_url(),
				event.classic_history_api_state(), if event.navigation_type() == .push {
					.push
				} else {
					.replace
				}) or { panic(err) }
		}
		if event.navigation_type() == .reload {
			entry := window.navigable_model().active_session_history_entry() or {
				panic('VERIFY(active session history entry)')
			}
			navigation.update_the_navigation_api_entries_for_a_same_document_navigation(entry,
				.reload)
		}
	}
	event_was_intercepted := event.interception_state() != .none
	same_document_entry_update_will_run_commit_handler_steps := end_result_is_same_document
		&& !event_was_intercepted && event.navigation_type() in [.push, .replace]
	if end_result_is_same_document {
		if !same_document_entry_update_will_run_commit_handler_steps
			&& !event.has_started_navigate_event_intercept_commit_handler_steps() {
			navigation.run_the_navigate_event_intercept_commit_handler_steps(event,
				api_method_tracker)
		}
	} else if tracker := api_method_tracker {
		navigation.clean_up(tracker)
	}
	if transition := navigation.transition_ {
		mut committed := unsafe { &dom.Promise(transition.committed()) }
		committed.resolve(dom.js_undefined())
	}
	return event.interception_state() == .none
}

fn (navigation &Navigation) navigation_error_information(reason dom.JSValue) ErrorInformation {
	mut context := ErrorExtractionContext{}
	if window := navigation.owning_window() {
		if extract := window.scripting_realm_.error_extraction_context_ {
			context = extract(reason)
		}
	}
	return extract_error_information(reason, context)
}

fn (navigation &Navigation) dispatch_navigation_error(information ErrorInformation) {
	event := dom.ErrorEvent.create('navigateerror', dom.ErrorEventInit{
		message:  information.message
		filename: information.filename
		lineno:   u32(information.lineno)
		colno:    u32(information.colno)
		error:    information.error
	})
	target := unsafe { &dom.EventTarget(navigation) }
	base := unsafe { &dom.Event(event) }
	navigation.timestamp_navigation_event(base)
	target.dispatch_event(base)
}

// Navigation.cpp:971–1072. The zero-handler resolved Promise is deliberate:
// completion must still be a reaction job after currententrychange/dispose.
pub fn (mut navigation Navigation) run_the_navigate_event_intercept_commit_handler_steps(event &NavigateEvent,
	api_method_tracker ?&NavigationAPIMethodTracker) {
	assert !event.has_started_navigate_event_intercept_commit_handler_steps()
	mut mutable_event := unsafe { &NavigateEvent(event) }
	mutable_event.set_has_started_navigate_event_intercept_commit_handler_steps()
	window := navigation.owning_window() or { panic('VERIFY(relevant Window)') }
	context := navigation.promise_context()
	mut promises := []&webidl.Promise{}
	for callback in event.navigation_handler_list() {
		invocation := webidl.CallbackType{
			...callback
			operation_returns_promise: .yes
			promise_context:           context
		}
		promises << webidl.invoke_promise_callback(invocation, none, [])
	}
	if promises.len == 0 {
		promises << webidl.create_resolved_promise_for(context, webidl.undefined_value())
	}
	owner_handle := voidptr(&navigation)
	webidl.wait_for_all(promises, fn [event, window, owner_handle, api_method_tracker] (_ []webidl.Value) {
		mut owner := unsafe { &Navigation(owner_handle) }
		if !window.associated_document().is_fully_active() { return }
		controller := event.abort_controller() or { return }
		if controller.signal().aborted() { return }
		ongoing := owner.ongoing_navigate_event() or {
			panic('VERIFY(event == ongoing navigate event)')
		}
		assert voidptr(ongoing) == voidptr(event)
		owner.ongoing_navigate_event_ = none
		mut finished_event := unsafe { &NavigateEvent(event) }
		finished_event.finish(true) or { panic(err) }
		if tracker := api_method_tracker { owner.resolve_the_finished_promise(tracker) }
		success := dom.Event.create('navigatesuccess', dom.EventInit{})
		owner.timestamp_navigation_event(success)
		unsafe { &dom.EventTarget(owner) }.dispatch_event(success)
		if transition := owner.transition_ {
			mut promise := unsafe { &dom.Promise(transition.finished()) }
			promise.resolve(dom.js_undefined())
		}
		owner.transition_ = none
	}, fn [event, window, owner_handle] (reason webidl.Value) {
		mut owner := unsafe { &Navigation(owner_handle) }
		if !window.associated_document().is_fully_active() { return }
		controller := event.abort_controller() or { return }
		if controller.signal().aborted() { return }
		ongoing := owner.ongoing_navigate_event() or {
			panic('VERIFY(event == ongoing navigate event)')
		}
		assert voidptr(ongoing) == voidptr(event)
		original := dom.js_webidl_value(reason)
		if tracker := owner.ongoing_api_method_tracker_ {
			owner.reject_the_finished_promise(tracker, original)
		}
		if event.interception_state() != .intercepted {
			mut finished_event := unsafe { &NavigateEvent(event) }
			finished_event.finish(false) or { panic(err) }
		}
		owner.abort_a_navigate_event(event, original)
	})
}
