module layout

import html

fn test_svg_input_snapshot_shares_the_document_attribute_strings() {
	mut document := html.parse_document('<!doctype html><svg id="icon" width="24" height="24" viewBox="0 0 24 24"><path id="path" d="M0 0H18V12H0ZM2 2H16V10H2Z" fill="red"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	icon := document.get_element_by_id('icon') or { panic('missing icon') }
	node := unsafe { &Node(icon.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
	input := retained_simple_svg_input(node) or { panic('expected a simple SVG input') }
	path := document.get_element_by_id('path') or { panic('missing path') }
	saved := input.elements.filter(voidptr(it.element) == voidptr(path))
	assert saved.len == 1
	value := saved[0].attributes.filter(it.local_name == 'd')
	assert value.len == 1
	assert value[0].value == path.get_attribute_value('d')
	// The snapshot compares against the document's own immutable string.
	attribute := path.attribute_list() or { panic('missing attributes') }.get_named_item('d') or {
		panic('missing d')
	}
	assert voidptr(value[0].value.str) == voidptr(attribute.value().str)
	assert retained_simple_svg_input_is_current(input)
	mut changed := path
	changed.set_attribute_value('d', 'M0 0H4V20H0Z')
	assert !retained_simple_svg_input_is_current(input)
}
