// Copyright (c) 2022, Andreas Kling <kling@ladybird.org>
// Copyright (c) 2023-2025, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of TraversableNavigable.{h,cpp}. The V representation owns the
// session-history graph directly and exposes host hooks for browsing-context,
// page-client, and beforeunload operations.
@[has_globals]
module html

import dom
import platform
import rand

__global html_user_agent_top_level_traversables = []&TraversableNavigable{}

pub fn user_agent_top_level_traversable_set() []&TraversableNavigable {
	return html_user_agent_top_level_traversables.clone()
}

pub fn create_a_new_top_level_browsing_context_and_document(page &dom.Page) !BrowsingContextAndDocument {
	created := BrowsingContextGroup.create_a_new_browsing_context_group_and_document(page)!
	return BrowsingContextAndDocument{
		browsing_context: browsing_context_model_for_native(created.browsing_context_group.browsing_context_set()[0])
		document: created.document
	}
}

pub enum HistoryStepResult {
	initiator_disallowed
	canceled_by_before_unload
	canceled_by_navigate
	applied
}

pub enum SynchronousNavigation {
	no
	yes
}

pub enum CheckIfUnloadingIsCanceledResult {
	canceled_by_before_unload
	canceled_by_navigate
	continue_
}

// HTML/ApplyHistoryStep.h: UnloadPromptShown.
pub enum UnloadPromptShown {
	no
	yes
}

pub struct HistoryObjectLengthAndIndex {
pub:
	script_history_length u64
	script_history_index  u64
}

pub struct EmulatedPositionData {
pub:
	latitude  f64
	longitude f64
	accuracy  f64
	error     ?string
}

@[heap]
pub struct TraversableStorageShed {
mut:
	values map[string]string
}

pub fn (mut shed TraversableStorageShed) set(storage_key string, key string, value string) {
	shed.values['${storage_key}\0${key}'] = value
}

pub fn (shed &TraversableStorageShed) get(storage_key string, key string) ?string {
	return shed.values['${storage_key}\0${key}']
}

pub type TraversableBeforeUnloadHook = fn([]&dom.Document) CheckIfUnloadingIsCanceledResult

pub type TraversableAppliedHook = fn(int, dom.NavigationType)

pub type TraversableScreenshotHook = fn(?u64)

pub type TraversableUnloadCompletion = fn (CheckIfUnloadingIsCanceledResult)

pub type TraversableUnloadCheckCompletion = fn (CheckIfUnloadingIsCanceledResult, UnloadPromptShown)

pub type TraversableHistoryStepCompletion = fn (HistoryStepResult)

@[heap]
pub struct TraversableNavigable {
mut:
	current_session_history_step_ int
	session_history_entries_      []&SessionHistoryEntry
	active_session_history_entry_ ?&SessionHistoryEntry
	legacy_current_session_history_entry_ ?&SessionHistoryEntry
	paused_apply_history_step_    ?&ApplyHistoryStepState
	apply_history_step_state_     ?&ApplyHistoryStepState
	system_visibility_state_      dom.VisibilityState = .hidden
	is_created_by_web_content_    bool
	close_steps_have_been_appended_ bool
	has_system_focus_             bool
	window_handle_                string
	active_document_              ?&dom.Document
	legacy_navigation_            ?&Navigation
	host_navigable_               ?&dom.Navigable
	traversal_queue_              &SessionHistoryTraversalQueue = unsafe { nil }
	storage_shed_                 &TraversableStorageShed = unsafe { nil }
	emulated_position_data_       EmulatedPositionData
	before_unload_hook_           ?TraversableBeforeUnloadHook
	applied_hook_                 ?TraversableAppliedHook
	screenshot_hook_              ?TraversableScreenshotHook
	screenshot_tasks_             []?u64
}

pub fn (traversable &TraversableNavigable) is_traversable() bool {
	_ = traversable
	return true
}

fn TraversableNavigable.new() &TraversableNavigable {
	traversable := &TraversableNavigable{
		window_handle_: rand.uuid_v4()
		traversal_queue_: &SessionHistoryTraversalQueue{}
		storage_shed_: &TraversableStorageShed{}
	}
	persistent := platform.enter_persistent()
	html_user_agent_top_level_traversables << traversable
	platform.leave_persistent(persistent)
	return traversable
}

pub fn TraversableNavigable.create_a_new_top_level_traversable(target_name string) !&TraversableNavigable {
	_ = target_name
	mut document := &dom.Document{}
	document.set_url(dom.url_about_blank())
	document.set_origin(dom.origin_create_opaque())
	state := &DocumentState{
		document: document
		document_id_: document.unique_id()
		origin: document.origin()
	}
	entry := &SessionHistoryEntry{
		step: 0
		url: dom.url_about_blank()
		document_state: state
	}
	mut traversable := TraversableNavigable.new()
	traversable.session_history_entries_ = [entry]
	traversable.active_session_history_entry_ = entry
	traversable.legacy_current_session_history_entry_ = entry
	traversable.active_document_ = document
	mut host_navigable := &dom.Navigable{
		is_top_level_traversable_: true
	}
	host_navigable.traversable_navigable_ = host_navigable
	host_navigable.set_active_document(document)
	traversable.host_navigable_ = host_navigable
	return traversable
}

pub fn TraversableNavigable.create_a_fresh_top_level_traversable(initial_navigation_url dom.URL, initial_resource DocumentResource) !&TraversableNavigable {
	mut traversable := TraversableNavigable.new()
	mut document := &dom.Document{}
	document.set_url(initial_navigation_url)
	document.set_origin(initial_navigation_url.origin())
	state := &DocumentState{
		document: document
		document_id_: document.unique_id()
		origin: document.origin()
		resource: initial_resource
		ever_populated: true
	}
	entry := &SessionHistoryEntry{
		step: 0
		url: initial_navigation_url
		document_state: state
	}
	traversable.session_history_entries_ = [entry]
	traversable.active_session_history_entry_ = entry
	traversable.legacy_current_session_history_entry_ = entry
	traversable.active_document_ = document
	mut host_navigable := &dom.Navigable{
		is_top_level_traversable_: true
	}
	host_navigable.traversable_navigable_ = host_navigable
	host_navigable.set_active_document(document)
	traversable.host_navigable_ = host_navigable
	return traversable
}

pub fn (traversable &TraversableNavigable) is_top_level_traversable() bool {
	host := traversable.host_navigable_ or { return true }
	return host.parent() == none
}

pub fn (traversable &TraversableNavigable) current_session_history_step() int {
	return traversable.current_session_history_step_
}

pub fn (traversable &TraversableNavigable) session_history_entries() []&SessionHistoryEntry {
	return traversable.session_history_entries_.clone()
}

pub fn (traversable &TraversableNavigable) active_session_history_entry() ?&SessionHistoryEntry {
	if model := traversable.local_navigable_model() {
		return model.active_session_history_entry()
	}
	return traversable.active_session_history_entry_
}

