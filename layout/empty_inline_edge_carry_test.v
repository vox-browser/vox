module layout

import html

fn carry_inline_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() { if found := carry_inline_node(child, id) { return found } }
	return none
}

fn check_empty_inline_carry(tail string, expected f64) {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:16px/20px Arial}#outer{border-right:1px solid;margin-right:3px}#inner{padding-right:10px}#atomic{display:inline-block;width:12px;height:10px}#abs{position:absolute;width:5px;height:5px}</style><div style="position:relative"><span id="outer"><span id="inner"><i id="atomic"></i>${tail}</span></span><span id="abs"></span></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 300, 100) or { panic('layout') }
	node := carry_inline_node(result.root, 'abs') or { panic('abs') }
	used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('used') }
	assert used.static_position().x().to_double() == expected
}

fn test_empty_inline_children_keep_enclosing_end_edges_before_static_positions() {
	for tail in ['<span></span>', '<span> </span>', '<span><span></span></span>', '<span></span> \n'] {
		check_empty_inline_carry(tail, 26)
	}
}

fn test_empty_inline_children_keep_their_own_opening_and_closing_edges() {
	check_empty_inline_carry('<span style="padding-left:4px;padding-right:5px;border-right:2px solid;margin-right:3px"></span>', 40)
}

fn test_skipped_inline_edges_do_not_retroactively_move_a_previous_absolute_marker() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:16px/20px Arial}#outer{padding-right:14px}#atomic{display:inline-block;width:12px;height:10px}#abs{position:absolute;width:5px;height:5px}</style><div style="position:relative"><span id="outer"><i id="atomic"></i><span id="abs"></span><span></span></span></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 300, 100) or { panic('layout') }
	node := carry_inline_node(result.root, 'abs') or { panic('abs') }
	used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('used') }
	assert used.static_position().x().to_double() == 12
}

fn test_carried_inline_edges_participate_in_the_following_tab_stop() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:16px/20px Arial}#flow{white-space:pre;tab-size:40px}#outer{border-right:1px solid;margin-right:3px}#inner{padding-right:10px}#atomic{display:inline-block;width:12px;height:10px}#next{display:inline-block;width:5px;height:5px}</style><div id="flow"><span id="outer"><span id="inner"><i id="atomic"></i><span></span></span></span>\t<i id="next"></i></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 300, 100) or { panic('layout') }
	node := carry_inline_node(result.root, 'next') or { panic('next') }
	used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('used') }
	assert used.offset.x().to_double() == 40
}
