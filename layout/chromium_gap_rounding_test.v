module layout

import dom
import html

fn gap_rounding_used(document &dom.Document, result DocumentLayoutResult, id string) &UsedValues {
	element := document.get_element_by_id(id) or { panic('missing #${id}') }
	bridge := element.as_node().layout_node() or { panic('missing layout') }
	node := unsafe { &Node(bridge.layout_handle) }
	styled := node.as_node_with_style() or { panic('missing style') }
	return result.used_values_for(styled) or { panic('missing used values') }
}

fn test_chromium_fixed_gaps_truncate_after_resolving_relative_units() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for gap in ['3.9px', '.3em', '.24375rem'] {
			for display in ['flex', 'grid'] {
				mut document := html.parse_document('<!doctype html><style>
					html{font-size:16px}body{margin:0}
					#row{display:${display};font-size:13px;gap:${gap};width:100px;
						grid-template-columns:10px 10px;align-content:start}
					#row>div{width:10px;height:10px;flex:none}
				</style><div id="row"><div id="first"></div><div id="second"></div></div>')
				defer { document.finalize() }
				document.set_font_rendering_policy(policy)
				result := run_document_layout(document, 800, 600) or { panic('layout failed') }
				first := gap_rounding_used(document, result, 'first')
				second := gap_rounding_used(document, result, 'second')
				expected := if policy == .chromium { 3.890625 } else { 3.90625 }
				assert second.offset.x().minus(first.offset.x()).to_double() == 10 + expected
			}
		}
	}
}

fn test_chromium_column_gaps_match_end_aligned_shrink_to_fit_rows() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}#stats{display:flex;flex-direction:column;align-items:flex-end;width:108px}
			#row{display:flex;gap:.3em;font-size:13px;border:1px solid transparent}
			#row>div{height:17px;flex:none}#number{width:16.265625px}#unit{width:34px}
			#column{display:flex;flex-direction:column;height:100px;row-gap:3.9px}
			#column>div{width:10px;height:10px;flex:none}
		</style><div id="stats"><div id="row"><div id="number"></div><div id="unit"></div></div></div>
		<div id="column"><div id="top"></div><div id="bottom"></div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		row := gap_rounding_used(document, result, 'row')
		top := gap_rounding_used(document, result, 'top')
		bottom := gap_rounding_used(document, result, 'bottom')
		expected := if policy == .chromium { 3.890625 } else { 3.90625 }
		assert row.border_box_width().to_double() == 16.265625 + 34 + 2 + expected
		assert row.offset.x().to_double() == 108 - (16.265625 + 34 + 1 + expected)
		assert bottom.offset.y().minus(top.offset.y()).to_double() == 10 + expected
	}
}

fn test_gap_percentages_calculations_and_normal_keep_their_existing_resolution() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for gap in ['3.9%', 'calc(2px + 1.9%)', 'normal'] {
			mut document := html.parse_document('<!doctype html><style>
				body{margin:0}#row{display:flex;width:100px;column-gap:${gap}}
				#row>div{width:10px;height:10px;flex:none}
			</style><div id="row"><div id="first"></div><div id="second"></div></div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			result := run_document_layout(document, 800, 600) or { panic('layout failed') }
			first := gap_rounding_used(document, result, 'first')
			second := gap_rounding_used(document, result, 'second')
			expected := if gap == 'normal' { 0.0 } else { 3.890625 }
			assert second.offset.x().minus(first.offset.x()).to_double() == 10 + expected
		}
	}
}
