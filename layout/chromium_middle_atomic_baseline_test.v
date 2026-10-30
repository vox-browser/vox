module layout

import css
import html
import platform

fn test_chromium_middle_alignment_retains_odd_subpixels_in_the_box_height() {
	mut document := html.parse_document('<!doctype html><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	for pair in [[1485, -743], [1565, -783], [1280, -640]] {
		offset := middle_alignment_offset(result.root, CSSPixels.new(0), CSSPixels.new(0),
			CSSPixels.from_raw(pair[0]), 0)
		assert offset == CSSPixels.from_raw(pair[1])
	}
}

fn test_chromium_middle_inline_text_does_not_export_its_face_baseline_to_the_parent_line() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><style>
		body { margin:0; font:16px/1.45em "Helvetica Neue", Arial, sans-serif }
		span { font-weight:bold; vertical-align:middle }
	</style><div id="direct"><span>Story title</span></div>
	<div id="nested"><span><a>Story title</a></span></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	mut pending := [result.root]
	mut checked := 0
	for pending.len > 0 {
		node := pending.pop()
		if source := node.dom_node() {
			if element := source.as_element() {
				if element.get_attribute_value('id') in ['direct', 'nested'] {
					styled := node.as_node_with_style() or { panic('missing style') }
					used := result.used_values_for(styled) or { panic('missing used values') }
					assert used.line_boxes.len == 1
					// Brave keeps the regular 16px face's parent baseline at 17px.
					// The bold middle-aligned run has an 18px face baseline.
					assert used.line_boxes[0].baseline() == css.CSSPixels.new(17)
					checked++
				}
			}
		}
		pending << node.children()
	}
	assert checked == 2
}

fn test_chromium_middle_atomic_boxes_do_not_raise_the_line_by_their_internal_baseline() {
	font := platform.document_font_path(400) or { panic('missing fixture font') }
	mut document := html.parse_document('<!doctype html><style>
		@font-face { font-family:Fixture; src:url("file://${font}") }
		body { margin:0; font:16px/20px Fixture }
		.box { display:inline-block; width:40px; height:40px; vertical-align:middle }
		#content .box { font:64px/80px Fixture }
		#baseline .box { vertical-align:baseline }
	</style><div id="empty">A<span class="box"></span>B</div>
	<div id="content">A<span class="box">X</span>B</div>
	<div id="baseline">A<span class="box"></span>B</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	mut lines := map[string]&UsedValues{}
	mut pending := [result.root]
	for pending.len > 0 {
		node := pending.pop()
		if source := node.dom_node() {
			if element := source.as_element() {
				id := element.get_attribute_value('id')
				if id in ['empty', 'content', 'baseline'] {
					styled := node.as_node_with_style() or { panic('missing style') }
					lines[id] = result.used_values_for(styled) or { panic('missing used values') }
				}
			}
		}
		pending << node.children()
	}
	empty := lines['empty'] or { panic('missing empty line') }
	content := lines['content'] or { panic('missing content line') }
	baseline := lines['baseline'] or { panic('missing baseline line') }
	assert empty.line_boxes.len == 1
	assert content.line_boxes.len == 1
	// Middle uses the margin-box midpoint and the parent's x-height. Its own
	// bottom-edge fallback or overflowing text baseline cannot change that.
	assert empty.content_height() == css.CSSPixels.new(40)
	assert content.content_height() == css.CSSPixels.new(40)
	assert empty.line_boxes[0].baseline() == content.line_boxes[0].baseline()
	// A baseline-aligned atomic box does export its own bottom-edge baseline.
	assert baseline.content_height().to_double() > 40
}
