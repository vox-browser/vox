// Copyright (c) 2023, Andrew Kaster <akaster@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigateEvent.{h,cpp}.
module html

import dom

pub enum NavigationFocusReset {
	after_transition
	manual
}

pub enum NavigationScrollBehavior {
	after_transition
	manual
}

pub enum NavigateEventInterceptionState {
	none
	intercepted
	committed
	scrolled
	finished
}

pub type NavigationInterceptHandler = fn () !

pub struct NavigationInterceptOptions {
pub:
	handler     ?NavigationInterceptHandler
	focus_reset ?NavigationFocusReset
	scroll      ?NavigationScrollBehavior
}

pub struct NavigateEventInit {
	dom.EventInit
pub:
	navigation_type          dom.NavigationType     = .push
	destination              &NavigationDestination = unsafe { nil }
	can_intercept            bool
	user_initiated           bool
	hash_change              bool
	signal                   &dom.AbortSignal = unsafe { nil }
	form_data                ?&FormData
	download_request         ?string
	info                     dom.JSValue = dom.js_undefined()
	has_ua_visual_transition bool
	source_element           ?&dom.Element
	// The C++ object obtains this through its relevant Window. The V port has no
	// realm/global-object graph yet, so its embedding supplies that association.
	associated_document   ?&dom.Document
	fully_active_override ?bool
	navigation            ?&Navigation
}

@[heap]
pub struct NavigateEvent {
	dom.Event
mut:
	interception_state_        NavigateEventInterceptionState
	navigation_handler_list_   []NavigationInterceptHandler
	focus_reset_behavior_      ?NavigationFocusReset
	scroll_behavior_           ?NavigationScrollBehavior
	abort_controller_          ?&dom.AbortController
	classic_history_api_state_ ?SerializationRecord
	navigation_type_           dom.NavigationType
	destination_               &NavigationDestination
	can_intercept_             bool
	user_initiated_            bool
	hash_change_               bool
	signal_                    &dom.AbortSignal
	form_data_                 ?&FormData
	download_request_          ?string
	info_                      dom.JSValue
	has_ua_visual_transition_  bool
	source_element_            ?&dom.Element
	associated_document_       ?&dom.Document
	fully_active_override_     ?bool
	navigation_                 ?&Navigation
}

fn NavigateEvent.new(event_name string, event_init NavigateEventInit) !&NavigateEvent {
	if event_init.destination == unsafe { nil } {
		return error('NavigateEventInit.destination is required')
	}
	if event_init.signal == unsafe { nil } {
		return error('NavigateEventInit.signal is required')
	}
	return &NavigateEvent{
		Event:                     dom.Event{
			interface_:   .navigate_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			time_stamp_:  dom.current_event_timestamp()
		}
		navigation_type_:          event_init.navigation_type
		destination_:              event_init.destination
		can_intercept_:            event_init.can_intercept
		user_initiated_:           event_init.user_initiated
		hash_change_:              event_init.hash_change
		signal_:                   event_init.signal
		form_data_:                event_init.form_data
		download_request_:         event_init.download_request
		info_:                     event_init.info
		has_ua_visual_transition_: event_init.has_ua_visual_transition
		source_element_:           event_init.source_element
		associated_document_:      event_init.associated_document
		fully_active_override_:    event_init.fully_active_override
		navigation_:                event_init.navigation
	}
}

pub fn NavigateEvent.create(event_name string, event_init NavigateEventInit) !&NavigateEvent {
	mut event := NavigateEvent.new(event_name, event_init)!
	event.set_is_trusted(true)
	return event
}

pub fn NavigateEvent.construct_impl(event_name string, event_init NavigateEventInit) !&NavigateEvent {
	return NavigateEvent.new(event_name, event_init)
}

pub fn (event &NavigateEvent) navigation_type() dom.NavigationType {
	return event.navigation_type_
}

pub fn (event &NavigateEvent) destination() &NavigationDestination {
	return event.destination_
}

pub fn (event &NavigateEvent) can_intercept() bool {
	return event.can_intercept_
}

pub fn (event &NavigateEvent) user_initiated() bool {
	return event.user_initiated_
}

pub fn (event &NavigateEvent) hash_change() bool {
	return event.hash_change_
}

pub fn (event &NavigateEvent) signal() &dom.AbortSignal {
	return event.signal_
}

pub fn (event &NavigateEvent) form_data() ?&FormData {
	return event.form_data_
}

pub fn (event &NavigateEvent) download_request() ?string {
	return event.download_request_
}

pub fn (event &NavigateEvent) info() dom.JSValue {
	return event.info_
}

pub fn (event &NavigateEvent) has_ua_visual_transition() bool {
	return event.has_ua_visual_transition_
}

pub fn (event &NavigateEvent) source_element() ?&dom.Element {
	return event.source_element_
}

pub fn (event &NavigateEvent) interception_state() NavigateEventInterceptionState {
	return event.interception_state_
}

pub fn (event &NavigateEvent) navigation_handler_count() int {
	return event.navigation_handler_list_.len
}

pub fn (event &NavigateEvent) navigation_handler_list() []NavigationInterceptHandler {
	return event.navigation_handler_list_.clone()
}

