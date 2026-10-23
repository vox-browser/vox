module html

import editing
import dom

fn attach_paragraph_integration_text_layout(node &dom.Node) {
	mut mutable_node := unsafe { &dom.Node(node) }
	mutable_node.set_layout_node(&dom.LayoutNode{
		is_text_node_: true
		visual_lines_data_: &dom.LayoutVisualLines{ values: [dom.VisualLine{
			start_offset: 0
			end_offset: node.length()
			end_offset_with_trailing_whitespace: node.length()
			has_fragments: true
			owner_paintable: u32(node.unique_id().value())
		}] }
	})
}

fn paragraph_integration_content(document &dom.Document, inserted &dom.Node) &editing.InsertedContent {
	parent := inserted.parent() or { panic('inserted paragraph has no parent') }
	for paragraph in parent.children_as_vector() {
		for child in paragraph.children_as_vector() {
			if child.is_text() {
				attach_paragraph_integration_text_layout(child)
			}
		}
	}
	mut content := editing.InsertedContent.new([inserted])
	content.begin_tracking_content_boundaries()
	return content
}

fn test_paragraph_integration_merges_both_ordinary_paragraph_seams() {
	document := parse_document('<!doctype html><body><div contenteditable><p>before</p><p id="inserted">middle</p><p>after</p></div></body>')
	inserted := document.get_element_by_id('inserted') or { panic('missing inserted paragraph') }
	mut content := paragraph_integration_content(document, inserted.as_node())
	integration := editing.ParagraphIntegration.new(document, content, editing.ParagraphBoundaryState{})

	decision := integration.decide()
	assert decision.merge_start
	assert decision.merge_end
	content.release()
}

fn test_paragraph_integration_respects_original_selection_edges() {
	document := parse_document('<!doctype html><body><div contenteditable><p>before</p><p id="inserted">middle</p><p>after</p></div></body>')
	inserted := document.get_element_by_id('inserted') or { panic('missing inserted paragraph') }
	mut content := paragraph_integration_content(document, inserted.as_node())
	integration := editing.ParagraphIntegration.new(document, content, editing.ParagraphBoundaryState{
		selection_start_was_start_of_paragraph: true
		selection_end_was_end_of_paragraph: true
	})

	decision := integration.decide()
	assert !decision.merge_start
	assert !decision.merge_end
	content.release()
}

fn test_paragraph_integration_rejects_blockquotes_and_heading_mismatches() {
	blockquote_document := parse_document('<!doctype html><body><div contenteditable><p>before</p><blockquote id="inserted">quote</blockquote><p>after</p></div></body>')
	blockquote := blockquote_document.get_element_by_id('inserted') or { panic('missing blockquote') }
	mut blockquote_content := paragraph_integration_content(blockquote_document, blockquote.as_node())
	blockquote_start := blockquote_content.start_boundary() or { panic('missing blockquote start') }
	assert voidptr(editing.block_node_of_node(blockquote_start.node)?) == voidptr(blockquote.as_node())
	assert (editing.block_node_of_node(blockquote_start.node)?.as_element() or {
		panic('blockquote block is not an element')
	}).local_name() == 'blockquote'
	blockquote_integration := editing.ParagraphIntegration.new(blockquote_document,
		blockquote_content, editing.ParagraphBoundaryState{})
	blockquote_decision := blockquote_integration.decide()
	assert !blockquote_decision.merge_start
	assert !blockquote_decision.merge_end
	blockquote_content.release()

	heading_document := parse_document('<!doctype html><body><div contenteditable><h1>before</h1><h2 id="inserted">middle</h2><h3>after</h3></div></body>')
	heading := heading_document.get_element_by_id('inserted') or { panic('missing heading') }
	mut heading_content := paragraph_integration_content(heading_document, heading.as_node())
	heading_integration := editing.ParagraphIntegration.new(heading_document, heading_content,
		editing.ParagraphBoundaryState{})
	heading_decision := heading_integration.decide()
	assert !heading_decision.merge_start
	assert !heading_decision.merge_end
	heading_content.release()
}

fn test_paragraph_integration_folds_empty_transport_block_at_start() {
	document := parse_document('<!doctype html><body><div contenteditable><p>before</p><p id="inserted"></p><p>after</p></div></body>')
	inserted := document.get_element_by_id('inserted') or { panic('missing inserted paragraph') }
	// NB: The fold requires a rendered position before the empty block to merge into.
	mut content := paragraph_integration_content(document, inserted.as_node())
	integration := editing.ParagraphIntegration.new(document, content, editing.ParagraphBoundaryState{})

	assert integration.decide().merge_start
	content.release()
}
