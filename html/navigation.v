// Copyright (c) 2023, Andrew Kaster <akaster@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Navigation.{h,cpp}. Navigable/traversable integration is
// exposed through hooks while those host objects remain outside this module.
module html

import dom
import webidl

pub enum NavigationHistoryBehavior {
	auto
	push
	replace
}

pub enum HistoryHandlingBehavior {
	push
	replace
}

pub fn to_history_handling_behavior(behavior NavigationHistoryBehavior) !HistoryHandlingBehavior {
	return match behavior {
		.push { .push }
		.replace { .replace }
		.auto { error('NavigationHistoryBehavior.auto has not been resolved') }
	}
}

pub fn to_navigation_history_behavior(behavior HistoryHandlingBehavior) NavigationHistoryBehavior {
	return match behavior {
		.push { .push }
		.replace { .replace }
	}
}

pub struct NavigationUpdateCurrentEntryOptions {
pub:
	state dom.JSValue = dom.js_undefined()
}

pub struct NavigationOptions {
pub:
	info ?dom.JSValue
}

pub struct NavigationNavigateOptions {
	NavigationOptions
pub:
	state   ?dom.JSValue
	history NavigationHistoryBehavior = .auto
}

pub struct NavigationReloadOptions {
	NavigationOptions
pub:
	state ?dom.JSValue
}

pub struct NavigationResult {
pub:
	committed &dom.Promise
	finished  &dom.Promise
}

pub type NavigationNavigateHook = fn(dom.URL, HistoryHandlingBehavior, SerializationRecord) !

pub type NavigationReloadHook = fn(SerializationRecord) !

pub type NavigationTraverseHook = fn(string) !

@[heap]
pub struct NavigationAPIMethodTracker {
pub mut:
	navigation         &Navigation = unsafe { nil }
	key                ?string
	info               dom.JSValue
	serialized_state   ?SerializationRecord
	committed_to_entry ?&NavigationHistoryEntry
	committed_promise  &dom.Promise = unsafe { nil }
	finished_promise   &dom.Promise = unsafe { nil }
}

fn NavigationAPIMethodTracker.create(navigation &Navigation, key ?string, info dom.JSValue, serialized_state ?SerializationRecord) &NavigationAPIMethodTracker {
	context := navigation.promise_context()
	mut finished := dom.Promise.from_webidl(webidl.create_promise_for(context))
	finished.mark_handled()
	return &NavigationAPIMethodTracker{
		navigation: navigation
		key: key
		info: info
		serialized_state: serialized_state
		committed_promise: dom.Promise.from_webidl(webidl.create_promise_for(context))
		finished_promise: finished
	}
}

@[heap]
pub struct Navigation {
	dom.EventTarget
mut:
	associated_document_                           ?&dom.Document
	entry_list_                                    []&NavigationHistoryEntry
	current_entry_index_                           i64 = -1
	transition_                                    ?&NavigationTransition
	ongoing_navigate_event_                        ?&NavigateEvent
	focus_changed_during_ongoing_navigation_       bool
	suppress_scroll_restoration_during_navigation_ bool
	ongoing_api_method_tracker_                    ?&NavigationAPIMethodTracker
	upcoming_non_traverse_api_method_tracker_      ?&NavigationAPIMethodTracker
	upcoming_traverse_api_method_trackers_         map[string]&NavigationAPIMethodTracker
	entries_and_events_disabled_override_          ?bool
	was_initial_about_blank_opened_                 bool
	navigate_hook_                                 ?NavigationNavigateHook
	reload_hook_                                   ?NavigationReloadHook
	traverse_hook_                                 ?NavigationTraverseHook
}

pub fn Navigation.create(document ?&dom.Document) &Navigation {
	return &Navigation{
		associated_document_: document
	}
}

pub fn (mut navigation Navigation) set_associated_document(document ?&dom.Document) {
	navigation.associated_document_ = document
}

pub fn (mut navigation Navigation) set_entries_and_events_disabled_override(value ?bool) {
	navigation.entries_and_events_disabled_override_ = value
}

pub fn (mut navigation Navigation) set_was_initial_about_blank_opened(value bool) {
	navigation.was_initial_about_blank_opened_ = value
}

