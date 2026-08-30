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
import rand

__global html_user_agent_top_level_traversables = []&TraversableNavigable{}

pub fn user_agent_top_level_traversable_set() []&TraversableNavigable {
	return html_user_agent_top_level_traversables.clone()
}

pub fn create_a_new_top_level_browsing_context_and_document(page &dom.Page) !BrowsingContextGroupAndDocument {
	return BrowsingContextGroup.create_a_new_browsing_context_group_and_document(page)
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

@[heap]
pub struct TraversableNavigable {
mut:
	current_session_history_step_ int
	session_history_entries_      []&SessionHistoryEntry
	active_session_history_entry_ ?&SessionHistoryEntry
	running_nested_apply_step_    bool
	system_visibility_state_      dom.VisibilityState = .hidden
	is_created_by_web_content_    bool
	is_closing_                   bool
	has_been_destroyed_           bool
	has_system_focus_             bool
	window_handle_                string
	active_document_              ?&dom.Document
	navigation_                   ?&Navigation
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
	html_user_agent_top_level_traversables << traversable
	return traversable
}

pub fn TraversableNavigable.create_a_new_top_level_traversable(target_name string) !&TraversableNavigable {
	_ = target_name
	mut document := &dom.Document{}
	document.set_url(dom.url_about_blank())
	document.set_origin(dom.origin_create_opaque())
	state := &DocumentState{
		document: document
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
	traversable.active_document_ = document
	mut host_navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	host_navigable.traversable_navigable_ = host_navigable
	traversable.host_navigable_ = host_navigable
	document.set_cached_navigable(host_navigable)
	return traversable
}

pub fn TraversableNavigable.create_a_fresh_top_level_traversable(initial_navigation_url dom.URL, initial_resource DocumentResource) !&TraversableNavigable {
	mut traversable := TraversableNavigable.new()
	mut document := &dom.Document{}
	document.set_url(initial_navigation_url)
	document.set_origin(initial_navigation_url.origin())
	state := &DocumentState{
		document: document
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
	traversable.active_document_ = document
	mut host_navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	host_navigable.traversable_navigable_ = host_navigable
	traversable.host_navigable_ = host_navigable
	document.set_cached_navigable(host_navigable)
	return traversable
}

pub fn (traversable &TraversableNavigable) is_top_level_traversable() bool {
	return true
}

pub fn (traversable &TraversableNavigable) current_session_history_step() int {
	return traversable.current_session_history_step_
}

pub fn (traversable &TraversableNavigable) session_history_entries() []&SessionHistoryEntry {
	return traversable.session_history_entries_.clone()
}

pub fn (traversable &TraversableNavigable) active_session_history_entry() ?&SessionHistoryEntry {
	return traversable.active_session_history_entry_
}

pub fn (traversable &TraversableNavigable) active_document() ?&dom.Document {
	return traversable.active_document_
}

pub fn (traversable &TraversableNavigable) running_nested_apply_history_step() bool {
	return traversable.running_nested_apply_step_
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
	traversable.navigation_ = navigation
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
	current := traversable.active_session_history_entry_ or { target }
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
	current := traversable.active_session_history_entry_ or { target }
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
	if target.document() != traversable.active_document_ || reload_pending {
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

pub fn (traversable &TraversableNavigable) check_if_unloading_is_canceled(documents []&dom.Document) CheckIfUnloadingIsCanceledResult {
	if hook := traversable.before_unload_hook_ {
		return hook(documents)
	}
	return .continue_
}

fn (mut traversable TraversableNavigable) apply_the_history_step(step int, check_for_cancellation bool, user_involvement UserNavigationInvolvement, navigation_type dom.NavigationType) HistoryStepResult {
	if traversable.has_been_destroyed_ {
		return .initiator_disallowed
	}
	used_step := traversable.get_the_used_step(step) or { return .initiator_disallowed }
	target := target_history_entry(traversable.session_history_entries_, used_step) or {
		return .initiator_disallowed
	}
	active := traversable.active_session_history_entry_ or { target }
	if check_for_cancellation {
		documents := collect_documents_that_will_unload(traversable.session_history_entries_, active, target)
		match traversable.check_if_unloading_is_canceled(documents) {
			.canceled_by_before_unload {
				return .canceled_by_before_unload
			}
			.canceled_by_navigate {
				return .canceled_by_navigate
			}
			.continue_ {}
		}
	}
	if navigation := traversable.navigation_ {
		if navigation_type == .traverse {
			mut mutable_navigation := unsafe { &Navigation(navigation) }
			if !mutable_navigation.fire_a_traverse_navigate_event(target, user_involvement) {
				return .canceled_by_navigate
			}
		}
	}
	traversable.running_nested_apply_step_ = true
	traversable.current_session_history_step_ = used_step
	traversable.active_session_history_entry_ = target
	traversable.active_document_ = target.document()
	if state := target.document_state {
		mut mutable_state := unsafe { &DocumentState(state) }
		mutable_state.reload_pending = false
	}
	traversable.running_nested_apply_step_ = false
	if hook := traversable.applied_hook_ {
		hook(used_step, navigation_type)
	}
	return .applied
}

pub fn (mut traversable TraversableNavigable) apply_the_traverse_history_step(step int, source_snapshot_params ?&SourceSnapshotParams, initiator_to_check ?&dom.Navigable, user_involvement UserNavigationInvolvement) HistoryStepResult {
	_ = source_snapshot_params
	_ = initiator_to_check
	return traversable.apply_the_history_step(step, true, user_involvement, .traverse)
}

pub fn (mut traversable TraversableNavigable) apply_the_reload_history_step(user_involvement UserNavigationInvolvement) HistoryStepResult {
	return traversable.apply_the_history_step(traversable.current_session_history_step_, true, user_involvement, .reload)
}

pub fn (mut traversable TraversableNavigable) apply_the_push_or_replace_history_step(step int, history_handling HistoryHandlingBehavior, user_involvement UserNavigationInvolvement, synchronous_navigation SynchronousNavigation) HistoryStepResult {
	_ = synchronous_navigation
	type_ := if history_handling == .replace {
		dom.NavigationType.replace
	} else {
		dom.NavigationType.push
	}
	return traversable.apply_the_history_step(step, false, user_involvement, type_)
}

pub fn (mut traversable TraversableNavigable) update_for_navigable_creation_or_destruction() HistoryStepResult {
	return traversable.apply_the_history_step(traversable.current_session_history_step_, false, .none_, .traverse)
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
	_ = source_document
	steps := traversable.get_all_used_history_steps()
	current_index := steps.index(traversable.current_session_history_step_)
	if current_index < 0 {
		return
	}
	target_index := current_index + delta
	if target_index < 0 || target_index >= steps.len {
		return
	}
	_ = traversable.apply_the_traverse_history_step(steps[target_index], none, none, if source_document != none {
		.none_
	} else {
		.browser_ui
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
	if traversable.is_closing_ {
		return
	}
	traversable.definitely_close_top_level_traversable()
}

pub fn (mut traversable TraversableNavigable) definitely_close_top_level_traversable() {
	traversable.is_closing_ = true
	traversable.destroy_top_level_traversable()
}

pub fn (mut traversable TraversableNavigable) destroy_top_level_traversable() {
	if traversable.has_been_destroyed_ {
		return
	}
	traversable.has_been_destroyed_ = true
	traversable.active_document_ = none
	html_user_agent_top_level_traversables = html_user_agent_top_level_traversables.filter(voidptr(it) != voidptr(&traversable))
}

pub fn (traversable &TraversableNavigable) has_been_destroyed() bool {
	return traversable.has_been_destroyed_
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

pub fn finalize_a_same_document_navigation(mut traversable TraversableNavigable, target_entry &SessionHistoryEntry, entry_to_replace ?&SessionHistoryEntry, history_handling HistoryHandlingBehavior, user_involvement UserNavigationInvolvement) {
	if traversable.has_been_destroyed_ {
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
	_ = traversable.apply_the_push_or_replace_history_step(target_step, history_handling, user_involvement, .yes)
}
