module layout

import dom
import html

fn float_flow_handle(document &dom.Document, id string) voidptr {
	element := document.get_element_by_id(id) or { panic('missing owner') }
	return element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()
}

fn float_flow_compare_full(mut document dom.Document) {
	before := document.record_display_list() or { panic('missing paint') }.dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert document.record_display_list() or { panic('missing rebuilt paint') }.dump() == before
}

fn test_retained_comment_float_tree_replays_incoming_float_bands_and_clearing() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="width:220px"><div id="vote" style="float:left;width:14px;height:30px">vote</div><div style="overflow:hidden"><p>Unchanged comment with enough text to wrap beside a vote column.</p></div><div style="clear:both"></div></section><p>Following content</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut changed := document.get_element_by_id('changed')?
	for content in [
		'<div style="float:left;width:60px;height:120px">preceding float</div>',
		'<p>Expanded preceding comment</p>',
		'',
	] {
		before := float_flow_handle(document, 'stable')
		vote := float_flow_handle(document, 'vote')
		changed.set_inner_html(content)!
		document.update_layout(.debugging)
		assert float_flow_handle(document, 'stable') == before
		assert float_flow_handle(document, 'vote') == vote
		float_flow_compare_full(mut document)
	}
}

fn test_retained_float_tree_rechecks_available_width_float_side_and_normal_flow_role() {
	mut document := html.parse_document('<!doctype html><div id="parent" style="width:240px"><section id="stable"><div id="vote" style="float:left;width:35%;height:40px">vote</div><p>Comment wraps around this floating column.</p></section></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut parent := document.get_element_by_id('parent')?
	for width in ['120px', '300px'] {
		parent.set_attribute_value('style', 'width:' + width)
		document.update_layout(.debugging)
		float_flow_compare_full(mut document)
	}
	mut vote := document.get_element_by_id('vote')?
	for style in ['float:right;width:40%;height:60px', 'float:none;width:60%;height:20px',
		'float:left;width:25%;height:50px'] {
		vote.set_attribute_value('style', style)
		document.update_layout(.debugging)
		float_flow_compare_full(mut document)
	}
}
