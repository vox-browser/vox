// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module layout

import dom
import html

fn button_overflow_baseline_node(result DocumentLayoutResult, id string) &Node {
	element := result.document.get_element_by_id(id) or { panic('missing ${id}') }
	bridge := element.as_node().layout_node() or { panic('missing layout') }
	return unsafe { &Node(bridge.layout_handle) }
}

// Ladybird a8cff13249e769020c4c102fdec51a9cf9dd1ac2, including the
// border-edge clamp added after the first version was reverted.
fn test_button_hidden_overflow_keeps_the_visible_text_baseline() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;font:16px/20px monospace}button{font:inherit;padding:4px 8px;border:2px solid;margin-bottom:13px}
			</style><button id="visible">terms</button><button id="hidden" style="overflow:hidden">terms</button>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		result := run_document_layout(document, 800, 600) or { panic('layout') }
		visible := button_overflow_baseline_node(result, 'visible')
		hidden := button_overflow_baseline_node(result, 'hidden')
		assert layout_box_baseline(result.state, visible, .last) == layout_box_baseline(result.state, hidden, .last)
	}
}

fn test_hidden_button_content_baselines_stay_inside_its_border_edges() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;font:16px/20px monospace}button{font:inherit;overflow:hidden;padding:0;border:2px solid;margin-bottom:13px}
		.short{height:30px;width:40px}.raised{height:30px}.raised span{display:block;margin-top:-80px}
		</style><button id="short" class="short">one two three four</button>
		<button id="raised" class="raised"><span>raised</span></button>')
	defer { document.finalize() }
	result := run_document_layout(document, 800, 600) or { panic('layout') }
	for id in ['short', 'raised'] {
		node := button_overflow_baseline_node(result, id)
		used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('used') }
		for preference in [BaselineSet.first, .last] {
			baseline := layout_box_baseline(result.state, node, preference)
			assert baseline.raw_value() >= used.margin_top.raw_value()
			assert baseline.raw_value() <= used.margin_top.plus(used.border_box_height()).raw_value()
		}
	}
}
