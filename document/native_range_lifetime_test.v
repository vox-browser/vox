module main

import dom
import html

// The process-wide live-range registry can outlive a document's payload arena:
// changing a range's boundaries transfers its current document without moving
// the Range object itself.
fn test_live_range_identity_survives_its_creation_document_storage() {
	$if !prealloc {
		return
	}
	mut source := html.parse_document('<!doctype html><body></body>')
	mut destination := html.parse_document('<!doctype html><body>destination</body>')
	source.enable_native_storage()
	storage := source.native_storage()
	mut scope := source.enter_native_storage()
	mut first := source.create_range()
	mut second := dom.Range.create_from_boundary_points(source.as_node(), 0, source.as_node(), 0)
	scope.finish()
	// Range identities are registry-owned, independently of the payload arena.
	assert !storage.arena.contains(voidptr(first))
	assert !storage.arena.contains(voidptr(second))
	first.select_node_contents(destination.as_node())!
	second.select_node_contents(destination.as_node())!
	source.release_native_storage()
	assert voidptr(first.start_container()) == voidptr(destination)
	assert voidptr(second.end_container()) == voidptr(destination)
	first.finalize()
	second.finalize()
	source.finalize()
	destination.finalize()
}

fn test_borrowed_document_ranges_retire_with_the_final_payload_reader() {
	$if !prealloc {
		return
	}
	mut owner := dom.Document.create(dom.URL{ value: 'https://range-owner.test/' })
	owner.enable_native_storage()
	mut borrowed := dom.Document.create(dom.URL{ value: 'https://range-owner.test/inert' })
	borrowed.borrow_native_storage(owner)
	mut allocations := owner.enter_native_storage()
	text := borrowed.create_text_node('borrowed payload')
	allocations.finish()
	mut range := dom.Range.create_from_boundary_points(text.as_node(), 0, text.as_node(), 8)
	mut storage := owner.native_storage()
	storage.retain()
	owner.release_native_storage()
	assert dom.Range.live_ranges().any(voidptr(it) == voidptr(range))
	assert text.data() == 'borrowed payload'
	storage.release()
	assert !dom.Range.live_ranges().any(voidptr(it) == voidptr(range))
	assert storage.arena.usage().capacity == 0
	// Retiring another document scans the registry without touching freed nodes.
	mut next := dom.Document.create(dom.URL{ value: 'https://range-next.test/' })
	next.enable_native_storage()
	next.release_native_storage()
	range.finalize()
	borrowed.release_native_storage()
	borrowed.finalize()
	owner.finalize()
	next.finalize()
}

fn test_adopted_range_keeps_receiving_mutations_after_its_original_owner_retires() {
	$if !prealloc {
		return
	}
	mut source := dom.Document.create(dom.URL{ value: 'https://range-source.test/' })
	mut destination := dom.Document.create(dom.URL{ value: 'https://range-destination.test/' })
	source.enable_native_storage()
	destination.enable_native_storage()
	mut allocations := source.enter_native_storage()
	mut text := source.create_text_node('abc')
	allocations.finish()
	mut range := dom.Range.create_from_boundary_points(text.as_node(), 0, text.as_node(), 3)
	destination.adopt_node(text.as_node())
	source.release_native_storage()
	assert dom.Range.live_ranges().any(voidptr(it) == voidptr(range))
	text.replace_data(0, 0, '!')!
	assert range.end_offset() == 4
	destination.release_native_storage()
	assert !dom.Range.live_ranges().any(voidptr(it) == voidptr(range))
	range.finalize()
	source.finalize()
	destination.finalize()
}