pub fn (navigation &Navigation) was_initial_about_blank_opened() bool {
	return navigation.was_initial_about_blank_opened_
}

pub fn (mut navigation Navigation) set_navigate_hook(hook ?NavigationNavigateHook) {
	navigation.navigate_hook_ = hook
}

pub fn (mut navigation Navigation) set_reload_hook(hook ?NavigationReloadHook) {
	navigation.reload_hook_ = hook
}

pub fn (mut navigation Navigation) set_traverse_hook(hook ?NavigationTraverseHook) {
	navigation.traverse_hook_ = hook
}

pub fn (navigation &Navigation) entries() []&NavigationHistoryEntry {
	if navigation.has_entries_and_events_disabled() {
		return []
	}
	return navigation.entry_list_.clone()
}

pub fn (navigation &Navigation) current_entry() ?&NavigationHistoryEntry {
	if navigation.has_entries_and_events_disabled() || navigation.current_entry_index_ < 0 || navigation.current_entry_index_ >= navigation.entry_list_.len {
		return none
	}
	return navigation.entry_list_[navigation.current_entry_index_]
}

pub fn (navigation &Navigation) current_entry_index() i64 {
	return navigation.current_entry_index_
}

pub fn (navigation &Navigation) transition() ?&NavigationTransition {
	return navigation.transition_
}

pub fn (navigation &Navigation) ongoing_navigate_event() ?&NavigateEvent {
	return navigation.ongoing_navigate_event_
}

pub fn (navigation &Navigation) focus_changed_during_ongoing_navigation() bool {
	return navigation.focus_changed_during_ongoing_navigation_
}

pub fn (mut navigation Navigation) set_focus_changed_during_ongoing_navigation(value bool) {
	navigation.focus_changed_during_ongoing_navigation_ = value
}

pub fn (navigation &Navigation) suppress_scroll_restoration_during_ongoing_navigation() bool {
	return navigation.suppress_scroll_restoration_during_navigation_
}

pub fn (mut navigation Navigation) update_current_entry(options NavigationUpdateCurrentEntryOptions) ! {
	current := navigation.current_entry() or {
		return error('InvalidStateError: no current NavigationHistoryEntry')
	}
	serialized_state := structured_serialize_for_storage(options.state)!
	mut session_entry := unsafe { &SessionHistoryEntry(current.session_history_entry()) }
	session_entry.navigation_api_state = serialized_state
	change_event := NavigationCurrentEntryChangeEvent.construct_impl('currententrychange', NavigationCurrentEntryChangeEventInit{
		from: current
	})!
	target := unsafe { &dom.EventTarget(navigation) }
	base_event := unsafe { &dom.Event(change_event) }
	target.dispatch_event(base_event)
}

pub fn (navigation &Navigation) can_go_back() bool {
	return !navigation.has_entries_and_events_disabled() && navigation.current_entry_index_ > 0
}

pub fn (navigation &Navigation) can_go_forward() bool {
	return !navigation.has_entries_and_events_disabled() && navigation.current_entry_index_ >= 0 && navigation.current_entry_index_ < navigation.entry_list_.len - 1
}

pub fn (navigation &Navigation) has_entries_and_events_disabled() bool {
	if override := navigation.entries_and_events_disabled_override_ {
		return override
	}
	document := navigation.associated_document_ or { return true }
	return !document.is_fully_active() || document.get_is_initial_about_blank()
		|| document.origin().is_opaque() || navigation.was_initial_about_blank_opened_
}

pub fn (navigation &Navigation) get_the_navigation_api_entry_index(session_entry &SessionHistoryEntry) i64 {
	for index, entry in navigation.entry_list_ {
		if voidptr(entry.session_history_entry()) == voidptr(session_entry) {
			return i64(index)
		}
	}
	return -1
}

// An early error result for an exception is a pair of promises rejected with
// that exception.
pub fn (navigation &Navigation) early_error_result(message string) NavigationResult {
	reason := dom.js_string(message)
	return NavigationResult{
		committed: dom.Promise.rejected(reason)
		finished: dom.Promise.rejected(reason)
	}
}

fn navigation_api_method_tracker_derived_result(tracker &NavigationAPIMethodTracker) NavigationResult {
	return NavigationResult{
		committed: tracker.committed_promise
		finished: tracker.finished_promise
	}
}

