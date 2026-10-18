module layout

import dom
import html

fn retained_inline_handle(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn retained_inline_assert_full_layout(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing rebuilt paint') }).dump() == before
}

fn test_retained_inline_layout_reuses_lines_after_an_unrelated_comment_toggle() {
	mut document :=
		html.parse_document('<!doctype html><style>.closed p{display:none}#stable{width:190px;margin:17px 0;font:16px/20px SerenityMono}</style><div id="changed" class="closed"><p>expanded comment</p></div><p id="stable">Unchanged <strong>nested inline text</strong> wraps onto several lines.</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	root := retained_inline_handle(document, 'stable')
	previous := document_layout_result(document)?
	cached := previous.state.inline_layouts_[u64(voidptr(root))] or { panic('uncached paragraph') }
	assert cached.inputs[0].parent_id == 0
	old_commands := document.record_display_list()?
	old_dump := old_commands.dump()
	old_rect := document.get_element_by_id('stable')?.get_bounding_client_rect()
	mut changed := document.get_element_by_id('changed')?
	changed.set_attribute_value('class', '')
	document.update_layout(.debugging)
	current := document_layout_result(document)?
	reused := current.state.inline_layouts_[u64(voidptr(root))] or { panic('lost paragraph') }
	assert voidptr(reused) == voidptr(cached)
	new_rect := document.get_element_by_id('stable')?.get_bounding_client_rect()
	assert new_rect.y > old_rect.y
	assert new_rect.height == old_rect.height
	assert old_commands.dump() == old_dump
	assert current.state.previous_inline_layouts_.len == 0
	retained_inline_assert_full_layout(mut document)
}

fn test_retained_inline_layout_rewraps_after_width_style_text_and_tree_changes() {
	mut document :=
		html.parse_document('<!doctype html><div id="changed"></div><section id="width" style="width:300px"><p id="stable">Retained text <strong id="strong">needs to wrap correctly</strong> when its width changes.</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut width := document.get_element_by_id('width')?
	width.set_attribute_value('style', 'width:100px')
	document.update_layout(.debugging)
	retained_inline_assert_full_layout(mut document)
	mut strong := document.get_element_by_id('strong')?
	strong.set_attribute_value('style', 'font-size:25px;letter-spacing:2px')
	document.update_layout(.debugging)
	retained_inline_assert_full_layout(mut document)
	mut strong_node := strong.as_node()
	strong_node.set_text_content('A different, much longer replacement text')!
	document.update_layout(.debugging)
	retained_inline_assert_full_layout(mut document)
	mut stable := document.get_element_by_id('stable')?
	stable.set_inner_html('<em>new children</em> and different trailing text')!
	document.update_layout(.debugging)
	retained_inline_assert_full_layout(mut document)
}

fn test_retained_inline_layout_keeps_float_clamp_positioned_and_first_letter_dependencies_live() {
	for content in [
		'<div style="float:left;width:120px;height:100px"></div><p id="stable">text wrapping beside a float whose size can affect every line</p>',
		'<div style="max-lines:2;continue:discard"><p id="stable">one two three four five six seven eight nine ten</p></div>',
		'<p id="stable">before <span style="position:relative;top:3px">positioned</span> after</p>',
		'<style>p::first-letter{font-size:40px}</style><p id="stable">First letter and remaining text</p>',
		'<p id="stable">before <span style="display:inline-block;width:40%">atomic content</span> after</p>',
	] {
		mut document := html.parse_document(
			'<!doctype html><div id="changed"></div><section style="width:200px">' + content +
			'</section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		mut changed := document.get_element_by_id('changed')?
		changed.set_inner_html('<p>new preceding content</p>')!
		document.update_layout(.debugging)
		retained_inline_assert_full_layout(mut document)
	}
}

fn test_retained_inline_layout_does_not_share_mutable_line_fragments_with_old_geometry() {
	mut document :=
		html.parse_document('<!doctype html><div id="changed"></div><p id="stable">A stable paragraph with several words.</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	root := retained_inline_handle(document, 'stable')
	previous := document_layout_result(document)?
	styled := root.as_node_with_style()?
	old := previous.state.try_get(styled)?
	old_length := old.line_boxes[0].fragments_[0].inline_length_
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p>new preceding content</p>')!
	document.update_layout(.debugging)
	current := document_layout_result(document)?
	mut used := current.state.try_get_mutable(styled)?
	used.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(777)
	assert old.line_boxes[0].fragments_[0].inline_length_ == old_length
	cached := current.state.inline_layouts_[u64(voidptr(root))] or {
		panic('missing retained lines')
	}
	assert cached.lines[0].fragments_[0].inline_length_ == old_length
	gc_collect()
	assert old.line_boxes[0].fragments_[0].inline_length_ == old_length
}
