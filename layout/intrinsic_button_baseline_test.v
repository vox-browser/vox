module layout

import html

fn intrinsic_button_node(result DocumentLayoutResult, id string) &Node {
	element := result.document.get_element_by_id(id) or { panic('missing ${id}') }
	bridge := element.as_node().layout_node() or { panic('missing layout') }
	return unsafe { &Node(bridge.layout_handle) }
}

fn test_intrinsic_inline_button_baseline_does_not_inflate_a_flex_description() {
	mut document := html.parse_document('<!doctype html><style>
 body{margin:0;font:16px/24px "Times New Roman"}
 #row{display:flex;width:500px}#column{display:flex;flex-direction:column;width:100%}
 #description{flex:1 1 auto;padding-bottom:10px}button{font:inherit;border:0;padding:0}
 .part{display:contents}</style><div id="row"><div id="column"><div id="description">
 <div id="text"><div class="part">First </div><button>228</button><div class="part"> partners<br>Second line</div></div>
 </div></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for _ in 0 .. 2 {
		result := run_document_layout(document, 1024, 768) or { panic('layout failed') }
		for id in ['description', 'text'] {
			node := intrinsic_button_node(result, id)
			used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('used') }
			assert used.content_height().to_double() == 48
		}
	}
}

fn test_intrinsic_block_flex_retains_both_baselines_after_discarding_text_lines() {
	for direction in ['row', 'column'] {
		mut document := html.parse_document('<!doctype html><style>
   body{margin:0;font:16px/24px monospace}
   #flex{display:flex;flex-direction:${direction};width:120px}
   </style><div id="flex"><div id="label">First<br>Last</div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 1024, 768) or { panic('layout failed') }
		node := intrinsic_button_node(result, 'flex')
		styled := node.as_node_with_style() or { panic('style') }
		first := layout_box_baseline(result.state, node, .first)
		last := layout_box_baseline(result.state, node, .last)
		assert first != last
		mut source := result.state
		mut probe := source.new_measurement_for_subtree(styled)
		defer { probe.release_measurement() }
		populate_intrinsic_containing_block_chain(mut probe, mut source, node)
		mut values := probe.get_mutable(styled)
		values.set_content_width(CSSPixels.new(120))
		values.set_has_definite_width(true)
		values.set_indefinite_content_height()
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(120)), AvailableSize.make_indefinite())
		_ = run_flex_formatting_context_with_mode(mut probe, node, mut values, .intrinsic_sizing, space)
		assert layout_box_baseline(probe, node, .first) == first
		assert layout_box_baseline(probe, node, .last) == last
		label := intrinsic_button_node(result, 'label').as_node_with_style() or { panic('label') }
		assert probe.get(label).line_boxes.len == 0
		assert values.derived_first_baseline() != none
		_ = run_flex_formatting_context_with_mode(mut probe, node, mut values, .normal, space)
		assert values.derived_first_baseline() == none
		assert layout_box_baseline(probe, node, .first) == first
	}
}

fn test_discarding_nested_normal_flex_and_grid_lines_keeps_their_baselines() {
	for display in ['flex', 'grid'] {
		mut document := html.parse_document('<!doctype html><style>
   body{margin:0;font:16px/24px monospace}#outer{display:flex}
   #nested{display:${display};width:120px}
		</style><div id="outer"><div id="wrapper"><div id="nested"><div>First<br>Last</div></div></div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 1024, 768) or { panic('layout failed') }
		node := intrinsic_button_node(result, 'nested')
		first := layout_box_baseline(result.state, node, .first)
		last := layout_box_baseline(result.state, node, .last)
		wrapper := intrinsic_button_node(result, 'wrapper')
		wrapper_first := layout_box_baseline(result.state, wrapper, .first)
		wrapper_last := layout_box_baseline(result.state, wrapper, .last)
		mut source := result.state
		clear_intrinsic_flex_item_line_boxes(mut source, intrinsic_button_node(result, 'outer'))
		assert layout_box_baseline(source, node, .first) == first
		assert layout_box_baseline(source, node, .last) == last
		assert layout_box_baseline(source, wrapper, .first) == wrapper_first
		assert layout_box_baseline(source, wrapper, .last) == wrapper_last
	}
}