fn (traversable &TraversableNavigable) local_navigable_model() ?&NavigableModel {
	host := traversable.host_navigable_ or { return none }
	return navigable_model_for_host(host)
}

// Source LocalTraversable inherits the same current/active entry owner from
// LocalNavigable. Only the older bare-host constructors use these local slots.
pub fn (traversable &TraversableNavigable) current_session_history_entry() ?&SessionHistoryEntry {
	if model := traversable.local_navigable_model() {
		return model.current_session_history_entry()
	}
	return traversable.legacy_current_session_history_entry_
}

pub fn (mut traversable TraversableNavigable) set_current_session_history_entry(entry ?&SessionHistoryEntry) {
	if mut model := traversable.local_navigable_model() {
		model.set_current_session_history_entry(entry)
		return
	}
	traversable.legacy_current_session_history_entry_ = entry
}

pub fn (mut traversable TraversableNavigable) set_active_session_history_entry(entry ?&SessionHistoryEntry) {
	if mut model := traversable.local_navigable_model() {
		model.set_active_session_history_entry(entry)
		return
	}
	traversable.active_session_history_entry_ = entry
}

pub fn (traversable &TraversableNavigable) active_document() ?&dom.Document {
	if host := traversable.host_navigable_ {
		return host.active_document()
	}
	return traversable.active_document_
}

pub fn (traversable &TraversableNavigable) active_document_id() ?dom.UniqueNodeID {
	document := traversable.active_document() or { return none }
	return document.unique_id()
}

// LocalTraversable inherits LocalNavigable's actual active WindowProxy slot.
// The proxy and Window must be existing registered HTML identities.
pub fn (traversable &TraversableNavigable) active_window() ?&WindowModel {
	host := traversable.host_navigable_ or { return none }
	proxy := host.active_window_proxy() or { return none }
	return window_proxy_model_for_native(proxy).window()
}

pub fn (traversable &TraversableNavigable) running_nested_apply_history_step() bool {
	return traversable.paused_apply_history_step_ != none
}

pub fn (traversable &TraversableNavigable) system_visibility_state() dom.VisibilityState {
	return traversable.system_visibility_state_
}

pub fn (traversable &TraversableNavigable) is_created_by_web_content() bool {
	return traversable.is_created_by_web_content_
}

pub fn (mut traversable TraversableNavigable) set_is_created_by_web_content(value bool) {
	traversable.is_created_by_web_content_ = value
}

pub fn (traversable &TraversableNavigable) window_handle() string {
	return traversable.window_handle_
}

pub fn (mut traversable TraversableNavigable) set_window_handle(value string) {
	traversable.window_handle_ = value
}

pub fn (mut traversable TraversableNavigable) set_navigation(navigation ?&Navigation) {
	// Retain the old bare-host adapter. Actual Window owners supply Navigation.
	traversable.legacy_navigation_ = navigation
}

pub fn (mut traversable TraversableNavigable) set_host_navigable(navigable ?&dom.Navigable) {
	traversable.host_navigable_ = navigable
}

pub fn (mut traversable TraversableNavigable) set_before_unload_hook(hook ?TraversableBeforeUnloadHook) {
	traversable.before_unload_hook_ = hook
}

pub fn (mut traversable TraversableNavigable) set_applied_hook(hook ?TraversableAppliedHook) {
	traversable.applied_hook_ = hook
}

fn session_history_entry_step(entry &SessionHistoryEntry) ?int {
	return match entry.step {
		int { entry.step as int }
		SessionHistoryEntryPending { none }
	}
}

fn collect_steps_from_entries(entries []&SessionHistoryEntry, mut steps []int) {
	for entry in entries {
		if step := session_history_entry_step(entry) {
			if step !in steps {
				steps << step
			}
		}
		if state := entry.document_state {
			for nested in state.nested_histories {
				collect_steps_from_entries(nested.entries, mut steps)
			}
		}
	}
}

pub fn (traversable &TraversableNavigable) get_all_used_history_steps() []int {
	mut steps := []int{}
	collect_steps_from_entries(traversable.session_history_entries_, mut steps)
	steps.sort()
	return steps
}

pub fn (traversable &TraversableNavigable) get_the_history_object_length_and_index(step int) !HistoryObjectLengthAndIndex {
	steps := traversable.get_all_used_history_steps()
	index := steps.index(step)
	if index < 0 {
		return error('InvalidStateError: step is not used by this traversable')
	}
	return HistoryObjectLengthAndIndex{
		script_history_length: u64(steps.len)
		script_history_index: u64(index)
	}
}

pub fn (traversable &TraversableNavigable) get_the_used_step(step int) !int {
	steps := traversable.get_all_used_history_steps()
	mut result := ?int(none)
	for candidate in steps {
		if candidate <= step {
			result = candidate
		}
	}
	return result or { error('InvalidStateError: no used step is at or before target') }
}

fn target_history_entry(entries []&SessionHistoryEntry, target_step int) ?&SessionHistoryEntry {
	mut target := ?&SessionHistoryEntry(none)
	mut target_entry_step := -1
	for entry in entries {
		if step := session_history_entry_step(entry) {
			if step <= target_step && step >= target_entry_step {
				target = entry
				target_entry_step = step
			}
		}
	}
	return target
}

pub fn (traversable &TraversableNavigable) get_all_navigables_whose_current_session_history_entry_will_change_or_reload(target_step int) []&dom.Navigable {
	host := traversable.host_navigable_ or { return []&dom.Navigable{} }
	target := target_history_entry(traversable.session_history_entries_, target_step) or {
		return []&dom.Navigable{}
	}
	current := traversable.active_session_history_entry() or { target }
	reload_pending := if state := target.document_state { state.reload_pending } else { false }
	if voidptr(target) != voidptr(current) || reload_pending {
		return [host]
	}
	return []&dom.Navigable{}
}

pub fn (traversable &TraversableNavigable) get_all_navigables_that_only_need_history_object_length_index_update(target_step int) []&dom.Navigable {
	host := traversable.host_navigable_ or { return []&dom.Navigable{} }
	target := target_history_entry(traversable.session_history_entries_, target_step) or {
		return []&dom.Navigable{}
	}
	current := traversable.active_session_history_entry() or { target }
	reload_pending := if state := target.document_state { state.reload_pending } else { false }
	if voidptr(target) == voidptr(current) && !reload_pending {
		return [host]
	}
	return []&dom.Navigable{}
}

pub fn (traversable &TraversableNavigable) get_all_navigables_that_might_experience_a_cross_document_traversal(target_step int) []&dom.Navigable {
	host := traversable.host_navigable_ or { return []&dom.Navigable{} }
	target := target_history_entry(traversable.session_history_entries_, target_step) or {
		return []&dom.Navigable{}
	}
	reload_pending := if state := target.document_state { state.reload_pending } else { false }
	target_state := target.document_state or { return [host] }
	target_document_id := target_state.document_id() or { return [host] }
	active_document_id := traversable.active_document_id() or { return [host] }
	if target_document_id != active_document_id || reload_pending {
		return [host]
	}
	return []&dom.Navigable{}
}

