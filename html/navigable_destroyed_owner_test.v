module html

import dom
import fetch
import page

@[heap]
struct NavigableDestroyedOwnerObservation {
mut:
	fetches             int
	history_completions int
	history_result      HistoryStepResult
}

fn navigable_destroyed_owner_fixture(address string) !(&dom.Document, &NavigableModel, &TraversableNavigable, &dom.Navigable) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native := document.navigable() or { return error('missing actual native Navigable') }
	model := navigable_model_for_host(native) or { return error('missing actual local model') }
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(native)
	traversable.active_document_ = document
	return document, model, traversable, native
}

fn test_actual_model_and_traversable_read_one_native_destroyed_flag() {
	mut document, mut model, traversable, native := navigable_destroyed_owner_fixture('https://navigable-destroyed-owner.example/model')!
	defer { document.finalize() }
	assert !native.has_been_destroyed() && !model.has_been_destroyed() && !traversable.has_been_destroyed()
	model.set_has_been_destroyed()
	assert native.has_been_destroyed() && model.has_been_destroyed() && traversable.has_been_destroyed()
	assert voidptr(navigable_model_for_host(native)?) == voidptr(model)
	assert voidptr(model.active_document()?) == voidptr(document)
}

fn test_actual_traversable_destruction_keeps_retained_native_and_model_flag_after_registry_removal() {
	mut document, model, mut traversable, native := navigable_destroyed_owner_fixture('https://navigable-destroyed-owner.example/removed')!
	defer { document.finalize() }
	assert traversable in user_agent_top_level_traversable_set()
	traversable.destroy_top_level_traversable()
	assert native.has_been_destroyed() && model.has_been_destroyed() && traversable.has_been_destroyed()
	assert navigable_model_for_host(native) == none
	assert !all_navigable_models().any(voidptr(it) == voidptr(model))
	assert traversable !in user_agent_top_level_traversable_set()
	assert native.active_document() == none && model.active_document() == none
	traversable.destroy_top_level_traversable()
	assert native.has_been_destroyed() && model.has_been_destroyed() && traversable.has_been_destroyed()
}

fn test_retained_destroyed_local_model_cannot_fetch_or_queue_navigation_and_history_guards_complete() {
	mut document, mut model, mut traversable, _ := navigable_destroyed_owner_fixture('https://navigable-destroyed-owner.example/guard')!
	defer { document.finalize() }
	entry := model.active_session_history_entry()?
	state := &NavigableDestroyedOwnerObservation{}
	model.set_navigation_fetch_hook(fn [state] (_ &fetch.Request) !&fetch.Response {
		mut observation := unsafe { &NavigableDestroyedOwnerObservation(state) }
		observation.fetches++
		return error('destroyed local Navigable must not issue a fetch')
	})
	traversable.destroy_top_level_traversable()
	assert model.has_been_destroyed()
	assert !model.has_pending_navigations()
	entries_before := model.get_session_history_entries().len
	model.navigate(NavigableNavigateParams{
		url:             dom.URL{value: 'https://navigable-destroyed-owner.example/unreachable'}
		source_document: document
	})!
	assert state.fetches == 0 && !model.has_pending_navigations()
	assert model.ongoing_navigation().kind == .empty
	assert model.get_session_history_entries().len == entries_before
	finalize_a_cross_document_navigation(model, .replace, .none, entry, document, fn [state] (result HistoryStepResult) {
		mut observation := unsafe { &NavigableDestroyedOwnerObservation(state) }
		observation.history_completions++
		observation.history_result = result
	})
	assert state.history_completions == 1 && state.history_result == .applied
	traversable.apply_the_traverse_history_step(0, none, none, .none_, fn [state] (result HistoryStepResult) {
		mut observation := unsafe { &NavigableDestroyedOwnerObservation(state) }
		observation.history_completions++
		observation.history_result = result
	})
	assert state.history_completions == 2 && state.history_result == .initiator_disallowed
}

fn test_traversable_host_reassociation_selects_native_destroyed_owner_without_a_stale_flag() {
	mut original, original_model, mut traversable, mut original_native := navigable_destroyed_owner_fixture('https://navigable-destroyed-owner.example/original')!
	mut replacement, replacement_model, _, replacement_native := navigable_destroyed_owner_fixture('https://navigable-destroyed-owner.example/replacement')!
	defer {
		original.finalize()
		replacement.finalize()
	}
	original_native.set_has_been_destroyed()
	assert original_model.has_been_destroyed() && traversable.has_been_destroyed()
	traversable.set_host_navigable(replacement_native)
	assert !traversable.has_been_destroyed() && !replacement_model.has_been_destroyed()
	assert original_native.has_been_destroyed() && !replacement_native.has_been_destroyed()
	traversable.set_host_navigable(original_native)
	assert traversable.has_been_destroyed()
}
