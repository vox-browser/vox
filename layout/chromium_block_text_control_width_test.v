module layout

import dom
import html

fn block_control_width_materialize(document &dom.Document) {
	controls := unsafe { &dom.ParentNode(document) }.query_selector_all('input,textarea') or {
		panic('missing controls')
	}
	for index in 0 .. controls.length() {
		node := controls.item(index) or { continue }
		element := node.as_element() or { continue }
		if element.local_name() == 'input' {
			_ = html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		} else {
			_ = html.HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) })
		}
	}
}

fn block_control_width_used(document &dom.Document, result DocumentLayoutResult, id string) &UsedValues {
	element := document.get_element_by_id(id) or { panic('missing control') }
	bridge := element.as_node().layout_node() or { panic('missing layout') }
	node := unsafe { &Node(bridge.layout_handle) }
	assert node.is_text_input_box() || node.is_textarea_box()
	styled := node.as_node_with_style() or { panic('missing style') }
	return result.used_values_for(styled) or { panic('missing used values') }
}

fn test_chromium_block_text_control_percentage_border_box_includes_each_edge_once() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for width in [320.0, 328.859375] {
			mut document := html.parse_document('<!doctype html><style>
				body {margin:0} #wrap {width:${width}px}
				input,textarea {display:block;width:100%;height:32px;
					box-sizing:border-box;border:1px solid;padding:6px 8px;font:13px Arial}
			</style><div id="wrap"><input id="input"><textarea id="area"></textarea></div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			block_control_width_materialize(document)
			result := run_document_layout(document, 800, 600) or { panic('layout failed') }
			for id in ['input', 'area'] {
				used := block_control_width_used(document, result, id)
				expected := width - if policy == .libweb { 2.0 } else { 0.0 }
				assert used.border_box_width().to_double() == expected
				assert used.content_width().to_double() == expected - 18
				assert used.border_box_height().to_double() == 32
			}
		}
	}
}

fn test_chromium_block_text_control_lengths_calc_and_min_max_use_the_complete_box_model() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><style>
			body {margin:0} #wrap {width:320px}
			input {display:block;width:100%;height:32px;
				box-sizing:border-box;border:1px solid;padding:6px 8px;font:13px Arial}
			#length {width:240px;border-width:4px}
			#clamp {min-width:260px;max-width:280px}
			#calc {width:calc(50% + 12px)}
			#content {width:240px;box-sizing:content-box}
		</style><div id="wrap"><input id="length"><input id="clamp"><input id="calc"><input id="content"></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		block_control_width_materialize(document)
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		for id, width in {
			'length':  240.0
			'clamp':   280.0
			'calc':    172.0
			'content': 258.0
		} {
			used := block_control_width_used(document, result, id)
			loss := if policy == .libweb && id != 'content' {
				if id == 'length' { 8.0 } else { 2.0 }
			} else {
				0.0
			}
			assert used.border_box_width().to_double() == width - loss
		}
	}
}

fn test_chromium_floating_text_control_matches_inline_flex_and_grid_widths() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for parent, child in {
			'':                                         'float:left'
			'display:flex':                             ''
			'display:grid;grid-template-columns:320px': ''
			'display:block':                            'display:inline-block'
		} {
			mut document := html.parse_document('<!doctype html><style>
				body {margin:0} #wrap {width:320px;${parent}}
				input {display:block;width:240px;height:32px;${child};
					box-sizing:border-box;border:4px solid;padding:6px 8px;font:13px Arial}
			</style><div id="wrap"><input id="input"></div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			block_control_width_materialize(document)
			result := run_document_layout(document, 800, 600) or { panic('layout failed') }
			used := block_control_width_used(document, result, 'input')
			expected := if parent == '' && policy == .libweb { 232.0 } else { 240.0 }
			assert used.border_box_width().to_double() == expected
			assert used.border_box_height().to_double() == 32
		}
	}
}

fn test_chromium_auto_block_text_controls_keep_their_intrinsic_content_width() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for tag in ['input', 'textarea'] {
			mut document := html.parse_document('<!doctype html><style>
				body {margin:0} input,textarea {width:auto;height:32px;
					box-sizing:border-box;border:4px solid;padding:6px 8px;font:13px monospace}
				#block {display:block} #inline {display:inline-block}
			</style><${tag} id="block" size="10" cols="10"></${tag}><${tag} id="inline" size="10" cols="10"></${tag}>')
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			block_control_width_materialize(document)
			result := run_document_layout(document, 800, 600) or { panic('layout failed') }
			block := block_control_width_used(document, result, 'block')
			inline_control := block_control_width_used(document, result, 'inline')
			expected := inline_control.border_box_width().to_double() - if policy == .libweb {
				24.0
			} else {
				0.0
			}
			assert block.border_box_width().to_double() == expected
		}
	}
}

fn test_block_text_control_minimum_border_and_padding_floor_does_not_underflow() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><style>
			input {display:block;width:10px;height:32px;
				box-sizing:border-box;border:8px solid;padding:12px;font:13px Arial}
		</style><input id="input">')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		block_control_width_materialize(document)
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		used := block_control_width_used(document, result, 'input')
		assert used.content_width().to_double() == 0
		assert used.border_box_width().to_double() == 40
	}
}

fn test_chromium_appearance_none_block_controls_keep_their_text_box_sizing() {
	mut document := html.parse_document('<!doctype html><style>
 body {margin:0} #wrap {width:320px}
 input,textarea {display:block;appearance:none;width:100%;height:32px;
 box-sizing:border-box;border:1px solid;padding:6px 8px;font:13px Arial}
 </style><div id="wrap"><input id="input"><textarea id="area"></textarea></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	block_control_width_materialize(document)
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	for id in ['input', 'area'] {
		used := block_control_width_used(document, result, id)
		assert used.border_box_width().to_double() == 320
	}
}
