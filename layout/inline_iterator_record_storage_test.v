module layout

import css
import dom
import platform

fn test_inline_iterator_records_retire_with_their_item_storage() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.enable_native_storage()
	style := css.ComputedProperties.new()
	mut container := BlockContainer.new(document, none, style)
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(100)), AvailableSize.make_indefinite())
	mut buffers := acquire_inline_item_buffers(document)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 64 {
		mut iterator := new_inline_iterator_with_item_storage(mut state, container, used, .normal, space, none, buffers.arena)
		$if prealloc { assert buffers.arena.contains(voidptr(iterator)) }
		assert iterator.next() == none
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	buffers.finish()
	// The public constructor continues to return an independently owned record.
	mut durable := InlineLevelIterator.new(mut state, container, used, .normal, space, none)
	assert durable.next() == none
	document.release_native_storage()
}
