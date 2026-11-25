module layout

import css
import dom
import platform

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
			values.set_had_clearance(true)
			box := unsafe { &Node(node) }
			_ = layout_inside_independent_formatting_context_with_mode(mut state, box,
				mut values, .normal, space)
			values.set_had_clearance(false)
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
			assert record.before.had_clearance()
			assert record.after.had_clearance()
		}
	}
	assert state.subtree_layout_decisions_.len == nodes.len
	allocations.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_subtree_layout_comparison_reuses_empty_rare_inputs() {
	missing := &UsedValues{}
	empty := &UsedValues{rare_: &UsedValuesRareData{}}
	margin := &UsedValues{rare_: &UsedValuesRareData{collapsed_flow_margin_bottom_: CSSPixels.new(4)}}
	mut arena := platform.new_arena('subtree input comparison fixture')
	defer { arena.release() }
	entry := arena.enter()
	defer { arena.leave(entry) }
	before := arena.usage().used
	for _ in 0 .. 256 {
		assert subtree_layout_inputs_match(missing, missing)
		assert subtree_layout_inputs_match(missing, empty)
		assert subtree_layout_inputs_difference(missing, empty) == ''
		assert !subtree_layout_inputs_match(margin, missing)
		assert subtree_layout_inputs_difference(margin, missing) == 'collapsed-margin'
	}
	assert arena.usage().used == before
}