pub fn (traversable &TraversableNavigable) get_session_history_entries_for_the_navigation_api(navigable &dom.Navigable, target_step int) []&SessionHistoryEntry {
	host := traversable.host_navigable_ or { return []&SessionHistoryEntry{} }
	if voidptr(host) != voidptr(navigable) || traversable.session_history_entries_.len == 0 {
		return []&SessionHistoryEntry{}
	}
	raw_entries := traversable.session_history_entries_
	mut starting_index := 0
	mut max_step := 0
	for index, entry in raw_entries {
		if step := session_history_entry_step(entry) {
			if step <= target_step && step > max_step {
				starting_index = index
				max_step = step
			}
		}
	}
	starting_state := raw_entries[starting_index].document_state or {
		return [raw_entries[starting_index]]
	}
	starting_origin := starting_state.origin
	mut result := [raw_entries[starting_index]]
	mut index := starting_index - 1
	for index > 0 {
		state := raw_entries[index].document_state or { break }
		if history_origins_differ(starting_origin, state.origin) {
			break
		}
		result.prepend(raw_entries[index])
		index--
	}
	index = starting_index + 1
	for index < raw_entries.len {
		state := raw_entries[index].document_state or { break }
		if history_origins_differ(starting_origin, state.origin) {
			break
		}
		result << raw_entries[index]
		index++
	}
	return result
}

fn history_origins_differ(first ?dom.Origin, second ?dom.Origin) bool {
	if left := first {
		if right := second {
			return !left.is_same_origin(right)
		}
	}
	return false
}

fn history_entry_origins_are_equal(first &SessionHistoryEntry, second &SessionHistoryEntry) bool {
	first_state := first.document_state or { panic('Source history entry requires its DocumentState') }
	second_state := second.document_state or { panic('Source history entry requires its DocumentState') }
	// URL::Origin::operator== calls is_same_origin. Optional equality also
	// distinguishes one absent origin from two absent origins.
	if left := first_state.origin {
		if right := second_state.origin {
			return left.is_same_origin(right)
		}
		return false
	}
	return second_state.origin == none
}

fn collect_documents_that_will_unload(entries []&SessionHistoryEntry, active &SessionHistoryEntry, target &SessionHistoryEntry) []&dom.Document {
	_ = entries
	mut documents := []&dom.Document{}
	active_document := active.document()
	target_document := target.document()
	if current := active_document {
		if destination := target_document {
			if current != destination {
				documents << current
			}
		} else {
			documents << current
		}
	}
	return documents
}

@[heap]
struct CheckUnloadingCanceledState {
mut:
	traversable         ?&TraversableNavigable
	documents           []&dom.Document
	target_entry        ?&SessionHistoryEntry
	user_involvement    ?UserNavigationInvolvement
	callback            TraversableUnloadCheckCompletion = unsafe { nil }
	final_status        CheckIfUnloadingIsCanceledResult = .continue_
	unload_prompt_shown UnloadPromptShown = .no
	needs_before_unload bool
	remaining_documents int
	completed           bool
	timeout_            &platform.Timer = unsafe { nil }
}

// CheckUnloadingCanceledState's Source constructor starts the deadline before
// either phase is queued. Platform.Timer owns the callback while active.
fn CheckUnloadingCanceledState.create(traversable ?&TraversableNavigable, documents []&dom.Document, target_entry ?&SessionHistoryEntry, user_involvement ?UserNavigationInvolvement, unload_prompt_shown UnloadPromptShown, callback TraversableUnloadCheckCompletion) &CheckUnloadingCanceledState {
	mut state := &CheckUnloadingCanceledState{
		traversable: traversable
		documents: documents.clone()
		target_entry: target_entry
		user_involvement: user_involvement
		unload_prompt_shown: unload_prompt_shown
		callback: callback
	}
	state.timeout_ = platform.Timer.create_single_shot(15000, fn [mut state] () {
		if !state.completed {
			eprintln('FIXME: check_if_unloading_is_canceled timed out')
			state.finish(.continue_)
		}
	})
	state.timeout_.start()
	return state
}

// LocalNavigable.cpp's actual local-Navigable input owner. The Document list
// is captured from each supplied native host when the check starts.
fn (mut state CheckUnloadingCanceledState) start_navigable_check(navigables []&dom.Navigable, target_entry ?&SessionHistoryEntry) {
	for navigable in navigables {
		// A pending child may not have committed its initial document yet.
		// Such hosts have no document that can cancel the unload.
		if navigable.has_been_destroyed() {
			continue
		}
		document := navigable.active_document() or { continue }
		if navigable_model_for_host(navigable) == none {
			panic('Source unload checks require actual local Navigable identities')
		}
		state.documents << document
	}
	if traversable := state.traversable {
		if state.user_involvement == none {
			panic('Source traversable unload check requires user involvement')
		}
		target := target_entry or { panic('Source traversable unload check requires a target entry') }
		state.target_entry = target
		current := traversable.current_session_history_entry() or {
			panic('Source traversable unload check requires its current entry')
		}
		if voidptr(target) != voidptr(current) && history_entry_origins_are_equal(target, current) {
			host := traversable.host_navigable_ or {
				panic('Source local Traversable requires its native Navigable')
			}
			state.needs_before_unload = navigables.any(voidptr(it) == voidptr(host))
			if state.needs_before_unload {
				active := traversable.active_document()
				for index, document in state.documents {
					if current_document := active {
						if voidptr(document) == voidptr(current_document) {
							state.documents.delete(index)
							break
						}
					}
				}
			}
			if traversable.active_window() == none {
				panic('Source native Traversable phase requires its active Window')
			}
			state.start_traverse_event_task()
			return
		}
	}
	state.start_document_tasks()
}

// Source's full check_if_unloading_is_canceled overload. Native hosts must
// belong to existing local NavigableModels; remote selection is caller-owned.
pub fn check_if_unloading_is_canceled(navigables []&dom.Navigable, traversable ?&TraversableNavigable, target_entry ?&SessionHistoryEntry, user_involvement ?UserNavigationInvolvement, unload_prompt_shown UnloadPromptShown, callback TraversableUnloadCheckCompletion) {
	mut state := CheckUnloadingCanceledState.create(traversable, [], none, user_involvement, unload_prompt_shown, callback)
	state.start_navigable_check(navigables, target_entry)
}

// V uses a distinct name for Source's result-only overload.
pub fn check_if_unloading_is_canceled_for_navigables(navigables []&dom.Navigable, callback TraversableUnloadCompletion) {
	check_if_unloading_is_canceled(navigables, none, none, none, .no, fn [callback] (result CheckIfUnloadingIsCanceledResult, _ UnloadPromptShown) {
		callback(result)
	})
}

