// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module layout

import dom
import html

fn clear_without_clearance_values(result DocumentLayoutResult, id string) &UsedValues {
	element := result.document.get_element_by_id(id) or { panic('missing ${id}') }
	bridge := element.as_node().layout_node() or { panic('missing layout') }
	node := unsafe { &Node(bridge.layout_handle) }
	return result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('used') }
}

// Ladybird 78913d8979f6348ae571c86341846f63ac5b823b.
fn test_empty_clear_blocks_only_stop_margin_collapsing_after_actual_clearance() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for clear in ['', 'clear:both'] {
			mut document := html.parse_document('<!doctype html><style>
				body{margin:0}.box{height:20px}.empty{margin-top:8px;${clear}}
				</style><div id="container"><div class="box"></div><div class="empty"></div>
				<div class="empty"></div><div class="empty"></div>
				<div id="after" class="box" style="margin-top:24px"></div></div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			result := run_document_layout(document, 800, 600) or { panic('layout') }
			assert clear_without_clearance_values(result, 'after').cumulative_offset().y()
				.minus(clear_without_clearance_values(result, 'container').cumulative_offset().y()).to_double() == 44
		}
		mut document := html.parse_document('<!doctype html><style>body{margin:0}</style>
			<div id="container"><div style="float:left;width:50px;height:50px"></div>
			<div style="clear:both;margin-top:8px"></div><div id="after" style="height:20px"></div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		result := run_document_layout(document, 800, 600) or { panic('layout') }
		assert clear_without_clearance_values(result, 'after').cumulative_offset().y()
			.minus(clear_without_clearance_values(result, 'container').cumulative_offset().y()).to_double() == 50
	}
}
