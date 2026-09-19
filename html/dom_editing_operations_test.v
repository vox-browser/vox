module html

import editing
import dom

fn test_move_node_preserving_ranges_keeps_selection_and_editing_boundaries() {
	mut document := parse_document('<!doctype html><body><div id="old"><span id="moved">text</span><em id="after">after</em></div><div id="new"><i>prefix</i><b>suffix</b></div></body>')
	old_parent := document.get_element_by_id('old') or { panic('missing old parent') }
	new_parent := document.get_element_by_id('new') or { panic('missing new parent') }
	moved := document.get_element_by_id('moved') or { panic('missing moved node') }
	moved_text := moved.as_node().first_child() or { panic('missing moved text') }

	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	mut selection := document.get_selection() or { panic('missing selection') }
	mut selected_range := dom.Range.create_from_boundary_points(moved_text, 1, moved_text,
		3)
	selection.set_range(selected_range)

	mut before := editing.MutationTrackedRange.new(dom.Range.create_from_boundary_points(old_parent.as_node(),
		0, old_parent.as_node(), 0))
	mut after := editing.MutationTrackedRange.new(dom.Range.create_from_boundary_points(old_parent.as_node(),
		1, old_parent.as_node(), 1))
	mut later := editing.MutationTrackedRange.new(dom.Range.create_from_boundary_points(old_parent.as_node(),
		2, old_parent.as_node(), 2))

	editing.move_node_preserving_ranges(moved.as_node(), new_parent.as_node(), 1)

	active := selection.range() or { panic('selection lost its range') }
	assert active.start() == dom.BoundaryPoint{ node: moved_text, offset: 1 }
	assert active.end() == dom.BoundaryPoint{ node: moved_text, offset: 3 }
	assert before.range().start() == dom.BoundaryPoint{ node: new_parent.as_node(), offset: 1 }
	assert after.range().start() == dom.BoundaryPoint{ node: new_parent.as_node(), offset: 2 }
	assert later.range().start() == dom.BoundaryPoint{ node: old_parent.as_node(), offset: 1 }
	assert moved.as_node().parent()? == new_parent.as_node()
	assert moved.as_node().index() == 1

	selection.remove_all_ranges()
	selected_range.finalize()
	before.release()
	after.release()
	later.release()
}

fn test_unwrap_node_preserving_ranges_keeps_wrapper_edge_boundaries() {
	document := parse_document('<!doctype html><body><div id="host">A<span id="wrapper"><b id="first">B</b><i id="last">C</i></span>D</div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	wrapper := document.get_element_by_id('wrapper') or { panic('missing wrapper') }
	first := document.get_element_by_id('first') or { panic('missing first child') }
	last := document.get_element_by_id('last') or { panic('missing last child') }
	mut before := editing.MutationTrackedRange.new(dom.Range.create_from_boundary_points(wrapper.as_node(),
		0, wrapper.as_node(), 0))
	mut after := editing.MutationTrackedRange.new(dom.Range.create_from_boundary_points(wrapper.as_node(),
		2, wrapper.as_node(), 2))

	editing.unwrap_node_preserving_ranges(wrapper.as_node())

	assert wrapper.as_node().parent() == none
	assert host.as_node().child_count() == 4
	assert host.as_node().child_at_index(1)? == first.as_node()
	assert host.as_node().child_at_index(2)? == last.as_node()
	assert before.range().start() == dom.BoundaryPoint{ node: host.as_node(), offset: 1 }
	assert after.range().start() == dom.BoundaryPoint{ node: host.as_node(), offset: 3 }

	before.release()
	after.release()
}
