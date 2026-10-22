module dom

import platform

@[heap]
struct InsertionSnapshotCallbackState {
mut:
	records      []&MutationRecord
	fragment     &Node = unsafe { nil }
	nested_child &Node = unsafe { nil }
	reentered    bool
}

fn reuse_insertion_snapshot_storage(node &Node) {
	for _ in 0 .. 4 {
		scratch := platform.begin_thread_scratch('insertion snapshot')
		overwrite := []&Node{len: 128, init: node}
		assert overwrite.len == 128
		assert voidptr(overwrite[127]) == voidptr(node)
		scratch.finish()
	}
}

fn test_mutation_record_copies_caller_owned_membership() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	target := document.create_element('div')!.as_node()
	first := document.create_text_node('first').as_node()
	second := document.create_text_node('second').as_node()
	replacement := document.create_text_node('replacement').as_node()
	mut added := [first, second]
	mut removed := [second, first]
	record := MutationRecord.create('childList', target, added, removed, first, second,
		none, none, none)
	added[0] = replacement
	removed[1] = replacement
	added.clear()
	removed.clear()
	assert record.added_nodes.len == 2 && record.removed_nodes.len == 2
	assert voidptr(record.added_nodes[0]) == voidptr(first)
	assert voidptr(record.added_nodes[1]) == voidptr(second)
	assert voidptr(record.removed_nodes[0]) == voidptr(second)
	assert voidptr(record.removed_nodes[1]) == voidptr(first)
	assert voidptr(record.target) == voidptr(target)
	assert voidptr(record.previous_sibling) == voidptr(first)
	assert voidptr(record.next_sibling) == voidptr(second)
}

fn test_mutation_record_exports_borrowed_scratch_membership() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	target := document.create_element('div')!.as_node()
	child := document.create_text_node('child').as_node()
	scratch := platform.begin_thread_scratch('insertion snapshot')
	added := [child]
	removed := [target, child]
	scratch.leave()
	record := MutationRecord.create('childList', target, added, removed, none, none,
		none, none, none)
	scratch.finish()
	reuse_insertion_snapshot_storage(target)
	assert record.added_nodes.len == 1 && record.removed_nodes.len == 2
	assert voidptr(record.added_nodes[0]) == voidptr(child)
	assert voidptr(record.removed_nodes[1]) == voidptr(child)
	assert record.added_nodes[0].text_content()? == 'child'
}

fn test_insertion_records_survive_deferred_delivery_and_snapshot_reuse() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut target := document.create_element('div')!.as_node()
	previous := document.create_text_node('previous').as_node()
	next := document.create_text_node('next').as_node()
	child := document.create_text_node('child').as_node()
	target.append_child(previous)!
	target.append_child(next)!
	mut observer := MutationObserver.construct_impl(none)!
	mut options := MutationObserverOptions{ child_list: true }
	observer.observe(target, mut options)!
	document.mutation_observer_microtask_queued = true
	target.insert_before(child, next, false)
	reuse_insertion_snapshot_storage(next)
	records := observer.take_records()
	assert records.len == 1
	assert records[0].added_nodes.len == 1 && records[0].removed_nodes.len == 0
	assert voidptr(records[0].added_nodes[0]) == voidptr(child)
	assert voidptr(records[0].previous_sibling) == voidptr(previous)
	assert voidptr(records[0].next_sibling) == voidptr(next)
	assert target.children.len == 3 && voidptr(target.children[1]) == voidptr(child)
}

fn test_observer_callback_can_retain_insertion_records_after_return() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut target := document.create_element('div')!.as_node()
	child := document.create_text_node('retained').as_node()
	state := &InsertionSnapshotCallbackState{}
	callback := &CallbackType{
		mutation_callback: fn [state] (records []&MutationRecord, _ &MutationObserver) {
			mut mutable_state := unsafe { &InsertionSnapshotCallbackState(state) }
			mutable_state.records << records
		}
	}
	mut observer := MutationObserver.construct_impl(callback)!
	mut options := MutationObserverOptions{ child_list: true }
	observer.observe(target, mut options)!
	target.append_child(child)!
	reuse_insertion_snapshot_storage(target)
	assert state.records.len == 1 && state.records[0].added_nodes.len == 1
	assert voidptr(state.records[0].added_nodes[0]) == voidptr(child)
	assert state.records[0].added_nodes[0].text_content()? == 'retained'
}

