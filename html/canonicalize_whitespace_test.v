module html

import editing
import dom

fn test_canonicalize_whitespace_after_node_insertion_canonicalizes_inserted_text_seam() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable>a  b</div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	text_node := host.as_node().first_child() or { panic('missing text') }
	text := unsafe { &dom.Text(text_node) }

	editing.canonicalize_whitespace_after_node_insertion(dom.BoundaryPoint{
		node: text_node
		offset: 1
	})

	assert text.data() == 'a\u00a0 b'
}

fn test_canonicalize_whitespace_after_node_insertion_preserves_run_across_inline_node_boundary() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><span id="left">a </span> b</div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	left := document.get_element_by_id('left') or { panic('missing left span') }
	left_text := unsafe { &dom.Text(left.as_node().first_child() or { panic('missing left text') }) }
	right_text := unsafe { &dom.Text(host.as_node().last_child() or { panic('missing right text') }) }

	editing.canonicalize_whitespace_after_node_insertion(dom.BoundaryPoint{
		node: host.as_node()
		offset: 1
	})

	assert left_text.data() == 'a\u00a0'
	assert right_text.data() == ' b'
}

fn test_canonicalize_whitespace_after_node_insertion_stops_at_atomic_inserted_content() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><span id="left">a </span><img><span id="right"> b</span></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	left := document.get_element_by_id('left') or { panic('missing left span') }
	right := document.get_element_by_id('right') or { panic('missing right span') }
	left_text := unsafe { &dom.Text(left.as_node().first_child() or { panic('missing left text') }) }
	right_text := unsafe { &dom.Text(right.as_node().first_child() or { panic('missing right text') }) }

	editing.canonicalize_whitespace_after_node_insertion(dom.BoundaryPoint{
		node: host.as_node()
		offset: 1
	})

	assert left_text.data() == 'a\u00a0'
	assert right_text.data() == ' b'
}

fn test_canonicalize_whitespace_after_node_insertion_leaves_preserved_space_unchanged() {
	mut document := parse_document('<!doctype html><body><div id="host" contenteditable style="white-space-collapse: preserve">a  b</div></body>')
	// NB: Resolved style is only computed for documents with a browsing context.
	document.set_browsing_context(&dom.BrowsingContext{})
	host := document.get_element_by_id('host') or { panic('missing host') }
	text_node := host.as_node().first_child() or { panic('missing text') }
	text := unsafe { &dom.Text(text_node) }

	editing.canonicalize_whitespace_after_node_insertion(dom.BoundaryPoint{
		node: text_node
		offset: 1
	})

	assert text.data() == 'a  b'
}
