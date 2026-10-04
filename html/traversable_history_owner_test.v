module html

import dom
import page

fn traversable_history_document(address string) !(&dom.Document, &NavigableModel) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native := document.navigable() or { return error('missing actual native Navigable') }
	model := navigable_model_for_host(native) or { return error('missing actual local Navigable') }
	return document, model
}

fn traversable_history_entry(document &dom.Document, address string, step int) &SessionHistoryEntry {
	return &SessionHistoryEntry{
		step:           step
		url:            dom.URL{address}
		document_state: &DocumentState{
			document:     document
			document_id_: document.unique_id()
			origin:       document.origin()
		}
	}
}

fn test_traversable_reads_and_writes_actual_inherited_current_and_active_history_owners_independently() {
	mut document, mut model := traversable_history_document('https://traversable-history-owner.example/initial')!
	defer { document.finalize() }
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(document.navigable()?)
	initial := model.current_session_history_entry()?
	assert voidptr(initial) == voidptr(model.active_session_history_entry()?)
	assert voidptr(traversable.current_session_history_entry()?) == voidptr(initial)
	assert voidptr(traversable.active_session_history_entry()?) == voidptr(initial)
	pending := traversable_history_entry(document, 'https://traversable-history-owner.example/pending', 1)
	model.set_current_session_history_entry(pending)
	assert voidptr(traversable.current_session_history_entry()?) == voidptr(pending)
	assert voidptr(traversable.active_session_history_entry()?) == voidptr(initial)
	replacement := traversable_history_entry(document, 'https://traversable-history-owner.example/replacement', 2)
	traversable.set_current_session_history_entry(replacement)
	assert voidptr(model.current_session_history_entry()?) == voidptr(replacement)
	assert voidptr(model.active_session_history_entry()?) == voidptr(initial)
	traversable.set_active_session_history_entry(pending)
	assert voidptr(model.active_session_history_entry()?) == voidptr(pending)
	assert voidptr(model.current_session_history_entry()?) == voidptr(replacement)
	model.set_active_session_history_entry(initial)
	assert voidptr(traversable.active_session_history_entry()?) == voidptr(initial)
	assert voidptr(traversable.current_session_history_entry()?) == voidptr(replacement)
}

fn test_registered_history_owner_preserves_null_without_using_stale_traversable_adapter_slots() {
	mut document, mut model := traversable_history_document('https://traversable-history-owner.example/null')!
	defer { document.finalize() }
	mut traversable := TraversableNavigable.create_a_fresh_top_level_traversable(document.url, EmptyDocumentResource{})!
	stale := traversable.current_session_history_entry()?
	assert voidptr(stale) == voidptr(traversable.active_session_history_entry()?)
	traversable.set_host_navigable(document.navigable()?)
	assert voidptr(traversable.current_session_history_entry()?) == voidptr(model.current_session_history_entry()?)
	assert voidptr(traversable.current_session_history_entry()?) != voidptr(stale)
	model.set_current_session_history_entry(none)
	assert traversable.current_session_history_entry() == none
	assert traversable.active_session_history_entry() != none
	traversable.set_active_session_history_entry(none)
	assert model.active_session_history_entry() == none
	assert traversable.active_session_history_entry() == none
	traversable.set_current_session_history_entry(stale)
	assert voidptr(model.current_session_history_entry()?) == voidptr(stale)
	assert traversable.active_session_history_entry() == none
	traversable.set_current_session_history_entry(none)
	assert model.current_session_history_entry() == none
}

fn test_traversable_history_getters_follow_actual_native_host_reassociation() {
	mut first, mut first_model := traversable_history_document('https://traversable-history-owner.example/first')!
	mut second, mut second_model := traversable_history_document('https://traversable-history-owner.example/second')!
	defer {
		first.finalize()
		second.finalize()
	}
	first_current := traversable_history_entry(first, 'https://traversable-history-owner.example/first-current', 1)
	second_current := traversable_history_entry(second, 'https://traversable-history-owner.example/second-current', 2)
	first_model.set_current_session_history_entry(first_current)
	second_model.set_current_session_history_entry(second_current)
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(first.navigable()?)
	assert voidptr(traversable.current_session_history_entry()?) == voidptr(first_current)
	assert voidptr(traversable.active_session_history_entry()?) == voidptr(first_model.active_session_history_entry()?)
	traversable.set_host_navigable(second.navigable()?)
	assert voidptr(traversable.current_session_history_entry()?) == voidptr(second_current)
	assert voidptr(traversable.active_session_history_entry()?) == voidptr(second_model.active_session_history_entry()?)
	traversable.set_current_session_history_entry(none)
	assert second_model.current_session_history_entry() == none
	assert voidptr(first_model.current_session_history_entry()?) == voidptr(first_current)
	traversable.set_host_navigable(first.navigable()?)
	assert voidptr(traversable.current_session_history_entry()?) == voidptr(first_current)
}

fn test_bare_host_history_adapter_initializes_current_and_active_then_keeps_them_independent() {
	mut traversable := TraversableNavigable.create_a_fresh_top_level_traversable(dom.URL{'https://traversable-history-owner.example/bare'}, EmptyDocumentResource{})!
	initial := traversable.current_session_history_entry()?
	assert voidptr(initial) == voidptr(traversable.active_session_history_entry()?)
	assert navigable_model_for_host(traversable.host_navigable_?) == none
	document := traversable.active_document()?
	pending := traversable_history_entry(document, 'https://traversable-history-owner.example/bare-pending', 1)
	traversable.set_current_session_history_entry(pending)
	assert voidptr(traversable.current_session_history_entry()?) == voidptr(pending)
	assert voidptr(traversable.active_session_history_entry()?) == voidptr(initial)
	traversable.set_active_session_history_entry(none)
	assert traversable.active_session_history_entry() == none
	assert voidptr(traversable.current_session_history_entry()?) == voidptr(pending)
	traversable.set_current_session_history_entry(none)
	assert traversable.current_session_history_entry() == none
}