fn test_fragment_adoption_keeps_source_and_destination_record_membership() {
	mut source := Document.create(URL{ value: 'https://source.example/' })
	mut destination := Document.create(URL{ value: 'https://destination.example/' })
	defer {
		source.finalize()
		destination.finalize()
	}
	mut fragment := source.create_document_fragment().as_node()
	first := source.create_text_node('first').as_node()
	second := source.create_text_node('second').as_node()
	fragment.append_child(first)!
	fragment.append_child(second)!
	mut target := destination.create_element('div')!.as_node()
	mut source_observer := MutationObserver.construct_impl(none)!
	mut destination_observer := MutationObserver.construct_impl(none)!
	mut options := MutationObserverOptions{ child_list: true }
	source_observer.observe(fragment, mut options)!
	destination_observer.observe(target, mut options)!
	source.mutation_observer_microtask_queued = true
	destination.mutation_observer_microtask_queued = true
	target.append_child(fragment)!
	reuse_insertion_snapshot_storage(target)
	removed := source_observer.take_records()
	added := destination_observer.take_records()
	assert removed.len == 1 && added.len == 1
	assert removed[0].removed_nodes.len == 2 && added[0].added_nodes.len == 2
	assert voidptr(removed[0].removed_nodes[0]) == voidptr(first)
	assert voidptr(removed[0].removed_nodes[1]) == voidptr(second)
	assert voidptr(added[0].added_nodes[0]) == voidptr(first)
	assert voidptr(added[0].added_nodes[1]) == voidptr(second)
	assert fragment.children.len == 0 && target.children.len == 2
	assert voidptr(fragment.document()) == voidptr(source)
	assert voidptr(first.document()) == voidptr(destination)
	assert voidptr(second.document()) == voidptr(destination)
	fragment.append_child(source.create_text_node('later').as_node())!
	reuse_insertion_snapshot_storage(fragment)
	assert removed[0].removed_nodes.len == 2
	assert voidptr(removed[0].removed_nodes[0]) == voidptr(target.children[0])
}

fn test_fragment_observer_reentrancy_preserves_the_outer_insertion_snapshot() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut fragment := document.create_document_fragment().as_node()
	first := document.create_text_node('first').as_node()
	second := document.create_text_node('second').as_node()
	nested_child := document.create_text_node('nested').as_node()
	fragment.append_child(first)!
	fragment.append_child(second)!
	state := &InsertionSnapshotCallbackState{ fragment: fragment, nested_child: nested_child }
	callback := &CallbackType{
		mutation_callback: fn [state] (records []&MutationRecord, _ &MutationObserver) {
			mut mutable_state := unsafe { &InsertionSnapshotCallbackState(state) }
			mutable_state.records << records
			if !mutable_state.reentered {
				mutable_state.reentered = true
				mut fragment_node := mutable_state.fragment
				fragment_node.append_child(mutable_state.nested_child) or { panic(err) }
			}
		}
	}
	mut observer := MutationObserver.construct_impl(callback)!
	mut options := MutationObserverOptions{ child_list: true }
	observer.observe(fragment, mut options)!
	mut target := document.create_element('div')!.as_node()
	target.append_child(fragment)!
	reuse_insertion_snapshot_storage(target)
	assert state.reentered && state.records.len == 2
	assert state.records[0].removed_nodes.len == 2
	assert voidptr(state.records[0].removed_nodes[0]) == voidptr(first)
	assert voidptr(state.records[0].removed_nodes[1]) == voidptr(second)
	assert target.children.len == 2 && fragment.children.len == 1
	assert voidptr(target.children[0]) == voidptr(first)
	assert voidptr(target.children[1]) == voidptr(second)
	assert voidptr(fragment.children[0]) == voidptr(nested_child)
	assert state.records[1].added_nodes.len == 1
	assert voidptr(state.records[1].added_nodes[0]) == voidptr(nested_child)
}

fn test_empty_fragment_does_not_publish_an_insertion_record() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut target := document.create_element('div')!.as_node()
	fragment := document.create_document_fragment().as_node()
	mut observer := MutationObserver.construct_impl(none)!
	mut options := MutationObserverOptions{ child_list: true }
	observer.observe(target, mut options)!
	target.append_child(fragment)!
	reuse_insertion_snapshot_storage(target)
	assert target.children.len == 0
	assert observer.take_records().len == 0
}