pub fn (mut navigation Navigation) maybe_set_the_upcoming_non_traverse_api_method_tracker(info dom.JSValue, state ?SerializationRecord) &NavigationAPIMethodTracker {
	tracker := NavigationAPIMethodTracker.create(navigation, none, info, state)
	if !navigation.has_entries_and_events_disabled() {
		navigation.upcoming_non_traverse_api_method_tracker_ = tracker
	}
	return tracker
}

pub fn (mut navigation Navigation) add_an_upcoming_traverse_api_method_tracker(key string, info dom.JSValue) &NavigationAPIMethodTracker {
	tracker := NavigationAPIMethodTracker.create(navigation, key, info, none)
	navigation.upcoming_traverse_api_method_trackers_[key] = tracker
	return tracker
}

pub fn (mut navigation Navigation) promote_an_upcoming_api_method_tracker_to_ongoing(destination_key ?string) {
	if key := destination_key {
		if tracker := navigation.upcoming_traverse_api_method_trackers_[key] {
			navigation.ongoing_api_method_tracker_ = tracker
			navigation.upcoming_traverse_api_method_trackers_.delete(key)
		}
	} else {
		navigation.ongoing_api_method_tracker_ = navigation.upcoming_non_traverse_api_method_tracker_
		navigation.upcoming_non_traverse_api_method_tracker_ = none
	}
}

pub fn (mut navigation Navigation) clean_up(tracker &NavigationAPIMethodTracker) {
	if current := navigation.ongoing_api_method_tracker_ {
		if voidptr(current) == voidptr(tracker) {
			navigation.ongoing_api_method_tracker_ = none
			return
		}
	}
	if key := tracker.key {
		navigation.upcoming_traverse_api_method_trackers_.delete(key)
	}
}

pub fn (mut navigation Navigation) notify_about_the_committed_to_entry(tracker &NavigationAPIMethodTracker, entry &NavigationHistoryEntry) {
	mut mutable_tracker := unsafe { &NavigationAPIMethodTracker(tracker) }
	mutable_tracker.committed_to_entry = entry
	if state := tracker.serialized_state {
		mut session_entry := unsafe { &SessionHistoryEntry(entry.session_history_entry()) }
		session_entry.navigation_api_state = state
		mutable_tracker.serialized_state = none
	}
	mut committed := unsafe { &dom.Promise(tracker.committed_promise) }
	committed.resolve(dom.js_object(voidptr(entry)))
}

pub fn (mut navigation Navigation) resolve_the_finished_promise(tracker &NavigationAPIMethodTracker) {
	entry := tracker.committed_to_entry or { return }
	mut finished := unsafe { &dom.Promise(tracker.finished_promise) }
	finished.resolve(dom.js_object(voidptr(entry)))
	navigation.clean_up(tracker)
}

pub fn (mut navigation Navigation) reject_the_finished_promise(tracker &NavigationAPIMethodTracker, reason dom.JSValue) {
	mut committed := unsafe { &dom.Promise(tracker.committed_promise) }
	mut finished := unsafe { &dom.Promise(tracker.finished_promise) }
	committed.reject(reason)
	finished.reject(reason)
	navigation.clean_up(tracker)
}

fn navigation_urls_equal_excluding_fragment(left dom.URL, right dom.URL) bool {
	mut left_copy := left
	mut right_copy := right
	left_copy.set_fragment(none)
	right_copy.set_fragment(none)
	return left_copy == right_copy
}

fn navigation_url_fragments_identical(left dom.URL, right dom.URL) bool {
	left_fragment := left.fragment()
	right_fragment := right.fragment()
	if value := left_fragment {
		if other := right_fragment {
			return value == other
		}
		return false
	}
	return right_fragment == none
}

fn (navigation &Navigation) can_rewrite_to(url dom.URL) bool {
	document := navigation.associated_document_ or { return false }
	return can_have_its_url_rewritten(document.url, url)
}

