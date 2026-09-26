module html

import editing
import dom

fn test_replacement_cleanup_coalesces_text_seams_and_preserves_inserted_range() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable>left<span id="marker"></span>tail</div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	marker := document.get_element_by_id('marker') or { panic('missing marker') }
	inserted_text := document.create_text_node('right')
	mut fragment := document.create_document_fragment()
	mut fragment_node := fragment.as_node()
	fragment_node.append_child(inserted_text.as_node()) or { panic(err) }
	mut content := editing.InsertedContent.new([inserted_text.as_node()])
	content.track_replacement_boundary(dom.BoundaryPoint{
		node: host.as_node()
		offset: marker.as_node().index()
	}, .inline_)
	host_node := host.as_node()
	content.insert_before(host_node, marker.as_node())
	content.begin_tracking_content_boundaries()
	mut marker_node := marker.as_node()
	marker_node.remove(false)
	assert host.inner_html()! == 'leftrighttail'

	end := editing.finalize_inserted_content(mut content, dom.BoundaryPoint{
		node: inserted_text.as_node()
		offset: inserted_text.length_in_utf16_code_units()
	})

	assert host.as_node().child_count() == 1
	assert inserted_text.data() == 'leftrighttail'
	assert content.start_boundary()? == dom.BoundaryPoint{
		node: inserted_text.as_node()
		offset: 4
	}
	assert end == dom.BoundaryPoint{ node: inserted_text.as_node(), offset: 9 }
	content.release()
}

fn test_replacement_cleanup_normalizes_only_interior_protected_spaces() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	inserted_text := document.create_text_node('\u00a0A\u00a0B\u00a0')
	mut fragment := document.create_document_fragment()
	mut fragment_node := fragment.as_node()
	fragment_node.append_child(inserted_text.as_node()) or { panic(err) }
	mut content := editing.InsertedContent.new([inserted_text.as_node()])
	host_node := host.as_node()
	content.insert_before(host_node, none)
	content.begin_tracking_content_boundaries()
	assert inserted_text.data() == '\u00a0A\u00a0B\u00a0'

	_ := editing.finalize_inserted_content(mut content, dom.BoundaryPoint{
		node: inserted_text.as_node()
		offset: inserted_text.length_in_utf16_code_units()
	})

	assert inserted_text.data() == '\u00a0A B\u00a0'
	content.release()
}

fn test_replacement_cleanup_merges_requested_end_text_seam() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><span id="marker"></span>tail</div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	marker := document.get_element_by_id('marker') or { panic('missing marker') }
	bold := document.create_element('b') or { panic(err) }
	first_text := document.create_text_node('first')
	mut bold_node := bold.as_node()
	bold_node.append_child(first_text.as_node()) or { panic(err) }
	last_text := document.create_text_node('last')
	mut fragment := document.create_document_fragment()
	mut fragment_node := fragment.as_node()
	fragment_node.append_child(bold.as_node()) or { panic(err) }
	fragment_node.append_child(last_text.as_node()) or { panic(err) }
	mut content := editing.InsertedContent.new([bold.as_node(), last_text.as_node()])
	host_node := host.as_node()
	content.insert_before(host_node, marker.as_node())
	content.begin_tracking_content_boundaries()
	mut marker_node := marker.as_node()
	marker_node.remove(false)
	assert host.inner_html()! == '<b>first</b>lasttail'
	content.require_end_text_seam_normalization()

	end := editing.finalize_inserted_content(mut content, dom.BoundaryPoint{
		node: last_text.as_node()
		offset: last_text.length_in_utf16_code_units()
	})

	assert host.inner_html()! == '<b>first</b>lasttail'
	assert end == dom.BoundaryPoint{ node: last_text.as_node(), offset: 4 }
	content.release()
}

fn test_replacement_cleanup_removes_empty_modifiable_containers() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	span := document.create_element('span') or { panic(err) }
	empty_bold := document.create_element('b') or { panic(err) }
	text := document.create_text_node('kept')
	mut span_node := span.as_node()
	span_node.append_child(empty_bold.as_node()) or { panic(err) }
	span_node.append_child(text.as_node()) or { panic(err) }
	mut fragment := document.create_document_fragment()
	mut fragment_node := fragment.as_node()
	fragment_node.append_child(span.as_node()) or { panic(err) }
	mut content := editing.InsertedContent.new([span.as_node()])
	host_node := host.as_node()
	content.insert_before(host_node, none)
	content.begin_tracking_content_boundaries()
	assert host.inner_html()! == '<span><b></b>kept</span>'

	_ := editing.finalize_inserted_content(mut content, dom.BoundaryPoint{
		node: text.as_node()
		offset: text.length_in_utf16_code_units()
	})

	assert span.inner_html()! == 'kept'
	assert empty_bold.as_node().parent() == none
	content.release()
}
