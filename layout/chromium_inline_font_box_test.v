module layout

import css
import html

fn font_box_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() { if found := font_box_node(child, id) { return found } }
	return none
}

fn check_inline_font_box(content string, leading int, padded bool) {
	padding := if padded { 'padding:3px;border:1px solid' } else { '' }
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:20px/${leading}px Arial}#host{position:relative;${padding}}.atomic{display:inline-block;width:20px}</style><div id="row"><span id="host">${content}</span></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 300, 100) or { panic('layout') }
	row := font_box_node(result.root, 'row') or { panic('row') }
	host := font_box_node(result.root, 'host') or { panic('host') }
	used := result.used_values_for(row.as_node_with_style() or { panic('style') }) or { panic('used') }
	metrics := layout_font_metrics_for_node(host)
	expected := CSSPixels.nearest_value_for(f64(metrics.ascent + metrics.descent)).plus(CSSPixels.new(if padded { 8 } else { 0 }))
	mut found := false
	for piece in compute_inline_box_pieces(row, used, result.state) {
		if voidptr(piece.node) == voidptr(host) {
			found = true
			assert piece.border_box_rect.height == expected
		}
	}
	assert found
}

fn test_chromium_inline_font_box_does_not_take_atomic_child_height() {
	for height in [10, 30] { check_inline_font_box('<i class="atomic" style="height:${height}px"></i>', 20, false) }
}

fn test_chromium_inline_font_box_ignores_leading_and_keeps_padding() {
	check_inline_font_box('<i class="atomic" style="height:10px"></i>', 40, true)
}

fn test_chromium_nested_inlines_keep_their_own_font_boxes() {
	check_inline_font_box('<span><i class="atomic" style="height:30px"></i></span>', 40, false)
	check_inline_font_box('<span style="font-size:40px">Text</span>', 40, false)
}

fn test_libweb_keeps_its_fragment_based_inline_box_height() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:20px/40px Arial}#host{padding:3px;border:1px solid}</style><div id="row"><span id="host"><i style="display:inline-block;width:20px;height:10px"></i></span></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 300, 100) or { panic('layout') }
	row := font_box_node(result.root, 'row') or { panic('row') }
	host := font_box_node(result.root, 'host') or { panic('host') }
	used := result.used_values_for(row.as_node_with_style() or { panic('style') }) or { panic('used') }
	mut found := false
	for piece in compute_inline_box_pieces(row, used, result.state) {
		if voidptr(piece.node) == voidptr(host) {
			found = true
			assert piece.border_box_rect.height == css.CSSPixels.new(18)
		}
	}
	assert found
}

fn inline_font_box_y_before_clearance(float_height int) CSSPixels {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:20px/20px Arial}#float{float:left;width:20px;height:${float_height}px}#host{border:1px solid}</style><div id="row"><i id="float"></i><span id="host">A</span><br style="clear:both">B</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 300, 140) or { panic('layout') }
	row := font_box_node(result.root, 'row') or { panic('row') }
	host := font_box_node(result.root, 'host') or { panic('host') }
	used := result.used_values_for(row.as_node_with_style() or { panic('style') }) or { panic('used') }
	for piece in compute_inline_box_pieces(row, used, result.state) {
		if voidptr(piece.node) == voidptr(host) { return piece.border_box_rect.y }
	}
	panic('missing inline piece')
}

fn test_inline_font_box_does_not_move_when_a_following_break_clears_a_float() {
	assert inline_font_box_y_before_clearance(80) == inline_font_box_y_before_clearance(0)
}
