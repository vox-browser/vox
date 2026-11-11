module layout

import dom
import html

fn test_document_caret_position_from_point_returns_text_offset_and_client_rect() {
	document := html.parse_document('<!doctype html><style>html,body,p{margin:0}</style><p id="text">Hello</p>')
	_ = layout_document_typed_in_viewport(document, 200, 100)
	mut mutable_document := unsafe { &dom.Document(document) }

	assert mutable_document.caret_position_from_point(-1, 0) == none
	assert mutable_document.caret_position_from_point(201, 0) == none
	position := mutable_document.caret_position_from_point(1, 8) or {
		panic('missing caret position')
	}
	assert position.offset_node().is_text()
	assert position.offset() == 0
	client_rect := position.get_client_rect() or { panic('missing caret client rect') }
	assert client_rect.width == 1
	assert client_rect.height > 0
}

fn test_caret_inside_nested_inline_block_padding_uses_its_own_text() {
	mut document := html.parse_document('<!doctype html><style>body{font:20px serif;margin:20px}span.box{border:2px solid black;padding:40px;display:inline-block}</style><span class="box" id="outer">foo <span class="box" id="inner">bar</span></span>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	outer := document.get_element_by_id('outer')?
	inner := document.get_element_by_id('inner')?
	outer_rect := outer.get_bounding_client_rect()
	inner_rect := inner.get_bounding_client_rect()
	outer_text := outer.as_node().first_child()?
	inner_text := inner.as_node().first_child()?
	left := document.caret_position_from_point(inner_rect.x + 10, inner_rect.y + inner_rect.height / 2)?
	assert left.offset_node() == inner_text
	assert left.offset() == 0
	right := document.caret_position_from_point(inner_rect.x + inner_rect.width - 10, inner_rect.y + inner_rect.height / 2)?
	assert right.offset_node() == inner_text
	assert right.offset() == 3
	above := document.caret_position_from_point(outer_rect.x + outer_rect.width - 10, outer_rect.y + 10)?
	assert above.offset_node() == outer_text
	assert above.offset() == 0
}

fn test_caret_in_wrapped_inline_block_padding_uses_the_continuation_offsets() {
	for mode in ['horizontal-tb', 'vertical-lr', 'vertical-rl'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:20px}#target{display:inline-block;font:20px/24px monospace;inline-size:70px;padding:30px;writing-mode:${mode}}</style><span id="target">first second third</span>')
		defer { document.finalize() }
		root := layout_document_typed_in_viewport(document, 800, 600)
		target := document.get_element_by_id('target')?
		text := target.as_node().first_child()?
		box := root.find_box(i64(target.as_node().unique_id()))?
		assert box.lines.len >= 2
		fragment := box.lines[1].fragments[0].paintable_fragment
		assert fragment.start_offset > 0
		rect := fragment.absolute_rect()
		border := box.border_box()
		before := if mode == 'horizontal-tb' {
			document.caret_position_from_point(border.x + 10, rect.y + rect.height / 2)?
		} else {
			document.caret_position_from_point(rect.x + rect.width / 2, border.y + 10)?
		}
		assert before.offset_node() == text
		assert before.offset() == u32(fragment.start_offset), '${mode}: ${before.offset()} != ${fragment.start_offset}'
		after := if mode == 'horizontal-tb' {
			document.caret_position_from_point(border.x + border.width - 10, rect.y + rect.height / 2)?
		} else {
			document.caret_position_from_point(rect.x + rect.width / 2, border.y + border.height - 10)?
		}
		assert after.offset_node() == text
		assert after.offset() == u32(box.lines[1].fragments.last().paintable_fragment.source_end_offset()), '${mode}: unexpected continuation end ${after.offset()}'
	}
}

fn test_document_caret_position_from_point_retargets_unlisted_shadow_root() {
	document := html.parse_document('<!doctype html><style>html,body,#host{margin:0}</style><div id="host"></div>')
	mut host := document.get_element_by_id('host') or { panic('missing host') }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	text := document.create_text_node('shadow text')
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(text.as_node()) or { panic(err) }
	_ = layout_document_typed_in_viewport(document, 200, 100)
	mut mutable_document := unsafe { &dom.Document(document) }

	retargeted := mutable_document.caret_position_from_point(1, 8) or {
		panic('missing retargeted caret position')
	}
	host_parent := host.as_node().parent() or { panic('host parent missing') }
	assert retargeted.offset_node() == host_parent
	assert retargeted.offset() == u32(host.as_node().index())

	exposed := mutable_document.caret_position_from_point(1, 8,
		dom.CaretPositionFromPointOptions{ shadow_roots: [shadow_root] }) or {
		panic('missing exposed caret position')
	}
	assert exposed.offset_node() == text.as_node()
}
