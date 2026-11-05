module layout

import dom
import html

fn generated_pseudo_bridge_root(element &dom.Element, pseudo dom.PseudoElement) &Node {
	subject := dom.AbstractElement.new(element, pseudo)
	styled := subject.unsafe_layout_node() or { panic('missing pseudo bridge') }
	mirror := styled.layout_node_ or { panic('missing pseudo layout node') }
	return unsafe { &Node(mirror.real_layout_handle()) }
}

fn test_generated_pseudo_bridge_keeps_the_styled_root_for_text_and_mixed_content() {
	image := 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
	for content in ['"word"', 'url("${image}") "word"', 'url("${image}")'] {
		mut document := html.parse_document('<!doctype html><style>
   #host::before,#host::after{content:${content}}
  </style><div id="host">host</div>')
		defer { document.finalize() }
		root := build_layout_tree(document) or { panic('missing tree') }
		_ = prepare_dom_layout_attachment(root)
		element := document.get_element_by_id('host') or { panic('missing host') }
		for pseudo in [dom.PseudoElement.before, .after] {
			node := generated_pseudo_bridge_root(element, pseudo)
			assert !node.is_text_node()
			assert node.as_node_with_style() != none
			parent := node.parent() or { panic('missing pseudo parent') }
			assert !parent.is_generated_for_pseudo_element()
		}
	}
}

fn test_generated_separator_inherits_live_font_size_without_rebuilding_the_tree() {
	mut document := html.parse_document('<!doctype html><style>
  html,body{margin:0;font:19px/1.4 SerenitySans}
  #time::before{content:" - "}
 </style><div id="time">9 hours ago</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 400, 200)
	mut element := document.get_element_by_id('time') or { panic('missing time') }
	before := generated_pseudo_bridge_root(element, .before)
	assert before.computed_values().font_size().to_double() == 19
	element.set_attribute_value('style', 'font-size:16px')
	document.update_layout(.debugging)
	after := generated_pseudo_bridge_root(element, .before)
	assert voidptr(before) == voidptr(after)
	assert after.computed_values().font_size().to_double() == 16
	assert element.get_bounding_client_rect().height == 22.390625
	current := document.record_display_list() or { panic('missing updated paint') }
	current_dump := current.dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing rebuilt paint') }).dump() == current_dump
}