fn (mut navigation Navigation) inner_navigate_event_firing_algorithm(navigation_type dom.NavigationType, destination &NavigationDestination, user_involvement UserNavigationInvolvement, source_element ?&dom.Element, form_data_entries ?[]FormDataEntry, download_request ?string, classic_history_api_state ?SerializationRecord) bool {
	if navigation.ongoing_navigate_event_ != none {
		navigation.abort_the_ongoing_navigation(navigation.navigation_abort_reason())
	}
	if navigation.has_entries_and_events_disabled() {
		return true
	}
	destination_entry := destination.navigation_history_entry()
	destination_key := if entry := destination_entry { ?string(entry.key()) } else { none }
	navigation.promote_an_upcoming_api_method_tracker_to_ongoing(destination_key)
	tracker := navigation.ongoing_api_method_tracker_
	document := navigation.associated_document_ or { return true }
	abort_controller := dom.AbortController.construct_impl() or { return false }
	current_url := dom.URL{
		value: document.url_string()
	}
	mut form_data := ?&FormData(none)
	if entries := form_data_entries {
		form_data = FormData.create(entries)
	}
	mut info := dom.js_undefined()
	if method_tracker := tracker {
		info = method_tracker.info
		mut mutable_tracker := unsafe { &NavigationAPIMethodTracker(method_tracker) }
		mutable_tracker.info = dom.js_undefined()
	}
	mut event := NavigateEvent.create('navigate', NavigateEventInit{
		cancelable: navigation_type != .traverse || destination.same_document()
		navigation_type: navigation_type
		destination: destination
		can_intercept: navigation.can_rewrite_to(destination.raw_url()) && (destination.same_document() || navigation_type != .traverse)
		user_initiated: user_involvement != .none_
		hash_change: classic_history_api_state == none && destination.same_document() && navigation_urls_equal_excluding_fragment(destination.raw_url(), current_url) && !navigation_url_fragments_identical(destination.raw_url(), current_url)
		signal: abort_controller.signal()
		form_data: form_data
		download_request: download_request
		info: info
		source_element: source_element
		associated_document: document
		fully_active_override: !navigation.has_entries_and_events_disabled()
		navigation: navigation
	}) or { return false }
	event.set_abort_controller(abort_controller)
	event.set_classic_history_api_state(classic_history_api_state)
	navigation.ongoing_navigate_event_ = event
	navigation.focus_changed_during_ongoing_navigation_ = false
	navigation.suppress_scroll_restoration_during_navigation_ = false
	target := unsafe { &dom.EventTarget(navigation) }
	base_event := unsafe { &dom.Event(event) }
	navigation.timestamp_navigation_event(base_event)
	dispatch_result := target.dispatch_event(base_event)
	if !dispatch_result {
		if !abort_controller.signal().aborted() {
			navigation.abort_the_ongoing_navigation(navigation.navigation_abort_reason())
		}
		return false
	}
	if window := navigation.owning_window() {
		// Source intercepted traversal resumes through the Page HistoryExecutor,
		// which is not yet available in this translation. Preserve the existing
		// traversal and ordinary-navigation adapters until their separate source
		// slices are complete. Interception commits through actual history here.
		if navigation_type != .traverse && event.interception_state() != .none {
			return navigation.finish_source_navigate_event(window, event, tracker)
		}
	}
	if event.interception_state() == .intercepted {
		event.mark_committed() or {
			navigation.abort_the_ongoing_navigation(dom.js_string(err.msg()))
			return false
		}
		from_entry := navigation.current_entry()
		if from := from_entry {
			mut committed := dom.Promise.create()
			finished := dom.Promise.create()
			committed.resolve(dom.js_object(voidptr(destination)))
			navigation.transition_ = NavigationTransition.create(navigation_type, from, destination, committed, finished)
		}
		event.run_navigation_handlers() or {
			event.finish(false) or {}
			navigation.abort_a_navigate_event(event, dom.js_string(err.msg()))
			return false
		}
		event.finish(true) or {
			navigation.abort_a_navigate_event(event, dom.js_string(err.msg()))
			return false
		}
	}
	navigation.ongoing_navigate_event_ = none
	return true
}

pub fn (mut navigation Navigation) abort_the_ongoing_navigation(reason dom.JSValue) {
	event := navigation.ongoing_navigate_event_ or { return }
	navigation.focus_changed_during_ongoing_navigation_ = false
	navigation.suppress_scroll_restoration_during_navigation_ = false
	if event.dispatched() {
		mut mutable_event := unsafe { &NavigateEvent(event) }
		mutable_event.set_cancelled(true)
	}
	navigation.abort_a_navigate_event(event, reason)
}

