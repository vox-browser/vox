module layout

import html
import dom

fn block_alignment_values(document &dom.Document, result DocumentLayoutResult, id string) &UsedValues {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	bridge := element.as_node().unsafe_layout_node() or { panic('missing bridge') }
	node := unsafe { &Node(bridge.real_layout_handle()) }
	styled := node.as_node_with_style() or { panic('missing style') }
	return result.used_values_for(styled) or { panic('missing values') }
}

fn test_block_align_content_centers_register_header_and_keeps_parent_size() {
	mut document := html.parse_document('<!doctype html><style>*{margin:0;padding:0}
		header{position:relative;height:70px;display:flex}
		figure{position:absolute;left:50%;height:100%;align-content:center;transform:translateX(-50%)}
		a{display:flex;align-items:center;height:44px;width:275px}i{display:block;width:200px;height:40px}
	</style><header><figure id="holder"><a id="link"><i id="logo"></i></a></figure></header>')
	defer { document.finalize() }
	for _ in 0 .. 2 {
		result := run_document_layout(document, 1024, 768) or { panic('layout failed') }
		assert block_alignment_values(document, result, 'holder').content_height().to_double() == 70
		assert block_alignment_values(document, result, 'link').offset.y().to_double() == 13
		assert block_alignment_values(document, result, 'logo').offset.y().to_double() == 2
	}
}

fn test_block_content_alignment_uses_single_subject_fallbacks_and_safe_overflow() {
	for align, expected in {'normal':0.0, 'start':0.0, 'stretch':0.0, 'space-between':0.0,
		'center':30.0, 'end':60.0, 'flex-end':60.0, 'space-around':30.0, 'space-evenly':30.0} {
		mut document := html.parse_document('<!doctype html><style>*{margin:0;padding:0}
			#outer{height:80px;align-content:${align}}#child{height:20px}</style>
			<div id="outer"><div id="child"></div></div>')
		result := run_document_layout(document, 400, 300) or { panic('layout failed') }
		assert block_alignment_values(document, result, 'child').offset.y().to_double() == expected
		document.finalize()
	}
	mut document := html.parse_document('<style>*{margin:0}#outer{height:20px;align-content:center}
		#child{height:80px}</style><div id="outer"><div id="child"></div></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 400, 300) or { panic('layout failed') }
	assert block_alignment_values(document, result, 'child').offset.y().to_double() == 0
}

fn test_block_content_alignment_contains_child_margins_and_keeps_explicit_abspos_insets() {
	mut document := html.parse_document('<!doctype html><style>*{margin:0;padding:0}
		#outer{position:relative;height:100px;align-content:center}
		#child{height:20px;margin:10px 0 6px}#absolute{position:absolute;top:3px;height:5px}
	</style><div id="outer"><div id="child"></div><div id="absolute"></div></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 400, 300) or { panic('layout failed') }
	assert block_alignment_values(document, result, 'child').offset.y().to_double() == 42
	assert block_alignment_values(document, result, 'absolute').offset.y().to_double() == 3
}

fn test_block_content_alignment_moves_inline_fragments_without_changing_line_height() {
	mut document := html.parse_document('<!doctype html><style>*{margin:0;padding:0}
		#outer{height:80px;align-content:center;font:20px/20px monospace}
	</style><div id="outer">Text</div>')
	defer { document.finalize() }
	result := run_document_layout(document, 400, 300) or { panic('layout failed') }
	values := block_alignment_values(document, result, 'outer')
	assert values.line_boxes.len == 1
	assert values.line_boxes[0].height().to_double() == 20
	assert values.line_boxes[0].bottom().to_double() == 50
}

fn test_block_content_alignment_contains_floats_and_does_not_enlarge_auto_height() {
	for height in [100, 0] {
		expected_height := if height > 0 { 100.0 } else { 20.0 }
		expected_y := if height > 0 { 40.0 } else { 0.0 }
		mut document := html.parse_document('<!doctype html><style>*{margin:0;padding:0}
			#outer{align-content:center;${if height > 0 { "height:100px" } else { "" }}}
			#float{float:left;width:20px;height:20px}
		</style><div id="outer"><div id="float"></div></div>')
		result := run_document_layout(document, 400, 300) or { panic('layout failed') }
		assert block_alignment_values(document, result, 'outer').content_height().to_double() == expected_height
		assert block_alignment_values(document, result, 'float').offset.y().to_double() == expected_y
		document.finalize()
	}
}

fn test_flow_root_content_alignment_uses_final_minimum_and_static_position() {
	mut document := html.parse_document('<!doctype html><style>*{margin:0;padding:0}
		#outer{display:flow-root;position:relative;min-height:70px;align-content:center}
		#child{height:20px}#absolute{position:absolute;height:3px}
	</style><div id="outer"><div id="child"></div><div id="absolute"></div></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 400, 300) or { panic('layout failed') }
	assert block_alignment_values(document, result, 'outer').content_height().to_double() == 70
	assert block_alignment_values(document, result, 'child').offset.y().to_double() == 25
	assert block_alignment_values(document, result, 'absolute').offset.y().to_double() == 45
}
