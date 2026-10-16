module layout

import html

fn select_layout_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := select_layout_node(child, id) {
			return found
		}
	}
	return none
}

fn select_used_height(result DocumentLayoutResult, node &Node) f64 {
	styled := node.as_node_with_style() or { panic('no style') }
	used := result.used_values_for(styled) or { panic('no used values') }
	return used.content_height().to_double()
}

// HTMLSelectElement's UA wrapper fills the select (height: 100%) so its label
// is centered in a select taller than the label's line.
fn test_select_label_wrapper_fills_the_select() {
	document := html.parse_document('<!doctype html><style>body { margin:0 }
		select { height:60px; appearance:none; border:0; padding:0; margin:0 }</style>
		<select id="tall"><option>English</option></select>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	select_node := select_layout_node(result.root, 'tall') or { panic('missing select') }
	assert select_used_height(result, select_node) == 60
	assert select_node.children().len > 0
	assert select_used_height(result, select_node.children()[0]) == 60
}

// Chromium applies an author line-height to the select's label; Ladybird
// forces line-height: normal on selects.
fn test_browser_select_keeps_author_line_height() {
	$if macos {
		mut document := html.parse_document('<!doctype html><style>body { margin:0; font:14px system-ui }
			select { line-height:40px; appearance:none; border:0; padding:0; margin:0 }</style>
			<select id="lined"><option>English</option></select>')
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		select_node := select_layout_node(result.root, 'lined') or { panic('missing select') }
		assert select_used_height(result, select_node) == 40
	}
}