fn (mut state CheckUnloadingCanceledState) finish(result CheckIfUnloadingIsCanceledResult) {
	if state.completed {
		return
	}
	state.completed = true
	state.timeout_.stop()
	state.callback(result, state.unload_prompt_shown)
}

fn (mut state CheckUnloadingCanceledState) document_task_completed() {
	state.remaining_documents--
	if state.remaining_documents == 0 {
		state.finish(state.final_status)
	}
}

fn (mut state CheckUnloadingCanceledState) start_document_tasks() {
	if state.documents.len == 0 {
		state.finish(state.final_status)
		return
	}
	state.remaining_documents = state.documents.len
	for document in state.documents {
		// Source's async state machine uses an always-runnable null-document
		// task and checks the retained Document's validity inside it.
		queue_a_task(.navigation_and_traversal, main_thread_event_loop(), none, fn [mut state, document] () {
			if document.has_been_destroyed() || !document.is_fully_active() {
				state.document_task_completed()
				return
			}
			mut mutable_document := unsafe { &dom.Document(document) }
			result := mutable_document.steps_to_fire_beforeunload(state.unload_prompt_shown == .yes)
			if result.unload_prompt_shown {
				state.unload_prompt_shown = .yes
			}
			if result.unload_prompt_canceled {
				state.final_status = .canceled_by_before_unload
			}
			state.document_task_completed()
		})
	}
}

fn (mut state CheckUnloadingCanceledState) start_traverse_event_task() {
	traversable := state.traversable or { panic('Source phase one requires its Traversable') }
	if window := traversable.active_window() {
		// The task keeps this global's queue-time associated Document. Its
		// steps re-read the inherited active Document and Window separately.
		queue_global_task(.navigation_and_traversal, unsafe { &dom.Window(window) }, fn [mut state] () {
			state.run_traverse_event_task(true)
		})
		return
	}
	// Existing bare-host constructors have no actual Window/global yet.
	active_document := traversable.active_document() or {
		state.start_document_tasks()
		return
	}
	queue_a_task(.navigation_and_traversal, main_thread_event_loop(), active_document, fn [mut state] () {
		state.run_traverse_event_task(false)
	})
}

fn (mut state CheckUnloadingCanceledState) run_traverse_event_task(actual_window_task bool) {
	traversable := state.traversable or { panic('Source phase one requires its Traversable') }
	if state.needs_before_unload {
		if current_active_document := traversable.active_document() {
			mut mutable_document := unsafe { &dom.Document(current_active_document) }
			result := mutable_document.steps_to_fire_beforeunload(false)
			if result.unload_prompt_shown {
				state.unload_prompt_shown = .yes
			}
			if result.unload_prompt_canceled {
				state.finish(.canceled_by_before_unload)
				return
			}
		} else if actual_window_task {
			panic('Source beforeunload phase requires its active Document')
		}
	}
	// Source reads the active Window again after beforeunload dispatch, whose
	// callbacks can change the actual WindowProxy's [[Window]].
	navigation := if actual_window_task {
		window := traversable.active_window() or {
			panic('Source traverse event phase requires its active Window')
		}
		?&Navigation(window.navigation())
	} else {
		traversable.legacy_navigation_
	}
	if owner := navigation {
		if target := state.target_entry {
			mut mutable_navigation := unsafe { &Navigation(owner) }
			user_involvement := state.user_involvement or {
				panic('Source traverse event phase requires user involvement')
			}
			if !mutable_navigation.fire_a_traverse_navigate_event(target, user_involvement) {
				state.finish(.canceled_by_navigate)
				return
			}
		} else if actual_window_task {
			panic('Source traverse event phase requires its target entry')
		}
	}
	state.start_document_tasks()
}

fn (traversable &TraversableNavigable) check_if_unloading_is_canceled_for_history_step(documents []&dom.Document, target &SessionHistoryEntry, user_involvement UserNavigationInvolvement, callback TraversableUnloadCompletion) {
	// Compatibility projection for the older local history-step continuation.
	// Source's actual UI history job carries the prompt flag separately.
	traversable.check_if_unloading_is_canceled_for_history_step_with_prompt(documents, target, user_involvement, .no, fn [callback] (result CheckIfUnloadingIsCanceledResult, _ UnloadPromptShown) {
		callback(result)
	})
}

fn (traversable &TraversableNavigable) check_if_unloading_is_canceled_for_history_step_with_prompt(documents []&dom.Document, target &SessionHistoryEntry, user_involvement UserNavigationInvolvement, unload_prompt_shown UnloadPromptShown, callback TraversableUnloadCheckCompletion) {
	mut state := CheckUnloadingCanceledState.create(traversable, documents, target, user_involvement, unload_prompt_shown, callback)
	if hook := traversable.before_unload_hook_ {
		queue_a_task(.navigation_and_traversal, main_thread_event_loop(), none, fn [hook, mut state] () {
			state.finish(hook(state.documents))
		})
		return
	}
	current := traversable.current_session_history_entry() or {
		state.start_document_tasks()
		return
	}
	if voidptr(target) != voidptr(current) && history_entry_origins_are_equal(target, current) {
		if active_document := traversable.active_document() {
			for index, document in state.documents {
				if voidptr(document) == voidptr(active_document) {
					state.documents.delete(index)
					state.needs_before_unload = true
					break
				}
			}
		}
		state.start_traverse_event_task()
		return
	}
	state.start_document_tasks()
}

pub fn (traversable &TraversableNavigable) check_if_unloading_is_canceled(documents []&dom.Document, callback TraversableUnloadCompletion) {
	// Source LocalNavigable.cpp's result-only overload initializes No and
	// explicitly projects the full completion pair to its first value.
	mut state := CheckUnloadingCanceledState.create(traversable, documents, none, .none_, .no, fn [callback] (result CheckIfUnloadingIsCanceledResult, _ UnloadPromptShown) {
		callback(result)
	})
	if hook := traversable.before_unload_hook_ {
		queue_a_task(.navigation_and_traversal, main_thread_event_loop(), none, fn [hook, mut state] () {
			state.finish(hook(state.documents))
		})
		return
	}
	state.start_document_tasks()
}

fn complete_history_step(callback ?TraversableHistoryStepCompletion, result HistoryStepResult) {
	if completion := callback {
		completion(result)
	}
}

@[heap]
struct HistoryStepContinuationState {
mut:
	traversable            &TraversableNavigable = unsafe { nil }
	used_step              int
	target                 &SessionHistoryEntry = unsafe { nil }
	source_snapshot_params ?&SourceSnapshotParams
	user_involvement       UserNavigationInvolvement
	navigation_type        dom.NavigationType
	on_complete            ?TraversableHistoryStepCompletion
}

