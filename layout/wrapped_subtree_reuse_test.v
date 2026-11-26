module layout

import dom
import html
import os

fn wrapped_subtree_handle(document &dom.Document, id string) voidptr {
	element := document.get_element_by_id(id) or { panic(id) }
	node := element.as_node()
	mirror := node.unsafe_layout_node() or { panic('layout') }
	return mirror.real_layout_handle()
}

fn wrapped_subtree_matches_full_rebuild(mut document dom.Document) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before
}

// An inline-level box that the previous build placed in the anonymous block
// wrapping an inline run beside block siblings keeps its boxes when a change
// in a sibling rebuilds the parent, which wraps it again.
fn test_inline_boxes_in_mixed_content_wrappers_keep_their_boxes() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:16px/20px sans-serif}</style><body><div id="parent"><p id="changed">first</p><span id="kept" style="display:inline-block">kept <b id="bold">bold</b></span> trailing text<p>after</p></div></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	keeps := os.getenv('VOX_RETAIN_WRAPPED_SUBTREE_REBUILDS') == ''
	for index in 0 .. 2 {
		kept := wrapped_subtree_handle(document, 'kept')
		bold := wrapped_subtree_handle(document, 'bold')
		mut changed := document.get_element_by_id('changed') or { panic('changed') }
		changed.set_inner_html('<em>changed ${index}</em> line<br>second') or { panic(err) }
		document.update_layout(.debugging)
		assert (wrapped_subtree_handle(document, 'kept') == kept) == keeps, 'pass ${index}'
		// Its descendants keep theirs either way.
		assert wrapped_subtree_handle(document, 'bold') == bold, 'pass ${index}'
		box := unsafe { &Node(wrapped_subtree_handle(document, 'kept')) }
		wrapper := box.parent() or { panic('wrapper') }
		assert wrapper.is_anonymous()
		wrapped_subtree_matches_full_rebuild(mut document)
	}
}
