module html

import editing
import dom

fn test_inserted_content_tracks_insertion_and_semantic_boundaries() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable>before <span id="reference">after</span></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	reference := document.get_element_by_id('reference') or { panic('missing reference') }
	mut range := document.create_range()
	range.set_start_before(reference.as_node()) or { panic(err) }
	range.set_end_before(reference.as_node()) or { panic(err) }
	replacement := editing.ReplacementFragment.new(range, '<b>one</b><img>') or { panic(err) }
	mut content := editing.InsertedContent.new(replacement.children())
	content.track_replacement_boundary(range.start(), .inline_)

	mut host_node := host.as_node()
	content.insert_before(mut host_node, reference.as_node())
	content.begin_tracking_content_boundaries()

	assert content.nodes().len == 2
	assert content.text_nodes().len == 1
	assert content.insertion_was_inside_paragraph()
	assert content.insertion_was_after_whitespace()
	assert content.insertion_boundary()?.node == host.as_node()
	assert content.insertion_boundary()?.offset == 1
	assert content.start_boundary()?.node.is_text()
	assert content.start_boundary()?.offset == 0
	assert content.end_boundary()?.node == host.as_node()
	assert content.end_boundary()?.offset == reference.as_node().index()

	content.begin_completion(content.end_boundary()?)
	assert content.completion_start_boundary()? == content.start_boundary()?
	content.require_end_text_seam_normalization()
	assert content.should_normalize_end_text_seam()
	content.release()
}

fn test_end_boundary_of_node_handles_text_placeholder_break_and_atomic_content() {
	document := parse_document('<!doctype html><body><div id="host"><p>text<br></p><img></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	paragraph := host.as_node().first_child() or { panic('missing paragraph') }
	text := paragraph.first_child() or { panic('missing text') }
	image := host.as_node().last_child() or { panic('missing image') }

	assert editing.end_boundary_of_node(text) == dom.BoundaryPoint{ node: text, offset: 4 }
	assert editing.end_boundary_of_node(paragraph) == dom.BoundaryPoint{
		node: paragraph
		offset: 1
	}
	assert editing.end_boundary_of_node(image) == dom.BoundaryPoint{
		node: host.as_node()
		offset: 2
	}
}