fn (mut state HistoryStepContinuationState) resume(result CheckIfUnloadingIsCanceledResult) {
	match result {
		.canceled_by_before_unload {
			complete_history_step(state.on_complete, .canceled_by_before_unload)
		}
		.canceled_by_navigate {
			complete_history_step(state.on_complete, .canceled_by_navigate)
		}
		.continue_ {
			mut mutable_traversable := unsafe { &TraversableNavigable(state.traversable) }
			mutable_traversable.apply_the_history_step_after_unload_check(state.used_step,
				state.target, state.source_snapshot_params, state.user_involvement, state.navigation_type,
				.no, state.on_complete)
		}
	}
}

pub enum ApplyHistoryStepPhase {
	waiting_for_document_population
	processing_continuations
	waiting_for_change_job_completion
	waiting_for_non_changing_jobs
	completed
}

// The full engine has one continuation and one change job per changing
// navigable. This translation currently owns the top-level entry directly, but
// keeps the same event-driven phases so population, synchronous queue jumps,
// activation, and completion never spin the event loop.
@[heap]
struct ApplyHistoryStepState {
mut:
	phase                  ApplyHistoryStepPhase = .waiting_for_document_population
	traversable            &TraversableNavigable = unsafe { nil }
	used_step              int
	target                 &SessionHistoryEntry = unsafe { nil }
	source_snapshot_params ?&SourceSnapshotParams
	user_involvement       UserNavigationInvolvement
	navigation_type        dom.NavigationType
	synchronous_navigation SynchronousNavigation
	on_complete            ?TraversableHistoryStepCompletion
	continuation_ready     bool
	change_job_scheduled   bool
	changing               bool
	non_changing           bool
	waiting_navigables     []&dom.Navigable
	pending_sync_signal    ?&TraversalPromiseState
}

fn (mut state ApplyHistoryStepState) start() {
	state.phase = .waiting_for_document_population
	state.changing = state.traversable.get_all_navigables_whose_current_session_history_entry_will_change_or_reload(state.used_step).len > 0
	state.non_changing = state.traversable.get_all_navigables_that_only_need_history_object_length_index_update(state.used_step).len > 0
	if state.changing && state.synchronous_navigation == .yes {
		if host := state.traversable.host_navigable_ {
			if model := navigable_model_for_host(host) {
				// A synchronous same-document history step must not steal a
				// navigable that a fresh cross-document navigation has claimed.
				// Doing so would abort its navigate event and strand its deferred
				// navigation work.
				if model.ongoing_navigation().kind == .navigation {
					state.changing = false
				}
			}
		}
	}
	if !state.changing {
		state.phase = .waiting_for_non_changing_jobs
		state.enter_waiting_for_non_changing_jobs()
		return
	}
	if host := state.traversable.host_navigable_ {
		mut mutable_traversable := unsafe { &TraversableNavigable(state.traversable) }
		mutable_traversable.set_current_session_history_entry(state.target)
		if model := navigable_model_for_host(host) {
			mut mutable_model := unsafe { &NavigableModel(model) }
			mutable_model.set_ongoing_navigation(NavigableOngoingNavigation{
				kind: .traversal
			})
		}
	}
	queue_a_task(.navigation_and_traversal, main_thread_event_loop(), none, fn [mut state] () {
		state.populate_target_document_if_needed()
	})
}

fn (mut state ApplyHistoryStepState) document_population_completed() {
	state.continuation_ready = true
	state.phase = .processing_continuations
	state.process_continuations()
}

fn (mut state ApplyHistoryStepState) populate_target_document_if_needed() {
	document_state := state.target.document_state or {
		state.document_population_completed()
		return
	}
	if document_state.document != none && !document_state.reload_pending {
		state.document_population_completed()
		return
	}
	mut mutable_document_state := unsafe { &DocumentState(document_state) }
	if mutable_document_state.reload_pending {
		mutable_document_state.set_document(none)
	}
	mutable_document_state.reload_pending = false
	if host := state.traversable.host_navigable_ {
		if model := navigable_model_for_host(host) {
			active_document := state.traversable.active_document_ or {
				state.document_population_completed()
				return
			}
			source_snapshot_params := if source := state.source_snapshot_params {
				*source
			} else {
				snapshot_source_snapshot_params(active_document)
			}
			dom_user_involvement := match state.user_involvement {
				.browser_ui { dom.UserNavigationInvolvement.browser_ui }
				.activation { dom.UserNavigationInvolvement.activation }
				.none_ { dom.UserNavigationInvolvement.none }
			}
			mut mutable_model := unsafe { &NavigableModel(model) }
			mutable_model.populate_session_history_entry_document(state.target, source_snapshot_params,
				mutable_model.snapshot_target_snapshot_params(), dom_user_involvement, none, none,
				fn [mut state] () {
					state.document_population_completed()
				})
			return
		}
	}

	mut document := dom.Document.create(state.target.url)
	document.set_document_type(.html)
	document.set_content_type('text/html')
	document.set_origin(document_state.origin or { state.target.url.origin() })
	match document_state.resource {
		string {
			parse_html_from_a_string(document, document_state.resource as string)
		}
		else {
			document.populate_with_html_head_and_body() or {}
		}
	}
	mutable_document_state.set_document(document)
	mutable_document_state.ever_populated = true
	state.document_population_completed()
}

fn (mut state ApplyHistoryStepState) process_continuations() {
	if state.phase != .processing_continuations || !state.continuation_ready {
		return
	}
	if state.traversable.paused_apply_history_step_ == none {
		if entry := state.traversable.traversal_queue_.first_synchronous_navigation_steps_with_target_navigable_not_contained_in(state.waiting_navigables) {
			state.traversable.paused_apply_history_step_ = state
			signal := &TraversalPromiseState{}
			state.pending_sync_signal = signal
			mut mutable_signal := unsafe { &TraversalPromiseState(signal) }
			mutable_signal.when_settled(fn [mut state] () {
				state.pending_sync_signal = none
				state.traversable.apply_history_step_state_ = state
				state.traversable.paused_apply_history_step_ = none
				state.process_continuations()
			})
			entry.execute_steps(signal)
			return
		}
	}

	if state.change_job_scheduled {
		return
	}
	if host := state.traversable.host_navigable_ {
		state.waiting_navigables << host
	}
	state.change_job_scheduled = true
	state.phase = .waiting_for_change_job_completion
	queue_a_task(.navigation_and_traversal, main_thread_event_loop(), none, fn [mut state] () {
		state.commit_change_job()
	})
}

fn (mut state ApplyHistoryStepState) commit_change_job() {
	if state.phase != .waiting_for_change_job_completion {
		return
	}
	if displayed_document := state.traversable.active_document_ {
		if target_document := state.target.document() {
			if voidptr(displayed_document) != voidptr(target_document) {
				deactivate_a_document_for_cross_document_navigation(displayed_document,
					state.user_involvement, state.target, fn [mut state] () {
						state.commit_change_job_after_potential_unloads()
					})
				return
			}
		}
	}
	state.commit_change_job_after_potential_unloads()
}