pub fn (mut navigation Navigation) abort_a_navigate_event(event &NavigateEvent, reason dom.JSValue) {
	mut execution_context := ?&TemporaryExecutionContext(none)
	if window := navigation.owning_window() {
		mut realm := window.scripting_realm_
		execution_context = TemporaryExecutionContext.create(mut realm, .yes)
	}
	defer {
		if mut context := execution_context { context.close() }
	}
	// Abort listeners can synchronously start another navigation. Retire the
	// old event and its tracker before dispatching the signal.
	navigation.ongoing_navigate_event_ = none
	if tracker := navigation.ongoing_api_method_tracker_ {
		navigation.reject_the_finished_promise(tracker, reason)
	}
	if controller := event.abort_controller() {
		mut mutable_controller := unsafe { &dom.AbortController(controller) }
		if window := navigation.owning_window() {
			settings := principal_realm_settings_object(window.scripting_realm_)
			mutable_controller.abort_with_clock(reason, fn [settings] () f64 {
				return settings.global_relative_event_timestamp()
			})
		} else {
			mutable_controller.abort(reason)
		}
	}
	information := navigation.navigation_error_information(reason)
	navigation.dispatch_navigation_error(information)
	if transition := navigation.transition_ {
		mut committed := unsafe { &dom.Promise(transition.committed()) }
		mut finished := unsafe { &dom.Promise(transition.finished()) }
		committed.reject(reason)
		finished.reject(reason)
		navigation.transition_ = none
	}
}

fn (mut navigation Navigation) complete_navigation_tracker() {
	if tracker := navigation.ongoing_api_method_tracker_ {
		if current := navigation.current_entry() {
			navigation.notify_about_the_committed_to_entry(tracker, current)
			navigation.resolve_the_finished_promise(tracker)
		}
	}
	if transition := navigation.transition_ {
		mut finished := unsafe { &dom.Promise(transition.finished()) }
		finished.resolve(dom.js_undefined())
		navigation.transition_ = none
	}
	success_event := dom.Event.create('navigatesuccess', dom.EventInit{})
	unsafe { &dom.EventTarget(navigation) }
	.dispatch_event(success_event)
}

pub fn (mut navigation Navigation) navigate(url string, options NavigationNavigateOptions) NavigationResult {
	document := navigation.associated_document_ or {
		return navigation.early_error_result('InvalidStateError: Navigation has no associated Document')
	}

	url_record := dom.dom_url_parse(url, document.base_url(), 'UTF-8') or {
		return navigation.early_error_result('SyntaxError: invalid navigation URL')
	}
	if url_record.scheme() == 'javascript' {
		return navigation.early_error_result('NotSupportedError: Cannot navigate to a javascript: URL')
	}
	state_value := options.state or { dom.js_undefined() }
	serialized_state := structured_serialize_for_storage(state_value) or {
		return navigation.early_error_result(err.msg())
	}
	if navigation.has_entries_and_events_disabled() || document.get_unload_counter() > 0 {
		return navigation.early_error_result('InvalidStateError: Document is not active for navigation')
	}
	mut behavior := options.history
	if behavior == .auto {
		behavior = if navigation.current_entry_index_ < 0 { .replace } else { .push }
	}
	info := options.info or { dom.js_undefined() }
	tracker := navigation.maybe_set_the_upcoming_non_traverse_api_method_tracker(info, serialized_state)
	if hook := navigation.navigate_hook_ {
		history_behavior := to_history_handling_behavior(behavior) or {
			HistoryHandlingBehavior.replace
		}
		hook(url_record, history_behavior, serialized_state) or {
			navigation.reject_the_finished_promise(tracker, dom.js_string(err.msg()))
			return navigation_api_method_tracker_derived_result(tracker)
		}
	}
	same_document := navigation_urls_equal_excluding_fragment(url_record, dom.URL{
		value: document.url_string()
	})
	if !navigation.fire_a_push_replace_reload_navigate_event(if behavior == .push {
		.push} else {
		.replace}, url_record, same_document, .none_, none, none, serialized_state, none) {
		return navigation_api_method_tracker_derived_result(tracker)
	}
	new_entry := &SessionHistoryEntry{
		url: url_record
		document_state: &DocumentState{
			document: document
		}
		navigation_api_state: serialized_state
	}
	if navigation.current_entry_index_ < 0 {
		navigation.initialize_the_navigation_api_entries_for_a_new_document([
			new_entry,
		], new_entry)
	} else {
		navigation.update_the_navigation_api_entries_for_a_same_document_navigation(new_entry, if behavior == .push {
			.push
		} else {
			.replace
		})
	}
	navigation.complete_navigation_tracker()
	return navigation_api_method_tracker_derived_result(tracker)
}

