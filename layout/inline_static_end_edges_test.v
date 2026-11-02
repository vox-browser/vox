module layout

import html

fn end_marker_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() { if node := end_marker_node(child, id) { return node } }
	return none
}

fn check_empty_pseudo_inline_end_marker(pseudo_style string, expected f64) {
	for whitespace in ['', ' ', '\n'] {
		mut document := html.parse_document('<!doctype html><style>
   body { margin:0; font:16px/20px Arial }
   #host { position:relative }
   #outer { border-right:1px solid; margin-right:3px }
   #inner { padding-right:10px } ${pseudo_style}
   #atomic { display:inline-block; width:12px; height:10px }
   #abs { position:absolute; width:10px; height:10px }
  </style><div id="host"><span id="outer"><span id="inner"><i id="atomic"></i></span></span>${whitespace}<span id="abs"></span></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 300, 100) or { panic('layout') }
		node := end_marker_node(result.root, 'abs') or { panic('abs') }
		used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('used') }
		assert used.static_position().x().to_double() == expected
	}
}

fn test_static_marker_after_nested_inline_end_edges() {
	check_empty_pseudo_inline_end_marker('', 26)
}

fn test_static_marker_after_empty_generated_inline_end_edges() {
	check_empty_pseudo_inline_end_marker('#inner::after { content:"" }', 26)
}

fn test_static_marker_includes_the_empty_pseudo_elements_own_end_edges() {
	check_empty_pseudo_inline_end_marker('#inner::after { content:""; padding-right:5px; border-right:2px solid; margin-right:3px }', 36)
}
