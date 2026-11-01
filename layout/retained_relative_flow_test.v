module layout

import dom
import html

fn relative_flow_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing element') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn relative_flow_assert_full_layout(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing rebuilt paint') }).dump() == before
}

fn test_unshifted_relative_inline_and_independent_layout_survive_an_external_change() {
	for independent in [false, true] {
		style := if independent { 'overflow:hidden;' } else { '' }
		mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="position:relative;width:180px;${style}">Several <span style="position:relative">unchanged words</span> wrap across lines.</section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		root := relative_flow_node(document, 'stable')
		key := u64(voidptr(root))
		before := document_layout_result(document) or { panic('missing layout') }
		old_y := document.get_element_by_id('stable')?.get_bounding_client_rect().y
		mut changed := document.get_element_by_id('changed')?
		changed.set_attribute_value('style', 'height:50px')
		document.update_layout(.debugging)
		after := document_layout_result(document) or { panic('missing current layout') }
		if independent {
			assert voidptr(before.state.block_layouts_[key] or { panic('missing block cache') }) ==
				voidptr(after.state.block_layouts_[key] or { panic('missing retained block cache') })
		} else {
			assert voidptr(before.state.inline_layouts_[key] or { panic('missing inline cache') }) ==
				voidptr(after.state.inline_layouts_[key] or { panic('missing retained inline cache') })
		}
		assert document.get_element_by_id('stable')?.get_bounding_client_rect().y == old_y + 50
		relative_flow_assert_full_layout(mut document)
	}
}

fn test_relative_layout_keeps_explicit_offsets_sticky_and_absolute_descendants_uncached() {
	for independent in [false, true] {
		for content in ['<span style="position:relative;top:10%">shifted</span>',
			'<span style="position:relative;left:0">explicit offset</span>',
			'<span style="position:sticky;top:0">sticky</span>',
			'<span style="position:absolute;top:10%">absolute</span>'] {
			style := if independent { 'overflow:hidden;' } else { '' }
			mut document := html.parse_document('<!doctype html><section id="stable" style="position:relative;width:180px;${style}">before ${content} after</section>')
			defer { document.finalize() }
			_ = layout_document_typed_in_viewport(document, 400, 300)
			root := relative_flow_node(document, 'stable')
			result := document_layout_result(document) or { panic('missing layout') }
			if independent { assert u64(voidptr(root)) !in result.state.block_layouts_ }
			else { assert u64(voidptr(root)) !in result.state.inline_layouts_ }
			relative_flow_assert_full_layout(mut document)
		}
	}
}

fn test_relative_layout_rechecks_offsets_and_containing_space_after_mutation() {
	for independent in [false, true] {
		style := if independent { 'overflow:hidden;' } else { '' }
		mut document := html.parse_document('<!doctype html><div id="parent" style="height:100px;width:300px"><section id="stable" style="position:relative;width:80%;${style}">Wrapping text with <span id="shift" style="position:relative">relative content</span> after it.</section></div>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		mut shift := document.get_element_by_id('shift')?
		shift.set_attribute_value('style', 'position:relative;top:10%')
		document.update_layout(.debugging)
		relative_flow_assert_full_layout(mut document)
		mut parent := document.get_element_by_id('parent')?
		for changed in ['height:200px;width:120px', 'height:60px;width:280px'] {
			parent.set_attribute_value('style', changed)
			document.update_layout(.debugging)
			relative_flow_assert_full_layout(mut document)
		}
	}
}