pub fn (mut navigation Navigation) reload(options NavigationReloadOptions) NavigationResult {
	if navigation.has_entries_and_events_disabled() {
		return navigation.early_error_result('InvalidStateError: Document is not active for reload')
	}
	current := navigation.current_entry() or {
		return navigation.early_error_result('InvalidStateError: no current entry')
	}
	state := if value := options.state {
		structured_serialize_for_storage(value) or { return navigation.early_error_result(err.msg()) }
	} else {
		current.session_history_entry().navigation_api_state
	}
	tracker := navigation.maybe_set_the_upcoming_non_traverse_api_method_tracker(options.info or {
		dom.js_undefined()
	}, state)
	if hook := navigation.reload_hook_ {
		hook(state) or {
			navigation.reject_the_finished_promise(tracker, dom.js_string(err.msg()))
			return navigation_api_method_tracker_derived_result(tracker)
		}
	}
	if !navigation.fire_a_push_replace_reload_navigate_event(.reload, current.session_history_entry().url, true, .none_, none, none, state, none) {
		return navigation_api_method_tracker_derived_result(tracker)
	}
	navigation.update_the_navigation_api_entries_for_a_same_document_navigation(current.session_history_entry(), .reload)
	navigation.complete_navigation_tracker()
	return navigation_api_method_tracker_derived_result(tracker)
}

pub fn (mut navigation Navigation) perform_a_navigation_api_traversal(key string, options NavigationOptions) NavigationResult {
	current := navigation.current_entry() or {
		return navigation.early_error_result('InvalidStateError: no current entry')
	}
	if key == current.key() {
		value := dom.js_object(voidptr(current))
		return NavigationResult{
			committed: dom.Promise.resolved(value)
			finished: dom.Promise.resolved(value)
		}
	}
	if tracker := navigation.upcoming_traverse_api_method_trackers_[key] {
		return navigation_api_method_tracker_derived_result(tracker)
	}
	tracker := navigation.add_an_upcoming_traverse_api_method_tracker(key, options.info or { dom.js_undefined() })
	if hook := navigation.traverse_hook_ {
		hook(key) or {
			navigation.reject_the_finished_promise(tracker, dom.js_string(err.msg()))
			return navigation_api_method_tracker_derived_result(tracker)
		}
	}
	mut destination_entry := ?&NavigationHistoryEntry(none)
	for entry in navigation.entry_list_ {
		if entry.key() == key {
			destination_entry = entry
			break
		}
	}
	entry := destination_entry or {
		navigation.reject_the_finished_promise(tracker, dom.js_string('InvalidStateError: stale session history entry'))
		return navigation_api_method_tracker_derived_result(tracker)
	}

	if !navigation.fire_a_traverse_navigate_event(entry.session_history_entry(), .none_) {
		return navigation_api_method_tracker_derived_result(tracker)
	}
	navigation.update_the_navigation_api_entries_for_a_same_document_navigation(entry.session_history_entry(), .traverse)
	navigation.complete_navigation_tracker()
	return navigation_api_method_tracker_derived_result(tracker)
}

pub fn (mut navigation Navigation) traverse_to(key string, options NavigationOptions) NavigationResult {
	if navigation.current_entry_index_ < 0 {
		return navigation.early_error_result('InvalidStateError: no current session history entry')
	}
	for entry in navigation.entry_list_ {
		if entry.session_history_entry().navigation_api_key == key {
			return navigation.perform_a_navigation_api_traversal(key, options)
		}
	}
	return navigation.early_error_result('InvalidStateError: key not found in session history list')
}

