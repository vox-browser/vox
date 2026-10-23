module html

import editing
import dom

fn mark_inserted_content_inline(element &dom.Element) {
	mut mutable_element := unsafe { &dom.Element(element) }
	mutable_element.set_computed_properties(none, &dom.CSSComputedProperties_{
		display_: dom.CSSDisplay_{
			is_inline_outside_: true
			is_flow_inside_: true
		}
	})
}

fn attach_rendered_text_for_inserted_content(text_node &dom.Node) {
	mut mutable_text_node := unsafe { &dom.Node(text_node) }
	mutable_text_node.set_layout_node(&dom.LayoutNode{
		is_text_node_: true
		visual_lines_data_: &dom.LayoutVisualLines{ values: [dom.VisualLine{
			start_offset: 0
			end_offset: text_node.length()
			end_offset_with_trailing_whitespace: text_node.length()
			has_fragments: true
			caret_stops: [dom.VisualCaretStop{ offset: 0, inline_coordinate: 0 }, dom.VisualCaretStop{
				offset: text_node.length()
				inline_coordinate: f64(text_node.length())
			}]
		}] }
	})
}

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
	// NB: Insertion topology is measured on visible positions, so give the destination text rendered lines.
	mark_inserted_content_inline(reference)
	attach_rendered_text_for_inserted_content(host.as_node().first_child() or { panic('missing leading text') })
	attach_rendered_text_for_inserted_content(reference.as_node().first_child() or {
		panic('missing reference text')
	})

	host_node := host.as_node()
	content.insert_before(host_node, reference.as_node())
	content.begin_tracking_content_boundaries()

	assert content.nodes().len == 2
	assert content.text_nodes().len == 1
	assert content.insertion_was_inside_paragraph()
	assert content.insertion_was_after_whitespace()
	assert voidptr(content.insertion_boundary()?.node) == voidptr(host.as_node())
	assert content.insertion_boundary()?.offset == 1
	assert content.start_boundary()?.node.is_text()
	assert content.start_boundary()?.offset == 0
	assert voidptr(content.end_boundary()?.node) == voidptr(host.as_node())
	assert content.end_boundary()?.offset == reference.as_node().index()

	content.begin_completion(content.end_boundary()?)
	completion_start := content.completion_start_boundary()?
	content_start := content.start_boundary()?
	assert voidptr(completion_start.node) == voidptr(content_start.node)
	assert completion_start.offset == content_start.offset
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

	text_end := editing.end_boundary_of_node(text)
	assert voidptr(text_end.node) == voidptr(text)
	assert text_end.offset == 4
	paragraph_end := editing.end_boundary_of_node(paragraph)
	assert voidptr(paragraph_end.node) == voidptr(paragraph)
	assert paragraph_end.offset == 1
	image_end := editing.end_boundary_of_node(image)
	assert voidptr(image_end.node) == voidptr(host.as_node())
	assert image_end.offset == 2
}
