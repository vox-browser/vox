module html

import editing
import dom

fn test_paragraph_transfer_moves_children_and_removes_source() {
	document := parse_document('<!doctype html><body><div contenteditable><p id="source"><b>A</b>C</p><p id="destination">X</p></div></body>')
	source := document.get_element_by_id('source') or { panic('missing source') }
	destination := document.get_element_by_id('destination') or { panic('missing destination') }
	first := source.as_node().first_child() or { panic('missing first source child') }
	last := source.as_node().last_child() or { panic('missing last source child') }

	result := editing.transfer_paragraph_contents(source.as_node(), dom.BoundaryPoint{
		node: destination.as_node()
		offset: 1
	}, editing.ParagraphTransferOptions{})

	assert source.as_node().parent() == none
	assert destination.inner_html()! == 'X<b>A</b>C'
	assert result.first_node == first
	assert result.last_node == last
	assert result.start == dom.BoundaryPoint{ node: destination.as_node(), offset: 1 }
	assert result.end == dom.BoundaryPoint{ node: last, offset: 1 }
	assert result.destination_text_seam == none
}

fn test_paragraph_transfer_unwraps_source_at_destination_boundary() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable>A<p id="source"><b>B</b>C</p>D</div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	source := document.get_element_by_id('source') or { panic('missing source') }

	result := editing.transfer_paragraph_contents(source.as_node(), dom.BoundaryPoint{
		node: host.as_node()
		offset: source.as_node().index()
	}, editing.ParagraphTransferOptions{})

	assert host.inner_html()! == 'A<b>B</b>CD'
	assert result.start == dom.BoundaryPoint{ node: host.as_node(), offset: 1 }
	assert result.end.node.is_text()
	assert unsafe { &dom.Text(result.end.node) }.data() == 'C'
	assert result.end.offset == 1
}

fn test_paragraph_transfer_coalesces_destination_text_seam() {
	document := parse_document('<!doctype html><body><div contenteditable><p id="source">right<b>!</b></p><p id="destination">left</p></div></body>')
	source := document.get_element_by_id('source') or { panic('missing source') }
	destination := document.get_element_by_id('destination') or { panic('missing destination') }

	result := editing.transfer_paragraph_contents(source.as_node(), dom.BoundaryPoint{
		node: destination.as_node()
		offset: 1
	}, editing.ParagraphTransferOptions{
		seam: .coalesce_destination_text
	})

	assert destination.inner_html()! == 'leftright<b>!</b>'
	seam := result.destination_text_seam or { panic('missing text seam') }
	assert seam == dom.BoundaryPoint{ node: result.first_node, offset: 4 }
	assert result.start == seam
	assert result.end.node.is_text()
	assert unsafe { &dom.Text(result.end.node) }.data() == '!'
}

fn test_paragraph_transfer_applies_legacy_font_style_policy() {
	document := parse_document('<!doctype html><body><div contenteditable><p id="source"><font color="red">A</font></p><p id="destination"></p></div></body>')
	source := document.get_element_by_id('source') or { panic('missing source') }
	destination := document.get_element_by_id('destination') or { panic('missing destination') }

	_ := editing.transfer_paragraph_contents(source.as_node(), dom.BoundaryPoint{
		node: destination.as_node()
		offset: 0
	}, editing.ParagraphTransferOptions{
		source_style: .match_destination
	})

	assert destination.inner_html()! == 'A'
}
