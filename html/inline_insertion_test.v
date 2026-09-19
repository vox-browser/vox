module html

import editing
import dom

fn mark_inline_for_editing_test(element &dom.Element) {
	mut mutable_element := unsafe { &dom.Element(element) }
	mutable_element.set_computed_properties(none, &dom.CSSComputedProperties_{
		display_: dom.CSSDisplay_{
			is_inline_outside_: true
			is_flow_inside_: true
		}
	})
}

fn test_inline_insertion_splits_highest_modifiable_style_ancestor() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><b>A<i>BC</i>D</b>E</div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	bold := host.as_node().first_child()?.as_element() or { panic('missing bold') }
	italic := bold.as_node().child_at_index(1)?.as_element() or { panic('missing italic') }
	mark_inline_for_editing_test(bold)
	mark_inline_for_editing_test(italic)
	text := italic.as_node().first_child() or { panic('missing text') }

	prepared := editing.prepare_inline_insertion_boundary(dom.BoundaryPoint{
		node: text
		offset: 1
	}, host.as_node())

	assert prepared.split_destination_style
	assert prepared.boundary == dom.BoundaryPoint{ node: host.as_node(), offset: 1 }
	assert host.inner_html()! == '<b>A<i>B</i></b><b><i>C</i>D</b>E'
}

fn test_inline_insertion_advances_past_trailing_styled_run() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><b>one</b><span>two</span></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	bold := host.as_node().first_child()?.as_element() or { panic('missing bold') }
	mark_inline_for_editing_test(bold)
	text := bold.as_node().first_child() or { panic('missing text') }

	prepared := editing.prepare_inline_insertion_boundary(dom.BoundaryPoint{
		node: text
		offset: text.length()
	}, host.as_node())

	assert !prepared.split_destination_style
	assert prepared.boundary == dom.BoundaryPoint{ node: host.as_node(), offset: 1 }
	assert host.inner_html()! == '<b>one</b><span>two</span>'
}

fn test_inline_insertion_leaves_list_destination_to_list_path() {
	document := parse_document('<!doctype html><body><ul id="list" contenteditable><li><b>AB</b></li></ul></body>')
	list := document.get_element_by_id('list') or { panic('missing list') }
	item := list.as_node().first_child()?.as_element() or { panic('missing list item') }
	bold := item.as_node().first_child()?.as_element() or { panic('missing bold') }
	mark_inline_for_editing_test(bold)
	text := bold.as_node().first_child() or { panic('missing text') }
	original := dom.BoundaryPoint{
		node: text
		offset: 1
	}

	prepared := editing.prepare_inline_insertion_boundary(original, list.as_node())

	assert !prepared.split_destination_style
	assert prepared.boundary == original
	assert list.inner_html()! == '<li><b>AB</b></li>'
}
