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