fn (mut state ApplyHistoryStepState) commit_change_job_after_potential_unloads() {
	if state.phase != .waiting_for_change_job_completion {
		return
	}
	mut traversable := unsafe { &TraversableNavigable(state.traversable) }
	resolved_document := state.target.document()
	traversable.active_session_history_entry_ = state.target
	traversable.active_document_ = resolved_document
	if mut host := traversable.host_navigable_ {
		if model := navigable_model_for_host(host) {
			mut mutable_model := unsafe { &NavigableModel(model) }
			mutable_model.set_ongoing_navigation(NavigableOngoingNavigation{})
			if document := resolved_document {
				mutable_model.activate_history_entry(state.target, document)
			}
		} else {
			host.set_active_document(resolved_document)
		}
	}
	if document_state := state.target.document_state {
		mut mutable_document_state := unsafe { &DocumentState(document_state) }
		mutable_document_state.reload_pending = false
	}
	if document := resolved_document {
		position := traversable.get_the_history_object_length_and_index(state.used_step) or {
			HistoryObjectLengthAndIndex{}
		}
		dom_entry := &dom.SessionHistoryEntry{
			url: state.target.url
			classic_history_api_state: dom.DOMSerializationRecord{
				data: state.target.classic_history_api_state.data.clone()
			}
		}
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.update_for_history_step_application(dom_entry, state.synchronous_navigation == .yes,
			int(position.script_history_length), int(position.script_history_index), state.navigation_type)
	}
	state.phase = .waiting_for_non_changing_jobs
	state.enter_waiting_for_non_changing_jobs()
}

fn (mut state ApplyHistoryStepState) enter_waiting_for_non_changing_jobs() {
	if !state.non_changing {
		state.complete()
		return
	}
	state.non_changing = false
	queue_a_task(.navigation_and_traversal, main_thread_event_loop(), none, fn [mut state] () {
		position := state.traversable.get_the_history_object_length_and_index(state.used_step) or {
			state.complete()
			return
		}
		if document := state.traversable.active_document_ {
			mut mutable_document := unsafe { &dom.Document(document) }
			mutable_document.history().index = int(position.script_history_index)
			mutable_document.history().length = int(position.script_history_length)
		}
		state.complete()
	})
}

fn (mut state ApplyHistoryStepState) complete() {
	if state.phase == .completed {
		return
	}
	state.phase = .completed
	state.traversable.current_session_history_step_ = state.used_step
	state.traversable.apply_history_step_state_ = none
	if hook := state.traversable.applied_hook_ {
		hook(state.used_step, state.navigation_type)
	}
	complete_history_step(state.on_complete, .applied)
}

fn (mut traversable TraversableNavigable) apply_the_history_step_after_unload_check(used_step int, target &SessionHistoryEntry, source_snapshot_params ?&SourceSnapshotParams, user_involvement UserNavigationInvolvement, navigation_type dom.NavigationType, synchronous_navigation SynchronousNavigation, on_complete ?TraversableHistoryStepCompletion) {
	mut state := &ApplyHistoryStepState{
		traversable: traversable
		used_step: used_step
		target: target
		source_snapshot_params: source_snapshot_params
		user_involvement: user_involvement
		navigation_type: navigation_type
		synchronous_navigation: synchronous_navigation
		on_complete: on_complete
	}
	traversable.apply_history_step_state_ = state
	state.start()
}

fn (mut traversable TraversableNavigable) apply_the_history_step(step int, check_for_cancellation bool, source_snapshot_params ?&SourceSnapshotParams, initiator_to_check ?&dom.Navigable, user_involvement UserNavigationInvolvement, navigation_type dom.NavigationType, synchronous_navigation SynchronousNavigation, on_complete ?TraversableHistoryStepCompletion) {
	if traversable.has_been_destroyed() {
		complete_history_step(on_complete, .initiator_disallowed)
		return
	}
	used_step := traversable.get_the_used_step(step) or {
		complete_history_step(on_complete, .initiator_disallowed)
		return
	}

	// 3. If initiatorToCheck is not null, then:
	if initiator := initiator_to_check {
		// 1. Assert: sourceSnapshotParams is not null.
		// NB: A traversal with an initiator must also include its sandboxing state. Reject an incomplete request.
		snapshot := source_snapshot_params or {
			complete_history_step(on_complete, .initiator_disallowed)
			return
		}

		// 2. For each navigable of get all navigables whose current session history entry will change or reload: if
		//    initiatorToCheck is not allowed by sandboxing to navigate navigable given sourceSnapshotParams, then
		//    return "initiator-disallowed".
		initiator_model := navigable_model_for_host(initiator)
		for navigable in traversable.get_all_navigables_whose_current_session_history_entry_will_change_or_reload(used_step) {
			target_model := navigable_model_for_host(navigable) or { continue }
			// NB: A removed initiator is no longer related to any navigable in the tree. Apply the sandboxed
			//     navigation flag instead of treating the missing relationship as permission.
			allowed := if model := initiator_model {
				model.allowed_by_sandboxing_to_navigate(target_model, *snapshot)
			} else {
				!snapshot.sandboxing_flags.contains(.sandboxed_navigation)
			}
			if !allowed {
				complete_history_step(on_complete, .initiator_disallowed)
				return
			}
		}
	}

	target := target_history_entry(traversable.session_history_entries_, used_step) or {
		complete_history_step(on_complete, .initiator_disallowed)
		return
	}
	active := traversable.active_session_history_entry() or { target }
	if check_for_cancellation {
		documents := collect_documents_that_will_unload(traversable.session_history_entries_, active, target)
		mut continuation := &HistoryStepContinuationState{
			traversable: unsafe { &TraversableNavigable(voidptr(traversable)) }
			used_step: used_step
			target: target
			source_snapshot_params: source_snapshot_params
			user_involvement: user_involvement
			navigation_type: navigation_type
			on_complete: on_complete
		}
		traversable.check_if_unloading_is_canceled_for_history_step(documents, target, user_involvement, fn [mut continuation] (result CheckIfUnloadingIsCanceledResult) {
			continuation.resume(result)
		})
		return
	}
	traversable.apply_the_history_step_after_unload_check(used_step, target, source_snapshot_params,
		user_involvement, navigation_type, synchronous_navigation, on_complete)
}

pub fn (mut traversable TraversableNavigable) apply_the_traverse_history_step(step int, source_snapshot_params ?&SourceSnapshotParams, initiator_to_check ?&dom.Navigable, user_involvement UserNavigationInvolvement, on_complete ?TraversableHistoryStepCompletion) {
	traversable.apply_the_history_step(step, true, source_snapshot_params, initiator_to_check, user_involvement,
		.traverse, .no, on_complete)
}

pub fn (mut traversable TraversableNavigable) apply_the_reload_history_step(user_involvement UserNavigationInvolvement, on_complete ?TraversableHistoryStepCompletion) {
	traversable.apply_the_history_step(traversable.current_session_history_step_, true, none, none,
		user_involvement, .reload, .no, on_complete)
}

