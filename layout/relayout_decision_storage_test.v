module layout

import css
import dom

fn test_fresh_subtree_decisions_survive_geometry_workspace_retirement_and_growth() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	owner := document.native_storage()
	mut allocations := document.enter_native_storage()
	mut state := LayoutState.new()
	mut nodes := []&NodeWithStyle{}
	for index in 0 .. 128 {
		mut node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
		node.set_layout_index(u32(index))
		nodes << node
	}
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(160)),
		AvailableSize.make_indefinite())
	// Each independent context can first populate or grow the shared index
	// inside a different workspace. Later contexts must still be able to write it.
	for batch in 0 .. 8 {
		mut work := begin_document_geometry_scratch(document)
		for node in nodes[batch * 16 .. (batch + 1) * 16] {
			mut values := state.get_mutable(node)
			values.set_content_width(CSSPixels.new(160))
			box := unsafe { &Node(node) }
			_ = layout_inside_independent_formatting_context_with_mode(mut state, box,
				mut values, .normal, space)
			key := u64(voidptr(box))
			assert state.subtree_layout_decisions_[key] == .fresh
			assert owner.arena.contains(unsafe { &state.subtree_layout_decisions_[key] })
		}
		work.finish()
		for node in nodes[..(batch + 1) * 16] {
			key := u64(voidptr(node))
			assert state.subtree_layout_decisions_[key] == .fresh
			record := state.relayout_records_[node.layout_index()] or { panic('missing relayout record') }
			assert record.space == space
		}
	}
	assert state.subtree_layout_decisions_.len == nodes.len
	allocations.finish()
	document.finalize()
	document.release_native_storage()
}
