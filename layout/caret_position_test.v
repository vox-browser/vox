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