pub fn (mut traversable TraversableNavigable) apply_the_push_or_replace_history_step(step int, history_handling HistoryHandlingBehavior, user_involvement UserNavigationInvolvement, synchronous_navigation SynchronousNavigation, on_complete ?TraversableHistoryStepCompletion) {
	type_ := if history_handling == .replace {
		dom.NavigationType.replace
	} else {
		dom.NavigationType.push
	}
	traversable.apply_the_history_step(step, false, none, none, user_involvement, type_, synchronous_navigation,
		on_complete)
}

pub fn (mut traversable TraversableNavigable) update_for_navigable_creation_or_destruction(on_complete ?TraversableHistoryStepCompletion) {
	traversable.apply_the_history_step(traversable.current_session_history_step_, false, none, none,
		.none_, .traverse, .no, on_complete)
}

fn clear_forward_in_entries(entries []&SessionHistoryEntry, current_step int) []&SessionHistoryEntry {
	mut kept := []&SessionHistoryEntry{}
	for entry in entries {
		step := session_history_entry_step(entry) or { continue }
		if step > current_step {
			continue
		}
		if state := entry.document_state {
			mut mutable_state := unsafe { &DocumentState(state) }
			mut nested_histories := []NestedHistory{cap: state.nested_histories.len}
			for nested in state.nested_histories {
				nested_histories << NestedHistory{
					id: nested.id
					entries: clear_forward_in_entries(nested.entries, current_step)
				}
			}
			mutable_state.nested_histories = nested_histories
		}
		kept << entry
	}
	return kept
}

pub fn (mut traversable TraversableNavigable) clear_the_forward_session_history() {
	traversable.session_history_entries_ = clear_forward_in_entries(traversable.session_history_entries_, traversable.current_session_history_step_)
}

pub fn (traversable &TraversableNavigable) can_go_forward() bool {
	for step in traversable.get_all_used_history_steps() {
		if step > traversable.current_session_history_step_ {
			return true
		}
	}
	return false
}

pub fn (mut traversable TraversableNavigable) traverse_the_history_by_delta(delta int, source_document ?&dom.Document) {
	// 1. Let sourceSnapshotParams and initiatorToCheck be null.
	mut source_snapshot_params := ?&SourceSnapshotParams(none)
	mut initiator_to_check := ?&dom.Navigable(none)

	// 2. Let userInvolvement be "browser UI".
	mut user_involvement := UserNavigationInvolvement.browser_ui

	// 3. If sourceDocument is given, then:
	if document := source_document {
		// 1. Set sourceSnapshotParams to the result of snapshotting source snapshot params given sourceDocument.
		source_snapshot_params = &SourceSnapshotParams{
			...snapshot_source_snapshot_params(document)
		}

		// 2. Set initiatorToCheck to sourceDocument's node navigable.
		initiator_to_check = document.navigable()

		// 3. Set userInvolvement to "none".
		user_involvement = .none_
	}

	// 4. Append the following session history traversal steps to traversable:
	traversable_pointer := voidptr(traversable)
	traversable.append_session_history_traversal_steps(fn [delta, traversable_pointer, source_snapshot_params, initiator_to_check, user_involvement] (signal &TraversalPromiseState) {
		mut mutable_traversable := unsafe { &TraversableNavigable(traversable_pointer) }
		steps := mutable_traversable.get_all_used_history_steps()
		current_index := steps.index(mutable_traversable.current_session_history_step_)
		target_index := current_index + delta
		if current_index < 0 || target_index < 0 || target_index >= steps.len {
			signal.resolve()
			return
		}
		mutable_traversable.apply_the_traverse_history_step(steps[target_index], source_snapshot_params,
			initiator_to_check, user_involvement, fn [signal] (_ HistoryStepResult) {
				signal.resolve()
			})
	})
}

pub fn (mut traversable TraversableNavigable) append_session_history_traversal_steps(steps SessionHistoryTraversalSteps) {
	traversable.traversal_queue_.append(steps)
}

pub fn (mut traversable TraversableNavigable) append_session_history_synchronous_navigation_steps(target &dom.Navigable, steps SessionHistoryTraversalSteps) {
	traversable.traversal_queue_.append_sync(steps, target)
}

pub fn (mut traversable TraversableNavigable) process_session_history_traversal_queue() {
	traversable.traversal_queue_.process()
}

pub fn (mut traversable TraversableNavigable) close_top_level_traversable() {
	if traversable.is_closing() {
		return
	}
	// Prevent re-entrant close requests from scheduling duplicate destruction work.
	traversable.set_closing(true)
	traversable.definitely_close_top_level_traversable()
}

pub fn (mut traversable TraversableNavigable) definitely_close_top_level_traversable() {
	assert traversable.is_top_level_traversable()
	traversable_pointer := voidptr(traversable)
	completion := fn [traversable_pointer] (result CheckIfUnloadingIsCanceledResult) {
		mut mutable_traversable := unsafe { &TraversableNavigable(traversable_pointer) }
		if result != .continue_ {
			// A canceled prompted close may be retried unless another close has
			// already reached the history queue (LocalTraversableNavigable.cpp).
			if !mutable_traversable.close_steps_have_been_appended_ {
				mutable_traversable.set_closing(false)
			}
			return
		}
		if mutable_traversable.close_steps_have_been_appended_ {
			return
		}
		mutable_traversable.close_steps_have_been_appended_ = true
		mutable_traversable.append_session_history_traversal_steps(fn [traversable_pointer] (signal &TraversalPromiseState) {
			mut mutable_traversable := unsafe { &TraversableNavigable(traversable_pointer) }
			if document := mutable_traversable.active_document_ {
				mut mutable_document := unsafe { &dom.Document(document) }
				mutable_document.unload_a_document_and_its_descendants(none)
			}
			mutable_traversable.destroy_top_level_traversable()
			signal.resolve()
		})
	}
	if traversable.local_navigable_model() != none {
		// Source collects the actual active Document's local native Navigables
		// and calls the result-only overload, whose projection initializes No.
		document := traversable.active_document() or {
			panic('Source prompted close requires its active Document')
		}
		check_if_unloading_is_canceled_for_navigables(document.inclusive_descendant_navigables(), completion)
		return
	}
	// Older bare-host constructors lack real local models/Window/Page owners.
	// Preserve their existing Document-list and hook compatibility path.
	documents := if document := traversable.active_document_ {
		mut result := []&dom.Document{}
		for navigable in document.inclusive_descendant_navigables() {
			if active := navigable.active_document() {
				result << active
			}
		}
		result
	} else {
		[]&dom.Document{}
	}
	traversable.check_if_unloading_is_canceled(documents, completion)
}

// LocalTraversableNavigable.cpp: the UI has already unloaded descendants.
pub fn (mut traversable TraversableNavigable) run_ui_traversable_close_unload_task() {
	traversable_pointer := voidptr(traversable)
	queue_a_task(.navigation_and_traversal, none, none, fn [traversable_pointer] () {
		mut mutable_traversable := unsafe { &TraversableNavigable(traversable_pointer) }
		if document := mutable_traversable.active_document() {
			mut mutable_document := unsafe { &dom.Document(document) }
			mutable_document.unload()
		}
		mutable_traversable.destroy_top_level_traversable()
	})
}

