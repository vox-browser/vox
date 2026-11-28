module layout

import dom
import html

fn block_paint_test_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing ' + id) }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn block_paint_test_compare(document &dom.Document, ids []string) {
	result := document_layout_result(document) or { panic('missing layout result') }
	for id in ids {
		node := block_paint_test_node(document, id)
		actual := block_box_from_typed_layout_shallow(node, result.state, [6]f64{})
		expected := uncached_block_box_from_typed_layout_shallow(node, result.state, [6]f64{})
		assert actual.scrollable_overflow == expected.scrollable_overflow
		assert retained_paint_payload_equal(actual, expected)
		used := result.state.try_get(node.as_node_with_style() or { panic('missing style') }) or { panic('missing geometry') }
		position := paint_cumulative_offset(node, result.state, used)
		assert retained_paint_payload_equal(text_lines_from_typed_layout(node, used, result.state, position),
			uncached_text_lines_from_typed_layout(node, used, result.state, position))
	}
}

fn test_retained_block_paint_rebases_atomic_menu_and_box_decorations_without_old_arena_links() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="overflow:hidden;width:180px"><p id="body" style="border:2px solid blue;border-radius:4px;outline:1px solid green;box-shadow:2px 3px 4px gray">Comment with <strong>decorated words</strong>.</p><ul id="menu" style="padding:0"><li style="display:inline"><span id="action" style="display:inline-block;max-width:80%;background:yellow">A wrapping action label</span></li><li style="display:inline"><a style="display:inline-block">reply</a></li></ul></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	old := document.record_display_list()?
	retained_scene := retain_display_list_scene(old)
	defer { release_display_list_scene(retained_scene) }
	old_commands := display_list_commands(old).clone()
	root := block_paint_test_node(document, 'stable')
	cache := document_layout_result(document)?.state.block_layouts_[u64(voidptr(root))] or { panic('missing independent flow') }
	assert cache.paint_boxes_.len > 0 && cache.paint_lines_.len > 0
	for _, snapshot in cache.paint_boxes_ {
		assert snapshot.box.children.len == 0 && snapshot.box.lines.len == 0
	}
	mut changed := document.get_element_by_id('changed')?
	for content in ['<p>Expanded preceding comment</p>', '', '<p>one</p><p>two</p>'] {
		changed.set_inner_html(content)!
		document.update_layout(.debugging)
		assert voidptr(document_layout_result(document)?.state.block_layouts_[u64(voidptr(root))]) == voidptr(cache)
		block_paint_test_compare(document, ['body', 'menu', 'action'])
		assert display_list_commands(old).clone() == old_commands
	}
}

fn test_retained_block_paint_invalidates_for_changed_geometry_text_and_inherited_style() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="overflow:hidden;width:180px"><p id="body">Comment body</p><span id="action" style="display:inline-block">reply</span></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut stable := document.get_element_by_id('stable')?
	for style in ['overflow:hidden;width:90px', 'overflow:hidden;width:220px;font-size:24px;color:red',
		'overflow:hidden;width:180px'] {
		stable.set_attribute_value('style', style)
		document.update_layout(.debugging)
		block_paint_test_compare(document, ['body', 'action'])
	}
	mut body := document.get_element_by_id('body')?
	body.set_inner_html('New content with more wrapping lines')!
	document.update_layout(.debugging)
	block_paint_test_compare(document, ['body', 'action'])
	before := (document.record_display_list()?).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list()?).dump() == before
}

fn test_retained_block_paint_keeps_transforms_filters_and_image_resources_on_full_builder() {
	for style in ['transform:translateX(3px)', 'filter:blur(1px)',
		'background-image:linear-gradient(red,blue)', 'background-image:url(example.png)'] {
		mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="overflow:hidden;width:180px"><p id="special" style=\'' + style + '\'>Specialized paint</p><span style="display:inline-block">reply</span></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		_ = document.record_display_list()?
		node := block_paint_test_node(document, 'special')
		result := document_layout_result(document)?
		if owner := result.state.block_paint_owners_[u64(voidptr(node))] {
			assert u64(voidptr(node)) !in owner.paint_boxes_
		}
		mut changed := document.get_element_by_id('changed')?
		changed.set_inner_html('<p>move everything</p>')!
		document.update_layout(.debugging)
		block_paint_test_compare(document, ['special'])
	}
}

fn percentage_flex_line_markup(text string) string {
	return '<!doctype html><style>body{margin:0;font:16px/20px sans-serif}#row{display:flex;width:300px}#item{flex:none;width:120px;border:1px solid}#item p{margin:4px}#fill{height:50%;background:#ccc}#other{flex:1;min-width:0;border:1px solid}</style><body><div id="row"><div id="item"><p>one</p><p>two words here</p><div id="fill">fill</div></div><div id="other">${text}</div></div></body>'
}

// A percentage height resolves against a stretched flex item's definite
// height. When a sibling grows the flex line, the item's block layout stays
// current while the percentage box gets a new height; its retained paint box
// must not be rebased from the old size.
fn test_retained_block_paint_follows_percentage_heights_in_a_growing_flex_line() {
	mut document := html.parse_document(percentage_flex_line_markup('other'))
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 400)
	mut other := document.get_element_by_id('other') or { panic('other') }
	mut text := other.as_node().first_child() or { panic('other text') }
	for value in ['other changed', 'other changed again, with many more words that wrap onto several further lines',
		'short'] {
		text.set_node_value(value) or { panic(err) }
		document.update_layout(.debugging)
		mut fresh := html.parse_document(percentage_flex_line_markup(value))
		_ = layout_document_typed_in_viewport(fresh, 400, 400)
		expected := (fresh.record_display_list() or { panic('fresh paint') }).dump()
		fresh.finalize()
		assert (document.record_display_list() or { panic('paint') }).dump() == expected, value
	}
}
