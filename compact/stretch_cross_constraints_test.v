module main

import html
import layout

fn test_stretch_cross_constraints_follow_final_flex_lines() {
	for axis in ['row', 'column'] {
		vertical := axis == 'column'
		cross := if vertical { 'width' } else { 'height' }
		main_axis :=  if vertical { 'height' } else { 'width' }
		margins := if vertical { 'margin-left:2px;margin-right:3px' } else { 'margin-top:2px;margin-bottom:3px' }
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{display:inline-flex;flex-flow:${axis} wrap;${main_axis}:40px;${cross}:50px}#target{${main_axis}:20px;${cross}:55px;max-${cross}:stretch;${margins};border:3px solid;padding:2px}#tall{${cross}:60px;${main_axis}:0}</style><div id="cb"><div id="target"></div><div id="tall"></div></div>')
		_ = layout.layout_document_typed_in_viewport(document, 400, 300)
		r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
		actual := if vertical { r.width } else { r.height }
		assert actual == 55, '${axis}: ${actual}'
		document.finalize()
	}
}

fn test_automatic_flex_stretch_maximum_resolves_against_its_containing_block() {
	for example in [
		['height:100px', 'margin:0', '100'],
		['height:100%', 'margin:0', '120'],
		['height:auto', 'margin:0', '120'],
	] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{${example[0]}}#target{display:flex;max-height:stretch;${example[1]}}#content{height:120px}</style><div id="cb"><div id="target"><div id="content"></div></div></div>')
		_ = layout.layout_document_typed_in_viewport(document, 400, 300)
		r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
		assert r.height == example[2].f64(), '${example}: ${r.height}'
		document.finalize()
	}
}

fn test_stretch_width_in_intrinsic_column_measurement_contributes_its_contents() {
	for wide in [false, true] {
		middle := if wide { '<div style="width:150px"></div>' } else { '' }
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{display:flex;flex-flow:column wrap;width:min-content;max-width:100px;height:100px;align-content:start}#cb>div{border:3px solid}.target{height:75px;width:stretch}.target span{display:inline-block;width:20px;height:20px}</style><div id="cb"><div id="first" class="target"><span></span></div>${middle}<div id="second" class="target"><span></span></div></div>')
		_ = layout.layout_document_typed_in_viewport(document, 400, 300)
		first := (document.get_element_by_id('first') or { panic('first') }).get_bounding_client_rect()
		second := (document.get_element_by_id('second') or { panic('second') }).get_bounding_client_rect()
		assert first.width == if wide { 156 } else { 26 }, '${wide}: ${first.width}'
		assert second.width == if wide { 100 } else { 26 }, '${wide}: ${second.width}'
		document.finalize()
	}
}

fn test_stretch_uses_constrained_automatic_single_flex_line_height() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{display:flex;width:100px;max-height:100px}.target{flex:none;margin:5px;border:3px solid;padding:2px}#preferred{height:stretch}#minimum{height:0;min-height:stretch}#maximum{height:500px;max-height:stretch}</style><div id="cb"><div id="preferred" class="target">X X</div><div id="minimum" class="target">X X</div><div id="maximum" class="target">X X</div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	for id in ['preferred', 'minimum', 'maximum'] {
		r := (document.get_element_by_id(id) or { panic(id) }).get_bounding_client_rect()
		assert r.height == 90, '${id}: ${r.height}'
	}
}

fn test_stretch_margin_edge_checks_skip_anonymous_block_wrappers() {
	for bordered in [false, true] {
		border := if bordered { 'border:3px solid' } else { '' }
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{height:100px;width:100px;${border}}#target{height:stretch;margin:25px}</style><div id="cb"><div></div><span><div id="target"></div></span></div>')
		_ = layout.layout_document_typed_in_viewport(document, 400, 300)
		r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
		assert r.height == if bordered { 50 } else { 100 }, '${border}: ${r.height}'
		document.finalize()
	}
}

fn test_fixed_minimum_wins_over_stretch_maximum() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{height:50px}#target{height:20px;min-height:70px;max-height:stretch}</style><div id="cb"><div id="target"></div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
	assert r.height == 70, '${r.height}'
}

fn test_absolute_stretch_uses_static_rectangle_alignment_across_writing_modes() {
	for outer in ['vertical-rl', 'vertical-lr'] {
		for inner in ['vertical-rl', 'vertical-lr'] {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{position:relative;writing-mode:${outer};width:60px;height:46px}#parent{writing-mode:horizontal-tb;width:100%;height:100%}#target{position:absolute;writing-mode:${inner};block-size:stretch;inline-size:20px;margin-block:2px 3px;border:3px solid;padding:2px}</style><div id="cb"><div id="parent"><div id="target"></div></div></div>')
			_ = layout.layout_document_typed_in_viewport(document, 400, 300)
			r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
			assert r.width == 55, '${outer}, ${inner}: ${r.width}'
			document.finalize()
		}
	}
}

fn test_stretch_block_axis_ignores_margins_at_unbordered_non_bfc_parent_edges() {
	for vertical in [false, true] {
		axis := if vertical { 'width' } else { 'height' }
		mode := if vertical { 'vertical-rl' } else { 'horizontal-tb' }
		for edge in ['', 'border-top:5px solid', 'border-right:5px solid', 'display:flow-root'] {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{writing-mode:${mode};width:50px;height:50px;${edge}}#target{${axis}:stretch;margin:1px 3px 5px 7px}</style><div id="cb"><div id="target"></div></div>')
			_ = layout.layout_document_typed_in_viewport(document, 400, 300)
			r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
			actual := if vertical { r.width } else { r.height }
			expected := if edge == 'display:flow-root' { if vertical { 40 } else { 44 } }
				else if vertical && edge == 'border-right:5px solid' { 47 }
				else if !vertical && edge == 'border-top:5px solid' { 49 }
				else { 50 }
			assert actual == expected, '${mode}, ${edge}: ${actual}'
			document.finalize()
		}
	}
}

fn test_wrapping_column_stretch_contributes_container_width_before_final_line_sizing() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{display:flex;flex-flow:column wrap;width:100px;height:100px;align-content:start}#cb>div{height:75px;border:3px solid;width:stretch}</style><div id="cb"><div id="first">a</div><div id="second">b</div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	for id in ['first', 'second'] {
		r := (document.get_element_by_id(id) or { panic(id) }).get_bounding_client_rect()
		assert r.width == 100, '${id}: ${r.width}'
	}
}
