module html

import editing
import dom

fn attach_block_plan_layout(node &dom.Node, owner u32) {
	if node.is_text() && node.length() > 0 {
		mut mutable_node := unsafe { &dom.Node(node) }
		mutable_node.set_layout_node(&dom.LayoutNode{
			is_text_node_: true
			visual_lines_data_: &dom.LayoutVisualLines{ values: [dom.VisualLine{
				start_offset: 0
				end_offset: node.length()
				end_offset_with_trailing_whitespace: node.length()
				has_fragments: true
				owner_paintable: owner
			}] }
		})
	}
	for child in node.children_as_vector() {
		attach_block_plan_layout(child, owner)
	}
}

fn block_plan_content(document &dom.Document) &editing.InsertedContent {
	paragraph := document.create_element('p') or { panic(err) }
	mut body := document.body() or { panic('missing body') }
	mut body_node := body.as_node()
	body_node.append_child(paragraph.as_node()) or { panic(err) }
	return editing.InsertedContent.new([paragraph.as_node()])
}

fn test_block_replacement_plan_splits_inside_rendered_paragraph() {
	document := parse_document('<!doctype html><body><div id="destination">beforeafter</div></body>')
	destination := document.get_element_by_id('destination') or { panic('missing destination') }
	attach_block_plan_layout(destination.as_node(), 1)
	content := block_plan_content(document)
	text := destination.as_node().first_child() or { panic('missing destination text') }

	plan := editing.make_block_replacement_plan(dom.BoundaryPoint{
		node: text
		offset: 6
	}, destination.as_node(), content)

	assert plan.insertion_mode == .split_destination
}

fn test_block_replacement_plan_inserts_after_paragraph_end() {
	document := parse_document('<!doctype html><body><div id="destination">before</div></body>')
	destination := document.get_element_by_id('destination') or { panic('missing destination') }
	attach_block_plan_layout(destination.as_node(), 2)
	content := block_plan_content(document)

	plan := editing.make_block_replacement_plan(dom.BoundaryPoint{
		node: destination.as_node()
		offset: destination.as_node().child_count()
	}, destination.as_node(), content)

	assert plan.insertion_mode == .insert_after_containing_block
}

fn test_block_replacement_plan_uses_empty_and_list_item_paths() {
	empty_document := parse_document('<!doctype html><body><div id="destination"><br></div></body>')
	empty_destination := empty_document.get_element_by_id('destination') or { panic('missing destination') }
	empty_content := block_plan_content(empty_document)
	empty_plan := editing.make_block_replacement_plan(dom.BoundaryPoint{
		node: empty_destination.as_node()
		offset: 0
	}, empty_destination.as_node(), empty_content)
	assert empty_plan.insertion_mode == .insert_inside_empty_block

	list_document := parse_document('<!doctype html><body><ul><li id="destination">item</li></ul></body>')
	list_destination := list_document.get_element_by_id('destination') or { panic('missing destination') }
	attach_block_plan_layout(list_destination.as_node(), 3)
	list_content := block_plan_content(list_document)
	list_plan := editing.make_block_replacement_plan(dom.BoundaryPoint{
		node: list_destination.as_node()
		offset: 0
	}, list_destination.as_node(), list_content)
	assert list_plan.insertion_mode == .insert_inside_list_item
}

fn test_block_replacement_plan_keeps_internal_break_boundary_in_container() {
	document := parse_document('<!doctype html><body><div id="destination">before<br id="marker">after</div></body>')
	destination := document.get_element_by_id('destination') or { panic('missing destination') }
	marker := document.get_element_by_id('marker') or { panic('missing marker') }
	attach_block_plan_layout(destination.as_node(), 4)
	content := block_plan_content(document)

	plan := editing.make_block_replacement_plan(dom.BoundaryPoint{
		node: destination.as_node()
		offset: marker.as_node().index() + 1
	}, destination.as_node(), content)

	assert plan.insertion_mode == .insert_at_internal_paragraph_boundary
}

fn test_block_replacement_integrates_matching_pasted_list() {
	document := parse_document('<!doctype html><body><ul id="list"><li id="destination">before</li><ul id="pasted"><li id="first">one</li><li id="last">two</li></ul></ul></body>')
	list := document.get_element_by_id('list') or { panic('missing list') }
	destination := document.get_element_by_id('destination') or { panic('missing destination') }
	pasted := document.get_element_by_id('pasted') or { panic('missing pasted list') }
	first := document.get_element_by_id('first') or { panic('missing first item') }
	last := document.get_element_by_id('last') or { panic('missing last item') }
	mut content := editing.InsertedContent.new([pasted.as_node()])

	editing.integrate_first_pasted_list(mut content, destination.as_node())

	assert list.as_node().child_count() == 3
	assert voidptr(list.as_node().child_at_index(1)?) == voidptr(first.as_node())
	assert voidptr(list.as_node().child_at_index(2)?) == voidptr(last.as_node())
	pasted_is_detached := pasted.as_node().parent() == none
	assert pasted_is_detached
	assert voidptr(content.first_node()?) == voidptr(first.as_node())
	assert voidptr(content.last_node()?) == voidptr(last.as_node())
}