pub fn (mut navigation Navigation) back(options NavigationOptions) NavigationResult {
	if !navigation.can_go_back() {
		return navigation.early_error_result('InvalidStateError: no previous session history entry')
	}
	return navigation.perform_a_navigation_api_traversal(navigation.entry_list_[navigation.current_entry_index_ - 1].key(), options)
}

pub fn (mut navigation Navigation) forward(options NavigationOptions) NavigationResult {
	if !navigation.can_go_forward() {
		return navigation.early_error_result('InvalidStateError: no next session history entry')
	}
	return navigation.perform_a_navigation_api_traversal(navigation.entry_list_[navigation.current_entry_index_ + 1].key(), options)
}

pub fn (mut navigation Navigation) fire_a_traverse_navigate_event(destination_session_entry &SessionHistoryEntry, user_involvement UserNavigationInvolvement) bool {
	mut destination := NavigationDestination.create()
	destination.set_url(destination_session_entry.url)
	for entry in navigation.entry_list_ {
		if entry.session_history_entry() == destination_session_entry {
			destination.set_entry(entry)
			destination.set_state(destination_session_entry.navigation_api_state)
			break
		}
	}
	if destination.navigation_history_entry() == none {
		destination.set_state(structured_serialize_for_storage(dom.js_null()) or {
			SerializationRecord{}
		})
	}
	document := navigation.associated_document_
	destination.set_is_same_document(if associated := document {
		if state := destination_session_entry.document_state {
			if document_id := state.document_id() {
				document_id == associated.unique_id()
			} else {
				false
			}
		} else {
			false
		}
	} else {
		false
	})
	return navigation.inner_navigate_event_firing_algorithm(.traverse, destination, user_involvement, none, none, none, none)
}

pub fn (mut navigation Navigation) fire_a_push_replace_reload_navigate_event(navigation_type dom.NavigationType, destination_url dom.URL, is_same_document bool, user_involvement UserNavigationInvolvement, source_element ?&dom.Element, form_data_entries ?[]FormDataEntry, navigation_api_state ?SerializationRecord, classic_history_api_state ?SerializationRecord) bool {
	state := navigation_api_state or {
		structured_serialize_for_storage(dom.js_null()) or { SerializationRecord{} }
	}

	if is_same_document && navigation.ongoing_navigate_event_ != none {
		navigation.abort_the_ongoing_navigation(navigation.navigation_abort_reason())
	}
	mut destination := NavigationDestination.create()
	destination.set_url(destination_url)
	destination.set_state(state)
	destination.set_is_same_document(is_same_document)
	return navigation.inner_navigate_event_firing_algorithm(navigation_type, destination, user_involvement, source_element, form_data_entries, none, classic_history_api_state)
}

pub fn (mut navigation Navigation) fire_a_download_request_navigate_event(destination_url dom.URL, user_involvement UserNavigationInvolvement, source_element ?&dom.Element, filename string) bool {
	mut destination := NavigationDestination.create()
	destination.set_url(destination_url)
	destination.set_state(structured_serialize_for_storage(dom.js_null()) or {
		SerializationRecord{}
	})
	destination.set_is_same_document(false)
	return navigation.inner_navigate_event_firing_algorithm(.push, destination, user_involvement, source_element, none, filename, none)
}

pub fn (mut navigation Navigation) initialize_the_navigation_api_entries_for_a_new_document(new_session_entries []&SessionHistoryEntry, initial_session_entry &SessionHistoryEntry) {
	if navigation.entry_list_.len > 0 || navigation.current_entry_index_ != -1 {
		return
	}
	navigation.was_initial_about_blank_opened_ = false
	if navigation.has_entries_and_events_disabled() {
		return
	}
	for session_entry in new_session_entries {
		navigation.entry_list_ << NavigationHistoryEntry.create(session_entry, navigation.associated_document_)
	}
	navigation.refresh_entry_views()
	navigation.current_entry_index_ = navigation.get_the_navigation_api_entry_index(initial_session_entry)
}

fn (mut navigation Navigation) refresh_entry_views() {
	mut session_entries := []&SessionHistoryEntry{cap: navigation.entry_list_.len}
	for entry in navigation.entry_list_ {
		session_entries << entry.session_history_entry()
	}
	for entry in navigation.entry_list_ {
		mut mutable_entry := unsafe { &NavigationHistoryEntry(entry) }
		mutable_entry.set_navigation_entries(session_entries)
		mutable_entry.set_fully_active_override(!navigation.has_entries_and_events_disabled())
	}
}

