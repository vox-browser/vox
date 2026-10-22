module layout

import css
import dom
import platform

fn coordinate_session_test_chain(count int) ([]&NodeWithStyle, []&UsedValues, &LayoutState) {
	document := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()
	mut nodes := []&NodeWithStyle{}
	mut values := []&UsedValues{}
	mut state := LayoutState.new()
	for index in 0 .. count {
		mut node := NodeWithStyle.new(document, none, style)
		node.set_layout_index(u32(index))
		mut used := state.get_mutable(node)
		used.set_content_offset(css.CSSPixelPoint.from_values(1.25, -2.5))
		if index > 0 {
			used.set_containing_block_used_values(values[index - 1])
		}
		nodes << node
		values << used
	}
	return nodes, values, state
}


fn test_coordinate_projection_reuses_ancestors_and_expires_before_geometry_changes() {
 nodes, values, state := coordinate_session_test_chain(32)
 expected := paint_cumulative_offset(unsafe { &Node(nodes.last()) },state,values.last())
 scope := begin_paint_coordinate_session(state)
 assert paint_cumulative_offset(unsafe { &Node(nodes.last()) },state,values.last()) == expected
 assert state.paint_coordinates_.entries[0].status == 2
 assert state.paint_coordinates_.entries[31].status == 2
 for index in 0..nodes.len {
  assert paint_cumulative_offset(unsafe { &Node(nodes[index]) },state,values[index]) == css.CSSPixelPoint.from_values(f64(index+1)*1.25,f64(index+1)*-2.5)
 }
 outer := state.paint_coordinates_
 inner := begin_paint_coordinate_session(state)
 assert voidptr(state.paint_coordinates_) != voidptr(outer)
 assert paint_cumulative_offset(unsafe { &Node(nodes.last()) },state,values.last()) == expected
 inner.finish()
 assert voidptr(state.paint_coordinates_) == voidptr(outer)
 scope.finish()
 assert state.paint_coordinates_ == unsafe { nil }
 mut first := values[0]
 first.offset = css.CSSPixelPoint.from_values(12.25,17.5)
 live := paint_cumulative_offset(unsafe { &Node(nodes.last()) },state,values.last())
 assert live == css.CSSPixelPoint.from_values(51, -60)
 next := begin_paint_coordinate_session(state)
 assert paint_cumulative_offset(unsafe { &Node(nodes.last()) },state,values.last()) == live
 next.finish()
}

fn test_coordinate_projection_preserves_cycles_deep_chains_and_foreign_records() {
 for count in [1,3,65,257] {
  nodes, values, state := coordinate_session_test_chain(count)
  mut first := values[0]
  first.set_containing_block_used_values(values.last())
  expected := paint_cumulative_offset(unsafe { &Node(nodes.last()) },state,values.last())
  scope := begin_paint_coordinate_session(state)
  assert paint_cumulative_offset(unsafe { &Node(nodes.last()) },state,values.last()) == expected
  scope.finish()
 }
 nodes, values, state := coordinate_session_test_chain(257)
 expected := paint_cumulative_offset(unsafe { &Node(nodes.last()) },state,values.last())
 scope := begin_paint_coordinate_session(state)
 assert paint_cumulative_offset(unsafe { &Node(nodes.last()) },state,values.last()) == expected
 mut foreign := UsedValues{node_: nodes.last(), offset: css.CSSPixelPoint.from_values(123,456)}
 assert paint_cumulative_offset(unsafe { &Node(nodes.last()) },state,foreign) == foreign.offset
 scope.finish()
}

fn test_coordinate_projection_keeps_saturating_addition_order() {
 nodes, values, state := coordinate_session_test_chain(3)
 mut root := values[0]
 mut middle := values[1]
 mut leaf := values[2]
 root.offset = css.CSSPixelPoint.new(css.CSSPixels.from_raw(-2_147_483_647),css.CSSPixels.from_raw(2_147_483_647))
 middle.offset = css.CSSPixelPoint.new(css.CSSPixels.from_raw(2_147_483_640),css.CSSPixels.from_raw(-2_147_483_640))
 leaf.offset = middle.offset
 expected := paint_cumulative_offset(unsafe { &Node(nodes.last()) },state,values.last())
 scope := begin_paint_coordinate_session(state)
 assert paint_cumulative_offset(unsafe { &Node(nodes.last()) },state,values.last()) == expected
 assert state.paint_coordinates_.entries[2].status != 2
 scope.finish()
}

fn test_coordinate_tables_expire_without_retaining_temporary_storage_or_caller_payloads() {
	nodes, values, state := coordinate_session_test_chain(513)
	mut arena := platform.new_arena('coordinate caller publication')
	entry := arena.enter()
	outer := begin_paint_coordinate_session(state)
	outer_table := state.paint_coordinates_
	position := paint_cumulative_offset(unsafe { &Node(nodes[31]) }, state, values[31])
	// Allocation after begin belongs to the caller, not the table workspace.
	payload := []u8{len: 4096, init: u8(71)}
	inner := begin_paint_coordinate_session(state)
	assert voidptr(state.paint_coordinates_) != voidptr(outer_table)
	assert paint_cumulative_offset(unsafe { &Node(nodes[31]) }, state, values[31]) == position
	inner.finish()
	assert voidptr(state.paint_coordinates_) == voidptr(outer_table)
	assert state.paint_coordinates_.entries[31].status == 2
	outer.finish()
	arena.leave(entry)
	used := arena.usage().used
	assert state.paint_coordinates_ == unsafe { nil }
	assert position == css.CSSPixelPoint.from_values(40, -80)
	assert payload.len == 4096
	assert payload.all(it == 71)
	$if prealloc {
		// Either table alone is much larger than this caller-owned payload.
		assert used < 8192, '${used} bytes retained after coordinate scopes'
	}
	arena.release()
}