pub fn (mut traversable TraversableNavigable) destroy_top_level_traversable() {
	if traversable.has_been_destroyed() {
		return
	}
	mut native := traversable.host_navigable_ or {
		panic('Source local Traversable requires its native Navigable')
	}
	native.set_has_been_destroyed()
	if host := traversable.host_navigable_ {
		if model := navigable_model_for_host(host) {
			mut mutable_model := unsafe { &NavigableModel(model) }
			mutable_model.remove_from_all_navigables()
		} else {
			mut mutable_host := unsafe { &dom.Navigable(host) }
			mutable_host.remove_from_all_navigables()
		}
	}
	traversable.active_document_ = none
	for index, candidate in html_user_agent_top_level_traversables {
		if voidptr(candidate) == voidptr(&traversable) {
			html_user_agent_top_level_traversables.delete(index)
			break
		}
	}
}

pub fn (traversable &TraversableNavigable) has_been_destroyed() bool {
	host := traversable.host_navigable_ or {
		panic('Source local Traversable requires its native Navigable')
	}
	return host.has_been_destroyed()
}

pub fn (traversable &TraversableNavigable) is_closing() bool {
	host := traversable.host_navigable_ or { panic('Source local traversable requires its native Navigable') }
	return host.is_closing()
}

pub fn (mut traversable TraversableNavigable) set_closing(value bool) {
	mut host := traversable.host_navigable_ or { panic('Source local traversable requires its native Navigable') }
	host.set_closing(value)
}

pub fn (mut traversable TraversableNavigable) set_has_system_focus(value bool) {
	traversable.has_system_focus_ = value
}

pub fn (traversable &TraversableNavigable) currently_focused_area() ?&dom.Node {
	if !traversable.has_system_focus_ {
		return none
	}
	document := traversable.active_document_ or { return none }
	return document.focused_area() or { unsafe { &dom.Node(document) } }
}

pub fn (mut traversable TraversableNavigable) set_system_visibility_state(state dom.VisibilityState) {
	if traversable.system_visibility_state_ == state {
		return
	}
	traversable.system_visibility_state_ = state
	if document := traversable.active_document_ {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.update_the_visibility_state(state)
	}
}

pub fn (traversable &TraversableNavigable) storage_shed() &TraversableStorageShed {
	return traversable.storage_shed_
}

pub fn (traversable &TraversableNavigable) emulated_position_data() EmulatedPositionData {
	return traversable.emulated_position_data_
}

pub fn (mut traversable TraversableNavigable) set_emulated_position_data(data EmulatedPositionData) {
	traversable.emulated_position_data_ = data
}

pub fn (mut traversable TraversableNavigable) set_screenshot_hook(hook ?TraversableScreenshotHook) {
	traversable.screenshot_hook_ = hook
}

pub fn (mut traversable TraversableNavigable) queue_screenshot_task(node_id ?u64) {
	traversable.screenshot_tasks_ << node_id
	if host := traversable.host_navigable_ {
		if model := navigable_model_for_host(host) {
			mut mutable_model := unsafe { &NavigableModel(model) }
			mutable_model.set_needs_repaint()
		}
	}
	if document := traversable.active_document() {
		document.request_frame()
	}
}

pub fn (mut traversable TraversableNavigable) process_screenshot_requests() {
	for traversable.screenshot_tasks_.len > 0 {
		task := traversable.screenshot_tasks_[0]
		traversable.screenshot_tasks_.delete(0)
		if hook := traversable.screenshot_hook_ {
			hook(task)
		}
	}
}

pub fn (mut traversable TraversableNavigable) append_session_history_entry(entry &SessionHistoryEntry) {
	traversable.session_history_entries_ << entry
}

fn deactivate_a_document_for_cross_document_navigation(displayed_document &dom.Document, user_navigation_involvement ?UserNavigationInvolvement, target_entry &SessionHistoryEntry, after_potential_unloads fn()) {
	_ = user_navigation_involvement
	if host := displayed_document.navigable() {
		if model := navigable_model_for_host(host) {
			mut mutable_model := unsafe { &NavigableModel(model) }
			mutable_model.set_ongoing_navigation(NavigableOngoingNavigation{})
		}
	}
	mut mutable_document := unsafe { &dom.Document(displayed_document) }
	mutable_document.unload_a_document_and_its_descendants(target_entry.document())
	after_potential_unloads()
}

pub fn finalize_a_same_document_navigation(mut traversable TraversableNavigable, target_entry &SessionHistoryEntry, entry_to_replace ?&SessionHistoryEntry, history_handling HistoryHandlingBehavior, user_involvement UserNavigationInvolvement, on_complete ?TraversableHistoryStepCompletion) {
	if traversable.has_been_destroyed() {
		complete_history_step(on_complete, .applied)
		return
	}
	active_entry := traversable.active_session_history_entry() or {
		if replaced := entry_to_replace {
			index := traversable.session_history_entries_.index(replaced)
			if index >= 0 {
				mut mutable_target := unsafe { &SessionHistoryEntry(target_entry) }
				mutable_target.step = replaced.step
				traversable.session_history_entries_[index] = target_entry
			}
		}
		complete_history_step(on_complete, .applied)
		return
	}
	// A later navigation can become active before this queued navigation is
	// finalized. Retain a requested replacement in the history list, but do not
	// let the superseded entry become active.
	if voidptr(active_entry) != voidptr(target_entry) {
		if replaced := entry_to_replace {
			index := traversable.session_history_entries_.index(replaced)
			if index >= 0 {
				mut mutable_target := unsafe { &SessionHistoryEntry(target_entry) }
				mutable_target.step = replaced.step
				traversable.session_history_entries_[index] = target_entry
			}
		}
		complete_history_step(on_complete, .applied)
		return
	}
	mut target_step := traversable.current_session_history_step_
	if replaced := entry_to_replace {
		index := traversable.session_history_entries_.index(replaced)
		if index >= 0 {
			target_step = session_history_entry_step(replaced) or { target_step }
			mut mutable_target := unsafe { &SessionHistoryEntry(target_entry) }
			mutable_target.step = target_step
			traversable.session_history_entries_[index] = target_entry
		} else {
			traversable.clear_the_forward_session_history()
			target_step++
			mut mutable_target := unsafe { &SessionHistoryEntry(target_entry) }
			mutable_target.step = target_step
			traversable.session_history_entries_ << target_entry
		}
	} else {
		traversable.clear_the_forward_session_history()
		target_step++
		mut mutable_target := unsafe { &SessionHistoryEntry(target_entry) }
		mutable_target.step = target_step
		traversable.session_history_entries_ << target_entry
	}
	traversable.apply_the_push_or_replace_history_step(target_step, history_handling, user_involvement,
		.yes, on_complete)
}