pub fn (event &NavigateEvent) focus_reset_behavior() ?NavigationFocusReset {
	return event.focus_reset_behavior_
}

pub fn (event &NavigateEvent) scroll_behavior() ?NavigationScrollBehavior {
	return event.scroll_behavior_
}

pub fn (event &NavigateEvent) abort_controller() ?&dom.AbortController {
	return event.abort_controller_
}

pub fn (event &NavigateEvent) classic_history_api_state() ?SerializationRecord {
	return event.classic_history_api_state_
}

pub fn (mut event NavigateEvent) set_abort_controller(controller &dom.AbortController) {
	event.abort_controller_ = controller
}

pub fn (mut event NavigateEvent) set_interception_state(state NavigateEventInterceptionState) {
	event.interception_state_ = state
}

pub fn (mut event NavigateEvent) set_classic_history_api_state(state ?SerializationRecord) {
	event.classic_history_api_state_ = state
}

fn (event &NavigateEvent) associated_document_is_fully_active() bool {
	if value := event.fully_active_override_ {
		return value
	}
	document := event.associated_document_ or { return false }
	return document.is_fully_active()
}

fn (event &NavigateEvent) perform_shared_checks() ! {
	if !event.associated_document_is_fully_active() {
		return error('InvalidStateError: Document is not fully active')
	}
	if !event.is_trusted() {
		return error('SecurityError: NavigateEvent is not trusted')
	}
	if event.cancelled() {
		return error('InvalidStateError: NavigateEvent already cancelled')
	}
}

pub fn (mut event NavigateEvent) intercept(options NavigationInterceptOptions) ! {
	event.perform_shared_checks()!
	if !event.can_intercept_ {
		return error('SecurityError: NavigateEvent cannot be intercepted')
	}
	if !event.dispatched() {
		return error('InvalidStateError: NavigateEvent is not being dispatched')
	}
	if event.interception_state_ !in [.none, .intercepted] {
		return error('InvalidStateError: NavigateEvent interception has already committed')
	}
	event.interception_state_ = .intercepted
	if handler := options.handler {
		event.navigation_handler_list_ << handler
	}
	if focus_reset := options.focus_reset {
		event.focus_reset_behavior_ = focus_reset
	}
	if scroll := options.scroll {
		event.scroll_behavior_ = scroll
	}
}

// Navigation invokes these handlers after dispatch. Promise-returning WebIDL
// callbacks are represented as fallible V callbacks until a JS Promise runtime
// is available.
pub fn (event &NavigateEvent) run_navigation_handlers() ! {
	for handler in event.navigation_handler_list_ {
		handler()!
	}
}

pub fn (mut event NavigateEvent) mark_committed() ! {
	if event.interception_state_ != .intercepted {
		return error('InvalidStateError: only an intercepted navigation can be committed')
	}
	event.interception_state_ = .committed
}

fn (mut event NavigateEvent) process_scroll_behavior() {
	event.interception_state_ = .scrolled
	if event.navigation_type_ in [.traverse, .reload] {
		// Scroll-position restoration needs the traversable history-entry state.
		return
	}
	if document := event.associated_document_ {
		mut mutable_document := unsafe { &dom.Document(document) }
		// This re-determines the indicated part and handles the
		// top-of-document case itself.
		mutable_document.scroll_to_the_fragment()
	}
}

pub fn (mut event NavigateEvent) scroll() ! {
	event.perform_shared_checks()!
	if event.interception_state_ != .committed {
		return error('InvalidStateError: NavigateEvent is not committed')
	}
	event.process_scroll_behavior()
}

fn (mut event NavigateEvent) potentially_process_scroll_behavior() {
	if event.interception_state_ == .scrolled {
		return
	}
	if behavior := event.scroll_behavior_ {
		if behavior == .manual {
			return
		}
	}
	event.process_scroll_behavior()
}

pub fn (mut event NavigateEvent) potentially_reset_the_focus() {
	assert event.interception_state_ in [.committed, .scrolled]
	if navigation := event.navigation_ {
		focus_changed := navigation.focus_changed_during_ongoing_navigation()
		mut mutable_navigation := unsafe { &Navigation(navigation) }
		mutable_navigation.set_focus_changed_during_ongoing_navigation(false)
		if focus_changed {
			return
		}
	}
	if behavior := event.focus_reset_behavior_ {
		if behavior == .manual {
			return
		}
	}
	if document := event.associated_document_ {
		mut mutable_document := unsafe { &dom.Document(document) }
		if body := document.body() {
			mutable_document.set_focused_area(unsafe { &dom.Element(body) }.as_node())
		} else if document_element := document.document_element() {
			mutable_document.set_focused_area(document_element.as_node())
		}
	}
}

fn (mut event NavigateEvent) potentially_reset_focus() {
	event.potentially_reset_the_focus()
}

pub fn (mut event NavigateEvent) finish(did_fulfill bool) ! {
	if event.interception_state_ in [.intercepted, .finished] {
		return error('InvalidStateError: NavigateEvent cannot finish in its current state')
	}
	if event.interception_state_ == .none {
		return
	}
	event.potentially_reset_focus()
	if did_fulfill {
		event.potentially_process_scroll_behavior()
	}
	event.interception_state_ = .finished
}