pub fn (mut navigation Navigation) update_the_navigation_api_entries_for_a_same_document_navigation(destination_session_entry &SessionHistoryEntry, navigation_type dom.NavigationType) {
	if navigation.has_entries_and_events_disabled() {
		return
	}
	old_current := navigation.current_entry()
	mut disposed := []&NavigationHistoryEntry{}
	match navigation_type {
		.traverse {
			navigation.current_entry_index_ = navigation.get_the_navigation_api_entry_index(destination_session_entry)
			if navigation.current_entry_index_ < 0 {
				return
			}
		}
		.push {
			navigation.current_entry_index_++
			for i := int(navigation.current_entry_index_); i < navigation.entry_list_.len; i++ {
				disposed << navigation.entry_list_[i]
			}
			navigation.entry_list_ = navigation.entry_list_[..int(navigation.current_entry_index_)].clone()
		}
		.replace {
			if current := old_current {
				disposed << current
			}
		}
		.reload {}
	}
	if navigation_type in [.push, .replace] {
		new_entry := NavigationHistoryEntry.create(destination_session_entry, navigation.associated_document_)
		index := int(navigation.current_entry_index_)
		if index < navigation.entry_list_.len {
			navigation.entry_list_[index] = new_entry
		} else {
			navigation.entry_list_ << new_entry
		}
	}
	navigation.refresh_entry_views()
	if tracker := navigation.ongoing_api_method_tracker_ {
		if current := navigation.current_entry() {
			navigation.notify_about_the_committed_to_entry(tracker, current)
		}
	}
	navigate_event := navigation.ongoing_navigate_event_
	api_method_tracker := navigation.ongoing_api_method_tracker_
	mut execution_context := ?&TemporaryExecutionContext(none)
	if window := navigation.owning_window() {
		mut realm := window.scripting_realm_
		execution_context = TemporaryExecutionContext.create(mut realm, .yes)
	}
	defer {
		if mut context := execution_context { context.close() }
	}
	if from := old_current {
		change_event := NavigationCurrentEntryChangeEvent.construct_impl('currententrychange', NavigationCurrentEntryChangeEventInit{
			navigation_type: navigation_type
			from: from
		}) or { return }
		target := unsafe { &dom.EventTarget(navigation) }
		base_event := unsafe { &dom.Event(change_event) }
		navigation.timestamp_navigation_event(base_event)
		target.dispatch_event(base_event)
	}
	for entry in disposed {
		dispose_event := dom.Event.create('dispose', dom.EventInit{})
		navigation.timestamp_navigation_event(dispose_event)
		unsafe { &dom.EventTarget(entry) }
		.dispatch_event(dispose_event)
	}
	if event := navigate_event {
		if ongoing := navigation.ongoing_navigate_event_ {
			if voidptr(event) == voidptr(ongoing)
				&& !event.has_started_navigate_event_intercept_commit_handler_steps()
				&& navigation.owning_window() != none {
				navigation.run_the_navigate_event_intercept_commit_handler_steps(event, api_method_tracker)
			}
		}
	}
}

pub fn (navigation &Navigation) set_onnavigate(handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(navigation) }
	.set_event_handler_attribute('navigate', handler)
}

pub fn (navigation &Navigation) onnavigate() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(navigation) }.event_handler_attribute('navigate')
}

pub fn (navigation &Navigation) set_onnavigatesuccess(handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(navigation) }
	.set_event_handler_attribute('navigatesuccess', handler)
}

pub fn (navigation &Navigation) onnavigatesuccess() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(navigation) }.event_handler_attribute('navigatesuccess')
}

pub fn (navigation &Navigation) set_onnavigateerror(handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(navigation) }
	.set_event_handler_attribute('navigateerror', handler)
}

pub fn (navigation &Navigation) onnavigateerror() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(navigation) }.event_handler_attribute('navigateerror')
}

pub fn (navigation &Navigation) set_oncurrententrychange(handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(navigation) }
	.set_event_handler_attribute('currententrychange', handler)
}

pub fn (navigation &Navigation) oncurrententrychange() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(navigation) }.event_handler_attribute('currententrychange')
}
